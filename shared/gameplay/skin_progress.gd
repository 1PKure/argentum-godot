class_name SkinProgress
extends RefCounted

var storage_path := "user://arena_skins_v1.cfg"
var wins := 0
var selected := "preset"
var claimed: Array[String] = []
var save_error := OK

func restore() -> void:
	save_error = OK
	wins = 0
	selected = "preset"
	claimed.clear()
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return
	var saved_wins: Variant = config.get_value("skins", "wins", 0)
	if saved_wins is int:
		wins = clampi(saved_wins, 0, 1000000)
	var ids: Variant = config.get_value("skins", "claimed", [])
	if ids is Array:
		for id: Variant in ids:
			if id is String and not id.is_empty() and not claimed.has(id):
				claimed.append(id)
	while claimed.size() > 256:
		claimed.pop_front()
	var candidate := str(config.get_value("skins", "selected", "preset"))
	if SkinCatalog.is_unlocked(candidate, wins):
		selected = candidate

func award(round_id: String) -> Dictionary:
	if round_id.is_empty() or claimed.has(round_id):
		return {}
	claimed.append(round_id)
	if claimed.size() > 256:
		claimed.pop_front()
	wins += 1
	var unlocked: Array[String] = []
	for skin: Dictionary in SkinCatalog.ENTRIES:
		if int(skin.wins) == wins:
			unlocked.append(str(skin.id))
	save_error = save()
	return {"wins": wins, "unlocked": unlocked}

func select(id: String) -> bool:
	if not SkinCatalog.is_unlocked(id, wins):
		return false
	selected = id
	save_error = save()
	return true

func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("skins", "wins", wins)
	config.set_value("skins", "selected", selected)
	config.set_value("skins", "claimed", claimed)
	return config.save(storage_path)
