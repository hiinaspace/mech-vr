class_name MechInput
extends Node
## Poses are cockpit local, metres, without head/hand-driven cockpit motion.
## Desktop: 1/2/3 selects head/left/right. RMB drag rotates the selected pose;
## Ctrl+RMB translates XY, Alt+RMB translates depth. Other poses stay independent.
signal pause_requested
signal reset_requested
signal mark_requested

var camera: XRCamera3D
var origin: XROrigin3D
var controllers: Array[XRController3D] = []
var xr_active := false
var focused := true
var selected_pose := 0
var desktop_valid := [true, true]
var _interface: XRInterface
var _window_focused := true
var _menu_held := false
var _blocked_buttons: Dictionary = {}
var initial_calibrated := false
var _tracking_ready_logged := false

func setup(body: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	origin = XROrigin3D.new()
	origin.name = "TrackingOrigin"
	body.add_child(origin)
	camera = XRCamera3D.new()
	camera.name = "Head"
	camera.near = 0.04
	camera.far = 1500.0
	origin.add_child(camera)
	camera.current = true
	for side in 2:
		var controller := XRController3D.new()
		controller.name = "LeftAim" if side == 0 else "RightAim"
		controller.tracker = &"left_hand" if side == 0 else &"right_hand"
		controller.pose = &"aim"
		origin.add_child(controller)
		controllers.append(controller)
	_reset_desktop_poses()
	get_window().focus_entered.connect(func(): _window_focused = true)
	get_window().focus_exited.connect(func(): _window_focused = false)
	if not "--xr" in OS.get_cmdline_user_args():
		get_viewport().use_xr = false
		return
	focused = false
	_interface = XRServer.find_interface("OpenXR")
	if not _interface:
		push_error("OpenXR interface unavailable. Launch with --xr-mode on -- --xr.")
		get_tree().quit(2)
		return
	_interface.connect("session_focussed", func(): focused = true)
	_interface.connect("session_visible", func(): focused = false)
	_interface.connect("session_stopping", func(): focused = false)
	_interface.connect("session_loss_pending", func(): focused = false)
	if not _interface.initialize():
		push_error("OpenXR initialization failed; refusing silent desktop fallback.")
		get_tree().quit(2)
		return
	xr_active = true
	get_viewport().use_xr = true
	origin.current = true
	XRServer.world_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("MECH_XR_INITIALIZED engine=%s runtime=%s render_target=%s world_scale=1" % [Engine.get_version_info().string, OS.get_environment("XR_RUNTIME_JSON"), _interface.get_render_target_size()])

func _reset_desktop_poses() -> void:
	camera.transform = Transform3D.IDENTITY
	controllers[0].transform = Transform3D(Basis.IDENTITY, Vector3(-0.28, -0.3, -0.42))
	controllers[1].transform = Transform3D(Basis.IDENTITY, Vector3(0.28, -0.3, -0.42))

func recenter() -> void:
	if not xr_active:
		origin.transform = Transform3D.IDENTITY
		_reset_desktop_poses()
		return
	# Only local tracking yaw is removed. Cockpit's world rotation is untouched.
	var head_pose := camera.transform
	var yaw := head_pose.basis.get_euler().y
	var centered_basis := Basis(Vector3.UP, -yaw)
	origin.transform = Transform3D(centered_basis, -(centered_basis * head_pose.origin))
	print("MECH_XR_RECENTER head=%s origin=%s" % [head_pose, origin.transform])

func sample() -> Dictionary:
	if xr_active and not initial_calibrated and focused and _head_tracked():
		# Main starts paused. This one-time placement makes its seated menu reachable.
		recenter()
		initial_calibrated = true
		print("MECH_XR_STARTUP_SEATED_CALIBRATION")
	var out := {
		"head": origin.transform * camera.transform,
		"left": origin.transform * controllers[0].transform,
		"right": origin.transform * controllers[1].transform,
		"valid_left": desktop_valid[0], "valid_right": desktop_valid[1],
		"focused": (focused and _head_tracked()) if xr_active else _window_focused,
		"move": Vector3.ZERO, "yaw": 0.0, "vertical": 0.0,
		"mode_toggle": false, "ui_left": false, "ui_right": false,
		"left_trigger": 0.0, "right_trigger": 0.0, "brake": false,
		"timestamp_usec": Time.get_ticks_usec(),
	}
	if xr_active:
		out.valid_left = controllers[0].get_has_tracking_data()
		out.valid_right = controllers[1].get_has_tracking_data()
		var left_stick := _deadzone(controllers[0].get_vector2("primary"))
		var right_stick := _deadzone(controllers[1].get_vector2("primary"))
		out.move = Vector3(left_stick.x, 0.0, -left_stick.y)
		out.yaw = -right_stick.x
		out.vertical = right_stick.y
		out.mode_toggle = controllers[1].is_button_pressed("ax_button")
		out.ui_left = controllers[0].is_button_pressed("by_button")
		out.ui_right = controllers[1].is_button_pressed("by_button")
		out.left_trigger = controllers[0].get_float("trigger")
		out.right_trigger = controllers[1].get_float("trigger")
		out.brake = controllers[0].is_button_pressed("ax_button")
		var left_menu := _fresh_button("left_menu", controllers[0].is_button_pressed("menu_button"), out.focused and out.valid_left)
		var right_menu := _fresh_button("right_menu", controllers[1].is_button_pressed("menu_button") or controllers[1].is_button_pressed("primary_click"), out.focused and out.valid_right)
		var menu := left_menu or right_menu
		if menu and not _menu_held:
			pause_requested.emit()
		_menu_held = menu
	else:
		out.move = Vector3(_axis(KEY_A, KEY_D), 0.0, _axis(KEY_W, KEY_S))
		out.yaw = _axis(KEY_RIGHT, KEY_LEFT)
		out.vertical = clampf(_axis(KEY_Q, KEY_E) + _axis(KEY_DOWN, KEY_UP), -1.0, 1.0)
		out.mode_toggle = Input.is_physical_key_pressed(KEY_TAB)
		out.ui_left = Input.is_physical_key_pressed(KEY_Z)
		out.ui_right = Input.is_physical_key_pressed(KEY_X)
		out.left_trigger = 1.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.0
		out.right_trigger = 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0
		out.brake = Input.is_physical_key_pressed(KEY_SPACE)
	mask_unavailable(out)
	if xr_active and not _tracking_ready_logged and out.focused and out.valid_left and out.valid_right:
		_tracking_ready_logged = true
		var profiles: Array[String] = []
		for controller in controllers:
			var tracker := XRServer.get_tracker(controller.tracker) as XRControllerTracker
			profiles.append(tracker.profile if tracker else "<missing>")
		print("MECH_XR_TRACKING_READY focused=true head=%s left=%s right=%s profiles=%s move=%s yaw=%s vertical=%s triggers=%s/%s" % [out.head.origin, out.left.origin, out.right.origin, profiles, out.move, out.yaw, out.vertical, out.left_trigger, out.right_trigger])
	return out

func _head_tracked() -> bool:
	var head_tracker := XRServer.get_tracker("head") as XRPositionalTracker
	var pose: XRPose = head_tracker.get_pose("default") if head_tracker else null
	return pose != null and pose.has_tracking_data

func mask_unavailable(out: Dictionary) -> void:
	# Apply equally to hardware and desktop loss simulation. Never consume stale
	# stick/action values after a pose or session becomes unavailable.
	var left_live: bool = out.focused and out.valid_left
	var right_live: bool = out.focused and out.valid_right
	out.ui_left = _fresh_button("ui_left", out.ui_left, left_live)
	out.ui_right = _fresh_button("ui_right", out.ui_right, right_live)
	out.mode_toggle = _fresh_button("mode_toggle", out.mode_toggle, right_live)
	if not left_live:
		out.move = Vector3.ZERO
		out.left_trigger = 0.0
		out.brake = false
	if not right_live:
		out.yaw = 0.0
		out.vertical = 0.0
		out.right_trigger = 0.0

func _fresh_button(action: String, pressed: bool, available: bool) -> bool:
	if not available:
		_blocked_buttons[action] = true
		return false
	if not pressed:
		_blocked_buttons[action] = false
	return pressed and not _blocked_buttons.get(action, false)

func _axis(negative: Key, positive: Key) -> float:
	return float(Input.is_physical_key_pressed(positive)) - float(Input.is_physical_key_pressed(negative))

func _deadzone(value: Vector2) -> Vector2:
	if value.length() < 0.15:
		return Vector2.ZERO
	return value.normalized() * minf((value.length() - 0.15) / 0.85, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: pause_requested.emit()
			KEY_R: reset_requested.emit()
			KEY_F8: mark_requested.emit()
			KEY_1: selected_pose = 0
			KEY_2: selected_pose = 1
			KEY_3: selected_pose = 2
			KEY_F6: desktop_valid[0] = not desktop_valid[0]
			KEY_F7: desktop_valid[1] = not desktop_valid[1]
	if xr_active or not event is InputEventMouseMotion:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	var target: Node3D = camera if selected_pose == 0 else controllers[selected_pose - 1]
	if event.ctrl_pressed:
		target.position += Vector3(event.relative.x, -event.relative.y, 0.0) * 0.0015
	elif event.alt_pressed:
		target.position.z += event.relative.y * 0.002
	else:
		target.rotation.y -= event.relative.x * 0.003
		target.rotation.x = clampf(target.rotation.x - event.relative.y * 0.003, -1.4, 1.4)
