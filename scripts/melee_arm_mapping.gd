class_name MeleeArmMapping
extends RefCounted
## Pure cockpit-reference mapping. No HMD/world pose or actual actuator feedback
## enters a parked command; finite motor lag must never integrate into its target.
const CONFIG_PATH := "user://melee-arm-calibration.cfg"
const NEUTRALS := [Vector3(-5,-2,-5), Vector3(5,-2,-5)]
const DEFAULT_HANDLES := [Vector3(-.28,-.30,-.42), Vector3(.28,-.30,-.42)]
const HAND_KEYS := ["left", "right"]
const TRIGGER_PRESS := .55
const TRIGGER_RELEASE := .3
var position_gain := Vector3(8,8,8)
var targets: Array[Transform3D] = []
var handle_poses: Array[Transform3D] = []
## Position: target = gain * handle.position + offset.position.
## Orientation: target = handle.orientation * offset.orientation.
var offsets: Array[Transform3D] = []
var calibration_mode := false
var adjusting: Array[bool] = [false,false]
var _grabbed: Array[bool] = [false,false]
var _trigger_ready: Array[bool] = [false,false]
var _grab_hand: Array[Transform3D] = [Transform3D.IDENTITY,Transform3D.IDENTITY]
var _grab_handle: Array[Transform3D] = [Transform3D.IDENTITY,Transform3D.IDENTITY]
var _before_calibration: Dictionary = {}

func _init() -> void:
	reset_calibration()

func step(sample: Dictionary, grabbed: Array[bool]) -> Array[Transform3D]:
	var live := bool(sample.get("focused",true)) and not bool(sample.get("paused",false))
	for i in 2:
		var hand: Transform3D = sample.get(HAND_KEYS[i],Transform3D.IDENTITY)
		var valid := live and bool(sample.get("valid_"+HAND_KEYS[i],true)) and _finite_pose(hand)
		var held := valid and grabbed[i]
		var trigger := float(sample.get(HAND_KEYS[i]+"_trigger",0.0))
		if held:
			if not _grabbed[i]:
				# Capture the hand-to-handle difference, not the deflected robot arm.
				# This preserves the absolute calibration and avoids target jumps
				# when a grab occurs near, rather than exactly on, the handle.
				_grab_hand[i] = hand.orthonormalized()
				_grab_handle[i] = handle_poses[i]
			var pose := Transform3D(hand.basis.orthonormalized() * _grab_hand[i].basis.inverse() * _grab_handle[i].basis,
				_grab_handle[i].origin + hand.origin - _grab_hand[i].origin)
			handle_poses[i] = pose
			var was_adjusting := adjusting[i]
			if calibration_mode and trigger <= TRIGGER_RELEASE:
				_trigger_ready[i] = true
				adjusting[i] = false
			elif calibration_mode and trigger >= TRIGGER_PRESS and _trigger_ready[i]:
				adjusting[i] = true
			if adjusting[i] or was_adjusting:
				# Target remains latched while moving both translation and rotation
				# of the cockpit handle; release continues with the new offset.
				offsets[i] = Transform3D(pose.basis.inverse() * targets[i].basis,
					targets[i].origin - position_gain * pose.origin)
			else:
				targets[i] = map_pose(i,pose)
		else:
			adjusting[i] = false
			_trigger_ready[i] = false
		_grabbed[i] = held
	return targets.duplicate()

func map_pose(index: int, pose: Transform3D) -> Transform3D:
	return Transform3D(pose.basis * offsets[index].basis,position_gain * pose.origin + offsets[index].origin)

func inverse_map(index: int, target_ref_pose: Transform3D) -> Transform3D:
	return Transform3D(target_ref_pose.basis * offsets[index].basis.inverse(),(target_ref_pose.origin-offsets[index].origin)/position_gain)

func begin_calibration() -> void:
	if calibration_mode: return
	_before_calibration = capture_configuration()
	calibration_mode = true
	adjusting = [false,false]
	_trigger_ready = [false,false]

func finish_calibration(path := CONFIG_PATH) -> Error:
	var error := save_calibration(path)
	if error == OK:
		calibration_mode = false
		adjusting = [false,false]
		_before_calibration = {}
	return error

func cancel_calibration() -> void:
	if not calibration_mode: return
	var held_targets := targets.duplicate()
	if not _before_calibration.is_empty(): restore_configuration(_before_calibration)
	# Restore the previous mapping while keeping robot commands continuous.
	# The parked handles move to the inverse locations of those current commands.
	for i in 2:
		targets[i] = held_targets[i]
		handle_poses[i] = inverse_map(i,targets[i])
	calibration_mode = false
	adjusting = [false,false]
	_grabbed = [false,false]
	_before_calibration = {}

func reset_calibration() -> void:
	position_gain = Vector3(8,8,8)
	targets.clear()
	handle_poses.clear()
	offsets.clear()
	for i in 2:
		targets.append(Transform3D(Basis.IDENTITY,NEUTRALS[i]))
		handle_poses.append(Transform3D(Basis.IDENTITY,DEFAULT_HANDLES[i]))
		offsets.append(Transform3D(Basis.IDENTITY,NEUTRALS[i]-position_gain*DEFAULT_HANDLES[i]))
	calibration_mode = false
	adjusting = [false,false]
	_grabbed = [false,false]
	_trigger_ready = [false,false]
	_before_calibration = {}

func reset_targets() -> void:
	## For a scenario reset to the neutral robot, retain calibrated offsets.
	for i in 2:
		targets[i] = Transform3D(Basis.IDENTITY,NEUTRALS[i])
		handle_poses[i] = inverse_map(i,targets[i])
	adjusting = [false,false]
	_grabbed = [false,false]
	_trigger_ready = [false,false]

func capture_configuration() -> Dictionary:
	return {"version":1,"gain":position_gain,"offsets":offsets.duplicate(),"handles":handle_poses.duplicate()}

func restore_configuration(config: Dictionary) -> Error:
	if config.get("version",0) != 1 or not config.get("gain") is Vector3: return ERR_INVALID_DATA
	var gain: Vector3 = config.gain
	if not gain.is_finite() or gain.x <= .01 or gain.y <= .01 or gain.z <= .01: return ERR_INVALID_DATA
	for key in ["offsets","handles"]:
		if not config.get(key) is Array or config[key].size()!=2: return ERR_INVALID_DATA
		for pose in config[key]:
			if not pose is Transform3D or not _finite_pose(pose) or absf(pose.basis.determinant()-1.0) > .001: return ERR_INVALID_DATA
	position_gain = gain
	for i in 2:
		offsets[i] = config.offsets[i].orthonormalized()
		handle_poses[i] = config.handles[i].orthonormalized()
		targets[i] = map_pose(i,handle_poses[i])
	_grabbed = [false,false]
	adjusting = [false,false]
	_trigger_ready = [false,false]
	return OK

func save_calibration(path := CONFIG_PATH) -> Error:
	var config := ConfigFile.new()
	var data := capture_configuration()
	for key in data: config.set_value("arm_mapping",key,data[key])
	return config.save(path)

func load_calibration(path := CONFIG_PATH) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK: return error
	var data := {}
	for key in ["version","gain","offsets","handles"]:
		data[key] = config.get_value("arm_mapping",key)
	return restore_configuration(data)

static func _finite_pose(pose: Transform3D) -> bool:
	return pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite() and absf(pose.basis.determinant()) > .00001
