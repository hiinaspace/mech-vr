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
var rigs: Array[Dictionary] = []
var fixture: StaticBody3D
var opponent_fixed := true
var opponent_mode := "guard"
var fixture_enabled := false
var arm_force_limit := 18000.0
var arm_torque_limit := 18000.0
var thrust_limit := 90000.0
var attitude_limit := 150000.0
var motors_enabled := true
var thrusters_enabled := true
var desired_basis := Basis.IDENTITY
var paused := false
var _saved_velocities: Array[Dictionary] = []
var _time := 0.0
var _velocity_command := Vector3.ZERO
var _angular_command := Vector3.ZERO

func setup() -> void:
	if not rigs.is_empty(): return
	process_physics_priority = 100
	for i in 2:
		var torso := _body("PlayerTorso" if i == 0 else "OpponentTorso", 6000.0, Vector3(4.8, 4.2, 2.5), Vector3.ZERO)
		torso.inertia = Vector3(22000, 14000, 26000)
		var weapons: Array[RigidBody3D] = []
		weapons.append(_body("Shield%d" % i, 250, SHIELD_SIZE, Vector3.ZERO))
		weapons.append(_body("Sword%d" % i, 100, Vector3(.32, 5.7, .32), (BLADE_BASE + BLADE_TIP) * .5))
		weapons[0].inertia = Vector3(800, 400, 1100)
		weapons[1].inertia = Vector3(450, 40, 450)
		var members: Array[RigidBody3D] = [torso, weapons[0], weapons[1]]
		for a in members:
			for b in members:
				if a != b: a.add_collision_exception_with(b)
		rigs.append({"torso": torso, "weapons": weapons, "commands": [Transform3D.IDENTITY, Transform3D.IDENTITY], "loads": [{}, {}], "thrust": Vector3.ZERO, "attitude": Vector3.ZERO})
	fixture = StaticBody3D.new()
	fixture.name = "ContactPlate"
	fixture.collision_layer = 0
	fixture.collision_mask = LAYER
	add_child(fixture)
	fixture.position = Vector3(5, 4.9, -7)
	_shape(fixture, Vector3(7, 10, .6), Vector3.ZERO)
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
	if rigs.size() > 1: rigs[1].commands[1] = _guard_pose()

func set_fixture_enabled(value: bool) -> void:
	var changed := value != fixture_enabled
	fixture_enabled = value
	if is_instance_valid(fixture): fixture.collision_layer = LAYER if value else 0
	# A slab comparison isolates that fixture: keep all enemy collisions far
	# away. Scenario changes already reset in the lab; this also works standalone.
	if changed and rigs.size() > 1:
		var shift := Vector3(100 if value else -100, 0, 0)
		for body in [rigs[1].torso, rigs[1].weapons[0], rigs[1].weapons[1]]:
			body.global_position += shift

func reset() -> void:
	_time = 0.0
	_velocity_command = Vector3.ZERO
	_angular_command = Vector3.ZERO
	desired_basis = Basis.IDENTITY
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
	if opponent_mode == "cut":
		# Slow periodic windup/cut: target moves, never the actual collision body.
		var phase := sin(_time * TAU / 5.0)
		rigs[1].commands[1] = Transform3D(Basis(Vector3.BACK, PI / 2 + phase * .8), Vector3(-2, 5.9, -6))
	for index in rigs.size():
		var rig := rigs[index]
		var torso: RigidBody3D = rig.torso
		for hand in 2: _drive_arm(rig, hand)
		var desired_v := torso.global_basis * _velocity_command if index == 0 else Vector3.ZERO
		var desired_w := torso.global_basis * _angular_command if index == 0 else Vector3.ZERO
		var force := ((desired_v - torso.linear_velocity) * torso.mass * 3.0).limit_length(thrust_limit) if thrusters_enabled else Vector3.ZERO
		var target_basis := desired_basis if index == 0 else Basis(Vector3.UP, PI)
		var attitude_error := _rotation_error(target_basis, torso.global_basis)
		var torque := (attitude_error * 90000.0 + (desired_w - torso.angular_velocity) * 60000.0).limit_length(attitude_limit) if thrusters_enabled else Vector3.ZERO
		if not torso.freeze:
			torso.apply_central_force(force)
			torso.apply_torque(torque)
		rig.thrust = force
		rig.attitude = torque

func _drive_arm(rig: Dictionary, hand: int) -> void:
	var torso: RigidBody3D = rig.torso
	var weapon: RigidBody3D = rig.weapons[hand]
	var target: Transform3D = torso.global_transform * rig.commands[hand]
	var lever := weapon.global_position - torso.global_position
	var relative_v := weapon.linear_velocity - torso.linear_velocity - torso.angular_velocity.cross(lever)
	var error := target.origin - weapon.global_position
	# Saturated position/velocity feedback; no integrator or stored windup.
	var force := (error.limit_length(2.0) * 11000.0 - relative_v * 2000.0).limit_length(arm_force_limit)
	var rotation_error := _rotation_error(target.basis, weapon.global_basis)
	var torque := (rotation_error * 14000.0 - (weapon.angular_velocity - torso.angular_velocity) * 3200.0).limit_length(arm_torque_limit)
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
					contacts.append({"rig": i, "hand": h, "position": state.get_contact_local_position(c), "normal": state.get_contact_local_normal(c), "impulse": state.get_contact_impulse(c)})
		result.append({"body": torso.global_transform, "grips": grips, "commands": commands, "loads": rig.loads.duplicate(true), "velocity": torso.linear_velocity, "angular_velocity": torso.angular_velocity, "thrust": rig.thrust, "attitude": rig.attitude})
	return {"time": _time, "rigs": result, "contacts": contacts, "opponent_fixed": opponent_fixed, "opponent_mode": opponent_mode, "fixture_enabled": fixture_enabled, "opponent_visible": not fixture_enabled}

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
