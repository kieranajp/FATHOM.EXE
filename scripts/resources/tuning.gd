# Tuning — abstract base class for per-system tuning resources.
#
# Each system owns a subclass with its own @export fields, and ships a flat
# .tres under data/tuning/ holding the numbers. See combat_tuning.gd for the
# pattern. Other systems (sailing, wind, camera, economy, world, render, audio,
# time, tavern) get their own subclass as their ticket lands.
#
# This base intentionally has no fields — it exists only to give the family a
# shared type so call sites can take a `Tuning` parameter when they don't care
# which system's numbers are inside.
class_name Tuning extends Resource
