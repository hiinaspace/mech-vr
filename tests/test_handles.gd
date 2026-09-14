extends SceneTree
const ControlModel = preload("res://scripts/control_model.gd")
const Handles = preload("res://scripts/cockpit_handles.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func sample(h: RefCounted) -> Dictionary:
	return {"left": h.handles[0], "right": h.handles[1], "left_grip": 0.0,
		"right_grip": 0.0, "valid_left": true, "valid_right": true, "focused": true}

func tick(h: RefCounted, c: MechControl, s: Dictionary) -> Dictionary:
	return c.step(h.step(s, c, 0.01), 0.01)

func _initialize() -> void:
	var h := Handles.new()
	var c := ControlModel.new()
	var s := sample(h)
	tick(h, c, s)
	check(c.owners == ["HOLD", "HOLD"], "Both arms start parked")
	s.left_grip = 1.0
	s.right_grip = 1.0
	tick(h, c, s)
	check(h.grabbed == [true, true], "Each hand freshly acquires its nearby handle")
	s.right.origin += Vector3(0.2, 0.1, 0.0)
	s.right.basis = Basis(Vector3.UP, 0.4)
	for _frame in 100:
		tick(h, c, s)
	var arm := c.arm_actual[1]
	var parked := h.handles[1]
	s.right_grip = 0.0
	tick(h, c, s)
	s.right.origin += Vector3(0.4, -0.1, 0.3)
	tick(h, c, s)
	check(h.handles[1].is_equal_approx(parked), "Released diegetic control stays in cockpit")
	check(c.arm_actual[1].is_equal_approx(arm), "Released robot arm holds actual pose")
	check(h.grabbed[0] and not h.grabbed[1], "Release is independent per hand")
	s.right_grip = 1.0
	tick(h, c, s)
	check(not h.grabbed[1], "Distant squeeze cannot acquire handle")
	s.right = parked
	tick(h, c, s)
	check(not h.grabbed[1], "Moving into range with held grip cannot acquire")
	s.right_grip = 0.0
	tick(h, c, s)
	s.right.basis = Basis(Vector3.UP, -0.3)
	s.right_grip = 1.0
	s.right_trigger = 1.0
	check(not tick(h, c, s).fire, "Regrab suppresses held trigger")
	check(c.arm_targets[1].is_equal_approx(arm), "Free regrab preserves arm target at arbitrary hand rotation")
	check(not tick(h, c, s).fire, "Held trigger remains suppressed")
	s.right_trigger = 0.0
	tick(h, c, s)
	s.right_trigger = 1.0
	check(tick(h, c, s).fire, "Fresh trigger after regrab fires")
	var original: Transform3D = s.right
	h.set_mode("calibrated")
	tick(h, c, s)
	check(not h.grabbed[0] and not h.grabbed[1], "Mode change parks both arms and rejects held grip")
	s.right_grip = 0.0
	tick(h, c, s)
	s.right_grip = 1.0
	tick(h, c, s)
	check(s.right.is_equal_approx(original), "Synthetic mapped sample never alters physical hand sample")
	var before := c.arm_actual[1].basis.get_rotation_quaternion()
	tick(h, c, s)
	check(c.arm_targets[1].basis.is_equal_approx(s.right.basis), "Calibrated regrab recovers global cockpit orientation")
	var after := c.arm_actual[1].basis.get_rotation_quaternion()
	check(before.angle_to(after) <= c.arm_angular_speed * 0.0101, "Orientation recovery respects servo angular limit")
	for _frame in 100:
		check(not tick(h, c, s).fire, "Calibrated recovery cannot resume held fire, even after alignment")
	s.right_trigger = 0.0
	tick(h, c, s)
	s.right_trigger = 1.0
	check(tick(h, c, s).fire, "Calibrated mode requires actual trigger release after alignment")
	s.valid_right = false
	tick(h, c, s)
	s.valid_right = true
	tick(h, c, s)
	check(not h.grabbed[1], "Tracking recovery requires new release then squeeze")
	s.right_grip = 0.0
	tick(h, c, s)
	s.right_grip = 1.0
	tick(h, c, s)
	check(h.grabbed[1], "Tracking recovery succeeds after fresh squeeze")
	s.focused = false
	tick(h, c, s)
	s.focused = true
	tick(h, c, s)
	check(not h.grabbed[1], "Focus recovery also rejects held squeeze")
	print("HANDLES_TESTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
