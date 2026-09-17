shader_type texture_blit;
render_mode blend_add;
uniform sampler2D brush : hint_blit_source0;
void blit() { COLOR0 = vec4(texture(brush, UV).rgb * MODULATE.rgb, 1.0); }
