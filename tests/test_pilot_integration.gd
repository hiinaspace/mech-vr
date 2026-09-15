extends SceneTree
class ReplayAdapter:
	extends "res://scripts/input_adapter.gd"
	var current: Dictionary = {}
	func sample() -> Dictionary:
		return current.duplicate()
var scene
var input: ReplayAdapter
var checks := 0
var failures := 0
var previous: PackedByteArray
var had_settings := false
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(caption)
func _initialize() -> void:
	call_deferred("run")
func step(count := 1) -> void:
	for _i in count: scene._physics_process(1.0/90.0)
func aim(hand: String, row: int) -> void:
	input.current[hand] = scene.panel.transform * Transform3D(Basis.IDENTITY,Vector3(0,.24-(row+.5)*.08,.5))
func click(hand: String, row: int) -> void:
	aim(hand,row)
	input.current[hand+"_trigger"] = 0.0
	step(2)
	input.current[hand+"_trigger"] = 1.0
	step()
func run() -> void:
	had_settings = FileAccess.file_exists("user://m0a.cfg")
	if had_settings: previous = FileAccess.get_file_as_bytes("user://m0a.cfg")
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process(false)
	var original = scene.adapter
	input = ReplayAdapter.new()
	input.current = original.sample()
	input.current.focused = true
	input.camera = original.camera
	input.origin = original.origin
	input.controllers = original.controllers
	scene.add_child(input)
	scene.adapter = input
	original.queue_free()
	scene.handles.enabled = true
	scene.handles.set_mode("free")
	scene.paused = true
	scene._reset()
	scene.paused = false
	scene.resume_delay = 0.0
	await physics_frame
	scene.paused = false
	input.current.focused = true
	input.current.valid_left = true
	input.current.valid_right = true
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	input.current.left_trigger = 0.0
	input.current.right_trigger = 0.0
	input.current.move = Vector3.ZERO
	input.current.yaw = 0.0
	input.current.vertical = 0.0
	input.current.brake = false
	input.current.left = scene.handles.handles[0]
	input.current.right = Transform3D(Basis.IDENTITY,scene.pilot.STICK_HOME)
	step(2)
	input.current.left_grip = 1.0
	input.current.right_grip = 1.0
	input.current.right_trigger = 1.0
	scene.world.last_shot_kind = "sentinel"
	step()
	check(scene.pilot_status.owners[1] == "PILOT", "actual center grip reserves right hand")
	check(not scene.handles.grabbed[1] and scene.handles.grabbed[0], "pilot ownership exclusive; other arm independent")
	check(not scene.pointers[1].visible, "pilot hand cannot point or click MFD")
	input.current.right.origin.x += .18
	input.current.right.basis = Basis(Vector3.BACK,.45)
	step(60)
	check(scene.model.velocity.x > 1.0, "physical stick translates actual motor")
	check(absf(scene.body.basis.x.y) > .10, "physical twist rolls actual cockpit")
	check(scene.world.last_shot_kind == "sentinel", "pilot trigger cannot fire rifle")
	input.current.right_grip = 0.0
	step(90)
	var attitude: Basis = scene.body.basis
	step(90)
	check(scene.body.basis.is_equal_approx(attitude), "spring release stops angular motion and keeps roll")
	check(scene.pilot.stick_pose.origin == scene.pilot.STICK_HOME, "rendered stick springs home")
	input.current.right = scene.handles.handles[1]
	input.current.right_grip = 1.0
	step(20)
	check(scene.handles.grabbed[1], "hand returns from pilot to parked rifle")
	check(scene.world.last_shot_kind == "sentinel", "held pilot trigger cannot fire upon arm regrab")
	# Isolate cruise axis from the preceding roll experiment.
	scene.paused = true
	scene._reset()
	scene.paused = false
	scene.resume_delay = 0.0
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	input.current.right_trigger = 0.0
	input.current.left = Transform3D(Basis.IDENTITY,scene.pilot.THROTTLE_HOME)
	input.current.right = scene.handles.handles[1]
	step(2)
	input.current.left_grip = 1.0
	input.current.right_grip = 1.0
	step()
	check(scene.pilot_status.owners[0] == "THROTTLE" and scene.handles.grabbed[1], "left throttle plus independent rifle")
	input.current.left.origin.z -= .30
	step(60)
	check(scene.pilot.throttle > .99 and scene.model.main_throttle > .3, "main throttle ramps actual motor")
	input.current.left_grip = 0.0
	step()
	input.current.left = scene.handles.handles[0]
	input.current.left_grip = 1.0
	input.current.head.basis = Basis(Vector3.UP,1.2)
	step(90)
	check(scene.handles.grabbed[0] and scene.handles.grabbed[1] and scene.pilot.throttle > .99, "persistent main thrust leaves both arms usable")
	check(absf(scene.model.velocity.x) < .01 and scene.model.velocity.z < -20, "gaze does not steer cruise")
	input.current.brake = true
	step(180)
	check(scene.pilot.throttle == 0.0 and scene.model.main_throttle == 0.0, "brake closes throttle and ramp")
	input.current.brake = false
	step(90)
	check(scene.model.velocity.length() < .01, "brake release cannot relaunch cruise")
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	input.current.right = Transform3D(Basis.IDENTITY,scene.pilot.STICK_HOME)
	step(2)
	input.current.right_grip = 1.0
	step()
	check(scene.pilot.stick_owner == 1, "fresh grab before pause")
	scene.paused = true
	step()
	scene.paused = false
	step(2)
	check(scene.pilot.stick_owner == -1, "pause recovery cannot inherit held grip")
	input.current.right_grip = 0.0
	step()
	input.current.right_grip = 1.0
	step()
	input.current.valid_right = false
	step()
	input.current.valid_right = true
	step()
	check(scene.pilot.stick_owner == -1, "tracking recovery cannot inherit held grip")
	scene.pilot.throttle = 1.0
	scene.paused = true
	scene._reset()
	scene.paused = false
	check(scene.pilot.throttle == 0.0 and scene.model.main_throttle == 0.0 and scene.model.body_basis == Basis.IDENTITY, "reset clears throttle and advanced attitude")
	scene.queue_free()
	await process_frame
	if had_settings:
		var file := FileAccess.open("user://m0a.cfg",FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://m0a.cfg"))
	print("PILOT_INTEGRATION checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
