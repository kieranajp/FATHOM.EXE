# Persistence — save/load to user://save.json. Versioned schema.
# Save on port_docked; load on Main boot if has_save().
# Owner: stub from F1. Real implementation lands with T08 (persistence).
extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1


func save() -> void:
	push_warning("Persistence.save stub — T08")


func load() -> bool:
	push_warning("Persistence.load stub — T08")
	return false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
