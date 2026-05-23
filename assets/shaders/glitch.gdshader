// Glitch shader stub - FATHOM.EXE legendary galleon.
// 
// Post-parity glitch ticket will fill this in to implement:
//   - Silhouette edge pixelation (suggests imperfect resolution by the world's rendering)
//   - Vertex tearing & displacement jumps
//   - Ontological violation styling: flat solid color in a wireframe world
//   - Audio and HUD digital telemetry corruption triggers
//
// This compiled stub is placed to prevent load/compile issues.

shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 glitch_color : source_color = vec3(1.0, 0.0, 1.0); // magenta default

void fragment() {
	ALBEDO = vec3(0.0);
	EMISSION = glitch_color;
}
