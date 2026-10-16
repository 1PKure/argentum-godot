class_name ClassCatalog
extends RefCounted

const DATA_PATH := "res://assets/argentum/source/data/"
const DEFAULT_CLASS := 1
const CHANGE_PEACE_MSEC := 10000
const RANGED_RANGE := 8
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


static func physical_damage(attacker_class: int, target_class: int) -> int:
	var attack := get_profile(attacker_class)
	var defense := get_profile(target_class)
	if attack.is_empty() or defense.is_empty():
		return CombatRules.BASIC_ATTACK_DAMAGE
	return maxi(1, roundi(float(attack.physical_power) * (1.0 - float(defense.armor_percent) / 100.0)))


static func magic_damage(amount: int, caster_class: int, target_class: int) -> int:
	var caster := get_profile(caster_class)
	var target := get_profile(target_class)
	return maxi(1, roundi(amount * (1.0 + float(caster.get("magic_bonus", 0)) / 100.0) * (1.0 - float(target.get("resistance_percent", 0)) / 100.0)))


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
		entry.bindings = [1, 2, 12, 13, 0, 0, 0, 0, 0, 0] if mana_factor > 0 else [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		var weapon: Dictionary = _equipment.get(int(entry.weapon), {})
		var ammo: Dictionary = _equipment.get(int(entry.ammunition), {})
		var weapon_damage := (float(weapon.get("MinHit", 0)) + float(weapon.get("MaxHit", 0))) * 0.5
		weapon_damage += (float(ammo.get("MinHit", 0)) + float(ammo.get("MaxHit", 0))) * 0.5
		var damage_section := "MODDANOPROYECTILES" if id == 8 else "MODDANOARMAS"
		entry.physical_power = roundi((30.0 + weapon_damage * 2.0) * float(balance[damage_section][key]))
		entry.armor_percent = 0.0
		entry.resistance_percent = 4.0 # 100 resistance skill × the original 0.04 modifier.
		entry.magic_bonus = 0.0
		for slot: String in ["armor", "weapon", "helmet", "shield", "accessory"]:
			var item: Dictionary = _equipment.get(int(entry[slot]), {})
			entry.armor_percent += (float(item.get("MinDef", 0)) + float(item.get("MaxDef", 0))) * 0.5
			entry.resistance_percent += float(item.get("ResistenciaMagica", 0))
			entry.magic_bonus += float(item.get("MagicDamageBonus", 0))
		entry.armor_percent = minf(60, entry.armor_percent)
		entry.resistance_percent = minf(60, entry.resistance_percent)
		entry.body_id = int(_equipment[int(entry.armor)].get("RopajeHumano", 21))
		entry.weapon_animation = int(weapon.get("Anim", 0))
		entry.shield_animation = int(_equipment.get(int(entry.shield), {}).get("Anim", 0))
		entry.helmet_animation = int(_equipment.get(int(entry.helmet), {}).get("Anim", 0))
		_classes[id] = entry
