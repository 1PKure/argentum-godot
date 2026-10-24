shader_type canvas_item;
render_mode unshaded;

// Fixed world-pixel scale: extending the camera padding never enlarges lava.
uniform vec2 surface_size = vec2(4032.0, 3648.0);

vec2 cell_offset(vec2 p) {
	vec2 n = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return 0.22 + 0.56 * fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 p = UV * surface_size;
	vec2 q = p / 70.0;
	q += vec2(sin(p.y * 0.042 + sin(p.x * 0.018)), sin(p.x * 0.033 + sin(p.y * 0.020))) * 0.10;
	vec2 cell = floor(q);
	vec2 local = fract(q);
	float first = 10.0;
	float second = 10.0;
	vec2 nearest = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbour = vec2(float(x), float(y));
			vec2 delta = neighbour + cell_offset(cell + neighbour) - local;
			float distance_to_cell = length(delta);
			if (distance_to_cell < first) {
				second = first;
				first = distance_to_cell;
				nearest = cell + neighbour;
			} else {
				second = min(second, distance_to_cell);
			}
		}
	}
	float edge = (second - first) * 70.0;
	float plate = cell_offset(nearest).x;
	float grain = fract(sin(dot(floor(p / 2.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 rock = mix(vec3(0.075, 0.073, 0.086), vec3(0.13, 0.12, 0.135), plate);
	rock += (grain - 0.5) * 0.014;
	rock += smoothstep(5.0, 11.0, edge) * 0.012;
	// Narrow molten seams, a faint warm edge and only a slow brightness change.
	float glow = 1.0 - smoothstep(0.7, 5.0, edge);
	float molten = 1.0 - smoothstep(0.25, 1.5, edge);
	float pulse = 0.88 + 0.04 * sin(TIME * 0.55 + plate * 9.0);
	float heat = 0.4 + 0.6 * smoothstep(-0.6, 0.75, sin(p.x * 0.016 + p.y * 0.010) * sin(p.y * 0.022 - p.x * 0.008));
	vec3 colour = rock + vec3(0.12, 0.025, 0.004) * glow * heat;
	colour = mix(colour, vec3(0.70, 0.27, 0.055) * pulse, molten * heat * 0.8);
	COLOR = vec4(colour, 1.0);
}
