shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 size = vec2(100.0, 40.0);
uniform float radius = 14.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.12;
uniform float blur = 3.0;
uniform float refraction = 0.018;
uniform float brightness = 1.0;
uniform float edge_light = 1.0;
uniform float opacity = 1.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 half_size = size * 0.5;
	float r = min(radius, min(half_size.x, half_size.y));
	vec2 p = (UV - 0.5) * size;
	float d = sd_round_box(p, half_size, r);
	float mask = clamp(0.5 - d, 0.0, 1.0);

	vec2 e = vec2(0.75, 0.0);
	vec2 n = vec2(
		sd_round_box(p + e.xy, half_size, r) - sd_round_box(p - e.xy, half_size, r),
		sd_round_box(p + e.yx, half_size, r) - sd_round_box(p - e.yx, half_size, r));
	n = normalize(n + vec2(1e-5));

	float edge = 1.0 - smoothstep(0.0, 12.0, -d);
	float bend = edge * edge * refraction;
	vec2 uv = SCREEN_UV - n * bend;
	vec3 bg;
	bg.r = textureLod(screen_tex, uv - n * bend * 0.5, blur).r;
	bg.g = textureLod(screen_tex, uv, blur).g;
	bg.b = textureLod(screen_tex, uv + n * bend * 0.5, blur).b;

	vec3 col = mix(bg, tint.rgb, tint_amount);
	col = col * brightness + vec3(0.025);
	col += vec3(0.07) * smoothstep(0.6, 0.0, UV.y);

	vec2 key = normalize(vec2(-0.55, -0.85));
	float spec = pow(max(dot(n, key), 0.0), 3.0) * edge;
	float spec_back = pow(max(dot(n, -key), 0.0), 4.0) * edge * 0.35;
	col += vec3(spec * 0.6 + spec_back) * edge_light;
	float rim = smoothstep(1.4, 0.0, abs(d + 0.7));
	col += vec3(rim * 0.3 * edge_light);

	COLOR = vec4(col, mask * opacity);
}
