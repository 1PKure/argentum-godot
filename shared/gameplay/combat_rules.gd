class_name CombatRules
extends RefCounted

const DEFAULT_MAX_HEALTH := 100
const DEFAULT_MAX_MANA := 100

const DEBUG_DAMAGE_AMOUNT := 10
const DEBUG_MANA_COST := 10

const BASIC_ATTACK_DAMAGE := 10
const BASIC_ATTACK_RANGE_TILES := 1
const BASIC_ATTACK_COOLDOWN_MSEC := 550 # Arena tuning; previous: 600 ms.


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


static func has_clear_shot(arena_id: String, origin: Vector2i, target: Vector2i) -> bool:
	# Bresenham traversal checks every crossed tile, including diagonal corner gaps.
	var point := origin
	var delta := Vector2i(absi(target.x - origin.x), absi(target.y - origin.y))
	var step := Vector2i(1 if target.x > origin.x else -1, 1 if target.y > origin.y else -1)
	var error := delta.x - delta.y
	while point != target:
		var previous := point
		var doubled := 2 * error
		if doubled > -delta.y:
			error -= delta.y
			point.x += step.x
		if doubled < delta.x:
			error += delta.x
			point.y += step.y
		if not ArenaData.is_walkable(arena_id, point):
			return false
		if point.x != previous.x and point.y != previous.y:
			if not ArenaData.is_walkable(arena_id, Vector2i(point.x, previous.y)) or not ArenaData.is_walkable(arena_id, Vector2i(previous.x, point.y)):
				return false
	return true
