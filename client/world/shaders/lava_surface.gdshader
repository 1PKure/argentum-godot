shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 p = floor(UV * vec2(420.0,330.0)) / 8.0;
	float flow = sin(p.x * 0.8 + sin(p.y * 1.2 + TIME * 0.12)) + sin(p.y * 0.7 - TIME * 0.15);
	float cracks = smoothstep(0.85,1.8,flow);
	COLOR = vec4(mix(vec3(0.20,0.065,0.055),vec3(0.78,0.26,0.06),cracks),1.0);
}
