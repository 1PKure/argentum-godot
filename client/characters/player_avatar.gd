class_name PlayerAvatar
extends Node2D

const MOVE_DURATION_SECONDS: float = 0.12
const TILE_SIZE: float = 48.0
const VISUAL_MOVEMENT_GRACE_SECONDS: float = 0.05
var is_ghost: bool
var _last_visual_direction := Vector2.DOWN
var _visual_movement_grace_timer := 0.0

const MOVE_SPEED: float = (
	TILE_SIZE
	/ MOVE_DURATION_SECONDS
)

const MOVEMENT_EPSILON: float = 0.01
const HUMAN_HEAD_COUNT := 41

const STATUS_BARS_POSITION := Vector2(
	-22.0,
	30.0
)

const TARGET_INDICATOR_POSITION := Vector2(
	0.0,
	18.0
)

const TARGET_INDICATOR_RADIUS := 18.0
const TARGET_INDICATOR_WIDTH := 2.0

const TARGET_INDICATOR_COLOR := Color(
	1.0,
	0.82,
	0.15,
	1.0
)

@onready var _player_visual: PlayerVisual = (
	$PlayerVisual
)

var peer_id: int
var grid_position: Vector2i
var display_name: String
var is_local_player: bool
var is_alive: bool

var _name_label: Label
var _status_bars: PlayerStatusBars

var _target_position: Vector2
var _is_selected := false


func _ready() -> void:
	_create_name_label()
	_create_status_bars()


func _process(delta: float) -> void:
	var movement_delta := (
		_target_position
		- position
	)

	var is_moving := (
		movement_delta.length_squared()
		> MOVEMENT_EPSILON
	)

	if is_moving:
		_last_visual_direction = (
			movement_delta
		)

		_visual_movement_grace_timer = (
			VISUAL_MOVEMENT_GRACE_SECONDS
		)

		_player_visual.set_movement(
			movement_delta,
			true
		)

		position = position.move_toward(
			_target_position,
			MOVE_SPEED * delta
		)
	else:
		position = _target_position

		if _visual_movement_grace_timer > 0.0:
			_visual_movement_grace_timer -= (
				delta
			)

			_player_visual.set_movement(
				_last_visual_direction,
				true
			)
		else:
			_player_visual.set_movement(
				_last_visual_direction,
				false
			)


func _draw() -> void:
	if not _is_selected:
		return

	draw_arc(
		TARGET_INDICATOR_POSITION,
		TARGET_INDICATOR_RADIUS,
		0.0,
		TAU,
		32,
		TARGET_INDICATOR_COLOR,
		TARGET_INDICATOR_WIDTH
	)


func setup(
	
	player_state: PlayerState,
	local_player: bool,
	world_position: Vector2
) -> void:
	peer_id = player_state.peer_id
	grid_position = player_state.grid_position
	display_name = player_state.display_name
	is_alive = player_state.is_alive
	is_ghost = player_state.is_ghost
	is_local_player = local_player
	is_alive = player_state.is_alive

	_player_visual.set_head_id(
		_get_head_id_from_peer()
	)
	
	_player_visual.set_ghost_mode(
	is_ghost
	)
	
	position = world_position
	_target_position = world_position

	if _name_label != null:
		_update_label()

	if _status_bars != null:
		_status_bars.apply_state(
			player_state
		)


func apply_server_position(
	new_grid_position: Vector2i,
	new_world_position: Vector2
) -> void:
	grid_position = new_grid_position
	_target_position = new_world_position


func apply_server_stats(
	player_state: PlayerState
) -> void:
	is_alive = player_state.is_alive
	is_ghost = player_state.is_ghost

	_player_visual.set_ghost_mode(
		is_ghost
	)

	if _status_bars != null:
		_status_bars.apply_state(
			player_state
		)

		_status_bars.visible = (
			not is_ghost
		)

	_update_label()


func set_selected(selected: bool) -> void:
	if _is_selected == selected:
		return

	_is_selected = selected

	queue_redraw()


func _get_head_id_from_peer() -> int:
	var peer_hash := absi(
		str(peer_id).hash()
	)

	return (
		peer_hash
		% HUMAN_HEAD_COUNT
	) + 1


func _create_name_label() -> void:
	_name_label = Label.new()

	_name_label.position = Vector2(
		-70.0,
		-74.0
	)

	_name_label.size = Vector2(
		140.0,
		24.0
	)

	_name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	add_child(_name_label)

	_update_label()


func _create_status_bars() -> void:
	_status_bars = PlayerStatusBars.new()

	_status_bars.position = (
		STATUS_BARS_POSITION
	)

	add_child(_status_bars)


func _update_label() -> void:
	if _name_label == null:
		return

	var final_name := display_name

	if is_local_player:
		final_name += " (YOU)"

	if is_ghost:
		final_name += " [GHOST]"

	_name_label.text = final_name
