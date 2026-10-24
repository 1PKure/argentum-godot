class_name ArenaIcons
extends RefCounted

const ROOT := "res://assets/argentum/custom/icons/"
static var _cache: Dictionary = {}

static func named(id: String) -> Texture2D:
	if not _cache.has(id): _cache[id] = load(ROOT+id+".svg")
	return _cache[id]

static func potion(action: String) -> Texture2D:
	return named("health" if action == "health_potion" else "mana")

static func spell(id: int, class_id: int = 1) -> Texture2D:
	if id == ClassCatalog.ATTACK_BINDING: return named("bow" if class_id == 8 else "sword")
	var data := SpellCatalog.get_spell(id)
	if data.is_empty(): return null
	# Distinct silhouettes retain each spell's own visual identity, including
	# spells from the same family. Potions keep their approved artwork.
	var key := "spell_%d" % id
	if ResourceLoader.exists(ROOT + key + ".svg"): return named(key)
	return named("magic")
