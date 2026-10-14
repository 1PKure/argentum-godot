class_name PlayerState
extends RefCounted

var peer_id: int
var display_name: String
var grid_position: Vector2i

var facing_direction: int

var max_health: int
var current_health: int

var max_mana: int
var current_mana: int

var is_alive: bool
var is_ghost: bool


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
	p_is_ghost: bool = false
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
	is_ghost = p_is_ghost


func apply_damage(amount: int) -> bool:
	if amount <= 0:
		return false

	if not is_alive:
		return false

	current_health = maxi(
		current_health - amount,
		0
	)

	if current_health <= 0:
		current_health = 0
		is_alive = false
		is_ghost = true

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
		"grid_x": grid_position.x,
		"grid_y": grid_position.y,
		"facing_direction": facing_direction,
		"max_health": max_health,
		"current_health": current_health,
		"max_mana": max_mana,
		"current_mana": current_mana,
		"is_alive": is_alive,
		"is_ghost": is_ghost
	}


static func from_dictionary(
	data: Dictionary
) -> PlayerState:
	return PlayerState.new(
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
		bool(
			data.get(
				"is_ghost",
				false
			)
		)
	)
