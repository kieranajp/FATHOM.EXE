// CRT Post-Process Shader - handles scanlines, screen curvature, vignettes,
// chromatic aberration, and subtle screen flicker for a retro vector monitor feel.

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Curvature / Warp (higher value = less warp, 0.0 = completely flat)
uniform float warp_amount : hint_range(0.0, 10.0) = 4.0;

// Scanlines
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_frequency : hint_range(10.0, 2000.0) = 540.0;

// Vignette
uniform float vignette_intensity : hint_range(0.0, 50.0) = 15.0;
uniform float vignette_power : hint_range(0.0, 5.0) = 0.25;

// Chromatic Aberration
uniform float chromatic_aberration : hint_range(0.0, 10.0) = 1.5;

// Flicker
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.003;
uniform float flicker_speed : hint_range(1.0, 100.0) = 60.0;

vec2 warp(vec2 uv, float amount) {
	if (amount <= 0.0001) {
		return uv;
	}
	vec2 coord = uv * 2.0 - 1.0;
	coord.x *= 1.0 + (coord.y * coord.y) / (amount * amount);
	coord.y *= 1.0 + (coord.x * coord.x) / (amount * amount);
	return coord * 0.5 + 0.5;
}

void fragment() {
	// 1. Curvature Warp
	vec2 uv = warp(SCREEN_UV, warp_amount);
	
	// Draw a solid black bezel outside the CRT curvature bounds
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// 2. Chromatic Aberration (Chroma Split)
		vec2 chroma_offset = vec2(chromatic_aberration * 0.001, 0.0);
		float r = texture(screen_texture, uv - chroma_offset).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, uv + chroma_offset).b;
		vec3 color = vec3(r, g, b);
		
		// 3. Scanlines
		float scanline = sin(uv.y * scanline_frequency * 6.28318530718);
		scanline = (scanline + 1.0) * 0.5; // Map from [-1, 1] to [0, 1]
		color = mix(color, color * (1.0 - scanline_intensity), scanline);
		
		// 4. Vignette (Darken corners)
		float vig = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
		vig = clamp(pow(vig * vignette_intensity, vignette_power), 0.0, 1.0);
		color *= vig;
		
		// 5. High-Frequency Luminance Flicker
		float flicker = 1.0 - (flicker_intensity * sin(TIME * flicker_speed));
		color *= flicker;
		
		COLOR = vec4(color, 1.0);
	}
}
