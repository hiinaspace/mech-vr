extends Node3D
## Read-only miniature of rendered geometry, including held/reset-blended poses.
## Its pedestal stays in the cockpit; range-relative yaw/pitch rotates the robot.
const MINI_SCALE := 0.014
var rig := Node3D.new()
var content := Node3D.new()
var sources: Array[Node3D] = []
var copies: Array[Node3D] = []
var suit: Node3D

func setup(body: Node3D, geometry: Array[Node3D]) -> void:
	suit = body
	sources = geometry
	position = Vector3(.48,-.50,-1.25)
	add_child(rig)
	rig.add_child(content)
	content.position = Vector3(0,8,0)
	for source in sources:
		var copy := source.duplicate() as Node3D
		content.add_child(copy)
		copies.append(copy)
		_tint(copy)
	var base := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = .13
	mesh.bottom_radius = .13
	mesh.height = .008
	base.mesh = mesh
	base.position.y = -.14
	add_child(base)
	_tint(base)
	var label := Label3D.new()
	label.text = "POSE / ACTUAL"
	label.font_size = 24
	label.pixel_size = .00065
	label.position = Vector3(0,-.165,.10)
	label.modulate = Color("76e8f2")
	add_child(label)
	sync()

func _tint(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(.18,.85,1,.65)
		# Preserve left/right equipment distinction without changing any geometry.
		if node.material_override is StandardMaterial3D:
			var original: Color = node.material_override.albedo_color
			if original.r > original.b:
				mat.albedo_color = Color(1,.75,.3,.8)
		node.material_override = mat
	for child in node.get_children():
		_tint(child)

func sync() -> void:
	rig.basis = (Basis(Vector3.UP,deg_to_rad(150)) * suit.basis).scaled(Vector3.ONE*MINI_SCALE)
	for index in sources.size():
		copies[index].transform = sources[index].transform
