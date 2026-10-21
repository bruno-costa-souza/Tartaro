shader_type canvas_item;
#include "res://shaders/common.gdshaderinc"

uniform vec4 color_a : source_color;
uniform vec4 color_b : source_color;
uniform vec4 grout : source_color;
uniform vec4 inlay : source_color = vec4(0.6, 0.45, 0.25, 1.0);
uniform vec2 room_size = vec2(360.0, 960.0);
uniform float tile = 34.0;
uniform float seed = 0.0;
uniform float band_inset = 26.0;
uniform float band_width = 15.0;

const int KEY[25] = {
	1, 1, 1, 1, 1,
	1, 0, 0, 0, 0,
	1, 0, 1, 1, 0,
	1, 0, 0, 1, 0,
	1, 1, 1, 1, 0
};

float meander(vec2 cell_uv) {
	ivec2 c = ivec2(clamp(floor(cell_uv * 5.0), vec2(0.0), vec2(4.0)));
	return float(KEY[c.y * 5 + c.x]);
}

vec3 flagstones(vec2 px) {
	float row = floor(px.y / tile);
	vec2 q = vec2(px.x / (tile * 1.15) + mod(row, 2.0) * 0.37, px.y / tile);
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float h = hash(cell + seed);
	vec3 col = mix(color_a.rgb, color_b.rgb, h);
	col *= 0.82 + 0.36 * fbm(px * 0.09 + h * 17.0);
	col *= 0.9 + 0.2 * fbm(px * 0.018 + seed);
	float ex = min(f.x, 1.0 - f.x) * 1.15;
	float ey = min(f.y, 1.0 - f.y);
	float g = smoothstep(0.0, 0.07, min(ex, ey));
	col += 0.07 * (1.0 - smoothstep(0.0, 0.12, f.y)) * g;
	col *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.12, 1.0 - f.y));
	col = mix(grout.rgb, col, g);
	float crack_line = abs(fbm(px * 0.045 + seed * 3.0) - 0.5);
	float crack = (1.0 - smoothstep(0.0, 0.018, crack_line)) * step(0.62, hash(cell + seed + 7.0));
	return col * (1.0 - crack * 0.55);
}

void fragment() {
	vec2 px = UV * room_size;
	vec3 col = flagstones(px);
	float wear = fbm(px * 0.06 + seed * 5.0);

	vec2 d4 = vec2(min(px.x, room_size.x - px.x), min(px.y, room_size.y - px.y));
	bool horiz = d4.y < d4.x;
	float d = min(d4.x, d4.y);
	float across = (d - band_inset) / band_width;
	if (across > -0.12 && across < 1.12) {
		float along = horiz ? px.x : px.y;
		vec3 band_bg = grout.rgb * 1.6;
		vec3 c = band_bg;
		if (across >= 0.0 && across <= 1.0) {
			float m = meander(vec2(fract(along / band_width), 1.0 - across));
			c = mix(band_bg, inlay.rgb * (0.85 + 0.3 * wear), m);
		} else {
			c = inlay.rgb * 0.8;
		}
		col = mix(col, c, 0.92);
	}

	vec2 cv = px - room_size * 0.5;
	float r = length(cv);
	float a = atan(cv.y, cv.x);
	if (r < 64.0) {
		float ring = smoothstep(1.5, 0.0, abs(r - 62.0)) + smoothstep(1.2, 0.0, abs(r - 55.0)) + smoothstep(1.2, 0.0, abs(r - 16.0));
		float petals = smoothstep(0.02, -0.02, r / 50.0 - (0.35 + 0.55 * abs(cos(a * 4.0))));
		petals *= step(18.0, r);
		float rays = step(0.82, abs(cos(a * 16.0))) * step(56.0, r) * step(r, 61.0);
		vec3 tile_col = mix(col, grout.rgb * 1.3, 0.55);
		tile_col = mix(tile_col, inlay.rgb * (0.8 + 0.4 * wear), clamp(petals * 0.85 + rays + ring, 0.0, 1.0));
		col = mix(col, tile_col, smoothstep(64.0, 60.0, r));
	}

	float ao = smoothstep(8.0, 70.0, d);
	col *= 0.42 + 0.58 * ao;
	COLOR = vec4(col, 1.0);
}
