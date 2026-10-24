extends "res://server/systems/arena_ranking_store.gd"

var fail_writes := false


func _init(path: String) -> void:
	super(path)


func _persist_payload(payload: Dictionary) -> Error:
	if fail_writes:
		return ERR_FILE_CANT_WRITE
	return super._persist_payload(payload)
