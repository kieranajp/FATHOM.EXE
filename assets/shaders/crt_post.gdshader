// CRT post-process — pass-through stub.
// Foundations: no-op. Scanlines / curvature / chroma split land with the CRT ticket.

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	COLOR = texture(screen_texture, SCREEN_UV);
}
