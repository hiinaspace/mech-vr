extends Node3D
## Mirror the shared exterior rig and equipment; never solve a second pose.
const MINI_SCALE := .014
var rig := Node3D.new()
var content := Node3D.new()
var sources: Array[Node3D] = []
var copies: Array[Node3D] = []
var label := Label3D.new()
var suit: Node3D
var robot: Node3D

func setup(body: Node3D, exterior: Node3D, equipment: Array[Node3D]) -> void:
	suit = body
	robot = exterior
	position = Vector3(.48,-.50,-1.25)
	add_child(rig)
	rig.add_child(content)
	content.position = Vector3(0,8,0)
	_copy_tree(exterior,content)
	for item in equipment: _copy_tree(item,content)
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

func _copy_tree(source: Node3D, parent: Node3D) -> void:
	var copy: Node3D
	if source is MeshInstance3D:
		copy = MeshInstance3D.new()
		copy.mesh = source.mesh
		copy.material_override = source.material_override
		_tint(copy)
	else: copy = Node3D.new()
	parent.add_child(copy)
	sources.append(source)
	copies.append(copy)
	for child in source.get_children():
		if child is Node3D: _copy_tree(child,copy)

func _tint(node: MeshInstance3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(.18,.85,1,.65)
	if node.material_override is StandardMaterial3D:
		var original: Color = node.material_override.albedo_color
		if original.r > original.b: mat.albedo_color = Color(1,.75,.3,.8)
	node.material_override = mat

func sync() -> void:
	rig.basis = (Basis(Vector3.UP,deg_to_rad(150))*suit.basis).scaled(Vector3.ONE*MINI_SCALE)
	label.text = "POSE / " + robot.flight.mode
	var bounds := AABB()
	var first := true
	for source in sources:
		if source is MeshInstance3D and source.visible:
			var local: Transform3D = suit.global_transform.affine_inverse()*source.global_transform
			var mesh_bounds: AABB = local*source.mesh.get_aabb()
			bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
			first = false
	content.position = -bounds.get_center()
	for i in sources.size():
		copies[i].transform = sources[i].transform
		copies[i].visible = sources[i].visible
