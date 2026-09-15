extends Node3D
## Decorative medium-field colony. Training obstacles remain separately explicit.
var environment := WorldEnvironment.new()
const SUN_DIRECTION := Vector3(-.5,.35,-.8)

func setup() -> void:
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/space_sky.gdshader")
	var images: Array[Image] = []
	for face in ["rt","lf","up","dn","bk","ft"]:
		var texture: Texture2D = load("res://assets/sky/space_%s.png" % face)
		var face_image := texture.get_image()
		# Quake skybox poles use a different orientation from Vulkan cubemaps.
		if face == "up":
			face_image.rotate_90(COUNTERCLOCKWISE)
		elif face == "dn":
			face_image.rotate_90(CLOCKWISE)
		images.append(face_image)
	var cube := Cubemap.new()
	cube.create_from_images(images)
	material.set_shader_parameter("starfield",cube)
	material.set_shader_parameter("sun_direction",SUN_DIRECTION.normalized())
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("9bbad6")
	settings.ambient_light_energy = .32
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 1.5
	settings.glow_strength = .85
	settings.glow_bloom = .04
	settings.glow_hdr_threshold = 1.0
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.basis = Basis.looking_at(-SUN_DIRECTION.normalized(),Vector3.UP)
	sun.light_color = Color("ffe3b4")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	_build_colony()

func material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = .35
	mat.roughness = .65
	if glow>0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(parent,mesh,pos,mat)

func _build_colony() -> void:
	var colony := Node3D.new()
	add_child(colony)
	colony.position = Vector3(-180,160,-1150)
	colony.rotation = Vector3(.12,.35,-.22)
	var hull := material(Color("829499"))
	var rim := material(Color("c1c5b8"))
	var dark := material(Color("263d50"))
	var window := material(Color("5bbdbb"),.65)
	var beacon := material(Color("ffd390"),3.0)
	var shell := CylinderMesh.new()
	shell.top_radius = 220
	shell.bottom_radius = 220
	shell.height = 1250
	shell.radial_segments = 64
	var cylinder := mesh_node(colony,shell,Vector3.ZERO,hull)
	cylinder.rotation.z = PI*.5
	# Structural rings and an axial hub make the cylinder legible at a glance.
	for x in [-630,-420,-210,0,210,420,630]:
		var ring := TorusMesh.new()
		ring.inner_radius = 218
		ring.outer_radius = 232
		ring.rings = 64
		ring.ring_segments = 8
		var node := mesh_node(colony,ring,Vector3(x,0,0),rim)
		node.rotation.z = PI*.5
	for x in [-680,680]:
		var hub := CylinderMesh.new()
		hub.top_radius = 70
		hub.bottom_radius = 70
		hub.height = 120
		var node := mesh_node(colony,hub,Vector3(x,0,0),dark)
		node.rotation.z = PI*.5
		box(colony,Vector3(x,0,-75),Vector3(24,12,8),beacon)
	# Three long mirror wings and thin ribs, still intentionally primitive meshes.
	for i in 3:
		var angle := TAU*float(i)/3.0+.2
		var radial := Vector3(0,cos(angle),sin(angle))
		var wing := Node3D.new()
		colony.add_child(wing)
		wing.position = radial*390
		wing.rotation.x = angle
		box(wing,Vector3.ZERO,Vector3(1100,9,145),dark)
		for x in [-530,-265,0,265,530]:
			box(wing,Vector3(x,0,0),Vector3(7,14,151),rim)
		for x in [-520,520]:
			var strut := box(colony,radial*305+Vector3(x,0,0),Vector3(10,175,10),rim)
			strut.rotation.x = angle
	for i in 12:
		var angle := TAU*float(i)/12
		var radial := Vector3(0,cos(angle),sin(angle))
		for x in [-525,-315,-105,105,315,525]:
			var strip := box(colony,radial*222+Vector3(x,0,0),Vector3(155,3,17),window)
			strip.rotation.x = angle
