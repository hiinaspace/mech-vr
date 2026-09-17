class_name MeleePhysics
extends Node3D
## Reduced free-space machine: torso and endpoint masses, no articulated joints.
## All normal motion comes from finite forces. Only reset teleports bodies.
const BLADE_BASE := Vector3(0, .65, -.15)
const BLADE_TIP := Vector3(0, 6.35, -.15)
const BLADE_RADIUS := .16
const SHIELD_SIZE := Vector3(4, 6, .4)
const COCKPIT_OFFSET := Vector3(0, 4.9, -1)
const NEUTRALS := [Vector3(-5, 2.9, -6), Vector3(5, 2.9, -6)]
const LAYER := 16
const BEAM_LAYER := 32
const TORSO_SIZE := Vector3(4.8, 4.2, 2.5)
const FIXTURE_SIZE := Vector3(7, 10, .6)
var armor_provider: Callable

var rigs: Array[Dictionary] = []
var fixture: StaticBody3D
var opponent_fixed := true
var opponent_mode := "guard"
var fixture_enabled := false
## Responsiveness changes PD bandwidth independently of mechanical strength.
var arm_response := 1.0
## Commanded downswing radians/second; actual motion is motor/contact limited.
var _slash_clock := 0.0
var slash_speed := 2.5:
	set(value):
		# Preserve the current authored phase and its fractional progress. Changing
		# duration must not reinterpret all elapsed fight time against a new cycle.
		var old_duration := 3.0 / clampf(slash_speed, .25, 12.0)
		var new_duration := 3.0 / clampf(value, .25, 12.0)
		var phase := fposmod(_slash_clock, 2.85 + old_duration)
		if phase >= 1.5 and phase < 1.5 + old_duration:
			phase = 1.5 + (phase - 1.5) * new_duration / old_duration
		elif phase >= 1.5 + old_duration:
			phase += new_duration - old_duration
		_slash_clock = phase
		slash_speed = value
var slash_phase := "guard"
var arm_force_limit := 18000.0
var arm_torque_limit := 18000.0
var thrust_limit := 90000.0
var attitude_limit := 150000.0
var motors_enabled := true
var thrusters_enabled := true
var desired_basis := Basis.IDENTITY
var player_boost := false
var boost_thrust_scale := 2.5
var paused := false
var _saved_velocities: Array[Dictionary] = []
var _time := 0.0
var _velocity_command := Vector3.ZERO
var _angular_command := Vector3.ZERO

func setup() -> void:
	if not rigs.is_empty(): return
	process_physics_priority = 100
	for i in 2:
		var torso := _body("PlayerTorso" if i == 0 else "OpponentTorso", 6000.0, TORSO_SIZE, Vector3.ZERO)
		torso.inertia = Vector3(22000, 14000, 26000)
		torso.set_meta("rig", i)
		torso.set_meta("part", "torso")
		var weapons: Array[RigidBody3D] = []
		weapons.append(_body("Shield%d" % i, 250, SHIELD_SIZE, Vector3.ZERO))
		weapons.append(_body("Sword%d" % i, 100, Vector3(.32, 5.7, .32), (BLADE_BASE + BLADE_TIP) * .5))
		for h in 2:
			weapons[h].set_meta("rig", i)
			weapons[h].set_meta("part", "shield" if h == 0 else "sword")
		weapons[0].inertia = Vector3(800, 400, 1100)
		weapons[1].inertia = Vector3(450, 40, 450)
		# Beam fields resist other beam fields, but armor only absorbs energy.
		weapons[1].collision_layer = BEAM_LAYER
		weapons[1].collision_mask = BEAM_LAYER
		var members: Array[RigidBody3D] = [torso, weapons[0], weapons[1]]
		for a in members:
			for b in members:
				if a != b: a.add_collision_exception_with(b)
		rigs.append({"torso": torso, "weapons": weapons, "commands": [Transform3D.IDENTITY, Transform3D.IDENTITY], "loads": [{}, {}], "thrust": Vector3.ZERO, "attitude": Vector3.ZERO})
	fixture = StaticBody3D.new()
	fixture.name = "ContactPlate"
	fixture.set_meta("rig", -1)
	fixture.set_meta("part", "fixture")
	fixture.collision_layer = 0
	fixture.collision_mask = 0
	add_child(fixture)
	fixture.position = Vector3(5, 4.9, -7)
	_shape(fixture, FIXTURE_SIZE, Vector3.ZERO)
	reset()

func _body(label: String, body_mass: float, size: Vector3, shape_offset: Vector3) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = label
	b.mass = body_mass
	b.gravity_scale = 0.0
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = 0.0
	b.angular_damp = 0.0
	b.can_sleep = false
	b.continuous_cd = true
	b.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	b.center_of_mass = Vector3.ZERO
	b.collision_layer = LAYER
	b.collision_mask = LAYER
	b.contact_monitor = true
	b.max_contacts_reported = 12
	var material := PhysicsMaterial.new()
	material.friction = .22
	material.bounce = 0.0
	b.physics_material_override = material
	add_child(b)
	_shape(b, size, shape_offset)
	return b

func _shape(body: CollisionObject3D, size: Vector3, offset: Vector3) -> void:
	var c := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	c.shape = box
	c.position = offset
	body.add_child(c)

func command_player(grips: Array[Transform3D], velocity: Vector3, angular_velocity: Vector3) -> void:
	if rigs.is_empty(): return
	for i in mini(grips.size(), 2): rigs[0].commands[i] = grips[i]
	# Commands are body-frame velocities, independent of HMD orientation.
	_velocity_command = velocity.limit_length(30)
	_angular_command = angular_velocity.limit_length(1.5)

func set_opponent_fixed(value: bool) -> void:
	opponent_fixed = value
	if rigs.size() > 1:
		rigs[1].torso.freeze = value or paused
		rigs[1].torso.linear_velocity = Vector3.ZERO
		rigs[1].torso.angular_velocity = Vector3.ZERO

func set_opponent_mode(value: String) -> void:
	opponent_mode = "cut" if value == "cut" else "guard"
	_time = 0.0
	_slash_clock = 0.0
	if rigs.size() > 1: rigs[1].commands[1] = _guard_pose()

func set_fixture_enabled(value: bool) -> void:
	var changed := value != fixture_enabled
	fixture_enabled = value
	if is_instance_valid(fixture):
		fixture.collision_layer = LAYER if value else 0
		fixture.collision_mask = LAYER if value else 0
	# A slab comparison isolates that fixture: keep all enemy collisions far
	# away. Scenario changes already reset in the lab; this also works standalone.
	if changed and rigs.size() > 1:
		var shift := Vector3(100 if value else -100, 0, 0)
		for body in [rigs[1].torso, rigs[1].weapons[0], rigs[1].weapons[1]]:
			body.global_position += shift

func reset() -> void:
	_time = 0.0
	_slash_clock = 0.0
	slash_phase = "guard"
	_velocity_command = Vector3.ZERO
	_angular_command = Vector3.ZERO
	desired_basis = Basis.IDENTITY
	player_boost = false
	for saved in _saved_velocities:
		saved.linear = Vector3.ZERO
		saved.angular = Vector3.ZERO
	for i in rigs.size():
		var rig := rigs[i]
		rig.thrust = Vector3.ZERO
		rig.attitude = Vector3.ZERO
		var body_frame := Transform3D.IDENTITY if i == 0 else Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -13))
		if i == 1 and fixture_enabled: body_frame.origin.x += 100
		_clear_body(rig.torso, body_frame)
		for hand in 2:
			var command := Transform3D(Basis.IDENTITY, NEUTRALS[hand])
			# Put the enemy blade in front of the player's right hand, crossing
			# its upright blade. Finite motors hold this same guard when free.
			if i == 1 and hand == 1:
				command = _guard_pose()
			rig.commands[hand] = command
			_clear_body(rig.weapons[hand], body_frame * command)
			rig.loads[hand] = {"force": Vector3.ZERO, "torque": Vector3.ZERO, "error": 0.0, "effort": 0.0}
		set_opponent_fixed(opponent_fixed)
	_update_beam_shapes(query_beam_contacts())

func _clear_body(body: RigidBody3D, pose: Transform3D) -> void:
	body.global_transform = pose
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.constant_force = Vector3.ZERO
	body.constant_torque = Vector3.ZERO
	body.sleeping = false

func _physics_process(delta: float) -> void:
	if rigs.is_empty() or paused: return
	_time += delta
	_update_beam_shapes(query_beam_contacts())
	if opponent_mode == "cut":
		_slash_clock += delta
		rigs[1].commands[1] = opponent_slash_pose(_slash_clock)
	else:
		slash_phase = "guard"
	for index in rigs.size():
		var rig := rigs[index]
		var torso: RigidBody3D = rig.torso
		for hand in 2: _drive_arm(rig, hand, delta)
		var desired_v := torso.global_basis * _velocity_command if index == 0 else Vector3.ZERO
		var desired_w := torso.global_basis * _angular_command if index == 0 else Vector3.ZERO
		var thrust_budget := maxf(thrust_limit, 0.0) * (clampf(boost_thrust_scale, 1.0, 4.0) if index == 0 and player_boost else 1.0)
		var force := ((desired_v - torso.linear_velocity) * torso.mass * 3.0).limit_length(thrust_budget) if thrusters_enabled else Vector3.ZERO
		var target_basis := desired_basis if index == 0 else Basis(Vector3.UP, PI)
		var attitude_error := _rotation_error(target_basis, torso.global_basis)
		var torque := (attitude_error * 90000.0 + (desired_w - torso.angular_velocity) * 60000.0).limit_length(maxf(attitude_limit, 0.0)) if thrusters_enabled else Vector3.ZERO
		if not torso.freeze:
			torso.apply_central_force(force)
			torso.apply_torque(torque)
		rig.thrust = force
		rig.attitude = torque

func _drive_arm(rig: Dictionary, hand: int, delta: float) -> void:
	var torso: RigidBody3D = rig.torso
	var weapon: RigidBody3D = rig.weapons[hand]
	var target: Transform3D = torso.global_transform * rig.commands[hand]
	var lever := weapon.global_position - torso.global_position
	var relative_v := weapon.linear_velocity - torso.linear_velocity - torso.angular_velocity.cross(lever)
	var error := target.origin - weapon.global_position
	# Implicit single-body PD gains keep the damping stable when bandwidth rises.
	# Coupled bodies/contact still need finite limits and simulation validation.
	# No integrator; clipped positional error cannot store accumulated windup.
	var response := clampf(arm_response, .25, 4.0)
	var kp := 11000.0 * response * response
	var kd := 2000.0 * response
	var denominator := 1.0 + (kd * delta + kp * delta * delta) / weapon.mass
	var force := ((error.limit_length(2.0) * kp - relative_v * (kd + kp * delta)) / denominator).limit_length(maxf(arm_force_limit, 0.0))
	var rotation_error := weapon.global_basis.inverse() * _rotation_error(target.basis, weapon.global_basis)
	var relative_w := weapon.global_basis.inverse() * (weapon.angular_velocity - torso.angular_velocity)
	kp = 14000.0 * response * response
	kd = 3200.0 * response
	var local_torque := Vector3.ZERO
	for axis in 3:
		denominator = 1.0 + (kd * delta + kp * delta * delta) / weapon.inertia[axis]
		local_torque[axis] = (rotation_error[axis] * kp - relative_w[axis] * (kd + kp * delta)) / denominator
	var torque := (weapon.global_basis * local_torque).limit_length(maxf(arm_torque_limit, 0.0))
	if not motors_enabled:
		force = Vector3.ZERO
		torque = Vector3.ZERO
	weapon.apply_central_force(force)
	weapon.apply_torque(torque)
	# Complete equal/opposite wrench, including the displaced force's moment.
	if not torso.freeze:
		torso.apply_central_force(-force)
		torso.apply_torque(-torque - lever.cross(force))
	rig.loads[hand] = {"force": force, "torque": torque, "error": error.length(), "effort": maxf(force.length() / maxf(arm_force_limit, 1), torque.length() / maxf(arm_torque_limit, 1))}

func capture_snapshot() -> Dictionary:
	return snapshot()

func snapshot() -> Dictionary:
	var result: Array[Dictionary] = []
	var contacts: Array[Dictionary] = []
	for i in rigs.size():
		var rig := rigs[i]
		var torso: RigidBody3D = rig.torso
		var grips: Array[Transform3D] = []
		var commands: Array[Transform3D] = []
		for h in 2:
			var weapon: RigidBody3D = rig.weapons[h]
			grips.append(weapon.global_transform)
			commands.append(torso.global_transform * rig.commands[h])
			var state := PhysicsServer3D.body_get_direct_state(weapon.get_rid())
			if state:
				# Godot uses "local" to mean this body; these are already world-space.
				for c in state.get_contact_count():
					var contact := {"rig": i, "hand": h, "position": state.get_contact_local_position(c), "normal": state.get_contact_local_normal(c), "impulse": state.get_contact_impulse(c)}
					var collider := state.get_contact_collider_object(c) as CollisionObject3D
					if h == 1 and collider:
						contact["saber_rig"] = i
						contact["saber_hand"] = 1
						contact["target_rig"] = int(collider.get_meta("rig", -1))
						contact["target_part"] = str(collider.get_meta("part", "other"))
						contact["target_local_position"] = collider.global_transform.affine_inverse() * state.get_contact_collider_position(c)
					contacts.append(contact)
		result.append({"body": torso.global_transform, "grips": grips, "commands": commands, "loads": rig.loads.duplicate(true), "velocity": torso.linear_velocity, "angular_velocity": torso.angular_velocity, "thrust": rig.thrust, "attitude": rig.attitude, "commanded_basis": desired_basis if i == 0 else Basis(Vector3.UP, PI), "boost": i == 0 and player_boost, "effective_thrust_limit": maxf(thrust_limit, 0.0) * (clampf(boost_thrust_scale, 1.0, 4.0) if i == 0 and player_boost else 1.0)})
	var beam_contacts := query_beam_contacts()
	for rig in result: rig["blade_fraction"] = 1.0
	for contact in beam_contacts: result[contact.saber_rig].blade_fraction = contact.blade_fraction
	return {"time": _time, "rigs": result, "contacts": contacts, "beam_contacts": beam_contacts, "opponent_fixed": opponent_fixed, "opponent_mode": opponent_mode, "fixture_enabled": fixture_enabled, "opponent_visible": not fixture_enabled, "slash_phase": slash_phase, "tuning": tuning_snapshot()}

func _rotation_error(target: Basis, actual: Basis) -> Vector3:
	var q := (target * actual.inverse()).get_rotation_quaternion().normalized()
	if q.w < 0: q = -q
	var angle := q.get_angle()
	return q.get_axis() * angle if angle > .00001 else Vector3.ZERO

func set_paused(value: bool) -> void:
	if paused == value: return
	paused = value
	if value:
		_saved_velocities.clear()
		for rig in rigs:
			for body in [rig.torso, rig.weapons[0], rig.weapons[1]]:
				_saved_velocities.append({"body": body, "linear": body.linear_velocity, "angular": body.angular_velocity})
				body.freeze = true
	else:
		for saved in _saved_velocities:
			saved.body.freeze = saved.body == rigs[1].torso and opponent_fixed
			saved.body.linear_velocity = saved.linear
			saved.body.angular_velocity = saved.angular
		_saved_velocities.clear()

func _guard_pose() -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(-2, 5.9, -6))

func opponent_slash_pose(elapsed: float) -> Transform3D:
	# Local +Z is behind the enemy. Wind up over the shoulder, pause visibly,
	# then sweep down/forward through a three-radian sagittal arc. Both position
	# and orientation are requests to the same finite motors used by the player.
	var duration := 3.0 / clampf(slash_speed, .25, 12.0)
	var phase := fposmod(elapsed, .9 + .6 + duration + .35 + 1.0)
	var high := Transform3D(Basis(Vector3.RIGHT, .6), Vector3(5, 7.0, -5.0))
	var low := Transform3D(Basis(Vector3.RIGHT, -2.4), Vector3(5, 4.8, -6.0))
	if phase < .9:
		slash_phase = "windup"
		return _guard_pose().interpolate_with(high, smoothstep(0.0, .9, phase))
	phase -= .9
	if phase < .6:
		slash_phase = "ready"
		return high
	phase -= .6
	if phase < duration:
		slash_phase = "slash"
		var fraction := phase / duration
		return Transform3D(Basis(Vector3.RIGHT, lerpf(.6, -2.4, fraction)), high.origin.lerp(low.origin, fraction))
	phase -= duration
	if phase < .35:
		slash_phase = "follow-through"
		return low
	slash_phase = "recover"
	return low.interpolate_with(_guard_pose(), smoothstep(0.0, 1.0, phase - .35))

func tuning_snapshot() -> Dictionary:
	return {"arm_response": arm_response, "slash_speed": slash_speed, "arm_force_limit": arm_force_limit, "arm_torque_limit": arm_torque_limit, "thrust_limit": thrust_limit, "attitude_limit": attitude_limit}

func capture_command() -> Dictionary:
	return {"grips": rigs[0].commands.duplicate(true), "velocity": _velocity_command, "angular_velocity": _angular_command, "desired_basis": desired_basis, "boost": player_boost}

func apply_command(command: Dictionary) -> void:
	var grips: Array[Transform3D] = []
	for pose in command.get("grips", []): grips.append(pose)
	command_player(grips, command.get("velocity", Vector3.ZERO), command.get("angular_velocity", Vector3.ZERO))
	desired_basis = command.get("desired_basis", desired_basis)
	player_boost = bool(command.get("boost", false))

func query_beam_contacts() -> Array[Dictionary]:
	# Query the entire authored beam every time, independently of its visually
	# shortened end. This is centerline/armor overlap, not a damage/impact solver.
	var contacts: Array[Dictionary] = []
	var armor: Array = []
	if armor_provider.is_valid():
		var pose_rigs: Array = []
		for rig in rigs:
			pose_rigs.append({"body":rig.torso.global_transform,"grips":[rig.weapons[0].global_transform,rig.weapons[1].global_transform]})
		armor = armor_provider.call({"rigs":pose_rigs,"opponent_visible":not fixture_enabled})
	else:
		for target_rig in rigs.size():
			armor.append({"target_rig":target_rig,"target_part":"torso","transform":rigs[target_rig].torso.global_transform,"size":TORSO_SIZE})
			armor.append({"target_rig":target_rig,"target_part":"shield","transform":rigs[target_rig].weapons[0].global_transform,"size":SHIELD_SIZE})
	if fixture_enabled: armor.append({"target_rig":-1,"target_part":"fixture","transform":fixture.global_transform,"size":FIXTURE_SIZE})
	for saber_rig in rigs.size():
		var sword: RigidBody3D = rigs[saber_rig].weapons[1]
		var start := sword.global_transform * BLADE_BASE
		var end := sword.global_transform * BLADE_TIP
		var closest: Dictionary = {}
		for candidate in armor:
			if int(candidate.target_rig)==saber_rig: continue
			var hit := segment_box_entry(start,end,candidate.transform,candidate.size)
			if hit.is_empty(): continue
			if not closest.is_empty() and hit.blade_fraction >= closest.blade_fraction: continue
			hit["saber_rig"] = saber_rig
			hit["saber_hand"] = 1
			hit["target_rig"] = int(candidate.target_rig)
			hit["target_part"] = str(candidate.target_part)
			if candidate.has("target_leaf"):
				hit["target_leaf"] = int(candidate.target_leaf)
				hit["target_mesh_local"] = hit.target_local_position
			closest = hit
		if not closest.is_empty(): contacts.append(closest)
	return contacts

static func segment_box_entry(start: Vector3, end: Vector3, frame: Transform3D, size: Vector3) -> Dictionary:
	var local_start := frame.affine_inverse() * start
	var local_end := frame.affine_inverse() * end
	var direction := local_end - local_start
	var half := size * .5
	var near := 0.0
	var far := 1.0
	var entry_normal := Vector3.ZERO
	var starts_inside := true
	for axis in 3:
		if absf(local_start[axis]) > half[axis]: starts_inside = false
		if absf(direction[axis]) < .000001:
			if absf(local_start[axis]) > half[axis]: return {}
			continue
		var a: float = (-half[axis] - local_start[axis]) / direction[axis]
		var b: float = (half[axis] - local_start[axis]) / direction[axis]
		var entry := minf(a, b)
		var exit := maxf(a, b)
		if entry > near:
			near = entry
			entry_normal = Vector3.ZERO
			entry_normal[axis] = -signf(direction[axis])
		far = minf(far, exit)
		if near > far: return {}
	if far < 0.0 or near > 1.0: return {}
	# If the emitter is already inside armor, absorption starts at its base.
	# Do not jump to the exit surface or draw the beam through that material.
	var position := start.lerp(end, near)
	return {"position": position, "normal": (frame.basis.inverse().transposed() * entry_normal).normalized(), "target_local_position": local_start.lerp(local_end, near), "distance": start.distance_to(position), "blade_fraction": near, "exit_fraction": far, "starts_inside": starts_inside}

func _update_beam_shapes(contacts: Array[Dictionary]) -> void:
	# Only the unabsorbed field can resist a second blade. Keep the full authored
	# query above independent from this collision extent to avoid feedback where
	# touching armor removes the very overlap needed to keep the beam clipped.
	var fractions := [1.0, 1.0]
	for contact in contacts: fractions[contact.saber_rig] = contact.blade_fraction
	for i in rigs.size():
		var shape: CollisionShape3D = rigs[i].weapons[1].get_child(0)
		var box := shape.shape as BoxShape3D
		var fraction: float = fractions[i]
		shape.disabled = fraction <= .0001
		var length := maxf(.001, BLADE_BASE.distance_to(BLADE_TIP) * fraction)
		var size := Vector3(.32, length, .32)
		if not box.size.is_equal_approx(size): box.size = size
		shape.position = BLADE_BASE.lerp(BLADE_TIP, fraction * .5)
