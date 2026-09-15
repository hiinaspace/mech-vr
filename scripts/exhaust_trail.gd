extends Node3D
## Bounded, world-space exhaust ribbons. Parent this to the scene world, never to
## the cockpit. Reset clears history after recenter/teleport. No physics effects.
const CAPACITY := 96
const LIFETIME := 2.8
const INTERVAL := .075
var pieces: Array[MeshInstance3D] = []
var ages: Array[float] = []
var _previous: Array[Vector3] = []
var _cursor := 0
var _elapsed := 0.0

func setup() -> void:
	if not pieces.is_empty(): return
	for _i in CAPACITY:
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		piece.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(.25,.7,1,.2)
		material.emission_enabled = true
		material.emission = Color(.18,.5,1)
		material.emission_energy_multiplier = .8
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.visible = false
		add_child(piece)
		pieces.append(piece)
		ages.append(LIFETIME)

func reset() -> void:
	_previous.clear()
	_elapsed = 0.0
	_cursor = 0
	for i in pieces.size():
		pieces[i].visible = false
		ages[i] = LIFETIME

func active_count() -> int:
	var count := 0
	for piece in pieces:
		if piece.visible: count += 1
	return count

func update_trail(dt: float, world_nozzles: Array[Vector3], world_velocity: Vector3, acceleration_magnitude: float, paused: bool) -> void:
	if pieces.is_empty(): setup()
	if not is_finite(dt) or not world_velocity.is_finite() or not is_finite(acceleration_magnitude): return
	for point in world_nozzles:
		if not point.is_finite(): return
	# Existing wake dissipates during coast/pause, with no newly emitted segments.
	for i in pieces.size():
		ages[i] += maxf(dt,0)
		pieces[i].visible = ages[i]<LIFETIME
		if pieces[i].visible:
			var fade := 1.0-ages[i]/LIFETIME
			pieces[i].material_override.albedo_color.a = .22*fade*fade
	if world_nozzles.size()!=_previous.size():
		_previous.assign(world_nozzles)
		return
	for i in world_nozzles.size():
		if world_nozzles[i].distance_to(_previous[i])>20.0:
			reset()
			_previous.assign(world_nozzles)
			return
	if paused or acceleration_magnitude<=.2 or world_velocity.length()<.4:
		_previous.assign(world_nozzles)
		_elapsed = 0.0
		return
	_elapsed += maxf(dt,0)
	if _elapsed<INTERVAL: return
	_elapsed = fmod(_elapsed,INTERVAL)
	for i in mini(world_nozzles.size(),2):
		var a := _previous[i]
		var b := world_nozzles[i]
		var delta := b-a
		if delta.length()<.02: continue
		var piece := pieces[_cursor]
		var direction := delta.normalized()
		piece.global_position = (a+b)*.5
		piece.global_basis = Basis.looking_at(direction,Vector3.UP if absf(direction.y)<.99 else Vector3.RIGHT)
		var width := .18+minf(acceleration_magnitude/50.0,.45)
		piece.scale = Vector3(width,width,delta.length()+.06)
		piece.visible = true
		piece.material_override.albedo_color.a = .22
		ages[_cursor] = 0
		_cursor = (_cursor+1)%CAPACITY
	_previous.assign(world_nozzles)
