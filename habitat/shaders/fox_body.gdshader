shader_type spatial;

// Dark purple body with subtle iridescent sheen
uniform vec4 base_colour    : source_color = vec4(0.118, 0.067, 0.220, 1.0); // #1E1138
uniform vec4 sheen_colour   : source_color = vec4(0.278, 0.196, 0.557, 1.0); // #473290
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.35;
uniform float roughness           : hint_range(0.0, 1.0) = 0.65;
uniform float specular             : hint_range(0.0, 1.0) = 0.3;
uniform float selection_highlight  : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Reflection vector — same as Blender's "Reflection" texture coordinate
	vec3 reflected = reflect(-VIEW, NORMAL);

	// Use the Y component of the reflected vector as the iridescence factor
	// (maps -1..1 to 0..1, giving a top-lit pearlescent look)
	float irid = clamp(reflected.y * 0.5 + 0.5, 0.0, 1.0);

	// Blend base colour with sheen based on reflection angle
	vec3 col = mix(base_colour.rgb, sheen_colour.rgb, irid * sheen_strength);

	// Selection highlight — warm orange rim
	col = mix(col, vec3(1.0, 0.6, 0.1), selection_highlight);

	ALBEDO     = col;
	EMISSION   = vec3(1.0, 0.55, 0.05) * selection_highlight * 2.0;
	ROUGHNESS  = roughness;
	SPECULAR   = specular;
	METALLIC   = 0.0;
}
