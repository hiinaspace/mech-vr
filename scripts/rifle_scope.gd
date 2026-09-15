extends Node3D
## One modest mono optic displayed on a stereo-positioned cockpit screen.
## External world uses layer 1; cockpit and own equipment use layer 2.
const WORLD_LAYER := 1
const OWN_LAYER := 2
const ENTER_DISTANCE := .42
const EXIT_DISTANCE := .50
const MAGNIFICATION := 4.0
var viewport := SubViewport.new()
var camera := Camera3D.new()
var screen := MeshInstance3D.new()
var active := false

func setup(parent: Node3D, shared_world: World3D) -> void:
	name = "RifleScope"
	parent.add_child(self)
	viewport.name = "OpticViewport"
	viewport.size = Vector2i(512,512)
	viewport.world_3d = shared_world
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	viewport.add_child(camera)
	camera.current = true
	camera.cull_mask = WORLD_LAYER
	camera.near = .15
	camera.far = 4000.0
	# A 75-degree reference camera magnifies linear angular size fourfold.
	camera.fov = rad_to_deg(2.0*atan(tan(deg_to_rad(75.0)*.5)/MAGNIFICATION))
	var quad := QuadMesh.new()
	quad.size = Vector2(.22,.22)
	screen.mesh = quad
	screen.layers = OWN_LAYER
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D optic : source_color, filter_linear;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	if (r > 0.5) { discard; }
	vec3 col = texture(optic, UV).rgb;
	if (r > 0.455) { col = vec3(0.08,0.22,0.25); }
	if (r > 0.448 && r < 0.458) { col = vec3(0.3,0.9,1.0); }
	if ((abs(p.x)<0.002 || abs(p.y)<0.002) && r<0.07 && r>0.015) { col = vec3(0.45,1.0,0.8); }
	ALBEDO = col;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("optic", viewport.get_texture())
	screen.material_override = mat
	add_child(screen)
	visible = false

func update_scope(head_local: Transform3D, handle_local: Transform3D, held: bool,
		rifle_equipped: bool, muzzle_world: Transform3D, live := true) -> void:
	var distance := head_local.origin.distance_to(handle_local.origin)
	var in_front := (head_local.affine_inverse()*handle_local.origin).z < -.06
	active = live and held and rifle_equipped and in_front and distance > .12 \
		and distance < (EXIT_DISTANCE if active else ENTER_DISTANCE)
	visible = active
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active: return
	# Keep the screen above the held handle while facing the pilot, independent
	# of rifle roll. The image itself follows the real external barrel.
	transform = Transform3D(head_local.basis.orthonormalized(), handle_local.origin + head_local.basis.y*.18)
	camera.global_transform = muzzle_world.orthonormalized()

static func exclude_tree(node: Node) -> void:
	if node is VisualInstance3D: node.layers = OWN_LAYER
	for child in node.get_children(): exclude_tree(child)
