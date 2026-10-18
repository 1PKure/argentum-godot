class_name SkinCatalog
extends RefCounted

# Stable reward IDs preserve v1 saves. A tier resolves to the current class's
# outfit; it never enters ClassCatalog's equipment or stat calculations.
const ENTRIES := [
	{"id": "preset", "name": "Atuendo de clase", "wins": 0, "body_id": 0},
	{"id": "explorer", "name": "Primer atuendo", "wins": 1},
	{"id": "scarlet", "name": "Segundo atuendo", "wins": 3},
	{"id": "light", "name": "Tercer atuendo", "wins": 5},
]
const DATA_PATH := "res://assets/argentum/source/data/arena_skins.json"
static var _variants: Dictionary = {}

static func get_skin(id: String, class_id: int = ClassCatalog.DEFAULT_CLASS) -> Dictionary:
	if _variants.is_empty():
		_variants = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var variants: Array = _variants.get(str(class_id), [])
	if variants.size() != 3:
		return {}
	for index in range(ENTRIES.size()):
		if ENTRIES[index].id == id:
			var entry: Dictionary = ENTRIES[index].duplicate()
			if index > 0:
				entry.merge(variants[index - 1], true)
			return entry
	return {}

static func for_class(class_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in ENTRIES:
		var skin := get_skin(str(entry.id), class_id)
		if not skin.is_empty():
			result.append(skin)
	return result

static func is_unlocked(id: String, wins: int, class_id: int = ClassCatalog.DEFAULT_CLASS) -> bool:
	var skin := get_skin(id, class_id)
	return not skin.is_empty() and wins >= int(skin.wins)
