extends SceneTree
const Adapter = preload("res://scripts/input_adapter.gd")
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	if not value:
		push_error("INPUT CHECK FAILED: " + description)
		quit(1)
		assert(false, description)
	checks += 1

func run() -> void:
	var openxr := XRServer.find_interface("OpenXR")
	for signal_name in ["session_focussed", "session_visible", "session_stopping", "session_loss_pending"]:
		check(openxr.has_signal(signal_name), "native session signal " + signal_name)
	var body := Node3D.new()
	root.add_child(body)
	var input := Adapter.new()
	body.add_child(input)
	input.setup(body)
	var before := input.sample()
	input.camera.rotation.y = 0.5
	var after := input.sample()
	check(after.left == before.left and after.right == before.right, "head movement leaves both hands independent")
	check(after.head != before.head and body.rotation == Vector3.ZERO, "head motion cannot steer body")
	input.controllers[0].position.x += 0.1
	var left_after := input.sample()
	check(left_after.right == after.right and left_after.head == after.head, "left hand independent of right/head")
	input.recenter()
	check(input.camera.position == Vector3.ZERO and input.origin.basis.get_scale() == Vector3.ONE, "desktop recenter at metre scale")
	check(not input.xr_active, "desktop does not initialize XR")
	check(not input._head_tracked(), "missing head tracker is invalid")
	var head := XRPositionalTracker.new()
	head.type = XRServer.TRACKER_HEAD
	head.name = &"head"
	XRServer.add_tracker(head)
	head.set_pose(&"default", Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	check(input._head_tracked(), "native XRPose tracking data recognized")
	head.invalidate_pose(&"default")
	check(not input._head_tracked(), "native invalidated head pose rejected")
	XRServer.remove_tracker(head)
	var raw := active_sample()
	raw.valid_left = false
	input.mask_unavailable(raw)
	check(raw.move == Vector3.ZERO and raw.left_trigger == 0.0 and not raw.brake and not raw.ui_left, "left loss suppresses locomotion/actions")
	check(raw.yaw == 1.0 and raw.vertical == 1.0 and raw.right_trigger == 1.0, "left loss preserves tracked right actions")
	raw = active_sample()
	raw.valid_right = false
	input.mask_unavailable(raw)
	check(raw.yaw == 0.0 and raw.vertical == 0.0 and raw.right_trigger == 0.0 and not raw.ui_right and not raw.mode_toggle, "right loss suppresses attitude/actions")
	check(raw.brake and raw.move != Vector3.ZERO, "right loss preserves tracked brake/translation")
	raw = active_sample()
	input.mask_unavailable(raw)
	check(not raw.ui_right and not raw.mode_toggle, "held recovered buttons cannot toggle UI/mode")
	raw = active_sample()
	raw.ui_right = false
	raw.mode_toggle = false
	input.mask_unavailable(raw)
	raw = active_sample()
	input.mask_unavailable(raw)
	check(raw.ui_right and raw.mode_toggle, "fresh recovered press can toggle UI/mode")
	raw = active_sample()
	raw.focused = false
	input.mask_unavailable(raw)
	check(raw.move == Vector3.ZERO and raw.yaw == 0.0 and raw.vertical == 0.0 and raw.left_trigger == 0.0 and raw.right_trigger == 0.0 and not raw.ui_left and not raw.ui_right and not raw.brake, "focus/head loss suppresses both hands and movement")
	print("MECH_INPUT_TEST_OK checks=%d" % checks)
	body.queue_free()
	quit()

func active_sample() -> Dictionary:
	return {"focused": true, "valid_left": true, "valid_right": true,
		"move": Vector3.ONE, "yaw": 1.0, "vertical": 1.0, "left_trigger": 1.0,
		"right_trigger": 1.0, "brake": true, "ui_left": true, "ui_right": true,
		"mode_toggle": true}
