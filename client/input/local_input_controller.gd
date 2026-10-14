class_name LocalInputController
extends Node

const INPUT_INTERVAL_SECONDS: float = 0.14

var _move_timer: float = 0.0
var _last_direction: int = -1


func _process(delta: float) -> void:
	_move_timer -= delta

	var direction: int = _get_input_direction()

	if direction == -1:
		_move_timer = 0.0
		_last_direction = -1
		return

	if direction != _last_direction:
		_move_timer = 0.0

	if _move_timer > 0.0:
		_last_direction = direction
		return

	PlayerNetwork.request_move(direction)

	_move_timer = INPUT_INTERVAL_SECONDS
	_last_direction = direction


func _get_input_direction() -> int:
	if Input.is_action_pressed("move_up"):
		return MovementRules.Direction.NORTH

	if Input.is_action_pressed("move_right"):
		return MovementRules.Direction.EAST

	if Input.is_action_pressed("move_down"):
		return MovementRules.Direction.SOUTH

	if Input.is_action_pressed("move_left"):
		return MovementRules.Direction.WEST

	return -1
