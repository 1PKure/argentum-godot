class_name SkinCatalog
extends RefCounted

# Presentation only: body overrides never enter ClassCatalog's stat calculations.
const ENTRIES := [
	{"id": "preset", "name": "Atuendo de clase", "wins": 0, "body_id": 0},
	{"id": "explorer", "name": "Explorador", "wins": 1, "body_id": 67},
	{"id": "scarlet", "name": "Escarlata", "wins": 3, "body_id": 48},
	{"id": "light", "name": "De la Luz", "wins": 5, "body_id": 262},
]

static func get_skin(id: String) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry.id == id:
			return entry.duplicate()
	return {}

static func is_unlocked(id: String, wins: int) -> bool:
	var skin := get_skin(id)
	return not skin.is_empty() and wins >= int(skin.wins)
