extends SceneTree
## Exercise the actual scene and physical world through asynchronous physics ticks.
class TestAdapter:
	extends "res://scripts/input_adapter.gd"
	var current: Dictionary = {}
	func sample() -> Dictionary:
		return current.duplicate(true)
var scene
var input: TestAdapter
var checks := 0
var failures := 0
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(caption)
func _initialize() -> void:
	call_deferred("run")
func ticks(count: int) -> void:
	for _i in count:
		await physics_frame
	await process_frame
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	if code >= KEY_A and code <= KEY_Z:
		event.unicode = code + 32
	root.push_input(event)
	var release := event.duplicate()
	release.pressed = false
	root.push_input(release)
func run() -> void:
	scene = load("res://melee.tscn").instantiate()
	root.add_child(scene)
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
	input.pause_requested.connect(scene._toggle_pause)
	input.reset_requested.connect(scene._reset)
	input.mark_requested.connect(scene._mark)
	original.queue_free()
	await ticks(2)
	check(scene.paused and scene.physics.paused, "lab starts paused")
	scene.demo = true
	scene._toggle_pause()
	await ticks(600)
	check(scene.contact_count > 0, "demo reaches actual rigid-body contact")
	check(scene.recorder.frame_count() > 100, "actual scene records resolved states")
	scene.demo = false
	input.current.left = scene.handles.handles[0]
	input.current.right = scene.handles.handles[1]
	input.current.left_grip = 1.0
	input.current.right_grip = 1.0
	await ticks(2)
	input.current.right_grip = 0.0
	await ticks(2)
	var parked: Transform3D = scene.handles.handles[1]
	input.current.right.origin += Vector3(.3,.2,0)
	await ticks(3)
	check(not scene.handles.grabbed[1] and scene.handles.handles[1].is_equal_approx(parked), "released handle parks while hand moves")
	input.current.right = parked
	input.current.right_grip = 1.0
	await ticks(2)
	check(scene.handles.grabbed[1], "fresh nearby grip reacquires")
	input.current.valid_right = false
	await ticks(2)
	check(not scene.handles.grabbed[1], "tracking loss parks arm")
	input.current.valid_right = true
	await ticks(2)
	check(not scene.handles.grabbed[1], "tracking return cannot regrab held grip")
	input.current.right_grip = 0.0
	await ticks(2)
	input.current.right = scene.handles.handles[1]
	input.current.right_grip = 1.0
	await ticks(2)
	check(scene.handles.grabbed[1], "tracking recovery accepts fresh nearby grip")
	input.current.focused = false
	await ticks(2)
	check(scene.paused and scene.physics.paused, "focus loss pauses physical simulation")
	input.current.focused = true
	await ticks(2)
	check(scene.paused, "focus return requires explicit resume")
	scene._toggle_pause()
	await ticks(4)
	scene._save_replay()
	check(scene.recorder.replaying and scene.paused and scene.physics.paused, "live export captures clip and freezes live simulation")
	check(scene.message.begins_with("Saved "), "live export writes replay successfully")
	var sim_before: float = scene.sim_time
	# PhysicsServer publishes the in-flight tick before freeze is fully visible.
	await ticks(2)
	var physical_before: Dictionary = scene.physics.snapshot()
	await ticks(12)
	check(scene.sim_time == sim_before and scene.physics.snapshot().time == physical_before.time, "replay leaves live clocks frozen")
	for rig_index in 2:
		var now: Dictionary = scene.physics.snapshot().rigs[rig_index]
		check(now.body.is_equal_approx(physical_before.rigs[rig_index].body), "replay freezes torso %d" % rig_index)
		for hand in 2:
			check(now.grips[hand].is_equal_approx(physical_before.rigs[rig_index].grips[hand]), "replay freezes grip %d/%d" % [rig_index,hand])
	scene.recorder.scrub(2.0)
	scene._action(2)
	check(is_equal_approx(scene.recorder.cursor,1.0), "panel back scrubs relative to current cursor")
	scene._action(3)
	check(is_equal_approx(scene.recorder.cursor,2.0), "panel forward scrubs relative to current cursor")
	key(KEY_BRACKETRIGHT)
	check(is_equal_approx(scene.recorder.cursor,3.0), "keyboard forward scrub uses current cursor")
	scene._action(8)
	check(scene.recorder.cursor == 0.0, "panel jump to start")
	scene.recorder.scrub(1.0)
	scene._annotate()
	await process_frame
	var mode_before: int = scene.mode
	var view_before: bool = scene.free_replay
	for code in [KEY_T, KEY_R, KEY_V, KEY_P, KEY_M, KEY_F, KEY_C]:
		key(code)
	key(KEY_F8)
	key(KEY_F5)
	await ticks(2)
	check(scene.recorder.annotations.is_empty(), "function shortcuts do not mark or export while editing")
	check(scene.recorder.replaying and scene.note_edit.visible and scene.mode == mode_before and scene.free_replay == view_before and not scene.recorder.playing, "typing note does not trigger lab shortcuts")
	check(scene.note_edit.text == "trvpmfc", "note receives typed shortcut letters")
	key(KEY_ENTER)
	await ticks(2)
	check(not scene.note_edit.visible and scene.recorder.annotations.size() == 1, "Enter stores note at replay cursor")
	var path := "user://melee-lab-test.json"
	check(scene.recorder.save_file(path,{"test":"scene lifecycle"}) == OK, "annotated scene replay export")
	var duration_before: float = scene.recorder.duration()
	scene._leave_replay()
	check(scene.paused and not scene.recorder.replaying and not scene.handles.grabbed[0] and not scene.handles.grabbed[1], "return live is paused with handles released")
	check(scene.load_replay_file(path) == OK, "scene imports saved clip through validated lab entry")
	check(scene.recorder.annotations.size() == 1 and is_equal_approx(scene.recorder.duration(),duration_before), "enter imported replay preserves clip and notes")
	var imported = scene.recorder
	var malformed = load("res://scripts/melee_replay.gd").new()
	malformed.record(1.0 / 30.0, {"rigs": "bad shape"})
	malformed.begin_replay()
	var invalid_path := "user://melee-lab-invalid-shape.json"
	check(malformed.save_file(invalid_path) == OK, "generic codec permits independent dictionary schema")
	check(scene.load_replay_file(invalid_path) == ERR_INVALID_DATA, "lab rejects incompatible snapshot schema")
	check(scene.recorder == imported and scene.recorder.annotations.size() == 1, "rejected lab import preserves current replay and notes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	scene.recorder.toggle_playing()
	await ticks(10)
	check(scene.recorder.cursor > 0.0 and scene.sim_time == sim_before, "imported playback advances without live simulation")
	scene._leave_replay()
	scene._toggle_pause()
	await ticks(2)
	check(not scene.handles.grabbed[1], "return live requires release and fresh regrab")
	# Pause establishes a stable resolved pose; change only the stabilized cockpit
	# frame, then exercise the acquisition edge before the next solver step.
	scene._toggle_pause()
	await ticks(3)
	scene.model.yaw = .25
	scene.model.body_basis = Basis(Vector3.UP,.25)
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	input.current.left = scene.handles.handles[0]
	input.current.right = scene.handles.handles[1]
	scene._toggle_pause()
	scene._physics_process(1.0 / 90.0)
	input.current.right_grip = 1.0
	var before_grab: Dictionary = scene.physics.snapshot().rigs[0]
	scene._physics_process(1.0 / 90.0)
	check(scene.handles.grabbed[1], "fresh regrab works with rotated stabilized cockpit")
	var command_world: Transform3D = before_grab.body * scene.physics.rigs[0].commands[1]
	check(command_world.is_equal_approx(before_grab.grips[1]), "rotated cockpit acquisition commands actual world grip without jump")
	await ticks(3)
	check(scene.physics.snapshot().rigs[0].body.is_finite(), "rotated regrab keeps physical suit finite")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	scene.queue_free()
	await process_frame
	print("MELEE_LAB_TEST checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
