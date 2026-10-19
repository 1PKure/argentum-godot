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
	var text := str(data.name).to_lower()
	if id == 25 or "inmov" in text: return named("paralyze")
	if id == 27 or "remover" in text or "curar veneno" in text: return named("remove")
	if str(data.effect) == "healing": return named("heal")
	if "apocal" in text: return named("apocalypse")
	if "descarga" in text or "rayo" in text or "eléctr" in text: return named("lightning")
	if "fuego" in text or "llama" in text or "aliento" in text: return named("fire")
	if "hielo" in text or "frío" in text: return named("ice")
	if "veneno" in text or "putref" in text: return named("poison")
	if "prote" in text or "fuerza" in text or "resisten" in text: return named("shield")
	if "luz" in text or "resuc" in text: return named("light")
	return named("magic")
