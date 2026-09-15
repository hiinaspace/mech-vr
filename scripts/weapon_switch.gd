class_name WeaponSwitch
extends RefCounted
## Weapon selection uses physical cockpit-local head/hand poses, never amplified
## robot arm poses. This module creates visual geometry only.
const TRIGGER_PRESS := 0.55
const TRIGGER_RELEASE := 0.30
const DOCK_HALF_WIDTH := 0.65
const DOCK_BOTTOM := -0.40
const DOCK_TOP := 0.55
const DOCK_FRONT := 0.05
const DOCK_BACK := 0.70

var sword := false
var return_anywhere := false
var visual_root: Node3D
var _armed := false
var _down := false
var _consume_until_release := false
var _last_heading := Vector3.BACK

func reset() -> void:
	sword = false
	_armed = false
	_down = false
	_consume_until_release = false
	_last_heading = Vector3.BACK
	if is_instance_valid(visual_root): visual_root.visible = false

func dock_contains(head: Transform3D, right: Transform3D) -> bool:
	# Project the head's rear direction onto the cockpit horizontal plane.
	# Retain the last usable heading when looking directly up/down.
	var rear := head.basis.z
	rear.y = 0.0
	if rear.length_squared() > 0.01: _last_heading = rear.normalized()
	var relative := right.origin - head.origin
	var depth := relative.dot(_last_heading)
	var lateral := relative.dot(Vector3.UP.cross(_last_heading))
	return absf(lateral) <= DOCK_HALF_WIDTH and relative.y >= DOCK_BOTTOM \
		and relative.y <= DOCK_TOP and depth >= DOCK_FRONT and depth <= DOCK_BACK

func step(sample: Dictionary, eligible: bool) -> Dictionary:
	var live := bool(sample.get("focused", true)) and not bool(sample.get("paused", false)) \
		and bool(sample.get("valid_right", true)) and bool(sample.get("valid_head", true))
	var near := live and dock_contains(sample.get("head", Transform3D.IDENTITY),
		sample.get("right", Transform3D.IDENTITY))
	var trigger := float(sample.get("right_trigger", 0.0))
	var changed := false
	var action_ready := live and eligible
	if not action_ready:
		# Handoff and recovery cannot inherit a previously observed release.
		_armed = false
		_down = trigger > TRIGGER_RELEASE
	elif trigger <= TRIGGER_RELEASE:
		_armed = true
		_down = false
	elif trigger >= TRIGGER_PRESS and not _down:
		_down = true
		if _armed and (near or (sword and return_anywhere)):
			sword = not sword
			changed = true
			_consume_until_release = true
		_armed = false
	# Carry consumption out of the dock: otherwise holding the swap press while
	# moving forward could fire the newly selected rifle or click the MFD.
	if trigger <= TRIGGER_RELEASE: _consume_until_release = false
	if is_instance_valid(visual_root): visual_root.visible = sword
	return {"sword": sword, "consume_trigger": near or _consume_until_release,
		"dock_near": near, "changed": changed, "dock_ready": near and action_ready and _armed}

func setup_visual(parent: Node3D) -> Node3D:
	visual_root = Node3D.new()
	visual_root.name = "BeamSword"
	parent.add_child(visual_root)
	_box(Vector3(.46,.55,1.1), Vector3(0,0,-.4), Color("667184"), 0.0)
	_box(Vector3(.95,.20,.25), Vector3(0,0,-.95), Color("db9cb9"), 0.0)
	# Thick emissive shell and a white core remain legible without postprocessing.
	_box(Vector3(.22,.30,5.7), Vector3(0,0,-3.90), Color(1,.08,.45,.22), 4.0)
	_box(Vector3(.095,.15,5.50), Vector3(0,0,-3.80), Color("ffe7fb"), 7.0)
	var light := OmniLight3D.new()
	light.name = "SwordGlow"
	light.light_color = Color("ff4baf")
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0,0,-1.4)
	visual_root.add_child(light)
	visual_root.visible = sword
	return visual_root

func _box(size: Vector3, position: Vector3, color: Color, emission: float) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .4
	if color.a<1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	instance.material_override = material
	visual_root.add_child(instance)
