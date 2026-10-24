class_name SkinProgress
extends RefCounted

# Keep the old path so the browser's existing local save can migrate once.
var storage_path := "user://arena_skins_v1.cfg"
var class_id := ClassCatalog.DEFAULT_CLASS
var _classes: Dictionary = {}
var wins: int:
	get: return wins_for_class(class_id)
var selected: String:
	get: return selection_for_class(class_id)
var claimed: Array[String] = []
var save_error := OK

func wins_for_class(id: int) -> int:
	return int(_classes.get(id, {}).get("wins", 0))

func selection_for_class(id: int) -> String:
	return str(_classes.get(id, {}).get("selected", "preset"))

func set_class(id: int) -> bool:
	if not ClassCatalog.all_ids().has(id) or id == class_id:
		return false
	class_id = id
	return true

func next_incomplete_class(except_id: int) -> int:
	for id: int in ClassCatalog.all_ids():
		if id != except_id and not SkinCatalog.is_unlocked("light", wins_for_class(id), id):
			return id
	return 0

func restore() -> void:
	save_error = OK
	class_id = ClassCatalog.DEFAULT_CLASS
	_classes.clear()
	claimed.clear()
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return
	var ids: Variant = config.get_value("skins", "claimed", [])
	if ids is Array:
		for id: Variant in ids:
			if id is String and not id.is_empty() and not claimed.has(id):
				claimed.append(id)
	while claimed.size() > 256:
		claimed.pop_front()
	if int(config.get_value("skins", "version", 1)) >= 2:
		for id: int in ClassCatalog.all_ids():
			_restore_class(config, "class_%d" % id, id)
	else:
		# v1 recorded no class identity. Preserve it once on the default Mage,
		# rather than granting all nine collections the same wins.
		_restore_class(config, "skins", ClassCatalog.DEFAULT_CLASS)
		save_error = save()

func _restore_class(config: ConfigFile, section: String, id: int) -> void:
	var saved: Variant = config.get_value(section, "wins", 0)
	var count := clampi(saved, 0, 1000000) if saved is int else 0
	var candidate := str(config.get_value(section, "selected", "preset"))
	_classes[id] = {"wins": count, "selected": candidate if SkinCatalog.is_unlocked(candidate, count, id) else "preset"}

func award(round_id: String, winning_class: int = -1) -> Dictionary:
	if winning_class == -1:
		winning_class = class_id
	if round_id.is_empty() or claimed.has(round_id) or not ClassCatalog.all_ids().has(winning_class):
		return {}
	claimed.append(round_id)
	if claimed.size() > 256:
		claimed.pop_front()
	var count := wins_for_class(winning_class) + 1
	_classes[winning_class] = {"wins": count, "selected": selection_for_class(winning_class)}
	var unlocked: Array[String] = []
	for skin: Dictionary in SkinCatalog.for_class(winning_class):
		if int(skin.wins) == count:
			unlocked.append(str(skin.id))
	var suggestion := next_incomplete_class(winning_class)
	save_error = save()
	return {"class_id": winning_class, "wins": count, "unlocked": unlocked,
		"invite_other_class": count > 5 and suggestion != 0, "suggested_class_id": suggestion,
		"all_collections_complete": count >= 5 and suggestion == 0}

func select(id: String) -> bool:
	if not SkinCatalog.is_unlocked(id, wins, class_id):
		return false
	_classes[class_id] = {"wins": wins, "selected": id}
	save_error = save()
	return true

func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("skins", "version", 2)
	config.set_value("skins", "claimed", claimed)
	for id: int in ClassCatalog.all_ids():
		config.set_value("class_%d" % id, "wins", wins_for_class(id))
		config.set_value("class_%d" % id, "selected", selection_for_class(id))
	return config.save(storage_path)
