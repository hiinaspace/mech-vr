class_name MechControl
extends RefCounted
## Deterministic M0a control state. Every pose is in the unscaled cockpit frame.
## The caller samples input once, steps this model, then moves/collides the body
## and resolves weapons using arm_actual. It may replace velocity after collision.

const NEUTRALS := [Vector3(-5, -2, -5), Vector3(5, -2, -5)]
const HAND_KEYS := ["left", "right"]
const TRIGGER_KEYS := ["left_trigger", "right_trigger"]
const VALID_KEYS := ["valid_left", "valid_right"]
const UI_KEYS := ["ui_left", "ui_right"]
const TRIGGER_THRESHOLD := 0.55
const ARM_REACH := 7.0
const ARM_ANGLE := deg_to_rad(80.0)

var velocity := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var yaw_rate := 0.0
var pitch_rate := 0.0
var roll_rate := 0.0
var body_basis := Basis.IDENTITY
var advanced_attitude := false
var main_throttle := 0.0
var boost := 1.0
var owners: Array[String] = ["ARM", "ARM"]
var arm_targets: Array[Transform3D] = []
var arm_actual: Array[Transform3D] = []
var position_gain := Vector3(8, 8, 8)
var arm_speed := 18.0
var arm_acceleration := 100.0
var arm_angular_speed := deg_to_rad(150.0)
var yaw_speed := deg_to_rad(30.0)
var pitch_speed := deg_to_rad(20.0)
var snap_yaw := false
var snap_angle := deg_to_rad(15.0)
var attitude_mode := false
var mode_neutral_required := false
var movement_neutral_required := false

var _anchor_hand: Array[Transform3D] = []
var _anchor_arm: Array[Transform3D] = []
var _arm_velocity: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _calibrated: Array[bool] = [false, false]
var _trigger_ready: Array[bool] = [false, false]
var _trigger_down: Array[bool] = [false, false]
var _ui_down: Array[bool] = [false, false]
var _mode_down := false
var _suspended := false
var _boost_depleted := false
var _snap_ready := false

func _init() -> void:
	reset()

func reset() -> void:
	velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	yaw_rate = 0.0
	pitch_rate = 0.0
	boost = 1.0
	roll_rate = 0.0
	body_basis = Basis.IDENTITY
	advanced_attitude = false
	main_throttle = 0.0
	attitude_mode = false
	mode_neutral_required = false
	movement_neutral_required = false
	_mode_down = false
	_suspended = false
	_boost_depleted = false
	_snap_ready = false
	arm_targets.clear()
	arm_actual.clear()
	_anchor_hand.clear()
	_anchor_arm.clear()
	for i in 2:
		var neutral := Transform3D(Basis.IDENTITY, NEUTRALS[i])
		arm_targets.append(neutral)
		arm_actual.append(neutral)
		_anchor_hand.append(Transform3D.IDENTITY)
		_anchor_arm.append(neutral)
		owners[i] = "ARM"
		_calibrated[i] = false
		_trigger_ready[i] = false
		_trigger_down[i] = false
		_ui_down[i] = false
		_arm_velocity[i] = Vector3.ZERO

func _hold(i: int, owner: String) -> void:
	owners[i] = owner
	arm_targets[i] = arm_actual[i]
	_arm_velocity[i] = Vector3.ZERO
	_trigger_ready[i] = false

func set_turn_options(slow_turn: bool, snap: bool) -> void:
	yaw_speed = deg_to_rad(15.0 if slow_turn else 30.0)
	pitch_speed = deg_to_rad(10.0 if slow_turn else 20.0)
	snap_yaw = snap
	yaw_rate = 0.0
	pitch_rate = 0.0
	_snap_ready = false

func _attach(i: int, hand: Transform3D) -> void:
	_anchor_hand[i] = hand.orthonormalized()
	_anchor_arm[i] = arm_actual[i]
	arm_targets[i] = arm_actual[i]
	_arm_velocity[i] = Vector3.ZERO
	owners[i] = "ARM"
	_calibrated[i] = true
	_trigger_ready[i] = false

func _target(i: int, hand: Transform3D) -> Transform3D:
	var position := _anchor_arm[i].origin + position_gain * (hand.origin - _anchor_hand[i].origin)
	position = NEUTRALS[i] + (position - NEUTRALS[i]).limit_length(ARM_REACH)
	var rotation := (hand.basis.orthonormalized().get_rotation_quaternion() *
		_anchor_hand[i].basis.get_rotation_quaternion().inverse() *
		_anchor_arm[i].basis.get_rotation_quaternion()).normalized()
	var angle := Quaternion.IDENTITY.angle_to(rotation)
	if angle > ARM_ANGLE:
		rotation = Quaternion.IDENTITY.slerp(rotation, ARM_ANGLE / angle)
	return Transform3D(Basis(rotation), position)

func _servo(i: int, dt: float) -> void:
	var offset := arm_targets[i].origin - arm_actual[i].origin
	# Braking-distance-limited target speed avoids ballistic overshoot at arrival.
	var wanted := offset.normalized() * minf(arm_speed, sqrt(2.0 * arm_acceleration * offset.length()))
	_arm_velocity[i] = _arm_velocity[i].move_toward(wanted, arm_acceleration * dt)
	var displacement := _arm_velocity[i] * dt
	if displacement.length() >= offset.length() and displacement.dot(offset) >= 0.0:
		displacement = offset
		_arm_velocity[i] = Vector3.ZERO
	var current := arm_actual[i].basis.get_rotation_quaternion()
	var target := arm_targets[i].basis.get_rotation_quaternion()
	var angle := current.angle_to(target)
	var rotation := current.slerp(target, minf(1.0, arm_angular_speed * dt / maxf(angle, 0.00001)))
	var position := arm_actual[i].origin + displacement
	# Servo inertia must never take the actual arm outside the same reach volume.
	var bounded: Vector3 = NEUTRALS[i] + (position - NEUTRALS[i]).limit_length(ARM_REACH)
	if not bounded.is_equal_approx(position):
		_arm_velocity[i] = Vector3.ZERO
	arm_actual[i] = Transform3D(Basis(rotation), bounded)

func step(sample: Dictionary, dt: float) -> Dictionary:
	dt = clampf(dt, 0.0, 0.1)
	var paused := bool(sample.get("paused", false)) or not bool(sample.get("focused", true))
	var result := {"fire": false, "click_left": false, "click_right": false,
		"boost_active": false, "paused": paused}
	var hands: Array[Transform3D] = [sample.get("left", Transform3D.IDENTITY), sample.get("right", Transform3D.IDENTITY)]
	var valid: Array[bool] = [sample.get("valid_left", true), sample.get("valid_right", true)]
	var triggers: Array[bool] = [float(sample.get("left_trigger", 0.0)) > TRIGGER_THRESHOLD,
		float(sample.get("right_trigger", 0.0)) > TRIGGER_THRESHOLD]
	var ui: Array[bool] = [sample.get("ui_left", false), sample.get("ui_right", false)]
	var toggle := bool(sample.get("mode_toggle", false))
	if paused:
		main_throttle = 0.0
		roll_rate = 0.0
		for i in 2:
			_hold(i, "HOLD")
			yaw_rate = 0.0
			pitch_rate = 0.0
			_trigger_down[i] = triggers[i]
			_ui_down[i] = ui[i]
		_mode_down = toggle
		_snap_ready = false
		_suspended = true
		return _finish_result(result)
	if _suspended:
		# Right-stick mode and actions must pass through neutral after focus returns.
		mode_neutral_required = true
		movement_neutral_required = true
		_suspended = false
	for i in 2:
		if not valid[i]:
			_hold(i, "HOLD")
		elif not _calibrated[i] or owners[i] == "HOLD":
			_attach(i, hands[i])
	# A simultaneous UI request has a deterministic winner (right); only one owner.
	for i in 2:
		if ui[i] and not _ui_down[i] and valid[i]:
			if owners[i] == "UI":
				_attach(i, hands[i])
			else:
				var other := 1 - i
				if owners[other] == "UI":
					_attach(other, hands[other])
				_hold(i, "UI")
	for i in 2:
		if valid[i] and not triggers[i]:
			_trigger_ready[i] = true
		if owners[i] == "ARM":
			arm_targets[i] = _target(i, hands[i])
			_servo(i, dt)
		elif owners[i] == "UI" and _trigger_ready[i] and triggers[i] and not _trigger_down[i]:
			result["click_" + HAND_KEYS[i]] = true
	result.fire = owners[1] == "ARM" and _trigger_ready[1] and triggers[1]
	if not triggers[0]:
		_boost_depleted = false
	var boosting: bool = owners[0] == "ARM" and _trigger_ready[0] and triggers[0] and not _boost_depleted and boost > 0.0
	var brake := bool(sample.get("brake", false))
	boosting = boosting and not brake
	if boosting:
		boost = maxf(0.0, boost - dt / 2.0)
		if boost <= 0.0:
			_boost_depleted = true
	else:
		boost = minf(1.0, boost + dt / 4.0)
	result.boost_active = boosting
	if toggle and not _mode_down:
		attitude_mode = not attitude_mode
		mode_neutral_required = true
	var vertical := clampf(float(sample.get("vertical", 0.0)), -1.0, 1.0)
	var yaw_input := clampf(float(sample.get("yaw", 0.0)), -1.0, 1.0)
	var move: Vector3 = sample.get("move", Vector3.ZERO)
	if movement_neutral_required:
		if move.length() < 0.15 and absf(vertical) < 0.15 and absf(yaw_input) < 0.15:
			movement_neutral_required = false
		move = Vector3.ZERO
		vertical = 0.0
		yaw_input = 0.0
	if mode_neutral_required:
		if absf(vertical) < 0.15 and absf(yaw_input) < 0.15:
			mode_neutral_required = false
		vertical = 0.0
	var pilot_rotation: Vector3 = sample.get("pilot_rotation", Vector3.ZERO)
	if movement_neutral_required: pilot_rotation = Vector3.ZERO
	if not pilot_rotation.is_zero_approx(): advanced_attitude = true
	var thumbstick_basis: Basis = sample.get("thumbstick_basis",Basis.IDENTITY)
	var stick_rates := thumbstick_basis*Vector3(vertical*pitch_speed if attitude_mode else 0.0,0,0)
	stick_rates.y += yaw_input*yaw_speed
	if absf(stick_rates.z)>.00001: advanced_attitude = true
	var desired_pitch := stick_rates.x
	desired_pitch += pilot_rotation.x * deg_to_rad(35.0)
	var old_yaw := yaw
	if snap_yaw:
		yaw_rate = move_toward(yaw_rate, pilot_rotation.y * deg_to_rad(45.0), deg_to_rad(150.0) * dt)
		if absf(yaw_input) < 0.15:
			_snap_ready = true
		elif absf(yaw_input) > 0.7 and _snap_ready:
			yaw = wrapf(yaw + signf(yaw_input) * snap_angle, -PI, PI)
			_snap_ready = false
	else:
		yaw_rate = move_toward(yaw_rate, (stick_rates.y + pilot_rotation.y * deg_to_rad(45.0)), deg_to_rad(150.0) * dt)
	pitch_rate = move_toward(pitch_rate, desired_pitch, deg_to_rad(100.0) * dt)
	yaw = wrapf(yaw + yaw_rate * dt, -PI, PI)
	pitch = pitch + pitch_rate * dt if advanced_attitude else clampf(pitch + pitch_rate * dt, deg_to_rad(-75), deg_to_rad(75))
	if not advanced_attitude and absf(pitch) >= deg_to_rad(75) and signf(pitch_rate) == signf(pitch):
		pitch_rate = 0.0
	roll_rate = move_toward(roll_rate, stick_rates.z + pilot_rotation.z * deg_to_rad(45.0), deg_to_rad(150.0) * dt)
	if advanced_attitude:
		# Increment local rotation without Euler reconstruction: stable through roll/poles.
		var rates := Vector3(pitch_rate * dt, wrapf(yaw - old_yaw, -PI, PI), roll_rate * dt)
		if rates.length() > 0.000001:
			body_basis = (body_basis * Basis(Quaternion(rates.normalized(), rates.length()))).orthonormalized()
		var angles := body_basis.get_euler()
		yaw = angles.y
		pitch = angles.x
	else:
		body_basis = Basis.from_euler(Vector3(pitch, yaw, 0))
	if not attitude_mode:
		move.y += vertical
	move = thumbstick_basis * move
	move += sample.get("pilot_move", Vector3.ZERO)
	move = move.limit_length(1.0)
	var basis := body_basis
	var desired_velocity := basis * move * (30.0 if boosting else 12.0)
	var acceleration := 30.0 if boosting else 12.0
	if move.is_zero_approx():
		acceleration = 8.0
	var requested_throttle := clampf(float(sample.get("main_throttle", 0.0)), 0.0, 1.0)
	main_throttle = move_toward(main_throttle, requested_throttle, dt * 0.65)
	if main_throttle > 0.0:
		desired_velocity += -basis.z * main_throttle * 90.0
		acceleration = 20.0 + main_throttle * 22.0
	if brake:
		main_throttle = 0.0
		desired_velocity = Vector3.ZERO
		acceleration = 45.0
	velocity = velocity.move_toward(desired_velocity, acceleration * dt)
	for i in 2:
		_trigger_down[i] = triggers[i]
		_ui_down[i] = ui[i]
	_mode_down = toggle
	return _finish_result(result)

func _finish_result(result: Dictionary) -> Dictionary:
	result["attitude_mode"] = attitude_mode
	result["mode_neutral_required"] = mode_neutral_required
	result["movement_neutral_required"] = movement_neutral_required
	result["yaw_rate"] = yaw_rate
	result["pitch_rate"] = pitch_rate
	result["body_basis"] = body_basis
	result["roll_rate"] = roll_rate
	result["main_throttle"] = main_throttle
	return result
