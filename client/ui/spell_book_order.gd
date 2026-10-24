class_name ArenaSpellBookOrder
extends RefCounted

const PATH := "user://spell_book_order.cfg"

static func section(profile: String, class_id: int) -> String:
	return "profile:%s:class:%d" % [profile, class_id]

static func load_order(profile: String, class_id: int) -> Array[int]:
	var legal := ClassCatalog.combat_book_ids(class_id)
	var result: Array[int] = []
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		var saved: Variant = config.get_value(section(profile,class_id), "order", [])
		if saved is Array:
			for value: Variant in saved:
				if value is int and value in legal and value not in result:
					result.append(value)
	for id: int in legal:
		if id not in result: result.append(id)
	return result

static func save_order(profile: String, class_id: int, order: Array[int]) -> Error:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(section(profile,class_id), "order", order)
	return config.save(PATH)
