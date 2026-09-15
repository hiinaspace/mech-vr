class_name PilotControls
extends RefCounted
## Cockpit-local physical pilot handles. Call before CockpitHandles, passing
## its current grabbed flags; merge motor fields after that adapter's step.
const STICK_HOME := Vector3(0, -0.42, -0.38)
const THROTTLE_HOME := Vector3(-0.49, -0.32, -0.38)
const CAPTURE_RADIUS := 0.115
const TRAVEL := 0.20
const THROTTLE_TRAVEL := 0.30
const ROTATION_TRAVEL := 0.55
const MOTOR_KEYS := ["pilot_move", "pilot_rotation", "main_throttle"]
var stick_owner := -1
var throttle_owner := -1
var throttle := 0.0
var stick_pose := Transform3D(Basis.IDENTITY, STICK_HOME)
var throttle_pose := Transform3D(Basis.IDENTITY, THROTTLE_HOME)
var _ready: Array[bool] = [false, false]
var _down: Array[bool] = [false, false]
var _stick_anchor := Transform3D.IDENTITY
var _throttle_anchor := Vector3.ZERO
var _throttle_at_grab := 0.0
var visual_root: Node3D
var stick_visual: Node3D
var throttle_visual: Node3D

func reset() -> void:
	stick_owner = -1
	throttle_owner = -1
	throttle = 0.0
	_ready = [false, false]
	_down = [false, false]
	stick_pose = Transform3D(Basis.IDENTITY, STICK_HOME)
	throttle_pose = Transform3D(Basis.IDENTITY, THROTTLE_HOME)
	_update_visual()

func step(raw: Dictionary, arm_grabbed: Array = [false, false]) -> Dictionary:
	var mapped := raw.duplicate()
	var move := Vector3.ZERO
	var rotation := Vector3.ZERO
	var live := bool(raw.get("focused", true)) and not bool(raw.get("paused", false))
	var brake := bool(raw.get("brake", false))
	# Emergency stop also closes the persistent throttle; recovery never relaunches.
	if not live or brake or not bool(raw.get("valid_left", true)): throttle = 0.0
	for i in 2:
		var hand_key: String = ["left", "right"][i]
		var physical: Transform3D = raw.get(hand_key, Transform3D.IDENTITY)
		var grip := float(raw.get(hand_key + "_grip", 0.0))
		var valid := live and bool(raw.get("valid_" + hand_key, true))
		var available := valid and not bool(arm_grabbed[i])
		if not available:
			if stick_owner == i: stick_owner = -1
			if throttle_owner == i:
				throttle_owner = -1
				if not valid: throttle = 0.0
			_ready[i] = false
			_down[i] = grip > 0.30
		elif grip <= 0.30:
			if stick_owner == i: stick_owner = -1
			if throttle_owner == i: throttle_owner = -1
			_ready[i] = true
			_down[i] = false
		elif grip >= 0.65 and not _down[i]:
			_down[i] = true
			if _ready[i]:
				if stick_owner < 0 and physical.origin.distance_to(STICK_HOME) <= CAPTURE_RADIUS:
					stick_owner = i
					_stick_anchor = physical.orthonormalized()
				elif i == 0 and throttle_owner < 0 and physical.origin.distance_to(throttle_pose.origin) <= CAPTURE_RADIUS:
					throttle_owner = i
					_throttle_anchor = physical.origin
					_throttle_at_grab = throttle
			_ready[i] = false
		if stick_owner == i:
			move = _deadzone_vector((physical.origin - _stick_anchor.origin) / TRAVEL, 0.09).limit_length(1.0)
			var q := (physical.basis.orthonormalized() * _stick_anchor.basis.inverse()).get_rotation_quaternion().normalized()
			if q.w < 0.0: q = Quaternion(-q.x, -q.y, -q.z, -q.w)
			if q.get_angle() > 0.0001:
				rotation = _deadzone_vector(q.get_axis() * q.get_angle() / ROTATION_TRAVEL, 0.10).limit_length(1.0)
			stick_pose = Transform3D(Basis(Quaternion.IDENTITY.slerp(q, minf(1.0, ROTATION_TRAVEL / maxf(q.get_angle(), 0.0001)))), STICK_HOME + move * TRAVEL)
		if throttle_owner == i:
			if brake:
				_throttle_anchor = physical.origin
				_throttle_at_grab = 0.0
			else:
				throttle = clampf(_throttle_at_grab - (physical.origin.z - _throttle_anchor.z) / THROTTLE_TRAVEL, 0.0, 1.0)
				if throttle < 0.035: throttle = 0.0
		if stick_owner == i or throttle_owner == i:
			mapped["valid_" + hand_key] = false
			mapped["ui_" + hand_key] = false
			mapped[hand_key + "_trigger"] = 1.0 # Keep downstream action gates unarmed.
	if stick_owner < 0: stick_pose = Transform3D(Basis.IDENTITY, STICK_HOME)
	throttle_pose = Transform3D(Basis.IDENTITY, THROTTLE_HOME + Vector3.FORWARD * throttle * THROTTLE_TRAVEL)
	_update_visual()
	for key in MOTOR_KEYS:
		mapped[key] = {"pilot_move": move, "pilot_rotation": rotation, "main_throttle": throttle}[key]
	var owners := ["", ""]
	if stick_owner >= 0: owners[stick_owner] = "PILOT"
	if throttle_owner >= 0: owners[throttle_owner] = "THROTTLE"
	return {"sample": mapped, "owners": owners, "pilot_move": move, "pilot_rotation": rotation,
		"main_throttle": throttle, "stick_owner": stick_owner, "throttle_owner": throttle_owner}

func _deadzone_vector(value: Vector3, deadzone: float) -> Vector3:
	var magnitude := value.length()
	return value.normalized() * clampf((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0) if magnitude > deadzone else Vector3.ZERO

func setup_visual(parent: Node3D) -> void:
	visual_root = Node3D.new()
	visual_root.name = "PilotControls"
	parent.add_child(visual_root)
	_box(visual_root, STICK_HOME + Vector3(0,-0.13,0), Vector3(0.19,0.035,0.19), Color("203c4d"))
	_box(visual_root, THROTTLE_HOME + Vector3(0,-0.09,-THROTTLE_TRAVEL/2), Vector3(0.13,0.025,THROTTLE_TRAVEL+0.13), Color("203c4d"))
	stick_visual = Node3D.new()
	visual_root.add_child(stick_visual)
	_box(stick_visual, Vector3.ZERO, Vector3(0.065,0.13,0.065), Color("58dce6"))
	throttle_visual = Node3D.new()
	visual_root.add_child(throttle_visual)
	_box(throttle_visual, Vector3.ZERO, Vector3(0.10,0.09,0.06), Color("f3b75f"))
	_label("MANEUVER / GRIP", STICK_HOME + Vector3(0,-0.16,-0.1))
	_label("MAIN THRUST", THROTTLE_HOME + Vector3(0,-0.12,-0.36))
	_update_visual()

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	node.position = at
	parent.add_child(node)

func _label(caption: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = caption
	label.font_size = 22
	label.pixel_size = 0.0005
	label.position = at
	visual_root.add_child(label)

func _update_visual() -> void:
	if is_instance_valid(stick_visual): stick_visual.transform = stick_pose
	if is_instance_valid(throttle_visual): throttle_visual.transform = throttle_pose
