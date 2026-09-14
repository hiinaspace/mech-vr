extends Node3D
## Read-only actual-geometry view or authored flight-pose preview. Camera, external
## arms and motor are untouched. The preview pivots around the suit centre; IK
## follows actual equipment targets in cockpit space, never stretched limbs.
const MINI_SCALE := 0.014
const FlightPose = preload("res://scripts/flight_pose.gd")
const CENTRE := Vector3(0,-8,0)
var rig := Node3D.new()
var content := Node3D.new()
var preview := Node3D.new()
var torso := Node3D.new()
var sources: Array[Node3D] = []
var copies: Array[Node3D] = []
var equipment: Array[Node3D] = []
var arm_links: Array[MeshInstance3D] = []
var markers: Array[MeshInstance3D] = []
var legs: Array[MeshInstance3D] = []
var flames: Array[MeshInstance3D] = []
var label := Label3D.new()
var suit: Node3D
var flight_enabled := true
var flight := FlightPose.new()

func setup(body: Node3D, geometry: Array[Node3D]) -> void:
	suit = body
	sources = geometry
	position = Vector3(.48,-.50,-1.25)
	add_child(rig)
	rig.add_child(content)
	content.position = -CENTRE
	for source in sources:
		var copy := source.duplicate() as Node3D
		content.add_child(copy)
		copies.append(copy)
		_tint(copy)
	rig.add_child(preview)
	preview.add_child(torso)
	_box(torso,Vector3(4.8,4.2,2.5),Vector3(0,3,0))
	_box(torso,Vector3(3.4,1.8,2.1),Vector3(0,-.5,0))
	_box(torso,Vector3(2,2,1.8),Vector3(0,6.1,0))
	_box(torso,Vector3(1.7,.35,.12),Vector3(0,6.2,-.95),Color(1,.75,.3,.95))
	_box(torso,Vector3(3.8,2.4,1.5),Vector3(0,2,1.8))
	for side in [-1,1]:
		for _part in 3:
			legs.append(_box(preview,Vector3.ONE,Vector3.ZERO))
		for _part in 2:
			arm_links.append(_box(preview,Vector3.ONE,Vector3.ZERO))
		markers.append(_box(preview,Vector3.ONE*.65,Vector3.ZERO,Color(1,.3,.2,.9)))
		# Source order is cockpit beam, torso, shield, rifle, arm segments.
		var copy := sources[2 if side == -1 else 3].duplicate() as Node3D
		preview.add_child(copy)
		_tint(copy)
		equipment.append(copy)
	for _i in 3:
		flames.append(_box(preview,Vector3.ONE,Vector3.ZERO,Color(.3,1,1,.95)))
	var base := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = .13
	mesh.bottom_radius = .13
	mesh.height = .008
	base.mesh = mesh
	base.position.y = -.14
	add_child(base)
	_tint(base)
	label.font_size = 24
	label.pixel_size = .00065
	label.position = Vector3(0,-.165,.10)
	label.modulate = Color("76e8f2")
	add_child(label)
	sync()

func _box(parent: Node3D, size: Vector3, at: Vector3, color := Color(.18,.85,1,.7)) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	node.material_override = mat
	parent.add_child(node)
	node.position = at
	return node

func _tint(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(.18,.85,1,.65)
		if node.material_override is StandardMaterial3D:
			var original: Color = node.material_override.albedo_color
			if original.r > original.b:
				mat.albedo_color = Color(1,.75,.3,.8)
		node.material_override = mat
	for child in node.get_children():
		_tint(child)

func update_flight(dt: float, local_velocity: Vector3, local_acceleration: Vector3, paused := false) -> void:
	flight.step(dt,local_velocity,local_acceleration,paused)

func _link(node: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	var delta := b-a
	node.position = (a+b)*.5
	node.basis = Basis.looking_at(delta.normalized(),Vector3.UP if absf(delta.normalized().y)<.99 else Vector3.RIGHT)
	node.scale = Vector3(width,width,maxf(delta.length(),.001))

func sync() -> void:
	rig.basis = (Basis(Vector3.UP,deg_to_rad(150)) * suit.basis).scaled(Vector3.ONE*MINI_SCALE)
	content.visible = not flight_enabled
	preview.visible = flight_enabled
	label.text = "POSE PREVIEW" if flight_enabled else "POSE / ACTUAL"
	for index in sources.size():
		copies[index].transform = sources[index].transform
	if not flight_enabled:
		return
	var orientation: Basis = flight.body_basis
	torso.basis = orientation
	for i in 2:
		var side := -1.0 if i==0 else 1.0
		var hip := orientation*Vector3(side*1.2,-1,0)
		var knee := orientation*Vector3(side*1.35,-4.1,.45+flight.flight_amount*.7)
		var ankle := orientation*Vector3(side*1.4,-7.1,.25+flight.flight_amount*1.1)
		_link(legs[i*3],hip,knee,1.25)
		_link(legs[i*3+1],knee,ankle,.95)
		_link(legs[i*3+2],ankle,ankle+orientation*Vector3(0,-.1,-1.5),1.0)
		equipment[i].transform = sources[2+i].transform
		equipment[i].position -= CENTRE
		var shoulder := orientation*Vector3(side*3,4,0)
		var target := equipment[i].position
		var points: Array[Vector3] = FlightPose.arm_points(shoulder,target,orientation*Vector3(side,-.6,.3))
		_link(arm_links[i*2],points[0],points[1],.7)
		_link(arm_links[i*2+1],points[1],points[2],.6)
		markers[i].position = target
		markers[i].visible = points[2].distance_to(target)>.05
	var main_strength: float = flight.main_acceleration
	for i in 2:
		var nozzle := orientation*Vector3(-1.1 if i==0 else 1.1,.8,2)
		flames[i].visible = main_strength>.2
		_link(flames[i],nozzle,nozzle-orientation.y*(.2+minf(main_strength/8.0,3.0)),.4)
	var residual: Vector3 = flight.residual_acceleration
	flames[2].visible = residual.length()>.2
	var origin := orientation*Vector3(0,-.5,1.5)
	var exhaust := -residual.normalized() if residual.length()>.001 else Vector3.DOWN
	_link(flames[2],origin,origin+exhaust*(.2+minf(residual.length()/8.0,3.0)),.3)
