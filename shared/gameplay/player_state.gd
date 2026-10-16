class_name PlayerState
extends RefCounted

var peer_id: int
var display_name: String
var class_id := ClassCatalog.DEFAULT_CLASS
var grid_position: Vector2i

var facing_direction: int

var max_health: int
var current_health: int

var max_mana: int
var current_mana: int

var is_alive: bool
var is_meditating := false
var active_effects: Array[String] = []
var is_ghost: bool:
	get:
		return not is_alive


func _init(
	p_peer_id: int = 0,
	p_display_name: String = "",
	p_grid_position: Vector2i = Vector2i.ZERO,
	p_facing_direction: int = MovementRules.Direction.SOUTH,
	p_max_health: int = CombatRules.DEFAULT_MAX_HEALTH,
	p_current_health: int = CombatRules.DEFAULT_MAX_HEALTH,
	p_max_mana: int = CombatRules.DEFAULT_MAX_MANA,
	p_current_mana: int = CombatRules.DEFAULT_MAX_MANA,
	p_is_alive: bool = true,
) -> void:
	peer_id = p_peer_id
	display_name = p_display_name
	grid_position = p_grid_position

	facing_direction = p_facing_direction

	max_health = p_max_health
	current_health = p_current_health

	max_mana = p_max_mana
	current_mana = p_current_mana

	is_alive = p_is_alive


func apply_damage(amount: int) -> bool:
	if amount <= 0:
		return false

	if not is_alive:
		return false

	current_health = maxi(
		current_health - amount,
		0
	)
	is_meditating = false

	if current_health <= 0:
		current_health = 0
		is_alive = false

	return true


func restore_health(amount: int) -> bool:
	if amount <= 0:
		return false

	if not is_alive:
		return false

	current_health = mini(
		current_health + amount,
		max_health
	)

	return true


func spend_mana(amount: int) -> bool:
	if amount <= 0:
		return false

	if not is_alive:
		return false

	if current_mana < amount:
		return false

	current_mana -= amount

	return true


func restore_mana(amount: int) -> bool:
	if amount <= 0:
		return false

	if not is_alive:
		return false

	current_mana = mini(
		current_mana + amount,
		max_mana
	)

	return true


func to_dictionary() -> Dictionary:
	return {
		"peer_id": peer_id,
		"display_name": display_name,
		"class_id": class_id,
		"grid_x": grid_position.x,
		"grid_y": grid_position.y,
		"facing_direction": facing_direction,
		"max_health": max_health,
		"current_health": current_health,
		"max_mana": max_mana,
		"current_mana": current_mana,
		"is_alive": is_alive,
		"is_ghost": is_ghost,
		"is_meditating": is_meditating,
		"active_effects": active_effects.duplicate(),
	}


static func from_dictionary(
	data: Dictionary
) -> PlayerState:
	var state := PlayerState.new(
		int(
			data.get(
				"peer_id",
				0
			)
		),
		str(
			data.get(
				"display_name",
				"Unknown"
			)
		),
		Vector2i(
			int(
				data.get(
					"grid_x",
					0
				)
			),
			int(
				data.get(
					"grid_y",
					0
				)
			)
		),
		int(
			data.get(
				"facing_direction",
				MovementRules.Direction.SOUTH
			)
		),
		int(
			data.get(
				"max_health",
				CombatRules.DEFAULT_MAX_HEALTH
			)
		),
		int(
			data.get(
				"current_health",
				CombatRules.DEFAULT_MAX_HEALTH
			)
		),
		int(
			data.get(
				"max_mana",
				CombatRules.DEFAULT_MAX_MANA
			)
		),
		int(
			data.get(
				"current_mana",
				CombatRules.DEFAULT_MAX_MANA
			)
		),
		bool(
			data.get(
				"is_alive",
				true
			)
		),
	)
	state.is_meditating = bool(data.get("is_meditating", false))
	state.class_id = int(data.get("class_id", ClassCatalog.DEFAULT_CLASS))
	state.active_effects.assign(data.get("active_effects", []))
	return state
