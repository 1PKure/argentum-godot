class_name RecoveryRules
extends RefCounted

# Explicit arena testing profile, not a representation of an AO20 class/level.
const ARENA_MAX_HEALTH := 500
const ARENA_MAX_MANA := 3000
const MEDITATION_WARMUP_MSEC := 2000
const MEDITATION_INTERVAL_MSEC := 1000
const MEDITATION_PERCENT := 5
const POTION_INTERVAL_MSEC := 330 # Arena tuning; AO20 IntervaloUserPuedeUsarU: 380 ms.
const ATTACK_POTION_GAP_MSEC := 700 # Arena tuning; source reference: 800 ms.
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
