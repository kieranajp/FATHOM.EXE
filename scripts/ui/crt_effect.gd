# CRTPostProcess — applies the CRT shader uniforms loaded from render.tres.
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	var tuning := load("res://data/tuning/render.tres") as RenderTuning
	if tuning == null:
		push_warning("CRTPostProcess: Failed to load render.tres tuning resource")
		return
		
	var mat := color_rect.material as ShaderMaterial
	if mat == null:
		push_warning("CRTPostProcess: ColorRect has no ShaderMaterial assigned")
		return
		
	mat.set_shader_parameter("warp_amount", tuning.crt_warp_amount)
	mat.set_shader_parameter("scanline_intensity", tuning.crt_scanline_intensity)
	mat.set_shader_parameter("scanline_frequency", tuning.crt_scanline_frequency)
	mat.set_shader_parameter("vignette_intensity", tuning.crt_vignette_intensity)
	mat.set_shader_parameter("vignette_power", tuning.crt_vignette_power)
	mat.set_shader_parameter("chromatic_aberration", tuning.crt_chromatic_aberration)
	mat.set_shader_parameter("flicker_intensity", tuning.crt_flicker_intensity)
	mat.set_shader_parameter("flicker_speed", tuning.crt_flicker_speed)
