class_name PlayerStatusBars
extends Node2D

const BAR_WIDTH := 44.0

const HEALTH_BAR_HEIGHT := 5.0
const MANA_BAR_HEIGHT := 4.0

const BAR_GAP := 2.0

const BACKGROUND_COLOR := Color(
	0.08,
	0.08,
	0.08,
	0.9
)

const BORDER_COLOR := Color(
	0.02,
	0.02,
	0.02,
	1.0
)

const HEALTH_COLOR := Color(
	0.8,
	0.12,
	0.12,
	1.0
)

const MANA_COLOR := Color(
	0.15,
	0.35,
	0.9,
	1.0
)

var _current_health := 0
var _max_health := 1

var _current_mana := 0
var _max_mana := 1
var _mana_is_private := false


func apply_state(
	player_state: PlayerState
) -> void:
	_current_health = player_state.current_health
	_max_health = player_state.max_health

	_mana_is_private = player_state.mana_is_private
	_current_mana = player_state.current_mana
	_max_mana = player_state.max_mana

	queue_redraw()


func _draw() -> void:
	var health_ratio := _get_ratio(
		_current_health,
		_max_health
	)

	var mana_ratio := _get_ratio(
		_current_mana,
		_max_mana
	)

	var health_rect := Rect2(
		Vector2.ZERO,
		Vector2(
			BAR_WIDTH,
			HEALTH_BAR_HEIGHT
		)
	)

	var mana_y := (
		HEALTH_BAR_HEIGHT
		+ BAR_GAP
	)

	var mana_rect := Rect2(
		Vector2(
			0.0,
			mana_y
		),
		Vector2(
			BAR_WIDTH,
			MANA_BAR_HEIGHT
		)
	)

	_draw_bar(
		health_rect,
		health_ratio,
		HEALTH_COLOR
	)

	if not _mana_is_private and _max_mana > 0:
		_draw_bar(mana_rect, mana_ratio, MANA_COLOR)


func _draw_bar(
	rect: Rect2,
	ratio: float,
	fill_color: Color
) -> void:
	draw_rect(
		rect,
		BACKGROUND_COLOR,
		true
	)

	var inner_rect := Rect2(
		rect.position + Vector2.ONE,
		Vector2(
			(rect.size.x - 2.0) * ratio,
			rect.size.y - 2.0
		)
	)

	if inner_rect.size.x > 0.0:
		draw_rect(
			inner_rect,
			fill_color,
			true
		)

	draw_rect(
		rect,
		BORDER_COLOR,
		false,
		1.0
	)


func _get_ratio(
	current_value: int,
	max_value: int
) -> float:
	if max_value <= 0:
		return 0.0

	return clampf(
		float(current_value)
		/ float(max_value),
		0.0,
		1.0
	)
