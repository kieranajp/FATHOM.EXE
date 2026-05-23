// Wireframe shader stub — foundations F1.
//
// Drawn as unlit emission so bloom (set up on WorldEnvironment) latches on.
// Real edge-wireframe pass (geometry-shader-style triangle barycentrics, faction
// glow colour uniform) lands with the aesthetics ticket. For now this produces
// a flat unlit colour so the smoke scene has something visible.
//
// Per-instance glow colour will be a shader uniform (`glow_color`) once the
// aesthetics ticket lands; foundations exposes it but defaults to player green.

shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 glow_color : source_color = vec3(0.2, 1.0, 0.4);

void fragment() {
	ALBEDO = vec3(0.0);
	EMISSION = glow_color;
}
