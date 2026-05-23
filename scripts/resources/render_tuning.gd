# RenderTuning — controls global CRT and wireframe shader parameters.
# Authored in data/tuning/render.tres; consumed by UI/post-process effects and meshes.
class_name RenderTuning extends Tuning

@export_group("Wireframe Shaders")
@export var wireframe_glow_intensity: float = 4.0
@export var wireframe_edge_thickness: float = 0.015

@export_group("CRT Post-Process")
@export var crt_warp_amount: float = 4.0
@export var crt_scanline_intensity: float = 0.15
@export var crt_scanline_frequency: float = 540.0
@export var crt_vignette_intensity: float = 15.0
@export var crt_vignette_power: float = 0.25
@export var crt_chromatic_aberration: float = 1.5
@export var crt_flicker_intensity: float = 0.003
@export var crt_flicker_speed: float = 60.0
