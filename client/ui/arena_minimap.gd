class_name ArenaMinimap
extends Control

var players: Dictionary = {}
var local_peer_id := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101711"))
	var cell := size / Vector2(MovementRules.GRID_COLUMNS, MovementRules.GRID_ROWS)
	for blocked: Vector2i in ArenaData.get_definition(ArenaData.DEFAULT_ARENA_ID).blocked_cells:
		draw_rect(Rect2(Vector2(blocked) * cell, cell), Color("6a644d"))
	for state: PlayerState in players.values():
		var tint := Color("f7d36d") if state.peer_id == local_peer_id else Color("f08077")
		if state.is_ghost:
			tint = Color("b8b8b8")
		draw_circle((Vector2(state.grid_position) + Vector2(0.5, 0.5)) * cell, 2.5, tint)
