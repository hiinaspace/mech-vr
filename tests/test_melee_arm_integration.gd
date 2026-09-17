extends SceneTree
class TestAdapter:
	extends "res://scripts/input_adapter.gd"
	var current: Dictionary = {}
	func sample() -> Dictionary: return current.duplicate(true)
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
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in count:
		scene._physics_process(dt)
		await physics_frame
func run() -> void:
	dt = 1.0 / Engine.physics_ticks_per_second
	scene = load("res://melee.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process(false)
	scene.calibration_path = "user://melee-arm-integration-calibration.cfg"
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
	scene._set_rtt(0)
	scene._toggle_pause()
	input.current.left = Transform3D(Basis.IDENTITY,scene.pilot.THROTTLE_HOME)
	await step(3)
	input.current.left_grip = 1.0
	await step(2)
	check(scene.pilot.throttle_owner == 0, "actual lab acquires left throttle")
	input.current.left.origin.z -= .30
	await step(3)
	input.current.left_grip = 0.0
	await step(2)
	check(scene.pilot.throttle > .99 and not scene.handles.grabbed[0], "released left hand leaves main throttle running")
	var latched: Array = scene.physics.capture_command().grips.duplicate()
	var start_body: Transform3D = scene.physics.snapshot().rigs[0].body
	var maximum_target_error := 0.0
	for i in 300:
		input.current.head.origin = Vector3(sin(i*.07)*.2,cos(i*.04)*.1,cos(i*.08)*.15)
		input.current.head.basis = Basis.from_euler(Vector3(.15*sin(i*.03),.5*sin(i*.05),0))
		input.current.left.origin.x = -.5 + sin(i*.06)*.2
		await step()
		for hand in 2:
			maximum_target_error = maxf(maximum_target_error,scene.physics.capture_command().grips[hand].origin.distance_to(latched[hand].origin))
	check(scene.physics.snapshot().rigs[0].body.origin.distance_to(start_body.origin) > 2.0, "long-throttle reproduction actually translates suit")
	check(maximum_target_error < .00001, "released targets do not drift with thrust, HMD pose, or free hand")
	# Make finite actuator lag unambiguous, then regrab near a calibrated handle.
	scene.physics.arm_force_limit = 0.0
	scene.physics.arm_torque_limit = 0.0
	var right_body: RigidBody3D = scene.physics.rigs[0].weapons[1]
	right_body.global_position += Vector3(2,1,0)
	input.current.brake = true
	input.current.right_grip = 0.0
	input.current.right = scene.handles.handles[1]
	await step(3)
	var requested: Transform3D = scene.physics.capture_command().grips[1]
	var actual_local: Transform3D = scene.physics.snapshot().rigs[0].body.affine_inverse()*right_body.global_transform
	check(actual_local.origin.distance_to(requested.origin) > .5, "regrab test contains actual actuator error")
	input.current.right.origin += Vector3(.04,0,0)
	input.current.right_grip = 1.0
	await step()
	check(scene.handles.grabbed[1] and scene.physics.capture_command().grips[1].is_equal_approx(requested), "regrab preserves latched target despite physical lag and near-handle offset")
	input.current.right.origin.x += .03
	await step()
	check(is_equal_approx(scene.physics.capture_command().grips[1].origin.x-requested.origin.x,.24), "subsequent hand motion uses calibrated gain")
	scene._begin_arm_calibration()
	input.current.brake = false
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	input.current.right_trigger = 0.0
	input.current.left_trigger = 0.0
	input.current.right = scene.handles.handles[1]
	await step(3)
	input.current.right_grip = 1.0
	await step(2)
	var target_before: Transform3D = scene.arm_mapping.targets[1]
	var offset_before: Transform3D = scene.arm_mapping.offsets[1]
	input.current.right_trigger = 1.0
	await step()
	input.current.right.origin += Vector3(.09,-.06,.04)
	input.current.right.basis = Basis.from_euler(Vector3(.2,.1,-.15))*input.current.right.basis
	input.current.left_trigger = 1.0
	input.current.move = Vector3(1,0,-1)
	await step(3)
	check(scene.arm_mapping.adjusting[1] and scene.arm_mapping.targets[1].is_equal_approx(target_before), "calibration trigger holds target while cockpit grip is repositioned")
	check(not scene.arm_mapping.offsets[1].is_equal_approx(offset_before), "calibration changes position and orientation offset")
	check(not scene.physics.player_boost and scene.model.main_throttle == 0.0, "calibration suppresses boost and persistent main thrust")
	input.current.right_trigger = 0.0
	await step()
	check(scene.arm_mapping.targets[1].is_equal_approx(target_before), "trigger release keeps calibrated target continuous")
	var saved_offset: Transform3D = scene.arm_mapping.offsets[1]
	scene._finish_arm_calibration()
	check(not scene.arm_mapping.calibration_mode and FileAccess.file_exists(scene.calibration_path), "explicit finish saves calibration to isolated path")
	var config_copy = load("res://scripts/melee_arm_mapping.gd").new()
	check(config_copy.load_calibration(scene.calibration_path) == OK and config_copy.offsets[1].is_equal_approx(saved_offset), "saved calibration loads with orientation and position offsets")
	scene._begin_arm_calibration()
	scene.arm_mapping.offsets[1].origin += Vector3(.3,0,0)
	scene._action(1)
	scene._action(8)
	check(not scene.arm_mapping.calibration_mode and scene.arm_mapping.offsets[1].is_equal_approx(saved_offset), "reset then cancel restores entry mapping, not an intermediate unsaved edit")
	scene._reset()
	check(scene.arm_mapping.offsets[1].is_equal_approx(saved_offset), "scenario reset preserves explicit calibration")
	check(scene.handles.handles[1].is_equal_approx(scene.arm_mapping.inverse_map(1,scene.arm_mapping.targets[1])), "reset handle location is inverse of retained calibration")
	input.current.right_grip = 0.0
	input.current.left_trigger = 0.0
	input.current.move = Vector3.ZERO
	scene._toggle_pause()
	await step(12)
	check(scene.last_snapshot.has("cockpit_error") and scene.last_snapshot.cockpit_error.actual.size() == 2 and scene.last_snapshot.cockpit_error.desired.size() == 2, "recorded cockpit error carries both hands in cockpit coordinates")
	scene._begin_replay()
	await step()
	var saved_sample: Dictionary = scene.recorder.sample()
	check(scene.cockpit_feedback.actual_frames[1].transform.is_equal_approx(saved_sample.cockpit_error.actual[1]), "replay restores actual inverse-mapped grip ghost")
	check(scene.cockpit_feedback.desired_frames[1].transform.is_equal_approx(saved_sample.cockpit_error.desired[1]), "replay restores desired inverse-mapped grip ghost")
	var replay_path := "user://melee-arm-integration-replay.json"
	check(scene.recorder.save_file(replay_path) == OK and scene.load_replay_file(replay_path) == OK, "replay with cockpit-error schema exports and imports")
	await step()
	check(scene.recorder.sample().cockpit_error.actual[0] is Transform3D, "cockpit-error pose types survive codec")
	# Capacity probe uses real captured scene state repeated over a 20-second
	# codec clip. This checks format size, not a claim of 20 seconds of gameplay.
	var capacity = load("res://scripts/melee_replay.gd").new()
	var capacity_sample: Dictionary = saved_sample.duplicate(true)
	var shield_leaf: int = scene.view.leaves.find(scene.view.equipment[0][0].get_child(0))
	capacity_sample.appearance.heat_marks = []
	for i in 100:
		capacity_sample.appearance.heat_marks.append({"leaf":shield_leaf,"position":Vector3(-1.8+(i%10)*.36,-2.7+int(i/10)*.54,.2),"heat":.8})
	check(scene.view.valid_appearance(capacity_sample.appearance), "100-cell heat stress schema passes visual validation")
	for i in 601: capacity.record(1.0/30.0,capacity_sample)
	capacity.begin_replay()
	var capacity_path := "user://melee-arm-capacity-test.json"
	var capacity_error: Error = capacity.save_file(capacity_path)
	check(capacity_error == OK, "20-second scene-schema replay with 100 heat cells fits export limit")
	if capacity_error == OK:
		var capacity_file := FileAccess.open(capacity_path,FileAccess.READ)
		print("MELEE_REPLAY_CAPACITY bytes=%d frames=%d" % [capacity_file.get_length(),capacity.frame_count()])
		capacity_file.close()
		check(scene.load_replay_file(capacity_path) == OK, "20-second replay imports within same limit")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.calibration_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(replay_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(capacity_path))
	scene.queue_free()
	await process_frame
	print("MELEE_ARM_INTEGRATION checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
