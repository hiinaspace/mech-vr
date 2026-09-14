extends SceneTree

const ControlModel = preload("res://scripts/control_model.gd")
var checks := 0
var failures := 0

func sample() -> Dictionary:
	return {"left": Transform3D(Basis.IDENTITY, Vector3(-0.25, 1.1, -0.4)),
		"right": Transform3D(Basis.IDENTITY, Vector3(0.25, 1.1, -0.4)),
		"head": Transform3D(Basis.IDENTITY, Vector3(0, 1.25, 0)),
		"valid_left": true, "valid_right": true, "focused": true}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run_for(control: RefCounted, input: Dictionary, duration: float, dt: float) -> void:
	for _i in int(round(duration / dt)):
		control.step(input, dt)

func _initialize() -> void:
	test_movement()
	test_ownership()
	test_frames_and_servos()
	test_rotation_mapping()
	print("CONTROL_TESTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func test_movement() -> void:
	for dt in [1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0]:
		var c := ControlModel.new()
		var s := sample()
		c.step(s, dt)
		s.move = Vector3(1, 1, -1)
		run_for(c, s, 1.0, dt)
		check(absf(c.velocity.length() - 12.0) < 0.001, "Normalized diagonal reaches cruise at one second dt=%f" % dt)
		check(c.velocity.normalized().distance_to(Vector3(1, 1, -1).normalized()) < 0.001, "Diagonal direction preserved")
		s.move = Vector3.ZERO
		run_for(c, s, 0.5, dt)
		check(absf(c.velocity.length() - 8.0) < 0.001, "Release deceleration is 8 m/s2")
		c.velocity = Vector3(0, 0, -30)
		s.move = Vector3(1, 1, 1)
		s.brake = true
		s.left_trigger = 1.0
		var distance := 0.0
		for _i in int(round(1.0 / dt)):
			var out: Dictionary = c.step(s, dt)
			check(not out.boost_active, "Brake beats boost")
			check(c.velocity.x == 0 and c.velocity.y == 0 and c.velocity.z <= 0, "Brake never reverses or obeys thrust")
			distance += c.velocity.length() * dt
		check(c.velocity == Vector3.ZERO, "Brake stops 30m/s before one second")
		check(absf(distance - 10.0) < 0.51, "Discrete braking agrees with 10m analytic stopping distance dt=%f actual=%f" % [dt, distance])
	var c := ControlModel.new()
	var s := sample()
	c.step(s, 0.01)
	c.velocity = Vector3(0, 0, -10)
	c.yaw = PI / 2
	c.step(s, 0.01)
	check(c.velocity.x == 0 and c.velocity.z < -9.9, "Rotating cockpit preserves world momentum")
	c.velocity = Vector3.ZERO
	s.move = Vector3(0, 0, -1)
	c.step(s, 0.1)
	check(c.velocity.x < -1.19 and absf(c.velocity.z) < 0.001, "New thrust follows body yaw")
	c.reset()
	s = sample()
	c.step(s, 0.01)
	s.left_trigger = 1.0
	s.move = Vector3.FORWARD
	run_for(c, s, 2.1, 0.01)
	check(not c.step(s, 0.01).boost_active, "Empty boost does not pulse while trigger remains held")
	s.left_trigger = 0.0
	run_for(c, s, 4.0, 0.01)
	check(is_equal_approx(c.boost, 1.0), "Boost recharges fully in four seconds")
	s.left_trigger = 1.0
	check(c.step(s, 0.01).boost_active, "Boost works after fresh press")

func test_ownership() -> void:
	var c := ControlModel.new()
	var s := sample()
	s.right_trigger = 1.0
	check(not c.step(s, 0.01).fire, "Initial held trigger requires release")
	s.right_trigger = 0.0
	c.step(s, 0.01)
	s.right_trigger = 1.0
	check(c.step(s, 0.01).fire, "Fresh trigger fires")
	s.ui_right = true
	var out: Dictionary = c.step(s, 0.01)
	check(c.owners[1] == "UI" and not out.fire and not out.click_right, "UI entry cancels held fire and suppresses click")
	var held := c.arm_actual[1]
	s.right.origin += Vector3(0.4, 0.2, 0.3)
	s.ui_right = false
	c.step(s, 0.01)
	check(c.arm_actual[1].is_equal_approx(held), "UI arm holds actual pose")
	s.right_trigger = 0.0
	c.step(s, 0.01)
	s.right_trigger = 1.0
	check(c.step(s, 0.01).click_right, "Fresh UI trigger clicks")
	check(not c.step(s, 0.01).click_right, "Held UI trigger never repeats click")
	s.ui_right = true
	out = c.step(s, 0.01)
	check(c.owners[1] == "ARM" and not out.fire, "UI exit suppresses held trigger")
	check(c.arm_actual[1].is_equal_approx(held) and c.arm_targets[1].is_equal_approx(held), "Reattachment has no target or actual snap")
	s.ui_right = false
	s.right_trigger = 0.0
	c.step(s, 0.01)
	s.right_trigger = 1.0
	check(c.step(s, 0.01).fire, "Fresh fire after reattachment")
	s.valid_right = false
	check(not c.step(s, 0.01).fire and c.owners[1] == "HOLD", "Tracking loss cancels fire")
	s.right.origin += Vector3(0.5, -0.2, 0)
	s.valid_right = true
	out = c.step(s, 0.01)
	check(not out.fire and c.arm_actual[1].is_equal_approx(held), "Tracking return rebases without snap and gates held trigger")
	s.ui_left = true
	s.left_trigger = 1.0
	out = c.step(s, 0.01)
	check(c.owners[0] == "UI" and not out.boost_active and not out.click_left, "Left UI inhibits boost and stale click")
	s.ui_right = true
	c.step(s, 0.01)
	check(c.owners[1] == "UI" and c.owners[0] == "ARM", "UI focus transfer is exclusive")
	s.focused = false
	out = c.step(s, 0.01)
	check(out.paused and not out.fire and not out.click_right and not out.boost_active, "Focus loss pauses all actions")
	s.focused = true
	out = c.step(s, 0.01)
	check(not out.fire and not out.boost_active and c.owners == ["ARM", "ARM"], "Focus recovery cannot replay held actions or UI toggles")
	s.paused = true
	var old_yaw := c.yaw
	s.yaw = 1.0
	s.move = Vector3.ONE
	out = c.step(s, 0.1)
	check(out.paused and c.yaw == old_yaw, "Settings pause freezes rotation")
	c.velocity = Vector3.ZERO
	s.paused = false
	out = c.step(s, 0.1)
	check(c.movement_neutral_required and c.velocity == Vector3.ZERO and c.yaw == old_yaw, "Resume rejects held translation and yaw until neutral")
	s.yaw = 0.0
	s.move = Vector3.ZERO
	c.step(s, 0.01)
	s.yaw = 1.0
	s.move = Vector3.FORWARD
	c.step(s, 0.1)
	check(not c.movement_neutral_required and c.velocity.length() > 1.0 and c.yaw != old_yaw, "Movement reenabled after neutral")

func test_frames_and_servos() -> void:
	var c := ControlModel.new()
	var s := sample()
	# Feed cockpit-local poses reconstructed from a nontrivial world frame.
	var body := Transform3D(Basis.from_euler(Vector3(0.3, 1.1, 0)), Vector3(100, -40, 70))
	s.right = body.affine_inverse() * (body * s.right)
	c.step(s, 0.01)
	var neutral: Transform3D = c.arm_actual[1]
	s.right.origin += Vector3(0.25, 0, 0)
	c.step(s, 0.01)
	check(c.arm_targets[1].origin.distance_to(neutral.origin + Vector3(2, 0, 0)) < 0.0001, "World/cockpit conversion retains 8x displacement")
	check(c.arm_actual[1].origin.distance_to(neutral.origin) < 0.011, "Servo acceleration bounds first step")
	check(c.arm_actual[1].origin.distance_to(c.arm_targets[1].origin) > 1.9, "Weapon actual pose differs from unachieved command")
	run_for(c, s, 2.0, 0.01)
	check(c.arm_actual[1].origin.distance_to(c.arm_targets[1].origin) < 0.02, "Servo settles to stationary command")
	for iteration in 8:
		s.ui_right = true
		c.step(s, 0.01)
		var held: Transform3D = c.arm_actual[1]
		s.ui_right = false
		s.right = Transform3D(Basis.from_euler(Vector3(0.04 * iteration, -0.1 * iteration, 0.1)), Vector3(iteration * 0.03, 1, -0.5))
		c.step(s, 0.01)
		s.ui_right = true
		c.step(s, 0.01)
		check(c.arm_targets[1].is_equal_approx(held), "Repeated rebase preserves pose %d" % iteration)
		s.ui_right = false
		c.step(s, 0.01)
	var anchor_hand: Transform3D = s.right
	var anchor_arm: Transform3D = c.arm_actual[1]
	var delta := Basis(Vector3.UP, 0.1)
	s.right.basis = delta * anchor_hand.basis
	c.step(s, 0.01)
	check(c.arm_targets[1].basis.is_equal_approx(delta * anchor_arm.basis), "Quaternion rebase applies cockpit-space delta in correct order")
	s.right.origin += Vector3(100, 100, 100)
	run_for(c, s, 2.0, 0.01)
	check(c.arm_targets[1].origin.distance_to(ControlModel.NEUTRALS[1]) <= 7.0001, "Target reach is bounded")
	check(c.arm_actual[1].origin.distance_to(ControlModel.NEUTRALS[1]) <= 7.0001, "Actual reach is bounded")
	check(c.yaw == 0.0 and c.pitch == 0.0, "Arms never rotate body")
	s.head = Transform3D(Basis.from_euler(Vector3(1, 2, 0.5)), Vector3(3, 4, 5))
	c.step(s, 0.01)
	check(c.yaw == 0.0 and c.pitch == 0.0, "Head motion never rotates body")

func test_rotation_mapping() -> void:
	var c := ControlModel.new()
	var s := sample()
	c.step(s, 0.01)
	s.vertical = 1.0
	s.mode_toggle = true
	c.step(s, 0.01)
	run_for(c, s, 1.0, 0.01)
	check(c.attitude_mode and c.mode_neutral_required and c.pitch == 0, "Mode toggle requires stick neutral before pitch")
	s.mode_toggle = false
	s.vertical = 0.0
	c.step(s, 0.01)
	s.vertical = 1.0
	run_for(c, s, 1.0, 0.01)
	check(c.pitch > deg_to_rad(17) and c.pitch < deg_to_rad(21), "Explicit pitch reaches configured angular rate")
	run_for(c, s, 10.0, 0.01)
	check(is_equal_approx(c.pitch, deg_to_rad(75)), "Pitch singularity limit")
	s.vertical = 0.0
	run_for(c, s, 1.0, 0.01)
	check(c.pitch_rate == 0, "Pitch release arrests rotation")
	c.reset()
	c.snap_yaw = true
	s = sample()
	c.step(s, 0.01)
	s.yaw = 1.0
	run_for(c, s, 1.0, 0.01)
	check(is_equal_approx(c.yaw, deg_to_rad(15)), "Snap yaw applies once while held")
	s.yaw = 0.0
	c.step(s, 0.01)
	s.yaw = -1.0
	c.step(s, 0.01)
	check(is_zero_approx(c.yaw), "Snap yaw rearms at neutral")
