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

	# Pre-load the cube model — duplicated per-crate so we can tint individual
	# instances if a future ticket wants damaged-vs-fresh crates.
	_crate_model = load("res://data/models/cube.tres") as LineModel
	_crate_material = _build_crate_material()

	_rng.randomize()


func _process(_delta: float) -> void:
	if tuning == null:
		return
	_rebuild_lines()
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
	# Bail if there's no line geometry to emit. Crates are handled separately,
	# so a World with only crates (no projectiles/splashes/sparks) must NOT
	# call surface_begin — an empty surface_end triggers a vertices.is_empty()
	# engine warning.
	var has_sparks := false
	for d in World.debris:
		if bool(d.get("is_spark", false)):
			has_sparks = true
			break
	if World.projectiles.is_empty() and World.splashes.is_empty() and not has_sparks:
		return

	_lines_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_emit_projectiles()
	_emit_splashes()
	_emit_sparks()
	_lines_mesh.surface_end()


# --- Projectiles ---
func _emit_projectiles() -> void:
	for p in World.projectiles:
		var t: String = String(p.get("type", "ball"))
		match t:
			"chain":
				_emit_chain(p)
			_:
				_emit_ball_or_grape(p, t)


# Ball or grape: short trail segment along velocity, faction-tinted (grape gets
# a JS-yellow override). Per JS reference, all three ammo types render in the
# same yellow palette — but the issue asks for faction tinting, so we deviate
# from the JS for clarity (player cyan, pirate red, authority blue) and keep
# grape's pellet yellow since the cluster is the dead-giveaway.
#
# The visual is a small "+" marker (two crossed line segments) at the head, plus
# a fading trail behind it. The cross makes the projectile readable at range
# even when the trail length is dwarfed by camera distance.
func _emit_ball_or_grape(p: Dictionary, t: String) -> void:
	var col: Color
	if t == "grape":
		col = GRAPE_COLOR
	else:
		col = _color_for_projectile(p)
	var px: float = float(p.x)
	var py: float = float(p.y)
	var pz: float = float(p.z)
	var head_color: Color = col * tuning.projectile_emission_energy
	head_color.a = 1.0

	# Trail behind the projectile. Fades alpha to zero at the tail end.
	var tx: float = px - float(p.vx) * tuning.projectile_trail_factor
	var ty: float = py - float(p.vy) * tuning.projectile_trail_factor
	var tz: float = pz - float(p.vz) * tuning.projectile_trail_factor
	var tail_color: Color = head_color
	tail_color.a = 0.0
	_lines_mesh.surface_set_color(head_color)
	_lines_mesh.surface_add_vertex(Vector3(px, py, pz))
	_lines_mesh.surface_set_color(tail_color)
	_lines_mesh.surface_add_vertex(Vector3(tx, ty, tz))

	# Crosshair at the head — three orthogonal ticks so the projectile reads as
	# a glowing volumetric point at range, not a flat plus that disappears when
	# viewed edge-on. The tick size scales with projectile_head_size — round-4
	# playtest had this at 0.25m (invisibly tiny at mid-flight); 0.6m reads
	# properly against the bloom on 4K. Grape pellets dodge this by hitting
	# the inner branch above with type=="grape" — kept tuned to a smaller cluster
	# read, see _emit_grape_pellet below if reintroduced later.
	var head_tick: float = tuning.projectile_head_size
	_lines_mesh.surface_set_color(head_color)
	_lines_mesh.surface_add_vertex(Vector3(px - head_tick, py, pz))
	_lines_mesh.surface_add_vertex(Vector3(px + head_tick, py, pz))
	_lines_mesh.surface_add_vertex(Vector3(px, py - head_tick, pz))
	_lines_mesh.surface_add_vertex(Vector3(px, py + head_tick, pz))
	# Z-arm too — the JS canvas renderer drew a screen-space dot; with three
	# axis-aligned arms we approximate a "bright point" silhouette regardless
	# of viewing angle.
	_lines_mesh.surface_add_vertex(Vector3(px, py, pz - head_tick))
	_lines_mesh.surface_add_vertex(Vector3(px, py, pz + head_tick))


# Chain shot: two yellow dots whirling around the projectile centre, joined by
# a connecting line. Direct mirror of the JS chain render (game.js:3287-3315),
# but expressed as three line segments because PRIMITIVE_LINES can't draw bare
# points.
func _emit_chain(p: Dictionary) -> void:
	var angle: float = float(p.life) * tuning.chain_visual_speed
	var r: float = tuning.chain_visual_radius
	var px: float = float(p.x)
	var py: float = float(p.y)
	var pz: float = float(p.z)
	var p1 := Vector3(px + sin(angle) * r, py, pz + cos(angle) * r)
	var p2 := Vector3(px - sin(angle) * r, py, pz - cos(angle) * r)
	var col: Color = CHAIN_COLOR * tuning.projectile_emission_energy
	col.a = 1.0
	_lines_mesh.surface_set_color(col)
	# Connecting segment between the two ends.
	_lines_mesh.surface_add_vertex(p1)
	_lines_mesh.surface_add_vertex(p2)
	# Short marker line on each end (so each dot reads as a chunky point even at
	# range; without it the two endpoints disappear into the connection). Scaled
	# proportionally with projectile_head_size so chain reads at the same visual
	# weight as ball/grape after the round-4 bump.
	var tick: float = tuning.projectile_head_size * 0.6
	_lines_mesh.surface_add_vertex(p1 + Vector3(tick, 0, 0))
	_lines_mesh.surface_add_vertex(p1 - Vector3(tick, 0, 0))
	_lines_mesh.surface_add_vertex(p2 + Vector3(tick, 0, 0))
	_lines_mesh.surface_add_vertex(p2 - Vector3(tick, 0, 0))


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
	var live_crates: Array = []
	for d in World.debris:
		if bool(d.get("is_spark", false)):
			continue
		live_crates.append(d)
		if not _crate_visuals.has(d):
			_crate_visuals[d] = _build_crate_visual()
		var inst: MeshInstance3D = _crate_visuals[d]
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
		if not live_crates.has(k):
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
