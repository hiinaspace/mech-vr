class_name MechRange
extends Node3D
## Shared analytic geometry keeps muzzle reticle, rifle and swept bolts consistent.

const SHIELD_HALF := Vector3(2.0, 3.0, 0.2)
const TORSO_HALF := Vector3(1.5, 3.0, 1.5)
const MAX_RANGE := 2600.0
const PLAYER_SPEED := 240.0
const MAX_PROJECTILES := 96
const MAX_EFFECTS := 120
const BOLT_SPEED := 40.0
const TELEGRAPH_TIME := 0.5

@export var cadence: float = 2.5
var hits: int = 0
var blocks: int = 0
var target_hits: int = 0
var shots_fired: int = 0
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
var pulses: Array[Dictionary] = []
var emitters: Array[Dictionary] = []
var _time := 0.0
var _sword_valid := false
var _sword_base := Vector3.ZERO
var _sword_tip := Vector3.ZERO
var _sword_contacts: Array[int] = []

func setup() -> void:
	if _built:
		return
	_built = true
	var dressing := preload("res://scripts/space_dressing.gd").new()
	add_child(dressing)
	dressing.setup()
	# Local practice deck and low backstop; the colony beyond is decorative.
	_obstacle(Vector3(0,-19,-35),Vector3(90,2,110),Color("293d4c"))
	_obstacle(Vector3(0,-8,-245),Vector3(80,16,4),Color("354956"))
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
	for entry in [
		[Vector3(-180, 60, -430), 22.0, Vector3(35, 15, 0)],
		[Vector3(170, 90, -650), 24.0, Vector3.ZERO],
		[Vector3(-550, 190, -900), 28.0, Vector3(0, 35, 55)],
		[Vector3(400, -70, -1100), 28.0, Vector3(70, 0, 0)],
		[Vector3(-750, 350, -1500), 32.0, Vector3.ZERO],
		[Vector3(250, 420, -1750), 32.0, Vector3(65, 25, 0)]]:
		_add_target(entry[0], entry[1], "OUTER RANGE")
		targets.back().motion = entry[2]
	for origin in [Vector3(-110, 45, -350), Vector3(200, 100, -700), Vector3(-580, 180, -1100)]:
		var turret := _box(origin, Vector3(5, 5, 8), Color(1, .24, .07), true)
		emitters.append({"position": origin, "mesh": turret, "timer": 4.5 + emitters.size(), "locked": Vector3.ZERO})
	_emitter = _box(emitter_position, Vector3(1.4, 1.4, 1.4), Color(1, 0.2, 0.12), true)
	_label("INCOMING / 60 m", emitter_position + Vector3(0, 4, 0), 0.025)
	for marker in [Vector3(-12, -17.9, -25), Vector3(12, -17.9, -45)]:
		_box(marker, Vector3(6, 0.12, 6), Color(0.1, 0.75, 0.85), true)
		_label("STOP MARKER", marker + Vector3(0, 3, 0), 0.035)
	reset()

func _add_target(center: Vector3, height: float, _caption: String) -> void:
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
		var body := _static_box(position_world, size)
		parts.append({"transform": Transform3D(Basis.IDENTITY, position_world), "half": size * 0.5, "mesh": mesh, "body": body, "local": part[0]})
	targets.append({"center": center, "height": height, "motion": Vector3.ZERO, "hud_position": center + Vector3(0,height*.75,0), "parts": parts, "hits": 0, "flash": 0.0})
	# Contact identity/range now lives in the 3D HUD.

func tick(dt: float, body_transform: Transform3D, shield_world: Transform3D, torso_half := TORSO_HALF) -> void:
	if dt <= 0:
		return
	for index in range(_flashes.size() - 1, -1, -1):
		_flashes[index].life -= dt
		var flash: Dictionary = _flashes[index]
		flash.mesh.position += flash.get("velocity", Vector3.ZERO) * dt
		flash.mesh.scale = Vector3.ONE * maxf(.05, flash.life / flash.get("duration", .5))
		if _flashes[index].life <= 0:
			_flashes[index].mesh.queue_free()
			_flashes.remove_at(index)

	_time += dt
	_update_targets()
	_tick_pulses(dt, shield_world)
	for emitter in emitters:
		# Outer turrets wake only within useful interception range.
		if emitter.position.distance_to(body_transform.origin) > 260.0:
			emitter.timer = 4.0
			emitter.mesh.scale = Vector3.ONE
			continue
		var outer_delay: float = maxf(0.0, emitter.timer)
		emitter.timer -= dt
		if outer_delay > TELEGRAPH_TIME:
			emitter.locked = body_transform.origin
		emitter.mesh.scale = Vector3.ONE * (1.5 if emitter.timer <= TELEGRAPH_TIME else 1.0)
		if emitter.timer <= 0:
			_spawn_bolt(emitter.locked, emitter.position)
			bolts.back().delay = minf(outer_delay, dt)
			emitter.timer += 4.0
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
		var body_fraction := segment_box(old, next, body_transform, torso_half)
		if shield_fraction >= 0 and (body_fraction < 0 or shield_fraction <= body_fraction):
			blocks += 1
			last_impact = old.lerp(next, shield_fraction)
			_burst(last_impact, Color(.3, .85, 1), true)
			_remove_bolt(index)
		elif body_fraction >= 0:
			hits += 1
			last_impact = old.lerp(next, body_fraction)
			_burst(last_impact, Color(1, .35, .08))
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

func _spawn_bolt(destination: Vector3, origin := emitter_position) -> void:
	if bolts.size() >= MAX_PROJECTILES:
		_remove_bolt(0)
	var mesh := _box(origin, Vector3(0.55, 0.55, 5.0), Color(1, 0.2, 0.05), true)
	var direction := (destination - origin).normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3.BACK
	mesh.quaternion = Quaternion(Vector3.FORWARD, direction)
	bolts.append({"position": origin, "velocity": direction * BOLT_SPEED, "age": 0.0, "mesh": mesh})

func _remove_bolt(index: int) -> void:
	bolts[index].mesh.queue_free()
	bolts.remove_at(index)

func aim_point(muzzle: Transform3D, shield_world: Transform3D) -> Vector3:
	return _resolve(muzzle, shield_world).point

func fire(muzzle: Transform3D, shield_world: Transform3D) -> Vector3:
	shots_fired += 1
	var result := _resolve(muzzle, shield_world)
	last_shot_kind = result.kind
	if pulses.size() >= MAX_PROJECTILES:
		pulses.pop_front().mesh.queue_free()
	var direction := -muzzle.basis.z.normalized()
	var mesh := _box(muzzle.origin, Vector3(.28, .28, 5.0), Color(.3, .9, 1), true)
	mesh.quaternion = Quaternion(Vector3.FORWARD, direction)
	mesh.layers = 2 # Near-muzzle pulse is excluded from the rifle optic.
	pulses.append({"position": muzzle.origin, "velocity": direction * PLAYER_SPEED, "mesh": mesh, "travel": 0.0})
	return result.point

func _update_targets() -> void:
	for index in range(targets.size()):
		var target: Dictionary = targets[index]
		var offset: Vector3 = target.motion * sin(_time * .25 + index) - target.motion * sin(float(index))
		for part in target.parts:
			part.previous = part.transform
			part.transform.origin = target.center + part.local + offset
			part.mesh.position = part.transform.origin
			part.body.position = part.transform.origin
		target.hud_position = target.center + offset + Vector3(0, target.height * .75, 0)

func _tick_pulses(dt: float, shield: Transform3D) -> void:
	for index in range(pulses.size() - 1, -1, -1):
		var pulse: Dictionary = pulses[index]
		var end: Vector3 = pulse.position + pulse.velocity * minf(dt, (MAX_RANGE - pulse.travel) / PLAYER_SPEED)
		var result := _resolve_segment(pulse.position, end, shield, true)
		if result.kind != "range":
			last_impact = result.point
			last_shot_kind = result.kind
			if result.target >= 0:
				_target_hit(result.target, result.point)
			else:
				_burst(result.point, Color(.3, .85, 1) if result.kind == "shield" else Color(1, .6, .1), result.kind == "shield")
			pulse.mesh.queue_free()
			pulses.remove_at(index)
			continue
		pulse.travel += pulse.position.distance_to(end)
		pulse.position = end
		pulse.mesh.position = end
		pulse.mesh.layers = 2 if pulse.travel < 12.0 else 1
		if pulse.travel >= MAX_RANGE - .001:
			pulse.mesh.queue_free()
			pulses.remove_at(index)

func _target_hit(index: int, point: Vector3) -> void:
	target_hits += 1
	targets[index].hits += 1
	targets[index].flash = .28
	_burst(point, Color(1, .55, .08))

func _burst(point: Vector3, color: Color, deflect := false) -> void:
	# Bounded expanding spark fan: hit confirmation only, no health/destruction.
	for index in range(9):
		if _flashes.size() >= MAX_EFFECTS:
			_flashes.pop_front().mesh.queue_free()
		var angle := index * TAU / 8.0
		var direction := Vector3(cos(angle), sin(angle), .5).normalized()
		var mesh := _box(point, Vector3(.45, .45, 2.0) if deflect else Vector3(1.5, 1.5, 1.5), color, true)
		mesh.quaternion = Quaternion(Vector3.FORWARD, direction)
		_flashes.append({"mesh": mesh, "life": .55, "duration": .55, "velocity": direction * (13.0 if deflect else 9.0)})

func sword_sweep(base: Vector3, tip: Vector3, active: bool, dt: float) -> void:
	if not active or dt <= 0:
		_sword_valid = false
		_sword_contacts.clear()
		return
	if not _sword_valid or maxf(base.distance_to(_sword_base), tip.distance_to(_sword_tip)) > 30.0:
		_sword_valid = true
		_sword_base = base
		_sword_tip = tip
		return
	var contacts: Array[int] = []
	for index in range(targets.size()):
		var touched := false
		var impact := tip
		for part in targets[index].parts:
			# Sweep closely spaced points along the full blade, plus current blade.
			# Radius and spacing cover narrow boxes between the samples.
			var steps := maxi(1, ceili(maxf(base.distance_to(tip), _sword_base.distance_to(_sword_tip)) / .2))
			for sample in range(steps + 1):
				var along := float(sample) / steps
				var start := _sword_base.lerp(_sword_tip, along)
				var end := base.lerp(tip, along)
				var relative_start := start
				if part.has("previous"):
					relative_start += part.transform.origin - part.previous.origin
				var fraction := segment_box(relative_start, end, part.transform, part.half + Vector3.ONE * .15)
				if fraction >= 0:
					touched = true
					impact = start.lerp(end, fraction)
					break
			if touched:
				break
		if touched:
			contacts.append(index)
			if not _sword_contacts.has(index):
				_target_hit(index, impact)
	_sword_contacts = contacts
	_sword_base = base
	_sword_tip = tip

func _resolve(muzzle: Transform3D, shield_world: Transform3D) -> Dictionary:
	var start := muzzle.origin
	var end := start - muzzle.basis.z.normalized() * MAX_RANGE
	return _resolve_segment(start, end, shield_world)

func _resolve_segment(start: Vector3, end: Vector3, shield_world: Transform3D, moving := false) -> Dictionary:
	var best := 1.0
	var target_index := -1
	var kind := "range"
	var fraction := segment_box(start, end, shield_world, SHIELD_HALF)
	if fraction >= 0:
		best = fraction
		kind = "shield"
	for index in range(targets.size()):
		for part in targets[index].parts:
			var relative_start := start
			if moving and part.has("previous"):
				relative_start += part.transform.origin - part.previous.origin
			fraction = segment_box(relative_start, end, part.transform, part.half)
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
	_time = 0.0
	_sword_valid = false
	_sword_contacts.clear()
	for pulse in pulses:
		pulse.mesh.queue_free()
	pulses.clear()
	for emitter in emitters:
		emitter.timer = 4.5
	_update_targets()
	hits = 0
	blocks = 0
	target_hits = 0
	shots_fired = 0
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

func _static_box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _box(center: Vector3, size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
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
