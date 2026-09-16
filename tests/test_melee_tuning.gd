extends SceneTree
## Exercise lab wiring with an explicit command clock and real PhysicsServer ticks.
class TestAdapter:
	extends "res://scripts/input_adapter.gd"
	var current: Dictionary = {}
	func sample() -> Dictionary:
		return current.duplicate(true)
var scene
var input: TestAdapter
var checks := 0
var failures := 0
var dt := 0.0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func step() -> void:
	scene._physics_process(dt)
	await physics_frame
func steps(count: int) -> void:
	for i in count:
		await step()
func run() -> void:
	dt = 1.0 / Engine.physics_ticks_per_second
	scene = load("res://melee.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process(false)
	var original = scene.adapter
	input = TestAdapter.new()
	input.current = original.sample()
	input.current.focused = true
	input.current.valid_left = true
	input.current.valid_right = true
	input.camera = original.camera
	input.origin = original.origin
	input.controllers = original.controllers
	scene.add_child(input)
	scene.adapter = input
	original.queue_free()
	await process_frame
	scene._set_rtt(200)
	scene._toggle_pause()
	# A freely coasting authority makes premature position exposure observable.
	scene.physics.motors_enabled = false
	scene.physics.thrusters_enabled = false
	scene.physics.rigs[0].torso.linear_velocity = Vector3(3,0,0)
	var seed: Dictionary = scene.last_snapshot.duplicate(true)
	var old_basis: Basis = scene.physics.capture_command().desired_basis
	var target_basis := Basis(Vector3.UP,.4)
	scene.model.yaw = .4
	scene.model.body_basis = target_basis
	var history: Array = []
	var first_send := -1.0
	var input_arrival := -1.0
	var display_arrival := -1.0
	var saw_delayed_translation := false
	for index in 35:
		var committed: Dictionary = scene.physics.snapshot()
		scene._physics_process(dt)
		var now: float = scene.delay.clock
		history.append({"sent":now,"snapshot":committed})
		if first_send < 0.0: first_send = now
		var accepted: Basis = scene.physics.capture_command().desired_basis
		if now < first_send + .1 - .00000001:
			check(accepted.is_equal_approx(old_basis), "authority cannot receive input before half RTT")
		elif input_arrival < 0.0:
			input_arrival = now
			check(accepted.is_equal_approx(target_basis), "authority receives command at half RTT")
		var expected: Dictionary = seed
		for sent in history:
			if float(sent.sent) <= now - .1 + .00000001:
				expected = sent.snapshot
		check(is_equal_approx(scene.last_snapshot.time,expected.time), "display uses committed snapshot after return delay")
		check(scene.last_snapshot.rigs[0].body.is_equal_approx(expected.rigs[0].body), "displayed physical body matches delayed committed pose")
		var shown: Dictionary = scene.last_snapshot.rigs[0]
		check(scene.cockpit.global_basis.is_equal_approx(shown.commanded_basis), "cockpit cannot reflect future commanded attitude")
		var expected_origin: Vector3 = shown.body.origin + shown.commanded_basis * scene.COCKPIT_OFFSET
		check(scene.cockpit.global_position.is_equal_approx(expected_origin), "cockpit position derives solely from displayed body")
		if committed.rigs[0].body.origin.distance_to(shown.body.origin) > .02:
			saw_delayed_translation = true
		if shown.commanded_basis.is_equal_approx(target_basis) and display_arrival < 0.0:
			display_arrival = now
		await physics_frame
	check(saw_delayed_translation, "moving authority visibly precedes displayed physical body")
	check(input_arrival >= first_send + .1 - .00000001 and input_arrival < first_send + .1 + dt + .00000001, "outbound latency is 100ms within one sampling tick")
	check(display_arrival >= first_send + .2 - .00000001 and display_arrival <= first_send + .2 + 2*dt + .00000001, "round trip presentation is 200ms plus commit sampling")
	var sim_before: float = scene.sim_time
	var frame_count: int = scene.recorder.frame_count()
	scene.set_tuning_fraction(0,.7)
	scene.set_tuning_fraction(3,.35)
	check(not scene.paused and scene.sim_time == sim_before and scene.recorder.frame_count() == frame_count, "live physical sliders do not pause or reset")
	var displayed_before: Dictionary = scene.last_snapshot.duplicate(true)
	scene.set_tuning_fraction(6,.25)
	check(scene.rtt_ms == 100 and not scene.paused and scene.sim_time == sim_before, "live RTT slider changes without resetting encounter")
	check(scene.delay.queued_counts() == Vector2i.ZERO, "RTT change flushes both queues")
	check(scene.delay.receive_snapshot().rigs[0].body.is_equal_approx(displayed_before.rigs[0].body), "RTT change seeds last displayed pose, never future authority")
	await steps(3)
	check(scene.sim_time > sim_before, "simulation continues after live tuning")
	scene._toggle_pause()
	check(scene.delay.queued_counts() == Vector2i.ZERO and scene.physics.paused, "pause flushes pending input and presentation")
	var paused_time: float = scene.delay.clock
	await steps(3)
	check(scene.delay.clock == paused_time and scene.delay.queued_counts() == Vector2i.ZERO, "pause cannot age or enqueue stale packets")
	scene._begin_replay()
	check(scene.recorder.replaying and scene.delay.queued_counts() == Vector2i.ZERO, "replay starts with queues flushed")
	await steps(3)
	check(scene.delay.clock == paused_time, "replay does not advance live delay clock")
	scene._leave_replay()
	scene._toggle_pause()
	await step()
	var resumed: Dictionary = scene.physics.capture_command()
	check(not resumed.boost and resumed.velocity == Vector3.ZERO and resumed.angular_velocity == Vector3.ZERO, "resume starts neutral before fresh delayed input")
	# Reuse the original physical pilot handles and left-arm boost ownership.
	scene._reset()
	scene._set_rtt(0)
	scene.physics.motors_enabled = true
	scene.physics.thrusters_enabled = true
	input.current.left = scene.handles.handles[0]
	input.current.right = Transform3D(Basis.IDENTITY,scene.pilot.STICK_HOME)
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	input.current.left_trigger = 0.0
	scene._toggle_pause()
	await steps(3)
	input.current.left_grip = 1.0
	input.current.right_grip = 1.0
	await steps(3)
	check(scene.handles.grabbed[0] and scene.pilot.stick_owner == 1, "lab assigns left arm and right six-axis pilot independently")
	input.current.right.origin += Vector3(.08,.06,-.1)
	input.current.right.basis = Basis.from_euler(Vector3(.2,.15,.18))
	await steps(3)
	check(scene.pilot_status.pilot_move.x > 0 and scene.pilot_status.pilot_move.y > 0 and scene.pilot_status.pilot_move.z < 0, "lab pilot sends translation on all three axes")
	check(scene.pilot_status.pilot_rotation.x != 0 and scene.pilot_status.pilot_rotation.y != 0 and scene.pilot_status.pilot_rotation.z != 0, "lab pilot sends rotation on all three axes")
	check(scene.physics.capture_command().angular_velocity.length() > 0, "six-axis command reaches physical authority")
	input.current.left_trigger = 1.0
	await steps(3)
	check(scene.physics.player_boost and scene.model.boost < 1.0, "fresh left-arm trigger reaches physical boost and drains reserve")
	var boosted: Dictionary = scene.physics.snapshot().rigs[0]
	check(boosted.effective_thrust_limit > scene.physics.thrust_limit, "boost increases finite physical thrust budget")
	input.current.brake = true
	await step()
	check(not scene.physics.player_boost, "brake wins over boost at authority")
	# Isolate armor absorption in the actual world: overlapping beam and shield,
	# no actuator/thruster force and no other geometry near the two test bodies.
	scene._reset()
	scene._set_rtt(0)
	scene.physics.motors_enabled = false
	scene.physics.thrusters_enabled = false
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	input.current.left_trigger = 0.0
	input.current.brake = false
	scene._toggle_pause()
	var serial := 0
	for rig in scene.physics.rigs:
		for body in [rig.torso,rig.weapons[0],rig.weapons[1]]:
			body.global_transform = Transform3D(Basis.IDENTITY,Vector3(100+serial*30,0,0))
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			serial += 1
	var saber: RigidBody3D = scene.physics.rigs[0].weapons[1]
	var armor: RigidBody3D = scene.physics.rigs[1].weapons[0]
	saber.global_transform = Transform3D.IDENTITY
	armor.global_transform = Transform3D(Basis.IDENTITY,Vector3(0,4,0))
	scene._flush_delay()
	await steps(12)
	var absorb: Dictionary = scene.physics.snapshot()
	check(absorb.beam_contacts.size() == 1 and absorb.beam_contacts[0].target_part == "shield", "actual armor overlap creates one nearest beam absorption")
	check(absorb.contacts.is_empty(), "armor overlap does not create solver contacts")
	check(saber.linear_velocity.is_zero_approx() and saber.angular_velocity.is_zero_approx() and armor.linear_velocity.is_zero_approx() and armor.angular_velocity.is_zero_approx(), "beam armor overlap transfers no mechanical impulse")
	var appearance: Dictionary = scene.view.capture_appearance()
	check(not appearance.heat_marks.is_empty() and appearance.heat_marks[0].heat > 0, "stationary armor overlap accumulates visual dwell heat")
	var outer_beam: MeshInstance3D = scene.view.sword_visuals[0].get_child(2)
	var clipped_scale: Vector3 = outer_beam.scale
	check(clipped_scale.y > 0 and clipped_scale.y < 1, "visible beam shortens to nearest armor entry")
	scene._begin_replay()
	# Rewind one sampled frame to ensure playback really restores saved visuals.
	scene.recorder.scrub(maxf(0,scene.recorder.duration()-.04))
	await step()
	var replay_state: Dictionary = scene.recorder.sample()
	check(replay_state.beam_contacts.size() == 1 and replay_state.rigs[0].blade_fraction < 1, "replay retains beam overlap and clipping schema")
	check(outer_beam.scale.is_equal_approx(clipped_scale), "replay restores shortened beam mesh")
	var replay_heat: Array = scene.view.capture_appearance().heat_marks
	check(replay_heat.size() == replay_state.appearance.heat_marks.size() and is_equal_approx(replay_heat[0].heat,replay_state.appearance.heat_marks[0].heat) and replay_heat[0].position.is_equal_approx(replay_state.appearance.heat_marks[0].position), "replay restores recorded heat without recomputing dwell")
	var replay_path := "user://melee-absorption-test.json"
	check(scene.recorder.save_file(replay_path,{"test":"beam armor absorption"}) == OK, "beam and heat replay exports")
	check(scene.load_replay_file(replay_path) == OK, "beam and heat replay imports through lab validator")
	scene.recorder.scrub(scene.recorder.duration())
	await step()
	check(scene.recorder.sample().beam_contacts.size() == 1 and not scene.view.capture_appearance().heat_marks.is_empty(), "imported replay preserves beam contacts and heat")
	check(outer_beam.scale.is_equal_approx(clipped_scale), "imported replay preserves clipped beam visuals")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(replay_path))
	scene.queue_free()
	await process_frame
	print("MELEE_TUNING_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
