class_name RecoveryRules
extends RefCounted

# Class resources come from ClassCatalog.
const MEDITATION_WARMUP_MSEC := 500
const MEDITATION_INTERVAL_MSEC := 500
const MEDITATION_PERCENT := 5
const POTION_INTERVAL_MSEC := 280 # Per input lane, shared between colors.
const POTION_COMBINED_MIN_MSEC := 200 # Shared floor when alternating click and Use.
const ATTACK_POTION_GAP_MSEC := 600 # Shared by click, Use and direct hotkeys.
const POTION_FILE := "res://assets/argentum/source/data/arena_consumables.ini"


static func get_potion(action: String) -> Dictionary:
	var id := 38 if action == "health_potion" else 37
	var sections := AODataFile.read_sections(POTION_FILE)
	var data: Dictionary = sections.get("OBJ%d" % id, {})
	if data.is_empty():
		return {}
	return {"id": id, "name": str(data.get("Name", "")),
		"min": int(data.get("MinModificador", 0)), "max": int(data.get("MaxModificador", 0)),
		"percent": int(data.get("Porcentaje", 0)), "icon_grh": int(data.get("GrhIndex", 0)),
		"sound_id": int(data.get("SND1", 0))}
