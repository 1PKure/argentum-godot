class_name ArenaGround
extends Node2D

const SHOW_DEBUG_GRID := false
const VISUAL_PADDING_TILES := 32

var _ground_grh_ids: Array[int] = []
var _arena_id := ArenaData.DEFAULT_ARENA_ID
var _lava_background: ColorRect

var _grid_columns: int
var _grid_rows: int
var _tile_size: int
var _world_origin: Vector2
var _visible_cells := Rect2i()
var _has_view := false
var _batch: ArenaCanvasBatch
var _meshes: Array[ArrayMesh] = []


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
	_arena_id = arena_id
	_ground_grh_ids = (
		ArenaData.get_ground_grh_ids(
			arena_id
		)
	)

	_grid_columns = grid_columns
	_grid_rows = grid_rows
	_tile_size = tile_size
	_world_origin = world_origin
	_has_view = false

	if _lava_background == null:
		_lava_background = ColorRect.new()
		_lava_background.show_behind_parent = true
		_lava_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = load("res://client/world/shaders/lava_surface.gdshader")
		_lava_background.material = shader_material
		add_child(_lava_background)
	_lava_background.position = _world_origin - Vector2.ONE * VISUAL_PADDING_TILES * _tile_size
	_lava_background.size = Vector2(_grid_columns + 2 * VISUAL_PADDING_TILES,_grid_rows + 2 * VISUAL_PADDING_TILES) * _tile_size
	(_lava_background.material as ShaderMaterial).set_shader_parameter("surface_size", _lava_background.size)
	_lava_background.visible = _arena_id == ArenaData.LAVA
	queue_redraw()


func set_visible_world_rect(area: Rect2) -> void:
	if _tile_size <= 0: return
	var first := (area.position-_world_origin)/_tile_size
	var last := (area.end-_world_origin)/_tile_size
	# A stable four-tile window avoids rebuilding geometry every animation frame.
	var start := Vector2i(floori(first.x/4.0)*4-4,floori(first.y/4.0)*4-4)
	var end := Vector2i(ceili(last.x/4.0)*4+4,ceili(last.y/4.0)*4+4)
	start = start.max(Vector2i(-VISUAL_PADDING_TILES,-VISUAL_PADDING_TILES))
	end = end.min(Vector2i(_grid_columns+VISUAL_PADDING_TILES,_grid_rows+VISUAL_PADDING_TILES))
	var cells := Rect2i(start,(end-start).max(Vector2i.ZERO))
	if _has_view and cells == _visible_cells:return
	_visible_cells = cells
	_has_view = true
	queue_redraw()

func cell_window() -> Rect2i:
	return _visible_cells if _has_view else Rect2i(-VISUAL_PADDING_TILES,-VISUAL_PADDING_TILES,_grid_columns+2*VISUAL_PADDING_TILES,_grid_rows+2*VISUAL_PADDING_TILES)

func _flush_batch() -> void:
	var geometry := _batch.mesh()
	if geometry != null:
		_meshes.append(geometry) # Canvas draw commands keep RIDs, not RefCounted ownership.
		draw_mesh(geometry,null)
	_batch = ArenaCanvasBatch.new()

func _draw() -> void:
	_meshes.clear()
	if (
		_grid_columns <= 0
		or _grid_rows <= 0
	):
		return

	if _ground_grh_ids.is_empty():
		_draw_themed_floor()
		return

	# Decorative exterior keeps a following camera filled at the arena edges.
	# Server walkability remains the original 20x12 bounds, marked by the border.
	var window := cell_window()
	for y in range(window.position.y,window.end.y):
		for x in range(window.position.x,window.end.x):
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


func _draw_themed_floor() -> void:
	_batch = ArenaCanvasBatch.new()
	var definition := ArenaData.get_definition(_arena_id)
	var area := Rect2(_world_origin,Vector2(_grid_columns,_grid_rows)*_tile_size)
	if _arena_id != ArenaData.LAVA:
		_batch.rect(Rect2(_world_origin - Vector2.ONE*VISUAL_PADDING_TILES*_tile_size,Vector2(_grid_columns+2*VISUAL_PADDING_TILES,_grid_rows+2*VISUAL_PADDING_TILES)*_tile_size),definition.exterior)
	_draw_exterior(area)
	var window := cell_window()
	for y in range(maxi(0,window.position.y),mini(_grid_rows,window.end.y)):
		for x in range(maxi(0,window.position.x),mini(_grid_columns,window.end.x)):
			var at := _world_origin + Vector2(x,y)*_tile_size
			var variation := posmod(x*17+y*31+x*y*7,7)
			var base: Color = definition.ground_color
			var tint := base.lightened(variation*0.009) if variation < 4 else base.darkened(variation*0.006)
			_batch.rect(Rect2(at,Vector2.ONE*_tile_size),tint)
			if _arena_id == ArenaData.DESERT:
				_batch.rect(Rect2(at+Vector2(8+variation*4,12+variation*3),Vector2(2,1)),Color("987b4d"))
				_batch.line(at+Vector2(5,35),at+Vector2(14+variation,34),Color(0.85,0.73,0.48,0.3))
			else:
				_batch.rect(Rect2(at+Vector2.ONE,Vector2.ONE*(_tile_size-2)),base.lightened(0.08),false,1)
				if _arena_id == ArenaData.LAVA and variation == 0:
					_batch.polyline(PackedVector2Array([at+Vector2(8,10),at+Vector2(17,18),at+Vector2(14,25)]),Color("82473b"),1)
	_batch.rect(area,definition.accent,false,2)
	if _arena_id == ArenaData.DUEL_ROOM:
		var center := area.get_center()
		_batch.arc(center,64,0,TAU,64,definition.accent,1)
		_batch.polyline(PackedVector2Array([center+Vector2(0,-48),center+Vector2(48,0),center+Vector2(0,48),center+Vector2(-48,0),center+Vector2(0,-48)]),definition.accent,1)

	_flush_batch()

# Decorative only. Draw before the playable floor; bounds and collisions do not
# change. Coordinates are world anchored so a following camera cannot slide them.
func _draw_exterior(area: Rect2) -> void:
	if _arena_id == ArenaData.DESERT:
		for band in range(-18,32):
			var points := PackedVector2Array()
			var shadow := PackedVector2Array()
			for sample in range(-12,34):
				var x := float(sample)*_tile_size
				var y := band*_tile_size*0.80+sin(sample*0.27+band*0.61)*_tile_size*0.40
				points.append(_world_origin+Vector2(x,y))
				shadow.append(_world_origin+Vector2(x,y+8))
			_batch.polyline(shadow,Color(0.29,0.22,0.12,0.16),9,true)
			_batch.polyline(points,Color(0.86,0.70,0.41,0.22),3,true)
		# Sandstone shelves and small wind-scoured stones beyond the arena.
		for y in range(-7,_grid_rows+8,2):
			for x in range(-8,_grid_columns+8,3):
				var at := _world_origin+Vector2(x*_tile_size,y*_tile_size)
				if area.grow(35).has_point(at): continue
				var k := float(posmod(x*19+y*7,11))
				if k < 5: continue
				var extent := Vector2(22+k,17+k*0.6)
				_flush_batch()
				draw_texture_rect(preload("res://assets/arena/scenery/rock.svg"),Rect2(at-extent*0.5,extent),false,Color(0.8,0.72,0.56,0.85))
		_batch.rect(area.grow(12),Color("493b28"),false,8)
		_batch.rect(area.grow(5),Color("c2a16a"),false,3)
	elif _arena_id == ArenaData.DUEL_ROOM:
		# A paved surrounding hall with masonry tiers, wall recesses and sconces.
		var window := cell_window()
		for y in range(maxi(-8,window.position.y),mini(_grid_rows+8,window.end.y)):
			for x in range(maxi(-8,window.position.x),mini(_grid_columns+8,window.end.x)):
				var at := _world_origin+Vector2(x,y)*_tile_size
				if area.has_point(at+Vector2.ONE*24): continue
				var tile := Rect2(at,Vector2.ONE*_tile_size)
				var tint := Color("353d47").lightened(posmod(x*7+y*3,5)*0.008)
				_batch.rect(tile,tint)
				_batch.rect(tile.grow(-1),Color("454e59"),false,1)
		for tier in range(3):
			var wall := area.grow(46+tier*22)
			_batch.rect(wall,Color("171f29"),false,12)
			_batch.rect(wall.grow(-4),Color("505a66"),false,2)
		for x in range(1,_grid_columns,3):
			for y in [-2,_grid_rows+1]:
				var at := _world_origin+(Vector2(x,y)+Vector2(0.5,0.5))*_tile_size
				_batch.rect(Rect2(at-Vector2(19,23),Vector2(38,46)),Color("141d28"))
				_batch.rect(Rect2(at-Vector2(16,20),Vector2(32,40)),Color("59626b"),false,3)
				_batch.circle(at,26,Color(1,0.68,0.29,0.045))
				_batch.circle(at,13,Color(1,0.70,0.35,0.07))
				_batch.line(at+Vector2(0,13),at,Color("8b744a"),4,true)
				_batch.polygon(PackedVector2Array([at+Vector2(-4,1),at+Vector2(-2,-5),at+Vector2(1,-10),at+Vector2(4,-2),at+Vector2(3,2)]),Color("e9b564"))
		_batch.rect(area.grow(14),Color("101823"),false,12)
		_batch.rect(area.grow(6),Color("8f835f"),false,3)
