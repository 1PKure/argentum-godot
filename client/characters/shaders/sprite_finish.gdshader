shader_type canvas_item;
render_mode unshaded;

uniform vec4 atlas_bounds = vec4(0.0, 0.0, 1.0, 1.0);
uniform float finish_strength : hint_range(0.0, 1.0) = 0.18;

varying vec4 sprite_tint;
void vertex() { sprite_tint = COLOR; }

bool same_ink(vec4 a, vec4 b) {
	return distance(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a)) < 0.055;
}
void fragment() {
	vec4 tint = sprite_tint;
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec2 center = (floor(UV / pixel) + 0.5) * pixel;
	vec2 quadrant = fract(UV / pixel);
	vec2 uv_e = center;
	vec4 e = texture(TEXTURE, clamp(uv_e, atlas_bounds.xy + pixel * 0.5, atlas_bounds.zw - pixel * 0.5));
	if (any(lessThan(uv_e,atlas_bounds.xy)) || any(greaterThan(uv_e,atlas_bounds.zw))) e = vec4(0.0);
	vec2 uv_b = center + vec2(0.0, -pixel.y);
	vec4 b = texture(TEXTURE, clamp(uv_b, atlas_bounds.xy + pixel * 0.5, atlas_bounds.zw - pixel * 0.5));
	if (any(lessThan(uv_b,atlas_bounds.xy)) || any(greaterThan(uv_b,atlas_bounds.zw))) b = vec4(0.0);
	vec2 uv_d = center + vec2(-pixel.x, 0.0);
	vec4 d = texture(TEXTURE, clamp(uv_d, atlas_bounds.xy + pixel * 0.5, atlas_bounds.zw - pixel * 0.5));
	if (any(lessThan(uv_d,atlas_bounds.xy)) || any(greaterThan(uv_d,atlas_bounds.zw))) d = vec4(0.0);
	vec2 uv_f = center + vec2(pixel.x, 0.0);
	vec4 f = texture(TEXTURE, clamp(uv_f, atlas_bounds.xy + pixel * 0.5, atlas_bounds.zw - pixel * 0.5));
	if (any(lessThan(uv_f,atlas_bounds.xy)) || any(greaterThan(uv_f,atlas_bounds.zw))) f = vec4(0.0);
	vec2 uv_h = center + vec2(0.0, pixel.y);
	vec4 h = texture(TEXTURE, clamp(uv_h, atlas_bounds.xy + pixel * 0.5, atlas_bounds.zw - pixel * 0.5));
	if (any(lessThan(uv_h,atlas_bounds.xy)) || any(greaterThan(uv_h,atlas_bounds.zw))) h = vec4(0.0);
	// Edge-directed 2x reconstruction rounds single-pixel staircases without
	// bilinear blur or mixing the neighboring frames of the source atlas.
	vec4 ink = e;
	if (!same_ink(b,h) && !same_ink(d,f)) {
		if (quadrant.x < 0.5 && quadrant.y < 0.5 && same_ink(d,b)) ink = d;
		if (quadrant.x >= 0.5 && quadrant.y < 0.5 && same_ink(b,f)) ink = f;
		if (quadrant.x < 0.5 && quadrant.y >= 0.5 && same_ink(d,h)) ink = d;
		if (quadrant.x >= 0.5 && quadrant.y >= 0.5 && same_ink(h,f)) ink = f;
	}
	float light = dot(ink.rgb, vec3(0.2126,0.7152,0.0722));
	vec3 rich = mix(vec3(light), ink.rgb, 1.0 + finish_strength * 0.5);
	// Cooler folds and warm ivory highlights retain each outfit's palette.
	rich *= mix(vec3(0.89,0.94,1.04), vec3(1.10,1.06,0.98), smoothstep(0.12,0.8,light));
	rich = mix(ink.rgb,rich,0.55 + finish_strength);
	float relief = clamp(dot(b.rgb - h.rgb, vec3(0.333)), -0.25,0.25);
	rich += relief * finish_strength * 0.5;
	COLOR = vec4(clamp(rich,vec3(0.0),vec3(1.0)),ink.a) * tint;
}
