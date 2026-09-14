class_name MechRange
extends Node3D
## Shared analytic geometry keeps muzzle reticle, rifle and swept bolts consistent.

const SHIELD_HALF := Vector3(2.0, 3.0, 0.2)
const TORSO_HALF := Vector3(1.5, 3.0, 1.5)
const MAX_RANGE := 400.0
const BOLT_SPEED := 40.0
const TELEGRAPH_TIME := 0.5

@export var cadence: float = 2.5
var hits: int = 0
var blocks: int = 0
var target_hits: int = 0
var emitter_position := Vector3(0, 0, -60)
var telegraphing: bool = false
var last_shot_kind: String = "none"
var last_impact := Vector3.ZERO
var targets: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _until_shot: float = 2.5
var _locked_target := Vector3.ZERO
var _emitter: MeshInstance3D
var _built := false

func setup() -> void:
	if _built:
		return
	_built = true
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.025, 0.04, 0.065)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.65, 0.73, 0.85)
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.0
	add_child(sun)
	_obstacle(Vector3(0, -19, -80), Vector3(400, 2, 420), Color(0.13, 0.17, 0.21))
	_obstacle(Vector3(0, 30, -245), Vector3(400, 100, 4), Color(0.2, 0.26, 0.31))
	# Docking truss: individual bars also obstruct rifle rays and suit movement.
	for x in [-42.0, 42.0]:
		_obstacle(Vector3(x, 0, -35), Vector3(1, 26, 1), Color(0.45, 0.47, 0.5))
	_obstacle(Vector3(0, 13, -35), Vector3(85, 1, 1), Color(0.45, 0.47, 0.5))
	for x in [-30.0, -15.0, 0.0, 15.0, 30.0]:
		_obstacle(Vector3(x, 11, -35), Vector3(0.35, 4, 0.35), Color(0.37, 0.4, 0.45))
	# Nearby human doorway: opening 0.9 x 2.0 m, a local scale reference.
	for x in [-7.55, -6.45]:
		_obstacle(Vector3(x, -16.9, -8), Vector3(0.2, 2.2, 0.2), Color(0.95, 0.65, 0.2))
	_obstacle(Vector3(-7, -15.7, -8), Vector3(1.3, 0.2, 0.2), Color(0.95, 0.65, 0.2))
	_label("HUMAN DOOR 2 m", Vector3(-7, -14.8, -8), 0.015)
	_add_target(Vector3(-18, -7, -60), 10.0, "60 m / 10 m")
	_add_target(Vector3(0, -5, -120), 14.0, "120 m / 14 m")
	_add_target(Vector3(24, -3, -200), 18.0, "200 m / 18 m MECH")
	_emitter = _box(emitter_position, Vector3(1.4, 1.4, 1.4), Color(1, 0.2, 0.12), true)
	_label("INCOMING / 60 m", emitter_position + Vector3(0, 4, 0), 0.025)
	for marker in [Vector3(-12, -17.9, -25), Vector3(12, -17.9, -45)]:
		_box(marker, Vector3(6, 0.12, 6), Color(0.1, 0.75, 0.85), true)
		_label("STOP MARKER", marker + Vector3(0, 3, 0), 0.035)
	reset()

func _add_target(center: Vector3, height: float, caption: String) -> void:
	var parts: Array[Dictionary] = []
	var color := Color(0.3, 0.75, 0.7)
	for part in [
		[Vector3(0, height * 0.02, 0), Vector3(height * 0.32, height * 0.42, 1)],
		[Vector3(0, height * 0.37, 0), Vector3(height * 0.17, height * 0.22, 1)],
		[Vector3(-height * 0.11, -height * 0.34, 0), Vector3(height * 0.13, height * 0.3, 1)],
		[Vector3(height * 0.11, -height * 0.34, 0), Vector3(height * 0.13, height * 0.3, 1)],
		[Vector3(-height * 0.25, 0, 0), Vector3(height * 0.12, height * 0.4, 1)],
		[Vector3(height * 0.25, 0, 0), Vector3(height * 0.12, height * 0.4, 1)]]:
		var position_world: Vector3 = center + part[0]
		var size: Vector3 = part[1]
		var mesh := _box(position_world, size, color)
		_static_box(position_world, size)
		parts.append({"transform": Transform3D(Basis.IDENTITY, position_world), "half": size * 0.5, "mesh": mesh})
	targets.append({"parts": parts, "hits": 0, "flash": 0.0})
	_label(caption, center + Vector3(0, height * 0.6, 0), 0.06)

func tick(dt: float, body_transform: Transform3D, shield_world: Transform3D) -> void:
	if dt <= 0:
		return
	var event_offset := _until_shot
	_until_shot -= dt
	if not telegraphing and _until_shot <= TELEGRAPH_TIME:
		telegraphing = true
		_locked_target = body_transform.origin
	while _until_shot <= 0:
		_spawn_bolt(_locked_target)
		# A newly emitted bolt moves only through time after its emission.
		bolts.back().delay = clampf(event_offset, 0.0, dt)
		var interval := maxf(cadence, TELEGRAPH_TIME + 0.1)
		_until_shot += interval
		event_offset += interval
		telegraphing = false
	if _until_shot <= TELEGRAPH_TIME and not telegraphing:
		telegraphing = true
		_locked_target = body_transform.origin
	if is_instance_valid(_emitter):
		_emitter.scale = Vector3.ONE * (1.7 if telegraphing else 1.0)
	for index in range(bolts.size() - 1, -1, -1):
		var bolt: Dictionary = bolts[index]
		var movement_dt := maxf(0.0, dt - float(bolt.get("delay", 0.0)))
		bolt.delay = 0.0
		var old: Vector3 = bolt.position
		var next: Vector3 = old + bolt.velocity * movement_dt
		var shield_fraction := segment_box(old, next, shield_world, SHIELD_HALF)
		var body_fraction := segment_box(old, next, body_transform, TORSO_HALF)
		if shield_fraction >= 0 and (body_fraction < 0 or shield_fraction <= body_fraction):
			blocks += 1
			last_impact = old.lerp(next, shield_fraction)
			_remove_bolt(index)
		elif body_fraction >= 0:
			hits += 1
			last_impact = old.lerp(next, body_fraction)
			_remove_bolt(index)
		else:
			bolt.position = next
			bolt.age += movement_dt
			bolt.mesh.position = next
			if bolt.age > 12.0:
				_remove_bolt(index)
	for target in targets:
		target.flash = maxf(0, target.flash - dt)
		for part in target.parts:
			part.mesh.material_override.albedo_color = Color(1, 0.85, 0.15) if target.flash > 0 else Color(0.3, 0.75, 0.7)
	for index in range(_flashes.size() - 1, -1, -1):
		_flashes[index].life -= dt
		if _flashes[index].life <= 0:
			_flashes[index].mesh.queue_free()
			_flashes.remove_at(index)

func _spawn_bolt(destination: Vector3) -> void:
	var mesh := _box(emitter_position, Vector3(0.3, 0.3, 1.2), Color(1, 0.2, 0.05), true)
	var direction := (destination - emitter_position).normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3.BACK
	mesh.quaternion = Quaternion(Vector3.FORWARD, direction)
	bolts.append({"position": emitter_position, "velocity": direction * BOLT_SPEED, "age": 0.0, "mesh": mesh})

func _remove_bolt(index: int) -> void:
	bolts[index].mesh.queue_free()
	bolts.remove_at(index)

func aim_point(muzzle: Transform3D, shield_world: Transform3D) -> Vector3:
	return _resolve(muzzle, shield_world).point

func fire(muzzle: Transform3D, shield_world: Transform3D) -> Vector3:
	var result := _resolve(muzzle, shield_world)
	last_shot_kind = result.kind
	if result.target >= 0:
		target_hits += 1
		targets[result.target].hits += 1
		targets[result.target].flash = 0.18
	var endpoint: Vector3 = result.point
	var distance := muzzle.origin.distance_to(endpoint)
	if distance > 0.001:
		var beam := _box((muzzle.origin + endpoint) * 0.5, Vector3(0.035, 0.035, distance), Color(0.3, 0.9, 1), true)
		beam.quaternion = Quaternion(Vector3.FORWARD, (endpoint - muzzle.origin).normalized())
		_flashes.append({"mesh": beam, "life": 0.075})
	return endpoint

func _resolve(muzzle: Transform3D, shield_world: Transform3D) -> Dictionary:
	var start := muzzle.origin
	var end := start - muzzle.basis.z.normalized() * MAX_RANGE
	var best := 1.0
	var target_index := -1
	var kind := "range"
	var fraction := segment_box(start, end, shield_world, SHIELD_HALF)
	if fraction >= 0:
		best = fraction
		kind = "shield"
	for index in range(targets.size()):
		for part in targets[index].parts:
			fraction = segment_box(start, end, part.transform, part.half)
			if fraction >= 0 and fraction < best:
				best = fraction
				target_index = index
				kind = "target"
	for obstacle in obstacles:
		fraction = segment_box(start, end, obstacle.transform, obstacle.half)
		if fraction >= 0 and fraction < best:
			best = fraction
			target_index = -1
			kind = "world"
	return {"point": start.lerp(end, best), "target": target_index, "kind": kind}

## Fraction of first intersection with a finite oriented box, or -1 for no hit.
## Includes segment starts inside the slab (fraction 0); handles parallel axes.
static func segment_box(from: Vector3, to: Vector3, box_transform: Transform3D, half_extents: Vector3) -> float:
	var inverse := box_transform.affine_inverse()
	var local_from := inverse * from
	var delta := inverse * to - local_from
	var entry := 0.0
	var leave := 1.0
	for axis in range(3):
		if absf(delta[axis]) < 0.000001:
			if absf(local_from[axis]) > half_extents[axis]:
				return -1.0
			continue
		var first := (-half_extents[axis] - local_from[axis]) / delta[axis]
		var second := (half_extents[axis] - local_from[axis]) / delta[axis]
		entry = maxf(entry, minf(first, second))
		leave = minf(leave, maxf(first, second))
		if entry > leave:
			return -1.0
	return entry

func reset() -> void:
	hits = 0
	blocks = 0
	target_hits = 0
	telegraphing = false
	_until_shot = maxf(cadence, TELEGRAPH_TIME + 0.1)
	last_shot_kind = "none"
	last_impact = Vector3.ZERO
	for bolt in bolts:
		bolt.mesh.queue_free()
	bolts.clear()
	for flash in _flashes:
		flash.mesh.queue_free()
	_flashes.clear()
	for target in targets:
		target.hits = 0
		target.flash = 0.0

func _obstacle(center: Vector3, size: Vector3, color: Color) -> void:
	_box(center, size, color)
	_static_box(center, size)
	obstacles.append({"transform": Transform3D(Basis.IDENTITY, center), "half": size * 0.5})

func _static_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _box(center: Vector3, size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = material
	instance.position = center
	add_child(instance)
	return instance

func _label(caption: String, center: Vector3, pixel: float) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position = center
	label.pixel_size = pixel
	label.font_size = 40
	label.no_depth_test = false
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
