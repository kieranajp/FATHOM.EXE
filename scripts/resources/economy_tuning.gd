# EconomyTuning — numbers for port pricing + ammo trading.
# Authored in data/tuning/economy.tres; loaded by autoload/economy.gd.
class_name EconomyTuning extends Tuning

# Price fluctuation: 1.0 + sin(travel_count * wave_frequency + port_seed) * wave_amplitude.
@export var wave_amplitude: float = 0.15
@export var wave_frequency: float = 0.5

# Producer port pricing multipliers (good is plentiful → cheap to buy, low resale).
@export var producer_buy_mult: float = 0.6
@export var producer_sell_mult: float = 0.4

# Consumer port pricing multipliers (good is in demand → expensive to buy, high resale).
@export var consumer_buy_mult: float = 1.8
@export var consumer_sell_mult: float = 1.4

# Default (neither producer nor consumer) pricing multipliers.
@export var default_buy_mult: float = 1.0
@export var default_sell_mult: float = 0.75

# Ammunition prices. Ammo is bought from / sold to the port market;
# sell prices are 0 (refit value only) per JS reference.
@export var ammo_ball_buy: int = 2
@export var ammo_ball_sell: int = 0
@export var ammo_chain_buy: int = 5
@export var ammo_chain_sell: int = 0
@export var ammo_grape_buy: int = 8
@export var ammo_grape_sell: int = 0

# Per-unit cargo-hold weight. Commodity = 10 per unit, ammo = 0.2 per unit.
# Used by Market and Shipyard cargo-overflow checks.
@export var commodity_weight: float = 10.0
@export var ammo_weight: float = 0.2

# Trade-in fraction of current ship cost, scaled by hull damage ratio.
@export var ship_tradein_fraction: float = 0.7
