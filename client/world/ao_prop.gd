class_name AOProp
extends Node2D

var _grh_id: int
var _visual_scale: float = 1.0

var _texture: Texture2D
var _region := Rect2()


func _ready() -> void:
	texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)


func setup(
	grh_id: int,
	world_position: Vector2,
	visual_scale: float
) -> void:
	_grh_id = grh_id
	_visual_scale = visual_scale

	position = world_position

	_load_grh()

	queue_redraw()


func _load_grh() -> void:
	var definition := (
		AOResources.get_grh_definition(
			_grh_id
		)
	)

	if definition.is_empty():
		return

	var file_num: int = int(
		definition.get(
			"file_num",
			0
		)
	)

	_region = definition.get(
		"region",
		Rect2()
	)

	_texture = AOResources.get_texture(
		file_num
	)


func _draw() -> void:
	if _texture == null:
		return

	if _region.size == Vector2.ZERO:
		return

	var render_size := (
		_region.size
		* _visual_scale
	)

	var destination_rect := Rect2(
		Vector2(
			-render_size.x * 0.5,
			-render_size.y
		),
		render_size
	)

	draw_texture_rect_region(
		_texture,
		destination_rect,
		_region
	)
