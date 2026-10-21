shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec4 hot : source_color;
uniform vec4 cool : source_color;
uniform float intensity = 2.2;
uniform float seed = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float n = fbm(UV * 3.5 + vec2(TIME * 0.12, TIME * 0.08) + seed);
	float n2 = fbm(UV * 6.0 - vec2(TIME * 0.18, -TIME * 0.1) + seed * 2.0);
	float edge = r + (fbm(UV * 5.0 + seed) - 0.5) * 0.35;
	if (edge > 1.0) {
		discard;
	}
	float heat = smoothstep(0.25, 0.75, n * n2 * 2.2);
	vec3 col = mix(cool.rgb, hot.rgb * intensity, heat);
	float rim = smoothstep(0.7, 1.0, edge);
	col = mix(col, cool.rgb * 0.35, rim);
	COLOR = vec4(col, 1.0 - smoothstep(0.9, 1.0, edge));
}
