class_name ArenaPreview
extends Control
var arena_id := ArenaData.DEFAULT_ARENA_ID
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(180,70)
func _draw() -> void:
	var definition := ArenaData.get_definition(arena_id)
	draw_rect(Rect2(Vector2.ZERO,size),definition.exterior)
	var area := Rect2(Vector2(10,5),size-Vector2(20,10))
	draw_rect(area,definition.ground_color)
	var cell := area.size/Vector2(20,12)
	for point: Vector2i in definition.scenery_cells:
		draw_rect(Rect2(area.position+Vector2(point)*cell,cell),definition.accent)
	for point: Vector2i in definition.spawn_points:
		draw_circle(area.position+(Vector2(point)+Vector2(0.5,0.5))*cell,3,Color("f3f0e8"))
	draw_rect(area,definition.accent,false,1)
