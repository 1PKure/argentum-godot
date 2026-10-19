class_name LocalInputController
extends Node

const INPUT_INTERVAL_SECONDS: float = MovementRules.MOVE_INTERVAL_SECONDS
const MIN_REPEAT_INTERVAL_SECONDS: float = (
	(MovementRules.MOVE_INTERVAL_MSEC - MovementRules.MOVE_TIMING_TOLERANCE_MSEC)
	/ 1000.0
)

var _move_timer: float = 0.0


func _process(delta: float) -> void:
	var previous_timer := _move_timer
	_move_timer -= delta

	var direction: int = _get_input_direction()

	if direction == -1:
		# Keep the remaining cooldown across release/repress. A fresh press before
		# the server interval must not send early and postpone the next valid step.
		_move_timer = maxf(_move_timer, 0.0)
		return
	if _move_timer > 0.000001:
		return

	_send_move_request(direction)

	# Preserve the fraction of a frame instead of adding that delay to every step.
	# After a stalled/background frame, discard catch-up requests rather than
	# sending a burst of old inputs when the game resumes.
	if previous_timer <= 0.0:
		# The first request starts a new interval; time before it was sent must
		# not shorten its next repeat (notably after startup/import stutters).
		_move_timer = INPUT_INTERVAL_SECONDS
	else:
		_move_timer += INPUT_INTERVAL_SECONDS
	if _move_timer <= 0.0:
		_move_timer = INPUT_INTERVAL_SECONDS
	else:
		# At low frame rates, do not carry more catch-up than the server can accept.
		_move_timer = maxf(_move_timer, MIN_REPEAT_INTERVAL_SECONDS)


func _send_move_request(direction: int) -> void:
	PlayerNetwork.request_move(direction)


func _get_input_direction() -> int:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return -1
	if Input.is_action_pressed("move_up"):
		return MovementRules.Direction.NORTH

	if Input.is_action_pressed("move_right"):
		return MovementRules.Direction.EAST

	if Input.is_action_pressed("move_down"):
		return MovementRules.Direction.SOUTH

	if Input.is_action_pressed("move_left"):
		return MovementRules.Direction.WEST

	return -1
