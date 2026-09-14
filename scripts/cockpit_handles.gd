class_name CockpitHandles
extends RefCounted
## Physical hand poses remain in the caller's sample. This adapter generates
## robot input while cockpit-local virtual handles can be released and parked.
const CAPTURE_RADIUS := 0.12
const GRIP_PRESS := 0.65
const GRIP_RELEASE := 0.30
const HAND_KEYS := ["left", "right"]
const VALID_KEYS := ["valid_left", "valid_right"]
const GRIP_KEYS := ["left_grip", "right_grip"]

var enabled := true
var mode := "free"
var handles: Array[Transform3D] = []
var grabbed: Array[bool] = [false, false]
var initialized: Array[bool] = [false, false]
var _ready: Array[bool] = [false, false]
var _down: Array[bool] = [false, false]
var _action_gate: Array[bool] = [false, false]

func _init() -> void:
	reset()

func reset() -> void:
	handles = [Transform3D(Basis.IDENTITY, Vector3(-0.28, -0.30, -0.42)),
		Transform3D(Basis.IDENTITY, Vector3(0.28, -0.30, -0.42))]
	for i in 2:
		grabbed[i] = false
		initialized[i] = true
		_ready[i] = false
		_down[i] = false
		_action_gate[i] = false

func set_mode(value: String) -> void:
	if value not in ["free", "calibrated"] or mode == value:
		return
	mode = value
	# Never silently reinterpret a held control. The visible parked handles
	# remain where released; each hand explicitly acquires the new mapping.
	for i in 2:
		grabbed[i] = false
		_ready[i] = false

func action_inhibited(index: int) -> bool:
	return _action_gate[index]

func step(sample: Dictionary, control: MechControl, _dt: float) -> Dictionary:
	var out := sample.duplicate()
	if not enabled:
		return out
	var live := bool(sample.get("focused", true)) and not bool(sample.get("paused", false))
	for i in 2:
		var physical: Transform3D = sample.get(HAND_KEYS[i], Transform3D.IDENTITY)
		var grip := float(sample.get(GRIP_KEYS[i], 0.0))
		var valid := live and bool(sample.get(VALID_KEYS[i], true))
		var acquired := false
		if not valid:
			grabbed[i] = false
			_ready[i] = false
			_down[i] = grip > GRIP_RELEASE
		else:
			if grip <= GRIP_RELEASE:
				grabbed[i] = false
				_ready[i] = true
				_down[i] = false
			elif grip >= GRIP_PRESS and not _down[i]:
				_down[i] = true
				if _ready[i] and physical.origin.distance_to(handles[i].origin) <= CAPTURE_RADIUS:
					grabbed[i] = true
					acquired = true
				_ready[i] = false
		if grabbed[i]:
			handles[i] = physical
			# _attach captures this frame's basis and arm actual. In calibrated
			# mode that synthetic acquisition basis cancels the held arm basis:
			# next target = physical * inverse(actual_at_grab) * actual_at_grab.
			# The existing servo then recovers orientation without teleporting.
			if acquired:
				_action_gate[i] = mode == "calibrated"
			if acquired and mode == "calibrated":
				_action_gate[i] = true
				physical.basis = control.arm_actual[i].basis
			if _action_gate[i]:
				var desired: Quaternion = handles[i].basis.orthonormalized().get_rotation_quaternion()
				var angle := Quaternion.IDENTITY.angle_to(desired)
				if angle > MechControl.ARM_ANGLE:
					desired = Quaternion.IDENTITY.slerp(desired, MechControl.ARM_ANGLE / angle)
				var aligned := control.arm_actual[i].basis.get_rotation_quaternion().angle_to(desired) < deg_to_rad(2.0)
				var trigger_key: String = HAND_KEYS[i] + "_trigger"
				if not acquired and aligned and float(sample.get(trigger_key, 0.0)) <= MechControl.TRIGGER_THRESHOLD:
					_action_gate[i] = false
				else:
					# Keep the model unarmed until a REAL release after alignment.
					# Synthetic zero here would arm it and replay a held trigger.
					out[trigger_key] = 1.0
			out[HAND_KEYS[i]] = physical
		out[VALID_KEYS[i]] = valid and grabbed[i]
		out["ui_" + HAND_KEYS[i]] = false
	if not grabbed[0]:
		out["move"] = Vector3.ZERO
	if not grabbed[1]:
		out["yaw"] = 0.0
		out["vertical"] = 0.0
		out["mode_toggle"] = false
	return out
