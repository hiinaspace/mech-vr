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
	for i in 240:
		await step(1)
		var current_contacts: Array = lab.snapshot().contacts
		contacts += current_contacts.size()
		for contact in current_contacts:
			contact_positions_valid = contact_positions_valid and absf(contact.position.z + 6.7) < .3
	check(contacts > 0, "Solver reports actual blade/plate contact")
	check(contact_positions_valid, "Reported contacts are world-space on the plate surface")
	check(sword.global_position.z > -7, "Plate blocks blade instead of allowing commanded pose through")
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
	lab.queue_free()
	print("MELEE_PHYSICS_CHECKS %d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
