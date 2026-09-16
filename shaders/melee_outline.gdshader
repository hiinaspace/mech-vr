shader_type spatial;
render_mode unshaded, cull_front;
void vertex() { VERTEX += NORMAL * .025; }
void fragment() { ALBEDO = vec3(.008,.016,.025); }
