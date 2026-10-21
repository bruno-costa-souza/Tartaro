shader_type canvas_item;
#include "res://shaders/common.gdshaderinc"

void fragment() {
	float glow = 1.0 - smoothstep(0.0, 0.85, length((UV - vec2(0.5, 0.14)) * vec2(1.0, 1.5)));
	float smoke = fbm(UV * vec2(3.0, 5.0) + vec2(TIME * 0.02, TIME * 0.05));
	float smoke2 = fbm(UV * vec2(6.0, 9.0) - vec2(TIME * 0.03, TIME * 0.02));
	vec3 col = mix(vec3(0.025, 0.018, 0.04), vec3(0.32, 0.1, 0.06), glow * 0.85);
	col += smoothstep(0.4, 0.9, smoke * smoke2 * 2.0) * vec3(0.12, 0.07, 0.16);
	col *= 1.0 - 0.5 * smoothstep(0.4, 1.0, length((UV - 0.5) * vec2(1.4, 1.0)));
	col *= 0.55;
	COLOR = vec4(col, 1.0);
}
