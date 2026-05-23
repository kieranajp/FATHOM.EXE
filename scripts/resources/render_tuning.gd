# RenderTuning — controls wireframe shader + bloom-glow parameters.
#
# Authored in `data/tuning/render.tres`; consumed by:
#   - wireframe.gdshader (via PlayerShip / PortMesh material setup) for
#     per-mesh glow_intensity + edge_thickness
#   - WorldEnvironment in OpenSea.tscn — the bloom chain below
#
# Bloom chain (the reason wireframes look like vector arcade lines):
#   1. wireframe.gdshader computes ALBEDO = glow_color * glow_intensity. With
#      `glow_intensity > 1.0` the ALBEDO exceeds the [0,1] LDR range and reads
#      as HDR after tonemapping.
#   2. WorldEnvironment.glow_enabled = true collects pixels brighter than
#      `bloom_hdr_threshold`, blurs them across `bloom_levels_*`, and adds them
#      back to the scene with `bloom_intensity / bloom_strength`.
#   3. The threshold should sit *below* the wireframe ALBEDO so wires bloom.
#      Increasing the threshold tightens the glow to brighter highlights only.
#
# All values mirror Godot Environment property names (with the `glow_` prefix
# dropped) — see scenes/OpenSea.tscn for where they're applied.
class_name RenderTuning extends Tuning

@export_group("Wireframe Shaders")
@export var wireframe_glow_intensity: float = 4.0
@export var wireframe_edge_thickness: float = 0.015

@export_group("Bloom / Glow (WorldEnvironment)")
@export var bloom_intensity: float = 2.0
@export var bloom_strength: float = 1.1
@export var bloom_bloom: float = 0.35
@export var bloom_hdr_threshold: float = 0.5
# Multi-scale bloom contribution. Levels 3-5 give a soft, broad halo;
# 1-2 sharpen tight glow next to lines. Tweak in the editor.
@export var bloom_level_1: float = 0.0
@export var bloom_level_2: float = 0.4
@export var bloom_level_3: float = 0.7
@export var bloom_level_4: float = 0.7
@export var bloom_level_5: float = 0.5
@export var bloom_level_6: float = 0.3
@export var bloom_level_7: float = 0.0
