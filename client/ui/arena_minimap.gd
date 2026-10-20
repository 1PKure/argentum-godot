class_name ArenaMinimap
extends Control

var players: Dictionary = {}
var local_peer_id := 0
var arena_id := ArenaData.DEFAULT_ARENA_ID

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func map_rect() -> Rect2:
	var available := size-Vector2(16,28)
	var unit := minf(available.x/float(MovementRules.GRID_COLUMNS),available.y/float(MovementRules.GRID_ROWS))
	var extent := Vector2(MovementRules.GRID_COLUMNS,MovementRules.GRID_ROWS)*unit
	return Rect2(Vector2((size.x-extent.x)*0.5,21),extent)

func point_for(cell: Vector2i) -> Vector2:
	var area := map_rect()
	return area.position+(Vector2(cell)+Vector2(0.5,0.5))*area.size/Vector2(MovementRules.GRID_COLUMNS,MovementRules.GRID_ROWS)

func _draw() -> void:
	if size.x < 32 or size.y < 32: return
	var definition := ArenaData.get_definition(arena_id)
	draw_style_box(_frame(),Rect2(Vector2.ZERO,size))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(8,12),str(definition.display_name),HORIZONTAL_ALIGNMENT_LEFT,size.x-34,10,Color("d6c99f"))
	draw_string(font,Vector2(size.x-17,12),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("aab3c2"))
	var area := map_rect()
	draw_rect(area.grow(2),Color("070f18"))
	var cell := area.size/Vector2(MovementRules.GRID_COLUMNS,MovementRules.GRID_ROWS)
	for y in MovementRules.GRID_ROWS:
		for x in MovementRules.GRID_COLUMNS:
			var tint: Color = definition.ground_color
			var noise := posmod(x*13+y*19+x*y,7)
			tint = tint.darkened(0.12+noise*0.015)
			draw_rect(Rect2(area.position+Vector2(x,y)*cell,cell+Vector2(0.1,0.1)),tint)
			if arena_id in [ArenaData.DUEL_ROOM,ArenaData.LAVA]:
				draw_rect(Rect2(area.position+Vector2(x,y)*cell,cell),Color(0.04,0.06,0.08,0.15),false,0.5)
	var middle := area.get_center()
	if arena_id == ArenaData.DUEL_ROOM:
		draw_arc(middle,cell.y*1.3,0,TAU,28,Color("b9a164"),0.7,true)
	elif arena_id == ArenaData.DESERT:
		for y in [2,7,10]:
			draw_polyline(PackedVector2Array([point_for(Vector2i(0,y)),point_for(Vector2i(6,y-1)),point_for(Vector2i(13,y)),point_for(Vector2i(19,y-1))]),Color(0.95,0.81,0.5,0.16),1,true)
	for blocked: Vector2i in definition.blocked_cells:
		var at := point_for(blocked)
		draw_circle(at+Vector2(0,1),cell.y*0.65,Color(0,0,0,0.35))
		if arena_id == ArenaData.FOREST:
			draw_circle(at,cell.y*0.8,Color("2c5237"))
			draw_circle(at-Vector2(0.5,0.8),cell.y*0.45,Color("60864f"))
		else:
			draw_rect(Rect2(at-cell*0.4,cell*0.8),Color("728071") if arena_id == ArenaData.DESERT else Color("77838c"))
	for spawn: Vector2i in definition.spawn_points:
		draw_arc(point_for(spawn),cell.y*0.7,0,TAU,16,Color(0.95,0.85,0.6,0.24),0.75,true)
	draw_rect(area,Color("b9a66f"),false,0.8)
	for state: PlayerState in players.values():
		if not MovementRules.is_inside_bounds(state.grid_position): continue
		var at := point_for(state.grid_position)
		var own := state.peer_id == local_peer_id
		var tint := Color("ffe393") if own else Color("ff8d87")
		if state.is_ghost: tint = Color("adb5c0")
		draw_circle(at,3.7,Color("111722"))
		if own:
			var heading := Vector2(MovementRules.get_offset(state.facing_direction))
			var side := heading.orthogonal()
			draw_colored_polygon(PackedVector2Array([at+heading*4.6,at-heading*2.6+side*3,at-heading*1.4,at-heading*2.6-side*3]),tint)
		else: draw_circle(at,2.6,tint)

func _frame() -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("101a28")
	frame.border_color = Color("344357")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(5)
	return frame
