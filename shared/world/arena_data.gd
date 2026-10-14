class_name ArenaData
extends RefCounted

const FOREST: String = "forest"
const DESERT: String = "desert"
const DUEL_ROOM: String = "duel_room"

const DEFAULT_ARENA_ID: String = FOREST


const ARENAS: Dictionary = {
	FOREST: {
		"display_name": "Forest",
		"implemented": true,

		"ground_grh_ids": [
			468,
			469,
			470,
			471,
			472,
			473,
			474,
			475,
			476,
			477,
			478,
			479,
			480,
			481,
			482,
			483
		],

		"blocked_cells": [
			Vector2i(2, 2),
			Vector2i(17, 2),
			Vector2i(2, 9)
		],

		"props": [
			{
				"grh_id": 466,
				"grid_position": Vector2i(2, 2)
			},
			{
				"grh_id": 467,
				"grid_position": Vector2i(17, 2)
			},
			{
				"grh_id": 484,
				"grid_position": Vector2i(2, 9)
			}
		],

		"spawn_points": [
			Vector2i(4, 5),
			Vector2i(15, 5)
		]
	},

	DESERT: {
		"display_name": "Desert",
		"implemented": false,
		"ground_grh_ids": [],
		"blocked_cells": [],
		"props": [],
		"spawn_points": []
	},

	DUEL_ROOM: {
		"display_name": "Duel Room",
		"implemented": false,
		"ground_grh_ids": [],
		"blocked_cells": [],
		"props": [],
		"spawn_points": []
	}
}


static func has_arena(
	arena_id: String
) -> bool:
	return ARENAS.has(
		arena_id
	)


static func is_implemented(
	arena_id: String
) -> bool:
	if not ARENAS.has(
		arena_id
	):
		return false

	var definition: Dictionary = (
		ARENAS[arena_id]
	)

	return bool(
		definition.get(
			"implemented",
			false
		)
	)


static func get_definition(
	arena_id: String
) -> Dictionary:
	if ARENAS.has(
		arena_id
	):
		return ARENAS[
			arena_id
		]

	return ARENAS[
		DEFAULT_ARENA_ID
	]


static func get_display_name(
	arena_id: String
) -> String:
	var definition: Dictionary = (
		get_definition(
			arena_id
		)
	)

	return str(
		definition.get(
			"display_name",
			"Unknown Arena"
		)
	)


static func get_ground_grh_ids(
	arena_id: String
) -> Array[int]:
	var result: Array[int] = []

	var definition: Dictionary = (
		get_definition(
			arena_id
		)
	)

	var values: Array = (
		definition.get(
			"ground_grh_ids",
			[]
		)
	)

	for value in values:
		result.append(
			int(value)
		)

	return result


static func get_props(
	arena_id: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	var definition: Dictionary = (
		get_definition(
			arena_id
		)
	)

	var values: Array = (
		definition.get(
			"props",
			[]
		)
	)

	for value in values:
		if value is Dictionary:
			result.append(
				value
			)

	return result


static func get_spawn_points(
	arena_id: String
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	var definition: Dictionary = (
		get_definition(
			arena_id
		)
	)

	var values: Array = (
		definition.get(
			"spawn_points",
			[]
		)
	)

	for value in values:
		if value is Vector2i:
			result.append(
				value
			)

	return result


static func is_cell_blocked(
	arena_id: String,
	position: Vector2i
) -> bool:
	var definition: Dictionary = (
		get_definition(
			arena_id
		)
	)

	var blocked_cells: Array = (
		definition.get(
			"blocked_cells",
			[]
		)
	)

	return blocked_cells.has(
		position
	)


static func is_walkable(
	arena_id: String,
	position: Vector2i
) -> bool:
	return (
		MovementRules.is_inside_bounds(
			position
		)
		and not is_cell_blocked(
			arena_id,
			position
		)
	)
