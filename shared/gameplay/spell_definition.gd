class_name SpellDefinition
extends Resource

enum Effect { DAMAGE, HEAL }

@export var id: int
@export var display_name: String
@export var mana_cost: int
@export var range_tiles: int
@export var cooldown_msec: int
@export var amount: int
@export var effect: Effect = Effect.DAMAGE
@export var can_target_self := false

