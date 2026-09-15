shader_type sky;
uniform samplerCube starfield : source_color, filter_linear_mipmap;
uniform vec3 sun_direction = vec3(-0.5,0.35,-0.8);
void sky() {
	vec3 stars = texture(starfield,EYEDIR).rgb * 5.0;
	float d = max(dot(normalize(EYEDIR),normalize(sun_direction)),0.0);
	float disc = smoothstep(cos(0.013),cos(0.010),d);
	float halo = pow(d,450.0)*0.25 + pow(d,45.0)*0.012;
	COLOR = stars + vec3(1.0,0.80,0.53)*(disc*14.0+halo);
}
