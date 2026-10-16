class_name CombatRules
extends RefCounted

const DEFAULT_MAX_HEALTH := 100
const DEFAULT_MAX_MANA := 100

const DEBUG_DAMAGE_AMOUNT := 10
const DEBUG_MANA_COST := 10

const BASIC_ATTACK_DAMAGE := 10
const BASIC_ATTACK_RANGE_TILES := 1
const BASIC_ATTACK_COOLDOWN_MSEC := 650 # Arena tuning; previous profile: 750 ms.


static func is_in_basic_attack_range(
	attacker_position: Vector2i,
	target_position: Vector2i
) -> bool:
	var delta := (
		target_position
		- attacker_position
	)

	var tile_distance := maxi(
		abs(delta.x),
		abs(delta.y)
	)

	return (
		tile_distance > 0
		and tile_distance <= BASIC_ATTACK_RANGE_TILES
	)
