// Wireframe shader - renders glowing vector lines with a bright inner core.
// Suitable for retro wireframe vector games (FATHOM.EXE).
// Computes anti-aliased edges using UV face coordinates and fwidth().

shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 glow_color : source_color = vec3(0.2, 1.0, 0.2);
uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 10.0) = 4.0;
uniform float edge_thickness : hint_range(0.001, 0.1) = 0.015;

void fragment() {
	// Find minimum distance to any face edge in UV space
	float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	
	// Estimate change in edge_dist per screen pixel for anti-aliasing
	float pixel_width = max(fwidth(edge_dist), 0.0001);
	
	// Smoothly fade out at the wireframe boundary
	float alpha = 1.0 - smoothstep(edge_thickness - pixel_width, edge_thickness, edge_dist);
	
	// Discard face interiors completely to achieve transparency
	if (alpha <= 0.0) {
		discard;
	}
	
	// Draw a bright inner core line exactly at the center of the wireframe line (edge_dist = 0)
	float core_limit = edge_thickness * 0.35;
	float core_blend = 1.0 - smoothstep(core_limit - pixel_width, core_limit, edge_dist);
	
	vec3 final_color = mix(glow_color * glow_intensity, core_color, core_blend);
	
	ALBEDO = vec3(0.0);
	EMISSION = final_color * alpha;
}
