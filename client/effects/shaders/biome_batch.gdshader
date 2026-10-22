shader_type canvas_item;
render_mode unshaded;
uniform vec2 bounds_origin;
uniform vec2 bounds_size;
uniform vec2 drift;
uniform float elapsed = 0.0;
uniform bool leaf = false;
void vertex() {
	float index = INSTANCE_CUSTOM.w;
	vec2 wobble = vec2(sin(elapsed*0.55+index)*6.0,sin(elapsed*0.30+index)*2.0);
	vec2 at = bounds_origin+mod(INSTANCE_CUSTOM.xy*bounds_size+elapsed*drift*INSTANCE_CUSTOM.z+wobble,bounds_size);
	float angle = sin(elapsed*1.3+index)*0.7;
	mat2 turn = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
	VERTEX = at+turn*VERTEX;
}
void fragment() {
	vec2 p = abs(UV*2.0-1.0);
	float edge = leaf ? p.x+p.y : length(p);
	COLOR.a *= 1.0-smoothstep(0.55,1.0,edge);
}
