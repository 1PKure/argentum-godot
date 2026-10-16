class_name ArenaGround
extends Node2D

const SHOW_DEBUG_GRID := false
const VISUAL_PADDING_TILES := 12

var _ground_grh_ids: Array[int] = []

var _grid_columns: int
var _grid_rows: int
var _tile_size: int
var _world_origin: Vector2


func _ready() -> void:
	texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)


func setup(
	arena_id: String,
	grid_columns: int,
	grid_rows: int,
	tile_size: int,
	world_origin: Vector2
) -> void:
	_ground_grh_ids = (
		ArenaData.get_ground_grh_ids(
			arena_id
		)
	)

	_grid_columns = grid_columns
	_grid_rows = grid_rows
	_tile_size = tile_size
	_world_origin = world_origin

	queue_redraw()


func _draw() -> void:
	if (
		_grid_columns <= 0
		or _grid_rows <= 0
	):
		return

	if _ground_grh_ids.is_empty():
		return

	# Decorative exterior keeps a following camera filled at the arena edges.
	# Server walkability remains the original 20x12 bounds, marked by the border.
	for y in range(-VISUAL_PADDING_TILES, _grid_rows + VISUAL_PADDING_TILES):
		for x in range(-VISUAL_PADDING_TILES, _grid_columns + VISUAL_PADDING_TILES):
			_draw_ground_tile(
				x,
				y
			)
	draw_rect(Rect2(_world_origin, Vector2(_grid_columns, _grid_rows) * _tile_size), Color(0.7, 0.63, 0.38, 0.9), false, 3.0)

	if SHOW_DEBUG_GRID:
		_draw_debug_grid()


func _draw_ground_tile(
	x: int,
	y: int
) -> void:
	var grh_id: int = (
		_get_ground_grh_id(
			x,
			y
		)
	)

	if grh_id <= 0:
		return

	var grh_definition: Dictionary = (
		AOResources.get_grh_definition(
			grh_id
		)
	)

	if grh_definition.is_empty():
		return

	var file_num: int = int(
		grh_definition.get(
			"file_num",
			0
		)
	)

	var region: Rect2 = (
		grh_definition.get(
			"region",
			Rect2()
		)
	)

	var texture: Texture2D = (
		AOResources.get_texture(
			file_num
		)
	)

	if texture == null:
		return

	var destination_position := (
		_world_origin
		+ Vector2(
			x * _tile_size,
			y * _tile_size
		)
	)

	var destination_rect := Rect2(
		destination_position,
		Vector2(
			_tile_size,
			_tile_size
		)
	)

	draw_texture_rect_region(
		texture,
		destination_rect,
		region,
		Color.WHITE if x >= 0 and y >= 0 and x < _grid_columns and y < _grid_rows else Color(0.35, 0.4, 0.32)
	)


func _get_ground_grh_id(
	x: int,
	y: int
) -> int:
	if _ground_grh_ids.is_empty():
		return 0

	var variation_index: int = (
		(
			x * 7
			+ y * 13
			+ x * y * 3
		)
		% _ground_grh_ids.size()
	)

	return _ground_grh_ids[
		variation_index
	]


func _draw_debug_grid() -> void:
	var width: int = (
		_grid_columns
		* _tile_size
	)

	var height: int = (
		_grid_rows
		* _tile_size
	)

	for x in range(
		_grid_columns + 1
	):
		var x_position: float = (
			_world_origin.x
			+ x * _tile_size
		)

		draw_line(
			Vector2(
				x_position,
				_world_origin.y
			),
			Vector2(
				x_position,
				_world_origin.y
				+ height
			),
			Color(
				1.0,
				1.0,
				1.0,
				0.15
			),
			1.0
		)

	for y in range(
		_grid_rows + 1
	):
		var y_position: float = (
			_world_origin.y
			+ y * _tile_size
		)

		draw_line(
			Vector2(
				_world_origin.x,
				y_position
			),
			Vector2(
				_world_origin.x
				+ width,
				y_position
			),
			Color(
				1.0,
				1.0,
				1.0,
				0.15
			),
			1.0
		)
