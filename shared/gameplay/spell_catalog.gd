class_name SpellCatalog
extends RefCounted

const DATA_FILE := "res://assets/argentum/source/data/Hechizos.dat"
const DEFAULT_BINDINGS: Array[int] = [1, 2, 12, 13]
# Arena cadence is deliberately faster than the imported reference profile.
const CAST_INTERVAL_MSEC := 950 # Arena tuning; previous: 1000 ms.
const ATTACK_SPELL_GAP_MSEC := 600 # Previous: 650 ms.
const SPELL_ATTACK_GAP_MSEC := 600
# Every enabled entry has a real server handler. Other entries stay consultable.
const STATUS_HANDLERS := [11, 25, 26, 27, 28, 29, 112, 132, 133, 263, 350]
const PERIODIC_HANDLERS := [242, 243, 268, 269]
static var _spells: Dictionary = {}


static func all_ids() -> Array[int]:
	_ensure_loaded()
	var ids: Array[int] = DEFAULT_BINDINGS.duplicate()
	for id: int in _spells:
		if not ids.has(id):
			ids.append(id)
	return ids


static func loadout_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in all_ids():
		if is_available(id):
			ids.append(id)
	return ids


static func get_spell(spell_id: int) -> Dictionary:
	_ensure_loaded()
	return _spells.get(spell_id, {})


static func is_available(spell_id: int) -> bool:
	var spell := get_spell(spell_id)
	return not spell.is_empty() and str(spell.unavailable_reason).is_empty()


static func display_icon_grh(spell_id: int) -> int:
	# Original public data: minor heal points to a blank cell; Dragon Breath
	# has no IconoIndex. Reuse existing healing/fire icons for presentation.
	if spell_id == 12:
		return 74686
	if spell_id == 4:
		return 74714
	return int(get_spell(spell_id).get("icon_grh", 0))


static func _ensure_loaded() -> void:
	if not _spells.is_empty():
		return
	var raw: Dictionary = {}
	var current_id := 0
	var section := RegEx.new()
	section.compile("^\\[HECHIZO([0-9]+)\\]")
	for raw_line in FileAccess.get_file_as_string(DATA_FILE).split("\n"):
		var line := raw_line.strip_edges()
		var matched := section.search(line)
		if matched != null:
			current_id = int(matched.get_string(1))
			raw[current_id] = {}
		elif current_id > 0 and line.contains("=") and not line.begins_with("'"):
			var split := line.find("=")
			raw[current_id][line.substr(0, split).strip_edges()] = line.substr(split + 1).strip_edges()
	for id: int in raw:
		var data: Dictionary = raw[id]
		var effect := "healing" if int(data.get("SubeHP", "0")) == 1 else "damage"
		if STATUS_HANDLERS.has(id):
			effect = "status" if int(data.get("MaxHP", "0")) == 0 else "healing"
		elif PERIODIC_HANDLERS.has(id):
			effect = "periodic"
		_spells[id] = {
			"id": id, "name": data.get("Nombre", "Entrada %d sin definición" % id),
			"description": data.get("Desc", "Sin descripción en el archivo de origen."),
			"words": data.get("PalabrasMagicas", ""), "mana": int(data.get("ManaRequerido", "0")),
			"min_amount": int(data.get("MinHP", "0")), "max_amount": int(data.get("MaxHP", "0")),
			"effect": effect, "icon_grh": int(data.get("IconoIndex", "0")),
			# Implosion's DAT stores animation GRH12834; FX4 points to that GRH.
			"fx_id": 4 if id == 54 else int(data.get("FXgrh", "0")), "sound_id": int(data.get("WAV", "0")),
			"duration": float(data.get("Duration", "0")), "cooldown": float(data.get("Cooldown", "0")),
			"eot_id": int(data.get("EOTID", "0")), "raw": data,
			"unavailable_reason": _unsupported_reason(id, data),
		}


static func _unsupported_reason(id: int, data: Dictionary) -> String:
	if not data.has("Nombre"):
		return "Entrada sin definición de hechizo en el archivo original."
	if STATUS_HANDLERS.has(id) or PERIODIC_HANDLERS.has(id):
		return ""
	var name := str(data.get("Nombre", "")).to_lower()
	if name.contains("npc") or int(data.get("Target", "0")) == 2 or name.begins_with("magia de") or name.contains("bufón") or name.contains("reyarb") or name.contains("testeo") or name.contains("kraken"):
		return "Hechizo de NPC o de administración; fuera de esta arena PvP."
	if int(data.get("Tipo", "0")) == 4:
		return "Requiere el sistema de invocaciones y mascotas."
	if name.begins_with("receta"):
		return "Receta de fabricación; requiere inventario y profesiones."
	if int(data.get("Tipo", "0")) == 1 and int(data.get("SubeHP", "0")) in [1, 2] and int(data.get("EOTID", "0")) == 0 and int(data.get("MaxHP", "0")) > 0 and int(data.get("IsSkill", "0")) == 0 and int(data.get("RequireWeaponType", "0")) == 0:
		return ""
	if int(data.get("Revivir", "0")) == 1:
		return "Resurrección requiere portar sus reglas de energía y clase. En la arena podés Reaparecer."
	if int(data.get("SubeAG", "0")) != 0 or int(data.get("SubeFU", "0")) != 0:
		return "Requiere atributos, equipo y sus fórmulas de combate."
	if int(data.get("Invisibilidad", "0")) != 0:
		return "Requiere visibilidad por jugador y ocultación en la red."
	return "Requiere portar sus reglas específicas de AO20; todavía no está habilitado."
