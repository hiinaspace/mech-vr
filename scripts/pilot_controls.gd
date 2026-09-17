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
## The displayed vectors are the deadzoned, bounded commands sent to the motor.
var move_input := Vector3.ZERO
var rotation_input := Vector3.ZERO
var origin_tether: MeshInstance3D
var rotation_vector: MeshInstance3D
var rotation_tip: MeshInstance3D
var origin_axes: Node3D
var current_axes: Node3D
var rotation_bars: Array[MeshInstance3D] = []

func reset() -> void:
	stick_owner = -1
	throttle_owner = -1
	throttle = 0.0
	move_input = Vector3.ZERO
	rotation_input = Vector3.ZERO
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
			var displayed_basis := Basis.IDENTITY if rotation.is_zero_approx() else Basis(rotation.normalized(),rotation.length()*ROTATION_TRAVEL)
			stick_pose = Transform3D(displayed_basis, STICK_HOME + move * TRAVEL)
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
	move_input = move
	rotation_input = rotation
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
	origin_axes = Node3D.new()
	origin_axes.name = "StickOriginAxes"
	visual_root.add_child(origin_axes)
	origin_axes.position = STICK_HOME
	_tripod(origin_axes,.10,.35)
	current_axes = Node3D.new()
	current_axes.name = "StickCommandAxes"
	visual_root.add_child(current_axes)
	_tripod(current_axes,.075,1.0)
	_box(origin_axes,Vector3.ZERO,Vector3.ONE*.022,Color(.9,.9,.9,.4))
	origin_tether = _box(visual_root,Vector3.ZERO,Vector3.ONE,Color("ffd379"))
	origin_tether.name = "TranslationDemand"
	rotation_vector = _box(visual_root,Vector3.ZERO,Vector3.ONE,Color("f4a3ff"))
	rotation_vector.name = "RotationDemand"
	rotation_tip = _box(visual_root,Vector3.ZERO,Vector3.ONE*.012,Color("f4a3ff"))
	for axis in 3:
		var bar := _box(visual_root,Vector3.ZERO,Vector3.ONE,_axis_color(axis))
		bar.name = ["PitchDemand","YawDemand","RollDemand"][axis]
		rotation_bars.append(bar)
		_label(["P","Y","R"][axis],STICK_HOME+Vector3(.14,-.045-axis*.028,0))
	_label("ROT",STICK_HOME+Vector3(.20,.01,0))
	_update_visual()

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _label(caption: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = caption
	label.font_size = 22
	label.pixel_size = 0.0005
	label.position = at
	visual_root.add_child(label)

func _axis_color(axis: int, alpha: float = 1.0) -> Color:
	var color: Color = [Color("f07878"),Color("83e297"),Color("83b7ff")][axis]
	color.a = alpha
	return color

func _tripod(parent: Node3D, length: float, alpha: float) -> void:
	for axis in 3:
		var size := Vector3.ONE*.004
		size[axis] = length
		var at := Vector3.ZERO
		at[axis] = length*.5
		_box(parent,at,size,_axis_color(axis,alpha))

func _line_between(mesh: MeshInstance3D, start: Vector3, end: Vector3, width: float) -> void:
	var delta := end-start
	mesh.visible = delta.length() > .0001
	if not mesh.visible: return
	var up := Vector3.RIGHT if absf(delta.normalized().dot(Vector3.UP)) > .95 else Vector3.UP
	mesh.transform = Transform3D(Basis.looking_at(delta.normalized(),up).scaled_local(Vector3(width,width,delta.length())),(start+end)*.5)

func _update_visual() -> void:
	if is_instance_valid(stick_visual): stick_visual.transform = stick_pose
	if is_instance_valid(throttle_visual): throttle_visual.transform = throttle_pose
	if not is_instance_valid(origin_tether): return
	current_axes.transform = stick_pose
	_line_between(origin_tether,STICK_HOME,STICK_HOME+move_input*TRAVEL,.004)
	var turn_origin := STICK_HOME+Vector3(0,.12,0)
	var turn_end := turn_origin+rotation_input*.12
	_line_between(rotation_vector,turn_origin,turn_end,.004)
	rotation_tip.visible = rotation_vector.visible
	rotation_tip.position = turn_end
	for axis in 3:
		var start := STICK_HOME+Vector3(.20,-.045-axis*.028,0)
		_line_between(rotation_bars[axis],start,start+Vector3(rotation_input[axis]*.045,0,0),.006)
