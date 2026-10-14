class_name SpellCatalog
extends RefCounted

const DAMAGE := 1
const HEAL := 2
const SPELLS := {
	DAMAGE: preload("res://shared/gameplay/spells/descarga.tres"),
	HEAL: preload("res://shared/gameplay/spells/curar_heridas.tres"),
}


static func get_spell(spell_id: int) -> SpellDefinition:
	return SPELLS.get(spell_id)

