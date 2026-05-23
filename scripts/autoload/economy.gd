# Economy — port price calculation.
# Reads GameState.travel_count + port.base_prices, applies deterministic wave.
# Owner: stub from F1. Real implementation lands with T06 (economy/market).
extends Node


func calculate_port_prices(_port: PortDef) -> Dictionary:
	push_warning("Economy.calculate_port_prices stub — T06")
	return {}
