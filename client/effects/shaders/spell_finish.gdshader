shader_type canvas_item;
render_mode unshaded;
// One texture read, no neighbors, screen copies, loops or per-frame CPU geometry.
// Alpha and source frame UV stay exact, including transparent atlas borders.
uniform float warmth : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 source = COLOR.rgb;
	float lightness = dot(source, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = mix(vec3(lightness), source, 1.12);
	vivid = (vivid - vec3(0.5)) * 1.06 + vec3(0.5);
	vec3 gold = vec3(1.0, 0.77, 0.30) * (0.35 + lightness * 0.9);
	float shimmer = 1.04;
	COLOR.rgb = clamp(mix(vivid, gold, warmth) * shimmer, vec3(0.0), vec3(1.0));
}
