# EventBus — global signal dispatch hub. No logic, just signals.
# Owner: foundations (F1). The vocabulary is locked by ARCHITECTURE.md.
# If you need a new signal: stop, propose it in the PR, do not silently add.
extends Node

# Combat
signal cannon_fired(side: String, ammo_type: String, ship: Node)
signal projectile_spawned(projectile: Dictionary)
signal projectile_hit(victim: Node, damage: float, ammo_type: String, attacker: Node)
signal projectile_splashed(x: float, z: float)
signal ship_damaged(ship: Node, amount: float, ammo_type: String)
signal ship_sunk(ship: Node, sunk_by: Node)
signal player_death

# Navigation
signal port_proximity_entered(port: PortDef)
signal port_proximity_exited
signal port_docked(port: PortDef)
signal port_undocked
signal archipelago_changed(archipelago: ArchipelagoDef)
signal travel_started(target: ArchipelagoDef)
signal travel_completed(target: ArchipelagoDef)
signal island_collided(port: PortDef, ship: Node)

# Economy
signal cargo_bought(item: String, amount: int, price: int)
signal cargo_sold(item: String, amount: int, price: int)
signal ship_purchased(class_id: String)
signal market_transaction_failed(reason: String)

# Time
signal hour_passed(day: int, hour: int)
signal day_passed(day: int)

# Authority / alerts
signal no_fire_zone_violated(violator: Node, near_port: PortDef)
signal enforcer_alert_started
signal enforcer_alert_ended

# UI
signal hud_message(text: String, severity: String)  # severity: info, warning, alert
signal map_toggled(open: bool)
signal inventory_toggled(open: bool)
signal dev_menu_toggled(open: bool)

# Post-parity (declared now, used later)
signal morale_changed(delta: float, reason: String)
signal officer_killed(officer: Officer)
signal reputation_changed(faction: String, delta: float)
signal contraband_detected(item: String, port: PortDef)
