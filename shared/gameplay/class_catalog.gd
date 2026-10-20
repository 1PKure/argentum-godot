class_name ClassCatalog
extends RefCounted

const DATA_PATH := "res://assets/argentum/source/data/"
const DEFAULT_CLASS := 1
const RANGED_RANGE := 8
const EQUIPMENT_SLOTS := ["armor", "weapon", "helmet", "shield", "accessory", "ammunition"]
const ATTACK_BINDING := -1
const MACRO_VERSION := 2
# Curated combat presentation. Keep imported DAT/rules intact for reference and
# regression fixtures; beginner spells no longer appear in the arena book/macros.
const COMBAT_BOOK_ORDER := [25,27,51,59,31,53,41,113,26,29,350,11,269,242,243,263,112,122,131,141,54,55,132,133,28,268,4]
const PRESET_LEVEL := 50
const PRESET_STRENGTH := 28 # Arena-ready attribute; explicit PvP tuning, not a racial base.
const PRESET_CONSTITUTION := 20 # Human: 18 + 2.
const PRESET_INTELLIGENCE := 18
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


static func combat_book_ids(class_id: int) -> Array[int]:
	var result: Array[int] = []
	for spell_id: int in COMBAT_BOOK_ORDER:
		if can_cast(class_id,spell_id): result.append(spell_id)
	return result


static func can_assign_spell(class_id: int, spell_id: int) -> bool:
	return COMBAT_BOOK_ORDER.has(spell_id) and can_cast(class_id,spell_id)


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
	return maxi(1, roundi(float(attack.physical_power) - float(defense.armor_points)))


static func physical_damage_range(attacker_class: int, target_class: int, attacker_equipment: Variant = null, target_equipment: Variant = null) -> Vector2i:
	var attack := get_profile(attacker_class) if attacker_equipment == null else get_equipped_profile(attacker_class, attacker_equipment)
	var defense := get_profile(target_class) if target_equipment == null else get_equipped_profile(target_class, target_equipment)
	return Vector2i(maxi(1, roundi(float(attack.physical_min) - float(defense.armor_points))), maxi(1, roundi(float(attack.physical_max) - float(defense.armor_points))))


static func roll_physical_damage(attacker_class: int, target_class: int, attacker_equipment: Dictionary, target_equipment: Dictionary) -> int:
	var damage_range := physical_damage_range(attacker_class, target_class, attacker_equipment, target_equipment)
	return randi_range(damage_range.x, damage_range.y)


static func magic_damage(amount: int, caster_class: int, target_class: int, caster_equipment: Variant = null, target_equipment: Variant = null, scale_by_level: bool = true, ignore_resistance: bool = false) -> int:
	var caster := get_profile(caster_class) if caster_equipment == null else get_equipped_profile(caster_class, caster_equipment)
	var target := get_profile(target_class) if target_equipment == null else get_equipped_profile(target_class, target_equipment)
	# AO20 modHechizos.HechizoPropUsuario: +3% per level before equipment.
	# EOT tick powers use their own DAT values, without this direct-hit bonus.
	var level_bonus := 1.0 + 0.03 * float(caster.level) if scale_by_level else 1.0
	var resistance := 0.0 if ignore_resistance else float(target.get("resistance_percent", 0))
	return maxi(1, roundi(amount * level_bonus * (1.0 + float(caster.get("magic_bonus", 0)) / 100.0) * (1.0 - resistance / 100.0)))


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
		# AO20 UserMod.GetMaxHp / GetMaxMana: fixed human level-50 mean profile.
		entry.level = PRESET_LEVEL
		entry.race = "Humano"
		entry.strength = PRESET_STRENGTH
		entry.constitution = PRESET_CONSTITUTION
		entry.intelligence = PRESET_INTELLIGENCE
		entry.max_health = roundi((float(balance.MODVIDA[key]) - (21.0 - PRESET_CONSTITUTION) * 0.5) * (PRESET_LEVEL - 1) + PRESET_CONSTITUTION)
		entry.max_mana = roundi(PRESET_INTELLIGENCE * float(balance.MANA_INICIAL[key]) + mana_factor * PRESET_INTELLIGENCE * (PRESET_LEVEL - 1))
		entry.base_hit = 35.0 * float(balance.GOLPE_PRE_36[key]) + (PRESET_LEVEL - 36) * float(balance.GOLPE_POST_36[key])
		entry.wrestling_modifier = float(balance.MODDANOWRESTLING[key])
		entry.resistance_skill = 100
		entry.base_resistance = 100.0 * float(balance.MODRESISTENCIAMAGICA[key]) + float(entry.resistance_skill) * float(balance.EXTRA.MagicResistanceSkillProtectionModifier)
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
			entry.bindings = [25, 27, 51 if spells.has(51) else (59 if spells.has(59) else ATTACK_BINDING), 31, 53 if spells.has(53) else (113 if spells.has(113) else 0), 26, 11, 269 if spells.has(269) else 268, 112 if spells.has(112) else (263 if spells.has(263) else 29), 41 if spells.has(41) else (242 if spells.has(242) else 0)]
			for index in range(entry.bindings.size()):
				if entry.bindings[index] != ATTACK_BINDING and not spells.has(entry.bindings[index]):
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
	var minimum := float(weapon.get("MinHit", 0))
	var maximum := float(weapon.get("MaxHit", 0))
	if int(profile.id) == 8 and not weapon.is_empty():
		minimum += float(ammo.get("MinHit", 0))
		maximum += float(ammo.get("MaxHit", 0))
	var modifier := float(profile.damage_modifier)
	if weapon.is_empty() or int(weapon.get("WeaponType", 0)) == 8:
		modifier = float(profile.wrestling_modifier)
	# AO20 SistemaCombate.GetUserDamageWithItem; neutral torso hit, no crits.
	var strength_bonus := maximum * 0.2 * maxf(0.0, float(profile.strength) - 15.0)
	profile.physical_min = roundi((3.0 * minimum + strength_bonus + float(profile.base_hit) + 1.0) * modifier)
	profile.physical_max = roundi((3.0 * maximum + strength_bonus + float(profile.base_hit) + 2.0) * modifier)
	profile.physical_power = roundi((float(profile.physical_min) + float(profile.physical_max)) * 0.5)
	profile.armor_points = 0.0
	profile.resistance_percent = float(profile.base_resistance)
	profile.magic_bonus = 0.0
	for slot: String in EQUIPMENT_SLOTS:
		var item: Dictionary = _equipment.get(int(equipped.get(slot, 0)), {})
		# Armor and shield absorb torso damage. Helmet is for future head hits.
		if slot in ["armor", "shield"]:
			profile.armor_points += (float(item.get("MinDef", 0)) + float(item.get("MaxDef", 0))) * 0.5
		profile.resistance_percent += float(item.get("ResistenciaMagica", 0))
		profile.magic_bonus += float(item.get("MagicDamageBonus", 0))
	profile.resistance_percent = minf(60, profile.resistance_percent)
	profile.body_id = int(_equipment.get(int(equipped.get("armor", 0)), {}).get("RopajeHumano", 21))
	profile.weapon_animation = int(weapon.get("Anim", 0))
	profile.shield_animation = int(_equipment.get(int(equipped.get("shield", 0)), {}).get("Anim", 0))
	profile.helmet_animation = int(_equipment.get(int(equipped.get("helmet", 0)), {}).get("Anim", 0))
	return profile
