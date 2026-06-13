shader_type spatial;
render_mode unshaded;

// Tail gradient: orange tip → pink mid → dark purple base
// Shifts with camera angle like Blender's Reflection coordinates

// Gradient stops (tip to base)
uniform vec4 colour_tip    : source_color = vec4(0.980, 0.502, 0.118, 1.0); // #FA8030 orange
uniform vec4 colour_mid    : source_color = vec4(0.867, 0.333, 0.600, 1.0); // #DD5599 pink
uniform vec4 colour_base   : source_color = vec4(0.149, 0.071, 0.278, 1.0); // #261247 dark purple

// How much the reflection angle shifts the gradient (0 = UV only, 1 = full reflection)
uniform float reflection_blend : hint_range(0.0, 1.0) = 0.45;

// Glow
uniform float emission_strength : hint_range(0.0, 8.0) = 2.5;

// UV axis driving the gradient: 0 = UV.x, 1 = UV.y — try both and pick whichever
// runs tip-to-base correctly on your mesh
uniform int uv_axis : hint_range(0, 1) = 1;

void fragment() {
	// Base gradient position from UV
	float uv_t = (uv_axis == 0) ? UV.x : UV.y;

	// Reflection-based shift (same math as Blender Reflection coord → ColorRamp)
	vec3 reflected = reflect(-VIEW, NORMAL);
	float refl_t = clamp(reflected.y * 0.5 + 0.5, 0.0, 1.0);

	// Blend UV and reflection to get the pearlescent camera-reactive gradient
	float t = clamp(mix(uv_t, refl_t, reflection_blend), 0.0, 1.0);

	// Two-stop gradient: tip(0) → mid(0.5) → base(1)
	vec3 col;
	if (t < 0.5) {
		col = mix(colour_tip.rgb, colour_mid.rgb, t * 2.0);
	} else {
		col = mix(colour_mid.rgb, colour_base.rgb, (t - 0.5) * 2.0);
	}

	ALBEDO   = col;
	EMISSION = col * emission_strength;
}
