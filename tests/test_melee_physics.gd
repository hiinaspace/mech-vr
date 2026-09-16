extends SceneTree
const Physics = preload("res://scripts/melee_physics.gd")
var lab: MeleePhysics
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(caption)
func step(count: int) -> void:
	for i in count: await physics_frame
func commands(z := -6.0) -> Array[Transform3D]:
	return [Transform3D(Basis.IDENTITY, Vector3(-5,2.9,-6)), Transform3D(Basis.IDENTITY, Vector3(5,2.9,z))]
func run() -> void:
	lab = Physics.new()
	root.add_child(lab)
	lab.setup()
	await step(5)
	var sword: RigidBody3D = lab.rigs[0].weapons[1]
	var torso: RigidBody3D = lab.rigs[0].torso
	check(sword.continuous_cd and sword.gravity_scale == 0 and sword.linear_damp == 0, "Explicit CCD and zero-gravity/damping")
	lab.set_fixture_enabled(true)
	torso.freeze = true
	check(lab.rigs[1].torso.position.x > 90 and not lab.snapshot().opponent_visible, "Slab comparison isolates opponent collisions and marks it hidden")
	lab.command_player(commands(-9), Vector3.ZERO, Vector3.ZERO)
	var contacts := 0
	var contact_positions_valid := true
	var contact_metadata_valid := true
	for i in 240:
		await step(1)
		var current_contacts: Array = lab.snapshot().contacts
		contacts += current_contacts.size()
		for contact in current_contacts:
			contact_positions_valid = contact_positions_valid and absf(contact.position.z + 6.7) < .3
			contact_metadata_valid = contact_metadata_valid and contact.get("target_part", "") == "fixture" and contact.get("saber_rig", -1) == 0 and absf(contact.target_local_position.z - .3) < .2
	check(contacts > 0, "Solver reports actual blade/plate contact")
	check(contact_positions_valid, "Reported contacts are world-space on the plate surface")
	check(contact_metadata_valid, "Saber contacts identify target and local heat position")
	var blade_min_z := INF
	for x in [-.16, .16]:
		for y in [.65, 6.35]:
			for z in [-.31, .01]:
				blade_min_z = minf(blade_min_z, (sword.global_transform * Vector3(x,y,z)).z)
	check(blade_min_z > -6.8, "Plate blocks actual blade volume, including when grip deflects behind blade")
	check(lab.rigs[0].loads[1].error > .5, "Obstruction produces readable command error")
	check(lab.rigs[0].loads[1].force.length() <= lab.arm_force_limit + .1, "Arm force remains finite under obstruction")
	lab.command_player(commands(-4), Vector3.ZERO, Vector3.ZERO)
	await step(200)
	check(sword.global_position.z > -5.5, "Withdrawal releases physical contact")
	check(sword.linear_velocity.length() < 2, "Release settles without accumulated spring windup")
	lab.set_paused(true)
	var stopped := sword.global_transform
	await step(10)
	check(sword.global_transform.is_equal_approx(stopped), "Pause freezes simulation")
	lab.reset()
	lab.set_paused(false)
	await step(2)
	check(sword.linear_velocity.length() < .2 and sword.global_position.distance_to(Vector3(5,2.9,-6)) < .1, "Reset while paused clears stored velocities")
	lab.set_fixture_enabled(false)
	torso.freeze = false
	lab.set_opponent_fixed(false)
	lab.thrusters_enabled = false
	# Isolate internal wrench: drive sword in empty space, verify total linear
	# and angular momentum of all three dynamic parts remains near zero.
	lab.rigs[1].torso.position.x += 100
	for w in lab.rigs[1].weapons: w.position.x += 100
	lab.command_player(commands(-7), Vector3.ZERO, Vector3.ZERO)
	await step(30)
	var momentum := Vector3.ZERO
	var angular := Vector3.ZERO
	for b in [torso, lab.rigs[0].weapons[0], sword]:
		momentum += b.linear_velocity * b.mass
		var inertia_world: Basis = b.global_basis * Basis.from_scale(b.inertia) * b.global_basis.transposed()
		angular += inertia_world * b.angular_velocity + b.global_position.cross(b.mass * b.linear_velocity)
	print("wrench momentum ", momentum.length(), " angular ", angular.length())
	check(torso.linear_velocity.length() > .005, "Finite actuator transmits reaction into free torso")
	check(momentum.length() < 2, "Internal actuator conserves linear momentum")
	check(angular.length() < 100, "Complete internal wrench approximately conserves angular momentum")
	lab.reset()
	lab.thrusters_enabled = true
	lab.set_opponent_fixed(false)
	lab.thrusters_enabled = false
	# Free opponent: the player pushes the horizontal guard blade. Check that
	# real solver contacts transmit into the opponent rather than world mounting.
	var enemy_start: Vector3 = lab.rigs[1].torso.global_position
	lab.command_player(commands(-8), Vector3.ZERO, Vector3.ZERO)
	contacts = 0
	for i in 100:
		await step(1)
		contacts += lab.snapshot().contacts.size()
	check(contacts > 0, "Crossing blades make actual solver contact")
	check(lab.rigs[1].torso.global_position.distance_to(enemy_start) > .01, "Blade contact displaces free opponent torso")
	lab.reset()
	lab.thrusters_enabled = true
	lab.set_opponent_mode("cut")
	await step(120)
	check(lab.rigs[1].weapons[1].angular_velocity.length() > .01, "Repeated-cut bot drives dynamic blade through finite motors")
	lab.set_opponent_fixed(true)
	await step(300)
	lab.set_opponent_fixed(false)
	await step(2)
	check(lab.rigs[1].torso.linear_velocity.length() < 2 and lab.rigs[1].torso.angular_velocity.length() < 2, "Freeing loaded fixed base does not release accumulated force")
	lab.motors_enabled = false
	lab.thrusters_enabled = false
	await step(3)
	lab.set_paused(true)
	var before_v: Vector3 = sword.linear_velocity
	var before_w: Vector3 = sword.angular_velocity
	await step(180)
	lab.set_paused(false)
	await step(2)
	check(sword.linear_velocity.distance_to(before_v) < .01 and sword.angular_velocity.distance_to(before_w) < .01, "Long replay pause preserves velocity without accumulating launch impulse")
	# Authored slash crosses from overhead to down/forward in the enemy frame.
	lab.slash_speed = 3.0
	var high := lab.opponent_slash_pose(1.2)
	var middle := lab.opponent_slash_pose(2.0)
	var low := lab.opponent_slash_pose(2.55)
	check((high * Physics.BLADE_TIP).y > 11 and (low * Physics.BLADE_TIP).y < 1, "Overhead slash spans raised blade through low follow-through")
	check((middle * Physics.BLADE_TIP).z < -9, "Slash sweeps forward from the enemy, not sideways")
	lab.slash_speed = 6.0
	var fast_low := lab.opponent_slash_pose(2.05)
	check(fast_low.is_equal_approx(low), "Higher slash speed shortens target downswing duration")
	# Live editing retimes only the active slash phase, preserving the exact
	# requested pose. Subsequent ticks then advance at the new speed.
	lab.set_opponent_mode("cut")
	await step(165)
	var before_retime := lab.opponent_slash_pose(lab._slash_clock)
	check(lab.slash_phase == "slash", "Live-speed regression starts during downswing")
	var fight_time: float = lab.snapshot().time
	lab.slash_speed = 3.0
	var after_retime := lab.opponent_slash_pose(lab._slash_clock)
	check(before_retime.is_equal_approx(after_retime) and is_equal_approx(lab.snapshot().time, fight_time), "Live speed edit preserves mid-slash pose without resetting fight")
	await step(3)
	var advanced: Transform3D = lab.rigs[1].commands[1]
	var advanced_angle := before_retime.basis.get_rotation_quaternion().angle_to(advanced.basis.get_rotation_quaternion())
	check(advanced_angle > .02 and advanced_angle < .15, "Retimed slash progresses continuously at new speed")
	# Other phases retain their own elapsed time even after several cycles.
	for phase_time in [.4, 1.1, 2.65, 3.1]:
		lab.slash_speed = 3.0
		lab._slash_clock = phase_time + 3.85 * 4
		var prior := lab.opponent_slash_pose(lab._slash_clock)
		lab.slash_speed = 6.0
		check(prior.is_equal_approx(lab.opponent_slash_pose(lab._slash_clock)), "Speed edit preserves windup/ready/follow-through/recovery phase")
	# Response is distinct from force cap: both influence physical tracking.
	lab.motors_enabled = true
	lab.reset()
	torso.freeze = true
	lab.rigs[1].torso.position.x += 100
	for w in lab.rigs[1].weapons: w.position.x += 100
	lab.arm_response = .5
	lab.arm_force_limit = 100000
	lab.arm_torque_limit = 100000
	lab.command_player(commands(-4), Vector3.ZERO, Vector3.ZERO)
	await step(10)
	var soft_error: float = lab.rigs[0].loads[1].error
	lab.reset()
	lab.arm_response = 3.0
	lab.command_player(commands(-4), Vector3.ZERO, Vector3.ZERO)
	await step(10)
	var fast_error: float = lab.rigs[0].loads[1].error
	check(fast_error < soft_error * .6, "Higher response measurably increases free-space tracking speed")
	lab.reset()
	lab.arm_force_limit = 1800
	lab.command_player(commands(-4), Vector3.ZERO, Vector3.ZERO)
	await step(10)
	check(lab.rigs[0].loads[1].error > fast_error, "Low mechanical force cap limits high-response tracking")
	lab.arm_force_limit = 100000
	lab.set_fixture_enabled(true)
	lab.reset()
	lab.command_player(commands(-9), Vector3.ZERO, Vector3.ZERO)
	var bounded := true
	contacts = 0
	for i in 180:
		await step(1)
		contacts += lab.snapshot().contacts.size()
		for rig in lab.rigs:
			for load in rig.loads:
				bounded = bounded and load.force.is_finite() and load.torque.is_finite() and load.force.length() <= lab.arm_force_limit + .1 and load.torque.length() <= lab.arm_torque_limit + .1
	check(bounded and contacts > 0, "High response/strength remains finite under physical contact")
	# Actual saber-body and saber-shield contacts carry target-local information.
	lab.set_fixture_enabled(false)
	lab.reset()
	lab.motors_enabled = false
	lab.thrusters_enabled = false
	lab.set_opponent_fixed(true)
	sword.global_position = Vector3(0,-2,-10)
	sword.linear_velocity = Vector3(0,0,-3)
	var torso_contact := false
	for i in 100:
		await step(1)
		for contact in lab.snapshot().contacts:
			if contact.get("target_part", "") == "torso" and contact.get("target_rig", -1) == 1:
				torso_contact = true
				check(contact.target_local_position.is_finite(), "Torso heat position is finite")
		if torso_contact: break
	check(torso_contact, "Actual saber-torso contact exposes target metadata")
	lab.reset()
	lab.rigs[1].weapons[0].freeze = true
	lab.rigs[1].weapons[1].position.x += 100
	sword.global_position = Vector3(5,0,-5)
	sword.linear_velocity = Vector3(0,0,-3)
	var shield_contact := false
	for i in 100:
		await step(1)
		for contact in lab.snapshot().contacts:
			if contact.get("target_part", "") == "shield" and contact.get("target_rig", -1) == 1:
				shield_contact = true
		if shield_contact: break
	check(shield_contact, "Actual saber-shield contact exposes target metadata")
	lab.rigs[1].weapons[0].freeze = false
	lab.reset()
	torso.freeze = false
	lab.thrusters_enabled = true
	lab.thrust_limit = 10000
	lab.player_boost = true
	lab.command_player(commands(), Vector3(30,0,0), Vector3.ZERO)
	await step(3)
	var boosted: Dictionary = lab.snapshot().rigs[0]
	check(boosted.boost and is_equal_approx(boosted.thrust.length(),25000) and is_equal_approx(boosted.effective_thrust_limit,25000), "Boost increases finite player thrust budget")
	check(is_equal_approx(lab.snapshot().rigs[1].effective_thrust_limit,10000), "Player boost does not raise enemy thrust")
	var saved_command := lab.capture_command()
	lab.player_boost = false
	lab.desired_basis = Basis(Vector3.UP, .4)
	lab.apply_command(saved_command)
	check(lab.player_boost and lab.snapshot().rigs[0].commanded_basis.is_equal_approx(Basis.IDENTITY), "Command capture/application retains authority orientation and boost")
	lab.queue_free()
	print("MELEE_PHYSICS_CHECKS %d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
