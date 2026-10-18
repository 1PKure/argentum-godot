class_name PlayerAvatar
extends Node2D

const MOVE_DURATION_SECONDS: float = MovementRules.MOVE_INTERVAL_SECONDS
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
const EFFECT_FOOT_POSITION := Vector2(0, 30)
const EFFECT_Z_INDEX := 30
const OVERHEAD_Z_INDEX := 40
const MEDITATION_SCALE := 1.05 # 30% smaller than the previous 1.5 scale.

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
var _meditation_fx: AnimatedSprite2D
var _is_meditating := false
var _effect_labels: Array[String] = []

var _target_position: Vector2
var _movement_waypoints: Array[Vector2] = []
var _is_selected := false
var _move_speed := MOVE_SPEED


func _ready() -> void:
	_create_name_label()
	_create_status_bars()


func _process(delta: float) -> void:
	var remaining_distance := _move_speed * maxf(delta, 0.0)
	var moved_this_frame := false
	# Preserve each confirmed turn. Carry unused frame time to the next segment
	# instead of cutting diagonally toward the newest received grid position.
	while not _movement_waypoints.is_empty():
		var waypoint: Vector2 = _movement_waypoints[0]
		var movement_delta := waypoint - position
		var distance := movement_delta.length()
		if distance <= MOVEMENT_EPSILON:
			position = waypoint
			_movement_waypoints.pop_front()
			continue
		if remaining_distance <= 0.0:
			break
		_last_visual_direction = movement_delta
		moved_this_frame = true
		var step := minf(distance, remaining_distance)
		position += movement_delta / distance * step
		remaining_distance -= step
		if step >= distance - MOVEMENT_EPSILON:
			position = waypoint
			_movement_waypoints.pop_front()

	if moved_this_frame:
		_visual_movement_grace_timer = VISUAL_MOVEMENT_GRACE_SECONDS
		_player_visual.set_movement(_last_visual_direction, true)
	else:
		_visual_movement_grace_timer = maxf(_visual_movement_grace_timer - delta, 0.0)
		_player_visual.set_movement(
			_last_visual_direction,
			_visual_movement_grace_timer > 0.0
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
	_apply_move_speed(player_state)
	is_alive = player_state.is_alive
	_apply_effect_presentation(player_state)
	_player_visual.set_loadout(player_state.class_id, player_state.equipped_items)

	_player_visual.set_head_id(
		_get_head_id_from_peer()
	)
	
	_player_visual.set_ghost_mode(
	is_ghost
	)
	
	position = world_position
	_target_position = world_position
	_movement_waypoints.clear()

	if _name_label != null:
		_update_label()

	if _status_bars != null:
		_status_bars.apply_state(
			player_state
		)
		_status_bars.visible = not is_ghost


func apply_server_position(
	new_grid_position: Vector2i,
	new_world_position: Vector2
) -> void:
	grid_position = new_grid_position
	if not new_world_position.is_equal_approx(_target_position):
		_movement_waypoints.append(new_world_position)
	_target_position = new_world_position


func apply_server_stats(
	player_state: PlayerState
) -> void:
	_apply_move_speed(player_state)
	is_alive = player_state.is_alive
	is_ghost = player_state.is_ghost
	_apply_effect_presentation(player_state)
	_player_visual.set_loadout(player_state.class_id, player_state.equipped_items)
	if _movement_waypoints.is_empty():
		_last_visual_direction = Vector2(MovementRules.get_offset(player_state.facing_direction))
		_player_visual.set_movement(_last_visual_direction, false)

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


func _apply_move_speed(state: PlayerState) -> void:
	_move_speed = TILE_SIZE * 1000.0 / MovementRules.PRACTICE_BOT_MOVE_INTERVAL_MSEC if state.is_bot else MOVE_SPEED


func _apply_effect_presentation(state: PlayerState) -> void:
	_is_meditating = state.is_meditating
	_effect_labels.assign(state.active_effects)
	if _is_meditating and _meditation_fx == null:
		# Public MeditationLevelMax uses FX120; lower-level FX153 is missing
		# from the same public FX table, so this test profile uses the valid FX.
		_meditation_fx = AOResources.create_fx_sprite(120)
		if _meditation_fx != null:
			_meditation_fx.scale = Vector2.ONE * MEDITATION_SCALE
			_meditation_fx.position = EFFECT_FOOT_POSITION + Vector2(_meditation_fx.get_meta("source_offset", Vector2.ZERO)) * MEDITATION_SCALE
			_meditation_fx.z_index = EFFECT_Z_INDEX
			_meditation_fx.modulate.a = 0.72
			add_child(_meditation_fx)
			_meditation_fx.play()
	if _meditation_fx != null:
		_meditation_fx.visible = _is_meditating and state.is_alive


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
	_name_label.z_index = OVERHEAD_Z_INDEX

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
	_status_bars.z_index = OVERHEAD_Z_INDEX

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
	elif _is_meditating:
		final_name += " · Meditando"
	elif not _effect_labels.is_empty():
		final_name += " · " + str(_effect_labels[0])

	_name_label.text = final_name
