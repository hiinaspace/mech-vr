shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 metal_color : source_color = vec4(.55,.65,.7,1.0);
uniform sampler2D grain_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D heat_texture : filter_linear;
uniform bool has_heat = false;
uniform vec3 half_size = vec3(.5);
varying vec3 local_point;
varying vec3 local_normal;
void vertex() { local_point = VERTEX; local_normal = NORMAL; }
void fragment() {
	float grain = texture(grain_texture, UV * vec2(5.0, 2.0)).r;
	ALBEDO = metal_color.rgb * (.82 + grain*.28);
	METALLIC = .32;
	ROUGHNESS = .43 + grain*.13;
	vec3 p = local_point / half_size;
	vec3 n = abs(local_normal);
	float face;
	vec2 face_uv;
	if (n.x > n.y && n.x > n.z) { face = local_normal.x < 0.0 ? 1.0 : 0.0; face_uv = p.zy; }
	else if (n.y > n.z) { face = local_normal.y < 0.0 ? 3.0 : 2.0; face_uv = p.xz; }
	else { face = local_normal.z < 0.0 ? 5.0 : 4.0; face_uv = p.xy; }
	vec2 atlas_uv = (clamp(face_uv*.5+.5,vec2(.005),vec2(.995))+vec2(mod(face,3.0),floor(face/3.0)))/vec2(3.0,2.0);
	float heat = has_heat ? texture(heat_texture,atlas_uv).r : 0.0;
	vec3 glow = mix(vec3(1.0,.045,.002),vec3(1.0,.8,.3),smoothstep(.45,1.0,heat));
	EMISSION = metal_color.rgb*.075 + glow*heat*3.0;
	ALBEDO = mix(ALBEDO,vec3(.14,.09,.06),clamp(heat*.3,0.0,.3));
}
