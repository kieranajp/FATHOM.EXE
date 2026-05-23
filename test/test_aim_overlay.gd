# T-round-4: AimOverlay smoke test. Confirms that calling _rebuild with a
# synthetic aim state populates the (_verts, _edges) scratch buffers with all
# five visual elements — trajectory + dashed cone (×2) + ring + height guide
# + crosshair. Doesn't assert exact counts (the dashing math is intentionally
# fuzzy) — just "non-empty after, empty before". Catches a future refactor
# that accidentally early-returns or wires the wrong buffer.
#
# We synthesise a PlayerShip stub so AimOverlay's references resolve. A real
# PlayerShip needs the full scene tree + autoloads to spawn, which would
# undermine the smoke-test ethos.
extends GutTest

var _overlay: AimOverlay
var _stub_player: PlayerShip


func before_each() -> void:
	_stub_player = PlayerShip.new()
	add_child_autofree(_stub_player)
	# Bare minimum state for _rebuild: yaw + position + a non-null ship_class so
	# the hit_radius lookup doesn't fall to the fallback branch.
	_stub_player.yaw = 0.0
	_stub_player.global_position = Vector3.ZERO
	_stub_player.ship_class = load("res://data/ships/dinghy.tres") as ShipClass

	_overlay = AimOverlay.new()
	add_child_autofree(_overlay)
	_overlay.tuning = load("res://data/tuning/combat.tres") as CombatTuning
	_overlay.set("_player", _stub_player)
	# _ready already constructed the mesh + material — fine.


func test_rebuild_populates_buffers_for_starboard_aim() -> void:
	var aim := {
		"side": "starboard",
		"reticle": Vector3(120.0, 8.0, 0.0),
		"yaw_offset": 0.0,
		"range": 120.0,
	}
	_overlay._rebuild(aim)
	# Vertex/edge buffers populated by all five elements. Trajectory alone is
	# TRAJECTORY_SEGMENTS (24) edges = 48 verts; everything else adds on top.
	# Loose bound — just confirm "the work ran".
	assert_gt(_overlay._verts.size(), 50, "Rebuild emits trajectory + extras")
	assert_eq(
		_overlay._edges.size(),
		_overlay._verts.size(),
		"Edge-pair layout: every vertex is part of exactly one edge endpoint",
	)


func test_rebuild_populates_buffers_for_port_aim() -> void:
	# Port-side should fire from the opposite flank — different start point, but
	# the same elements emit, so non-empty buffers either way.
	var aim := {
		"side": "port",
		"reticle": Vector3(-120.0, 8.0, 0.0),
		"yaw_offset": 0.0,
		"range": 120.0,
	}
	_overlay._rebuild(aim)
	assert_gt(_overlay._verts.size(), 50, "Port side also emits non-empty geometry")


func test_rebuild_clears_buffers_between_frames() -> void:
	# Two rebuilds shouldn't accumulate — the scratch buffers must reset every
	# frame, otherwise we'd render the previous frame's curve on top of the new
	# one as a smear.
	var aim := {"side": "starboard", "reticle": Vector3(100.0, 5.0, 0.0)}
	_overlay._rebuild(aim)
	var first_size: int = _overlay._verts.size()
	_overlay._rebuild(aim)
	assert_eq(
		_overlay._verts.size(),
		first_size,
		"Per-frame buffer reset — second rebuild matches first, not 2x",
	)
