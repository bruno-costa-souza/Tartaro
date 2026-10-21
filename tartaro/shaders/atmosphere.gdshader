shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec4 fog_color : source_color = vec4(0.3, 0.2, 0.45, 1.0);
uniform float fog_amount = 0.14;
uniform float vignette = 0.8;

void fragment() {
	float v = smoothstep(0.32, 0.92, length((UV - 0.5) * vec2(1.0, 0.72)));
	float f = fbm(UV * vec2(2.5, 4.0) + vec2(TIME * 0.015, -TIME * 0.03));
	vec3 col = mix(fog_color.rgb, vec3(0.0), v);
	float a = v * vignette + smoothstep(0.35, 0.8, f) * fog_amount * (1.0 - v);
	COLOR = vec4(col, a);
}
