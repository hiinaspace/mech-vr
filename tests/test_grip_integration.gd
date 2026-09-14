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
	scene.handles.reset()
	scene.robot.posture_enabled = true
	await physics_frame
	scene.paused = false
	input.current.left_grip = 0.0
	input.current.right_grip = 0.0
	step(2)
	check(not scene.handles.grabbed[0] and not scene.handles.grabbed[1],"No automatic grip on resume")
	input.current.left = scene.handles.handles[0]
	input.current.right = scene.handles.handles[1]
	input.current.left_grip = 1.0
	input.current.right_grip = 1.0
	step()
	check(scene.handles.grabbed[0] and scene.handles.grabbed[1],"Actual scene captures both parked controls")
	input.current.left.origin.x += .12
	step(30)
	var parked: Transform3D = scene.handles.handles[0]
	var arm: Transform3D = scene.model.arm_actual[0]
	input.current.left_trigger = 1.0
	step()
	input.current.left_grip = 0.0
	input.current.left.origin.y += .3
	step()
	check(scene.handles.handles[0].is_equal_approx(parked),"Released control stays behind as physical hand moves")
	check(scene.handles.grabbed[1],"Other hand retains independent grip")
	check(scene.hands[0].transform.is_equal_approx(input.current.left),"Physical hand render remains tracked")
	check(scene.handle_visuals[0].transform.is_equal_approx(parked),"Parked mesh matches diegetic control")
	step(10)
	check(scene.model.arm_actual[0].is_equal_approx(arm),"Robot holds actual pose while physical hand is free")
	scene.world.cadence = 2.5
	aim("left",2)
	step(2)
	check(is_equal_approx(scene.world.cadence,2.5),"Held boost trigger cannot become a UI click on release")
	click("left",2)
	check(is_equal_approx(scene.world.cadence,4.0),"Released hand can operate live MFD")
	step(8)
	check(is_equal_approx(scene.world.cadence,4.0),"Held UI trigger causes one click")
	click("left",3)
	check(scene.handles.mode == "calibrated","Live regrab comparison button selects calibrated orientation")
	step()
	check(not scene.handles.grabbed[1],"Changing mapping parks the other control explicitly")
	input.current.right_grip = 0.0
	input.current.right_trigger = 1.0
	input.current.right = scene.handles.handles[1]
	input.current.right.basis = Basis.from_euler(Vector3(.3,.4,.1))
	step()
	var before: Transform3D = scene.model.arm_actual[1]
	input.current.right_grip = 1.0
	scene.world.last_shot_kind = "sentinel"
	step()
	check(scene.model.arm_actual[1].is_equal_approx(before),"Calibrated acquisition does not teleport actual rifle")
	step(120)
	check(scene.model.arm_actual[1].basis.get_rotation_quaternion().angle_to(input.current.right.basis.get_rotation_quaternion()) < .04,"Calibrated orientation settles through servo")
	check(scene.world.last_shot_kind == "sentinel","Held trigger remains inhibited throughout and after recovery")
	input.current.right_trigger = 0.0
	step(2)
	input.current.right_trigger = 1.0
	step()
	check(scene.world.last_shot_kind != "sentinel","Fresh trigger press fires after calibrated recovery")
	var body_before: Transform3D = scene.body.transform
	var gun_before: Transform3D = scene.arms[1].global_transform
	var shield_before: Transform3D = scene.arms[0].global_transform
	for _i in range(240):
		scene.robot.update_pose(1.0/90.0,Vector3(0,0,-20),Vector3(0,0,-12),scene.arms,Basis.IDENTITY)
		scene.hologram.sync()
	check(scene.robot.flight.body_basis.y.dot(Vector3.FORWARD)>.8,"Hologram adopts forward spine flight pose")
	check(scene.robot.flames[0].visible or scene.robot.flames[2].visible,"Acceleration produces visible exhaust")
	check(scene.body.transform.is_equal_approx(body_before),"Visual pose never steers cockpit")
	check(scene.arms[1].global_transform.is_equal_approx(gun_before) and scene.arms[0].global_transform.is_equal_approx(shield_before),"Visual pose never changes actual muzzle/shield")
	scene.robot.update_pose(1.0/90.0,Vector3(0,0,-20),Vector3.ZERO,scene.arms,Basis.IDENTITY)
	scene.hologram.sync()
	check(not scene.robot.flames[0].visible and not scene.robot.flames[2].visible,"Coasting has no acceleration exhaust")
	click("left",5)
	check(not scene.robot.posture_enabled,"Live HUD can select upright shared body posture")
	click("left",4)
	check(not scene.handles.enabled,"Live HUD can restore legacy B-toggle control")
	scene.queue_free()
	await process_frame
	if had_settings:
		var file := FileAccess.open("user://m0a.cfg",FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://m0a.cfg"))
	print("GRIP_INTEGRATION checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
