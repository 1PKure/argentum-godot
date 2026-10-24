class_name ArenaData
extends RefCounted

const FOREST := "forest"
const DESERT := "desert"
const LAVA := "lava"
const DUEL_ROOM := "duel_room"
const DEFAULT_ARENA_ID := FOREST
const IDS: Array[String] = [FOREST, DESERT, LAVA, DUEL_ROOM]
const ARENAS := {
	FOREST: {
		"display_name":"Bosque", "implemented":true,
		"description":"Césped y árboles. Un pasillo central despejado para el duelo.",
		"ground_color":Color("527441"), "exterior":Color("253526"), "accent":Color("b9ba75"), "obstacle_kind":"tree",
		"ground_grh_ids":[468,469,470,471,472,473,474,475,476,477,478,479,480,481,482,483],
		"blocked_cells":[], "scenery_cells":[Vector2i(2,2),Vector2i(17,2),Vector2i(2,9),Vector2i(17,9)],
		"props":[{"grh_id":466,"grid_position":Vector2i(2,2)},{"grh_id":467,"grid_position":Vector2i(17,2)},{"grh_id":484,"grid_position":Vector2i(2,9)},{"grh_id":484,"grid_position":Vector2i(17,9)}],
		"decorations":[Vector2i(-2,1),Vector2i(21,1),Vector2i(-1,10),Vector2i(20,10)],
		"spawn_points":[Vector2i(4,5),Vector2i(15,5)]
	},
	DESERT: {
		"display_name":"Desierto", "implemented":true,
		"description":"Arena cálida, cactus y rocas. Sin penalización de movimiento.",
		"ground_color":Color("b99b60"), "exterior":Color("715e3d"), "accent":Color("f0d99a"), "obstacle_kind":"cactus",
		"ground_grh_ids":[], "props":[],
		"blocked_cells":[], "scenery_cells":[Vector2i(3,2),Vector2i(16,2),Vector2i(3,9),Vector2i(16,9)],
		"decorations":[Vector2i(-2,3),Vector2i(21,3),Vector2i(2,-2),Vector2i(17,13)],
		"spawn_points":[Vector2i(4,5),Vector2i(15,5)]
	},
	LAVA: {
		"display_name":"Lava", "implemented":true,
		"description":"Obsidiana y basalto sobre lava animada. El exterior es decorativo y no causa daño.",
		"ground_color":Color("39323b"), "exterior":Color("511c1b"), "accent":Color("e68a4d"), "obstacle_kind":"basalt",
		"ground_grh_ids":[], "props":[],
		"blocked_cells":[], "scenery_cells":[Vector2i(2,3),Vector2i(17,3),Vector2i(2,8),Vector2i(17,8)],
		"decorations":[Vector2i(-2,2),Vector2i(21,2),Vector2i(3,-2),Vector2i(16,13)],
		"spawn_points":[Vector2i(4,5),Vector2i(15,5)]
	},
	DUEL_ROOM: {
		"display_name":"Sala de Duelos", "implemented":true,
		"description":"Piedra, columnas y antorchas. Espacio simétrico de entrenamiento.",
		"ground_color":Color("525962"), "exterior":Color("22262c"), "accent":Color("d6b66a"), "obstacle_kind":"pillar",
		"ground_grh_ids":[], "props":[],
		"blocked_cells":[], "scenery_cells":[Vector2i(2,2),Vector2i(17,2),Vector2i(2,9),Vector2i(17,9)],
		"decorations":[Vector2i(4,-2),Vector2i(15,-2),Vector2i(4,13),Vector2i(15,13)],
		"spawn_points":[Vector2i(4,5),Vector2i(15,5)]
	}
}

static func has_arena(id: String) -> bool:
	return ARENAS.has(id)

static func is_implemented(id: String) -> bool:
	return ARENAS.has(id) and bool(ARENAS[id].implemented)

static func get_definition(id: String) -> Dictionary:
	return ARENAS.get(id,ARENAS[DEFAULT_ARENA_ID]).duplicate(true)

static func get_display_name(id: String) -> String:
	return str(ARENAS.get(id,ARENAS[DEFAULT_ARENA_ID]).display_name)

static func get_ground_grh_ids(id: String) -> Array[int]:
	var result: Array[int] = []
	result.assign(ARENAS.get(id,ARENAS[DEFAULT_ARENA_ID]).ground_grh_ids)
	return result

static func get_props(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(get_definition(id).props)
	return result

static func get_spawn_points(id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(get_definition(id).spawn_points)
	return result

static func is_cell_blocked(id: String, cell: Vector2i) -> bool:
	return ARENAS.get(id,ARENAS[DEFAULT_ARENA_ID]).blocked_cells.has(cell)

static func is_walkable(id: String, cell: Vector2i) -> bool:
	return is_implemented(id) and MovementRules.is_inside_bounds(cell) and not is_cell_blocked(id,cell)
