extends RefCounted
## Hand grip is the origin; bore and sight remain aligned with hand-local -Z.
const MUZZLE := Vector3(0,.78,-5.0)
var visual_root: Node3D

func setup(parent: Node3D) -> Node3D:
	visual_root = Node3D.new()
	visual_root.name = "MobileSuitRifle"
	parent.add_child(visual_root)
	_box("Grip", Vector3(.55,1.20,.65), Vector3(0,.08,.10), Color("414957"))
	_box("Receiver", Vector3(.95,.85,2.8), Vector3(0,.80,-.65), Color("cad4de"))
	_box("Stock", Vector3(.65,.65,1.6), Vector3(0,.70,1.25), Color("536174"))
	_box("PowerPack", Vector3(.74,.95,.95), Vector3(0,.13,-1.30), Color("62748a"))
	_box("BarrelShroud", Vector3(.68,.60,2.15), Vector3(0,.78,-2.90), Color("647d96"))
	_box("MuzzleBrake", Vector3(.82,.67,.75), Vector3(0,.78,-4.62), Color("d5dce1"))
	_box("Bore", Vector3(.36,.32,.02), MUZZLE, Color("111e2e"))
	_box("TopSight", Vector3(.28,.32,1.00), Vector3(0,1.38,-.70), Color("233748"))
	_box("ChargeStrip", Vector3(.97,.10,1.65), Vector3(0,1.02,-.65), Color("71eaff"), 2.5)
	return visual_root

func muzzle_transform() -> Transform3D:
	return visual_root.global_transform * Transform3D(Basis.IDENTITY,MUZZLE)

func _box(label: String, size: Vector3, at: Vector3, color: Color, glow := 0.0) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .5
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	node.material_override = mat
	visual_root.add_child(node)
