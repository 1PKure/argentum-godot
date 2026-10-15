class_name SpellCatalog
extends RefCounted

const DATA_FILE := "res://assets/argentum/source/data/Hechizos.dat"
const LOADOUT: Array[int] = [1, 2, 12, 13]
# AO20 intervalos.ini: spell/spell, attack/spell and spell/attack.
const CAST_INTERVAL_MSEC := 1230
const ATTACK_SPELL_GAP_MSEC := 800
const SPELL_ATTACK_GAP_MSEC := 800

static var _spells: Dictionary = {}


static func loadout_ids() -> Array[int]:
	return LOADOUT.duplicate()


static func get_spell(spell_id: int) -> Dictionary:
	if _spells.is_empty():
		_load_database()
	return _spells.get(spell_id, {})


static func is_available(spell_id: int) -> bool:
	return LOADOUT.has(spell_id) and not get_spell(spell_id).is_empty()


static func _load_database() -> void:
	var content := FileAccess.get_file_as_string(DATA_FILE)
	var raw: Dictionary = {}
	var current_id := 0
	for raw_line in content.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("[HECHIZO"):
			current_id = line.trim_prefix("[HECHIZO").trim_suffix("]").to_int()
			if LOADOUT.has(current_id):
				raw[current_id] = {}
		elif LOADOUT.has(current_id) and line.contains("=") and not line.begins_with("'"):
			var split := line.find("=")
			raw[current_id][line.substr(0, split).strip_edges()] = line.substr(split + 1).strip_edges()
	for spell_id: int in LOADOUT:
		var data: Dictionary = raw.get(spell_id, {})
		if data.is_empty():
			push_error("Missing AO20 spell: %d" % spell_id)
			continue
		_spells[spell_id] = {
			"id": spell_id,
			"name": data.get("Nombre", ""),
			"description": data.get("Desc", ""),
			"words": data.get("PalabrasMagicas", ""),
			"mana": int(data.get("ManaRequerido", "0")),
			"min_amount": int(data.get("MinHP", "0")),
			"max_amount": int(data.get("MaxHP", "0")),
			"effect": "healing" if int(data.get("SubeHP", "0")) == 1 else "damage",
			"icon_grh": int(data.get("IconoIndex", "0")),
			"fx_id": int(data.get("FXgrh", "0")),
			"sound_id": int(data.get("WAV", "0")),
		}
