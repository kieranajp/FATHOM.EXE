# HudTuning — numbers for the HUD overlay (T07). Authored in data/tuning/hud.tres.
class_name HudTuning extends Tuning

# How long an `EventBus.hud_message` banner stays visible before auto-hide.
@export var alert_duration: float = 2.5

# Hull-HP threshold below which the HP bar turns red and the HUD root flashes
# a subtle red border. Fraction of max_health.
@export var low_hp_threshold: float = 0.30

# Reload duration the HUD assumes for combat-readiness bars while T06 is
# unshipped. Once T06 lands and reload state moves onto PlayerState (or
# PlayerShip), the HUD will read it directly and this fallback goes away.
@export var assumed_reload_seconds: float = 3.0

# Range (in metres) inside which the target panel will show. Matches the
# combat tuning's expected acquisition radius; T06 may tweak.
@export var target_panel_max_distance: float = 200.0

# Wind-needle visual length in pixels. Drawn from a 64px compass dial centre.
@export var wind_needle_length_px: float = 22.0
