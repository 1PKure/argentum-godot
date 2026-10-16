class_name ClassCatalog
extends RefCounted

const DATA_PATH := "res://assets/argentum/source/data/"
const DEFAULT_CLASS := 1
const RANGED_RANGE := 8
const EQUIPMENT_SLOTS := ["armor", "weapon", "helmet", "shield", "accessory", "ammunition"]
const ATTACK_BINDING := -1
const MACRO_VERSION := 2
static var _classes: Dictionary = {}
static var _equipment: Dictionary = {}


static func all_ids() -> Array[int]:
	_ensure_loaded()
	var ids: Array[int] = []
	ids.assign(_classes.keys())
	return ids


static func get_profile(id: int) -> Dictionary:
	_ensure_loaded()
	return _classes.get(id, {}).duplicate(true)


static func get_item(id: int) -> Dictionary:
	_ensure_loaded()
	return _equipment.get(id, {}).duplicate(true)


static func can_cast(class_id: int, spell_id: int) -> bool:
	var profile := get_profile(class_id)
	return not profile.is_empty() and profile.spells.has(spell_id) and SpellCatalog.is_available(spell_id)


static func default_equipment(class_id: int) -> Dictionary:
	var profile := get_profile(class_id)
	var equipped: Dictionary = {}
	for slot: String in EQUIPMENT_SLOTS:
		if int(profile.get(slot, 0)) > 0:
			equipped[slot] = int(profile[slot])
	return equipped


static func get_equipped_profile(class_id: int, equipped: Dictionary) -> Dictionary:
	var profile := get_profile(class_id)
	if profile.is_empty():
		return {}
	return _calculate_equipment(profile, equipped)


static func physical_damage(attacker_class: int, target_class: int, attacker_equipment: Variant = null, target_equipment: Variant = null) -> int:
	var attack := get_profile(attacker_class) if attacker_equipment == null else get_equipped_profile(attacker_class, attacker_equipment)
	var defense := get_profile(target_class) if target_equipment == null else get_equipped_profile(target_class, target_equipment)
	if attack.is_empty() or defense.is_empty():
		return CombatRules.BASIC_ATTACK_DAMAGE
	return maxi(1, roundi(float(attack.physical_power) * (1.0 - float(defense.armor_percent) / 100.0)))


static func magic_damage(amount: int, caster_class: int, target_class: int, caster_equipment: Variant = null, target_equipment: Variant = null) -> int:
	var caster := get_profile(caster_class) if caster_equipment == null else get_equipped_profile(caster_class, caster_equipment)
	var target := get_profile(target_class) if target_equipment == null else get_equipped_profile(target_class, target_equipment)
	return maxi(1, roundi(amount * (1.0 + float(caster.get("magic_bonus", 0)) / 100.0) * (1.0 - float(target.get("resistance_percent", 0)) / 100.0)))


static func equipment_slot(class_id: int, item_id: int) -> String:
	var profile := get_profile(class_id)
	for slot: String in EQUIPMENT_SLOTS:
		if int(profile.get(slot, 0)) == item_id and item_id > 0:
			return slot
	return ""


static func _ensure_loaded() -> void:
	if not _classes.is_empty():
		return
	var equipment := AODataFile.read_sections(DATA_PATH + "arena_equipment.ini")
	for section: String in equipment:
		var id := int(section.trim_prefix("OBJ"))
		if id > 0:
			_equipment[id] = equipment[section]
	var balance := AODataFile.read_sections(DATA_PATH + "Balance.dat")
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH + "arena_classes.json"))
	var common := [1, 2, 12, 13, 3, 11, 25, 26, 27, 29, 31, 43, 268]
	for entry: Dictionary in entries:
		var id := int(entry.id)
		var key := str(entry.key)
		var mana_factor := float(balance.MULT_MANA[key])
		# Normalize the existing arena mage (500 HP / 3000 MP) using the original
		# class ratios. These are fixed test profiles, not AO20 level progression.
		entry.max_health = roundi(500.0 * float(balance.MODVIDA[key]) / 7.5)
		entry.max_mana = roundi(3000.0 * mana_factor / 2.65)
		entry.range = RANGED_RANGE if id == 8 else 1
		var spells: Array = []
		if mana_factor > 0:
			spells = common.duplicate()
			if id == 1:
				spells = SpellCatalog.loadout_ids()
			elif id == 2:
				spells.append_array([50, 51, 53, 112, 122, 131, 132, 133, 242, 263, 269])
			elif id == 5:
				spells.append_array([50, 51, 53, 112, 242, 263, 269])
			elif id == 6:
				spells.append_array([59, 113, 242, 243, 263, 269, 350])
			spells.erase(247) # NPC projectile entry; bow attacks use the physical rules.
			for index in range(spells.size() - 1, -1, -1):
				if int(SpellCatalog.get_spell(spells[index]).mana) > int(entry.max_mana):
					spells.remove_at(index)
		entry.spells = spells
		entry.bindings = [0, 0, ATTACK_BINDING, 0, 0, 0, 0, 0, 0, 0]
		if mana_factor > 0:
			entry.bindings = [25, 27, 51 if spells.has(51) else 3, 31, 53, 26, 11, 269 if spells.has(269) else 268, 12, 0]
			for index in range(entry.bindings.size()):
				if not spells.has(entry.bindings[index]):
					entry.bindings[index] = 0
		entry.damage_modifier = float(balance["MODDANOPROYECTILES" if id == 8 else "MODDANOARMAS"][key])
		var equipped: Dictionary = {}
		for slot: String in EQUIPMENT_SLOTS:
			if int(entry[slot]) > 0:
				equipped[slot] = int(entry[slot])
		_classes[id] = _calculate_equipment(entry, equipped)


static func _calculate_equipment(profile: Dictionary, equipped: Dictionary) -> Dictionary:
	var weapon: Dictionary = _equipment.get(int(equipped.get("weapon", 0)), {})
	var ammo: Dictionary = _equipment.get(int(equipped.get("ammunition", 0)), {})
	var weapon_damage := (float(weapon.get("MinHit", 0)) + float(weapon.get("MaxHit", 0))) * 0.5
	weapon_damage += (float(ammo.get("MinHit", 0)) + float(ammo.get("MaxHit", 0))) * 0.5
	profile.physical_power = roundi((30.0 + weapon_damage * 2.0) * float(profile.damage_modifier))
	profile.armor_percent = 0.0
	profile.resistance_percent = 4.0
	profile.magic_bonus = 0.0
	for slot: String in EQUIPMENT_SLOTS:
		var item: Dictionary = _equipment.get(int(equipped.get(slot, 0)), {})
		profile.armor_percent += (float(item.get("MinDef", 0)) + float(item.get("MaxDef", 0))) * 0.5
		profile.resistance_percent += float(item.get("ResistenciaMagica", 0))
		profile.magic_bonus += float(item.get("MagicDamageBonus", 0))
	profile.armor_percent = minf(60, profile.armor_percent)
	profile.resistance_percent = minf(60, profile.resistance_percent)
	profile.body_id = int(_equipment.get(int(equipped.get("armor", 0)), {}).get("RopajeHumano", 21))
	profile.weapon_animation = int(weapon.get("Anim", 0))
	profile.shield_animation = int(_equipment.get(int(equipped.get("shield", 0)), {}).get("Anim", 0))
	profile.helmet_animation = int(_equipment.get(int(equipped.get("helmet", 0)), {}).get("Anim", 0))
	return profile
