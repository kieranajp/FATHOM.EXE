# CombatVisuals — read-only renderer for projectiles, splashes, debris.
#
# Sibling under OpenSea.tscn. Each frame, walks World.projectiles /
# World.splashes / World.debris and emits geometry into one shared ImmediateMesh
# (PRIMITIVE_LINES with per-vertex colour). Crates are a special case: each
# `is_spark: false` debris entry gets its own pooled MeshInstance3D using the
# cube LineModel so we get a proper wireframe box with rotation.
#
# Single source of truth for visuals — never writes back to gameplay state.
# Lifecycle of the underlying entries is owned by CombatSystem. Wave height
# comes from Ocean.get_wave_height (the single contract per ARCHITECTURE.md).
#
# JS reference: game.js render block "F./G./H." (projectiles/splashes/debris).
class_name CombatVisuals extends Node3D

# JS-canonical neon-yellow when the projectile's owner faction is unclear.
# Mirrors game.js fill style for the ball/grape primitive renders.
const FALLBACK_PLAYER_COLOR := Color("#33ffff")
const FALLBACK_PIRATE_COLOR := Color("#ff5555")
const FALLBACK_AUTHORITY_COLOR := Color("#3388ff")
const CHAIN_COLOR := Color("#ffff33")
const GRAPE_COLOR := Color("#ffff66")

# Extra cull margin so the mesh isn't clipped by the camera frustum culling
# (matches AimOverlay — these overlays have unstable AABBs).
const CULL_MARGIN: float = 4096.0

@export var tuning: CombatVisualsTuning
@export var ocean_path: NodePath

var _ocean: Ocean
var _lines_mesh: ImmediateMesh
var _lines_instance: MeshInstance3D
var _lines_material: StandardMaterial3D
# Round-5: projectile heads render as camera-facing FILLED quads into a
# second ImmediateMesh (PRIMITIVE_TRIANGLES). Lines and triangles can't
# share a single surface so we keep them in parallel meshes.
var _heads_mesh: ImmediateMesh
var _heads_instance: MeshInstance3D
var _heads_material: StandardMaterial3D

# Crate pool. Each MeshInstance3D holds its own ImmediateMesh built once from
# cube.tres. We add/remove from the pool as crates appear/disappear in
# World.debris. Keyed by the debris dict identity (RefCounted-by-reference);
# when an entry vanishes from World.debris we free its instance next frame.
var _crate_model: LineModel
var _crate_material: StandardMaterial3D
var _crate_visuals: Dictionary = {}  # crate dict -> MeshInstance3D
# Reusable arrays / scratch — avoid per-frame allocation churn where we can.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/combat_visuals.tres") as CombatVisualsTuning
	if ocean_path != NodePath(""):
		var on := get_node_or_null(ocean_path)
		if on is Ocean:
			_ocean = on as Ocean

	_lines_material = _build_lines_material()
	_lines_mesh = ImmediateMesh.new()
	_lines_instance = MeshInstance3D.new()
	_lines_instance.name = "CombatLines"
	_lines_instance.mesh = _lines_mesh
	_lines_instance.material_override = _lines_material
	_lines_instance.extra_cull_margin = CULL_MARGIN
	add_child(_lines_instance)

	# Heads mesh — solid filled billboarded quads at projectile heads. Shares
	# the same unshaded + per-vertex-colour approach as the lines mesh so the
	# bloom chain picks up bright projectile colours the same way.
	_heads_material = _build_lines_material()
	# CRITICAL: disable backface culling. The quad we build in _emit_head_quad
	# uses `cam_basis.x` and `cam_basis.y` as edges; the resulting face normal
	# is `cam_basis.x × cam_basis.y = cam_basis.z`, which in Godot points AWAY
	# from where the camera looks. Both triangles are therefore back-facing
	# from the chase cam, and default CULL_BACK hides the entire head — that's
	# the round-5 "tiny speck" regression: what the user saw was the trail in
	# the lines surface, not the head quad at all.
	_heads_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_heads_mesh = ImmediateMesh.new()
	_heads_instance = MeshInstance3D.new()
	_heads_instance.name = "CombatHeads"
	_heads_instance.mesh = _heads_mesh
	_heads_instance.material_override = _heads_material
	_heads_instance.extra_cull_margin = CULL_MARGIN
	add_child(_heads_instance)

	# Pre-load the cube model — duplicated per-crate so we can tint individual
	# instances if a future ticket wants damaged-vs-fresh crates.
	_crate_model = load("res://data/models/cube.tres") as LineModel
	_crate_material = _build_crate_material()

	_rng.randomize()


func _process(_delta: float) -> void:
	if tuning == null:
		return
	_rebuild_lines()
	_rebuild_heads()
	_sync_crates()


# Per-vertex colour with `vertex_color_use_as_albedo` is the cleanest way to
# mix faction-tinted projectiles, cyan splash rings, and orange sparks in one
# surface. Emission needs to come from albedo too (the emission texture would
# need a per-vertex feed we don't have). The bloom chain in OpenSea picks up
# anything above its hdr_threshold so high-energy albedo wires still glow.
func _build_lines_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	# Emission from albedo: the bloom chain reads ALBEDO * energy as HDR. We
	# multiply albedo here implicitly via the colour values we push (e.g. cyan
	# splash colour authored at full intensity; alpha attenuates the trail).
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.disable_fog = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	return mat


func _build_crate_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tuning.crate_color
	mat.emission_enabled = true
	mat.emission = tuning.crate_color
	mat.emission_energy_multiplier = tuning.crate_emission_energy
	mat.disable_fog = true
	return mat


# Walks the three world arrays and emits PRIMITIVE_LINES with per-vertex colour.
# Keeps allocation cost low: one surface_begin/end per frame, plain vertex pushes
# in between — same idiom as Ocean / AimOverlay.
func _rebuild_lines() -> void:
	_lines_mesh.clear_surfaces()
	# Bail if there's no line geometry to emit. Round-7: ball/grape projectiles
	# no longer emit a trail (matches JS — projectiles are single rects, only
	# sparks get the `* 0.04` motion trail). Round-10: chain moved off the
	# PRIMITIVE_LINES surface entirely (now billboarded quads in _rebuild_heads
	# so it reads at 4K instead of being a hairline). The lines surface only
	# carries splash rings and spark trails now.
	var has_sparks := false
	for d in World.debris:
		if bool(d.get("is_spark", false)):
			has_sparks = true
			break
	if World.splashes.is_empty() and not has_sparks:
		return

	_lines_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_emit_splashes()
	_emit_sparks()
	_lines_mesh.surface_end()


# Solid camera-facing quads for projectile heads (PRIMITIVE_TRIANGLES).
#   ball/grape → one quad per projectile.
#   chain    → two head quads (bola ends) + one billboarded link quad
#              connecting them. See _emit_chain_bola.
#
# Camera is resolved via the active viewport. Headless tests don't have one,
# so we skip emission entirely — splash + spark geometry on the lines surface
# still emits.
func _rebuild_heads() -> void:
	_heads_mesh.clear_surfaces()
	if World.projectiles.is_empty():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam == null:
		return

	# Camera-space right/up — flatten via global_transform.basis so the quad
	# always faces the camera regardless of pitch/yaw. Camera position is
	# needed for the chain link's view-aligned perpendicular.
	var cam_basis: Basis = cam.global_transform.basis
	var cam_right: Vector3 = cam_basis.x
	var cam_up: Vector3 = cam_basis.y
	var cam_pos: Vector3 = cam.global_transform.origin

	_heads_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in World.projectiles:
		var t: String = String(p.get("type", "ball"))
		if t == "chain":
			_emit_chain_bola(p, cam_right, cam_up, cam_pos)
		else:
			_emit_head_quad(p, t, cam_right, cam_up)
	_heads_mesh.surface_end()


func _emit_head_quad(p: Dictionary, t: String, cam_right: Vector3, cam_up: Vector3) -> void:
	var col: Color
	# `half_extent` is the quad's half-width/half-height in world metres
	# (configured value in combat_visuals.tres). Final quad is 2× this on each
	# axis — so `projectile_ball_size = 1.0` → 2.0m square at the head.
	# Named explicitly to avoid the round-5 ambiguity that called it `half` (as
	# if it had been pre-halved already) and made the regression hard to spot.
	var half_extent: float
	if t == "grape":
		col = GRAPE_COLOR
		half_extent = tuning.projectile_grape_size
	else:
		col = _color_for_projectile(p)
		half_extent = tuning.projectile_ball_size
	var head_color: Color = col * tuning.projectile_emission_energy
	head_color.a = 1.0
	var centre := Vector3(float(p.x), float(p.y), float(p.z))
	# Material has `cull_mode = CULL_DISABLED` because billboarded quads' face
	# normal is `cam_right × cam_up = cam_basis.z`, which points AWAY from
	# where the camera looks (Godot cameras look toward -basis.z) — under
	# default CULL_BACK the quad was completely invisible (round-5 "tiny
	# speck" regression: the speck was the LINES-surface trail; the head
	# itself never rendered).
	_emit_quad_at(centre, half_extent, head_color, cam_right, cam_up)


# Chain shot: BOLA. Two yellow head quads whirling around the projectile
# centre at radius `chain_visual_radius`, joined by a billboarded thick-line
# quad. Mirrors JS chain render (game.js:3287-3315) which draws two filled
# yellow rects at p1/p2 = centre ± (sin·r, 0, cos·r) joined by a strokeLine.
#
# Geometry: 2 head quads × 6 verts + 1 link quad × 6 verts = 18 verts per
# chain projectile. All emitted into the heads triangle surface so head + link
# share the same backface-disabled material and bloom path.
#
# Round-10 supersedes the round-1..9 chain render which used PRIMITIVE_LINES
# (1px in Vulkan — basically invisible at 4K, matched the bug report).
func _emit_chain_bola(p: Dictionary, cam_right: Vector3, cam_up: Vector3, cam_pos: Vector3) -> void:
	var angle: float = float(p.life) * tuning.chain_visual_speed
	var r: float = tuning.chain_visual_radius
	var px: float = float(p.x)
	var py: float = float(p.y)
	var pz: float = float(p.z)
	var p1 := Vector3(px + sin(angle) * r, py, pz + cos(angle) * r)
	var p2 := Vector3(px - sin(angle) * r, py, pz - cos(angle) * r)
	var col: Color = CHAIN_COLOR * tuning.projectile_emission_energy
	col.a = 1.0

	# 1. Two head quads at p1, p2.
	_emit_quad_at(p1, tuning.chain_head_size, col, cam_right, cam_up)
	_emit_quad_at(p2, tuning.chain_head_size, col, cam_right, cam_up)

	# 2. Connecting link as a view-aligned billboarded quad — same formula as
	#    ThickLineRenderer._append_quad. Perpendicular is (view × line)
	#    normalised, scaled by half-thickness; if collinear with view, fall back
	#    to cam_up projected onto the plane perpendicular to the line.
	var half_t: float = tuning.chain_link_thickness * 0.5
	var line_dir: Vector3 = p2 - p1
	var line_len: float = line_dir.length()
	if line_len <= 1e-5:
		return
	line_dir /= line_len
	var mid: Vector3 = (p1 + p2) * 0.5
	var view_dir: Vector3 = cam_pos - mid
	var view_len: float = view_dir.length()
	if view_len <= 1e-5:
		return
	view_dir /= view_len
	var perp: Vector3 = view_dir.cross(line_dir)
	var perp_len: float = perp.length()
	if perp_len > 1e-5:
		perp = (perp / perp_len) * half_t
	else:
		# Line points along view direction — fall back to cam_up flattened onto
		# the plane perpendicular to the line so the quad doesn't degenerate.
		var up_perp: Vector3 = cam_up - line_dir * cam_up.dot(line_dir)
		if up_perp.length_squared() < 1e-10:
			return
		perp = up_perp.normalized() * half_t

	_heads_mesh.surface_set_color(col)
	_heads_mesh.surface_add_vertex(p1 + perp)
	_heads_mesh.surface_add_vertex(p1 - perp)
	_heads_mesh.surface_add_vertex(p2 + perp)
	_heads_mesh.surface_add_vertex(p2 + perp)
	_heads_mesh.surface_add_vertex(p1 - perp)
	_heads_mesh.surface_add_vertex(p2 - perp)


# Emits a single camera-facing quad of `half_extent` at `centre` with `col`.
# Shared between projectile head rendering (_emit_head_quad) and the chain
# bola's two ends. Six verts, two triangles.
func _emit_quad_at(centre: Vector3, half_extent: float, col: Color, cam_right: Vector3, cam_up: Vector3) -> void:
	var r: Vector3 = cam_right * half_extent
	var u: Vector3 = cam_up * half_extent
	var v0: Vector3 = centre - r - u
	var v1: Vector3 = centre + r - u
	var v2: Vector3 = centre + r + u
	var v3: Vector3 = centre - r + u
	_heads_mesh.surface_set_color(col)
	_heads_mesh.surface_add_vertex(v0)
	_heads_mesh.surface_add_vertex(v1)
	_heads_mesh.surface_add_vertex(v2)
	_heads_mesh.surface_add_vertex(v0)
	_heads_mesh.surface_add_vertex(v2)
	_heads_mesh.surface_add_vertex(v3)


# Projectile colour by attacker faction. Falls back to is_player_owned when no
# attacker is set (e.g. legacy fixtures) or the attacker has no faction info.
func _color_for_projectile(p: Dictionary) -> Color:
	var attacker = p.get("attacker", null)
	if attacker is EnemyShip:
		return Factions.color_for((attacker as EnemyShip).faction_id)
	if attacker is PlayerShip:
		return FALLBACK_PLAYER_COLOR
	# No attacker → fall back to ownership flag.
	if bool(p.get("is_player_owned", false)):
		return FALLBACK_PLAYER_COLOR
	return FALLBACK_PIRATE_COLOR


# --- Splashes ---
# Horizontal cyan ring at sea level, expanding outward. Alpha fades with
# remaining life (life is decremented by CombatSystem each tick). One PRIMITIVE_LINES
# pair per segment (line-strip simulated by emitting paired endpoints).
func _emit_splashes() -> void:
	var segments: int = tuning.splash_ring_segments
	if segments < 4:
		segments = 4
	for s in World.splashes:
		var sx: float = float(s.x)
		var sz: float = float(s.z)
		var r: float = float(s.r)
		var life: float = float(s.life)
		var initial_life: float = 0.55  # splash_life from CombatTuning; the ratio is what we care about
		# Use whatever value lives on the dict; combat_system creates with the
		# tuning default 0.55s. If a future ticket changes it, we'd ideally read
		# the original — for now the canonical splash_life is good enough.
		var alpha: float = clampf(life / initial_life, 0.0, 1.0)
		var col: Color = tuning.splash_color * tuning.splash_emission_energy
		col.a = alpha
		_lines_mesh.surface_set_color(col)
		var prev := _splash_ring_point(sx, sz, r, 0, segments)
		for i in range(1, segments + 1):
			var curr := _splash_ring_point(sx, sz, r, i, segments)
			_lines_mesh.surface_add_vertex(prev)
			_lines_mesh.surface_add_vertex(curr)
			prev = curr


# Returns a ring sample point — rides the actual wave surface so the ring isn't
# a flat disc on choppy water (matches JS getWaveHeight call in game.js:3354).
func _splash_ring_point(cx: float, cz: float, radius: float, i: int, segments: int) -> Vector3:
	var theta: float = float(i) / float(segments) * TAU
	var px: float = cx + sin(theta) * radius
	var pz: float = cz + cos(theta) * radius
	var py: float = _ocean.get_wave_height(px, pz) if _ocean != null else 0.0
	return Vector3(px, py, pz)


# --- Sparks (debris.is_spark == true) ---
# Each spark = a short line segment from current position to (pos - vel * factor)
# in orange. Same trail trick as projectiles but with a fixed orange palette
# and slightly lower energy (gut shots scatter, they don't streak).
func _emit_sparks() -> void:
	var col: Color = tuning.spark_color * tuning.spark_emission_energy
	col.a = 1.0
	_lines_mesh.surface_set_color(col)
	for d in World.debris:
		if not bool(d.get("is_spark", false)):
			continue
		var tx: float = float(d.x) - float(d.vx) * tuning.projectile_trail_factor
		var ty: float = float(d.y) - float(d.vy) * tuning.projectile_trail_factor
		var tz: float = float(d.z) - float(d.vz) * tuning.projectile_trail_factor
		_lines_mesh.surface_add_vertex(Vector3(float(d.x), float(d.y), float(d.z)))
		_lines_mesh.surface_add_vertex(Vector3(tx, ty, tz))


# --- Crates ---
# Crates are wireframe cubes that ride the wave + tumble slowly. They live as
# per-crate MeshInstance3D children so each can have its own transform without
# us rebuilding cube geometry every frame. The pool is keyed by the dict ref
# so a one-pass diff updates the visible set.
func _sync_crates() -> void:
	# 1. Spawn visuals for any crate dict we haven't seen yet.
	# IMPORTANT: Godot 4 hashes dictionaries by content, and combat mutates
	# x/y/z/yaw on every tick — so using `d` directly as a key invalidates the
	# hash next frame and `_crate_visuals[d]` blows up with "Invalid access to
	# property or key {…}". We key by the stable monotonic `id` stamped at
	# spawn time by CombatSystem._next_id() instead.
	var live_ids: Dictionary = {}
	for d in World.debris:
		if bool(d.get("is_spark", false)):
			continue
		var id: int = int(d.get("id", 0))
		live_ids[id] = true
		if not _crate_visuals.has(id):
			_crate_visuals[id] = _build_crate_visual()
		var inst: MeshInstance3D = _crate_visuals[id]
		# Crate y rides the wave surface (or whatever the combat system wrote
		# into d.y for this frame).
		inst.position = Vector3(float(d.x), float(d.y), float(d.z))
		var b := Basis()
		b = b.rotated(Vector3.UP, float(d.get("yaw", 0.0)))
		b = b.rotated(Vector3.RIGHT, float(d.get("pitch", 0.0)))
		b = b.rotated(Vector3.FORWARD, float(d.get("roll", 0.0)))
		# Scale baked into the basis so we don't double-scale via the mesh's
		# build_immediate_mesh call (which was already done at 1.0 for the
		# instance — see _build_crate_visual).
		inst.transform.basis = b.scaled(Vector3.ONE * tuning.crate_scale)

	# 2. Free visuals for crates that disappeared from World.debris.
	var stale: Array = []
	for k in _crate_visuals.keys():
		if not live_ids.has(k):
			stale.append(k)
	for k in stale:
		var inst: MeshInstance3D = _crate_visuals[k]
		inst.queue_free()
		_crate_visuals.erase(k)


func _build_crate_visual() -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = _crate_model.build_immediate_mesh(1.0)
	inst.material_override = _crate_material
	inst.extra_cull_margin = CULL_MARGIN
	add_child(inst)
	return inst
