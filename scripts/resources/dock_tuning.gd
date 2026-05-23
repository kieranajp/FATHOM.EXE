# DockTuning — numbers for port proximity + dock state machine.
# Authored in data/tuning/dock.tres; loaded by systems/open_sea.gd and
# systems/port.gd.
#
# JS reference: proximity threshold == port.size + 15 (game.js:2909);
# undock immunity == 4.0s in JS, dialled to 3.0s here per the T03 brief
# (matches the existing collision_immunity_seconds for consistency).
class_name DockTuning extends Tuning

# Slack added to a port's own `size` when checking proximity.
# `in_proximity := dist(player, port) < port.size + proximity_padding`.
@export var proximity_padding: float = 15.0

# Seconds of collision immunity granted to the player on undock — so the
# spawn-near-port doesn't immediately trigger a bounce.
@export var undock_immunity_seconds: float = 3.0

# How often the proximity check runs. 4 Hz is plenty for a slow-moving ship
# and saves the per-frame node iteration.
@export var proximity_tick_hz: float = 4.0

# Beacon spin rate (rad/s). JS: yaw = time * 0.6 (game.js:3034).
@export var beacon_spin_rate: float = 0.6
