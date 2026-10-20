class_name ArenaBiomeAmbient
extends Node2D
## Low-density, world-anchored atmosphere. Presentation only; inherits the
## room's pause state and never changes targeting, movement or map collision.

var biome := "forest"
var particle_count := 28
var bounds := Rect2()
var _elapsed := 0.0
var _foreground: Node2D
const MAX_PARTICLES := 32


func setup(arena_id: String, world_bounds: Rect2) -> void:
	biome = arena_id
	bounds = world_bounds
	_elapsed = 0.0
	particle_count = 32 if biome == ArenaData.DESERT else (30 if biome == ArenaData.LAVA else (18 if biome == ArenaData.DUEL_ROOM else 28))
	queue_redraw()
	if _foreground != null: _foreground.queue_redraw()


func _ready() -> void:
	z_index = -1 # Above scenery/floor, most motes remain behind the avatars.
	_foreground = Node2D.new()
	_foreground.z_index = 2 # Just a few tiny nearby particles give a second plane.
	_foreground.draw.connect(func() -> void: _draw_particles(_foreground, true))
	add_child(_foreground)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	_foreground.queue_redraw()


func set_age(seconds: float) -> void:
	_elapsed = maxf(0, seconds)
	queue_redraw()
	if _foreground != null: _foreground.queue_redraw()


func particle_position(index: int, seconds: float) -> Vector2:
	var x_seed := fposmod(sin(index * 127.1 + 9.3) * 43758.5453, 1.0)
	var y_seed := fposmod(sin(index * 311.7 + 4.9) * 22641.319, 1.0)
	var speed := 0.65 + (index % 7) * 0.13
	var drift := Vector2(3.0, -2.0)
	if biome == ArenaData.DESERT: drift = Vector2(15.0, 2.0)
	elif biome == ArenaData.LAVA: drift = Vector2(2.0, -13.0)
	elif biome == ArenaData.FOREST: drift = Vector2(4.0, -3.0)
	var extent := Vector2(maxf(bounds.size.x, 1), maxf(bounds.size.y, 1))
	return bounds.position + Vector2(fposmod(x_seed*extent.x+seconds*drift.x*speed+sin(seconds*0.45+index)*5,extent.x),fposmod(y_seed*extent.y+seconds*drift.y*speed+sin(seconds*0.25+index)*3,extent.y))


func _draw() -> void:
	_draw_particles(self, false)


func _draw_particles(canvas: Node2D, front: bool) -> void:
	if not bounds.has_area(): return
	for i in range(particle_count):
		if (i % 6 == 0) != front: continue
		var at := particle_position(i, _elapsed)
		var nearby := 1.18 if front else 0.82
		var pulse := 0.70 + sin(_elapsed * 0.75 + i * 1.8) * 0.20
		if biome == ArenaData.LAVA:
			var color := Color("ffad58") if i % 3 else Color("b8a6a0")
			canvas.draw_circle(at, 4.0*nearby, Color(color, 0.045*pulse), true, -1, true)
			canvas.draw_circle(at, (1.2 if i%3 else 0.8)*nearby, Color(color, 0.42*pulse), true, -1, true)
			if i % 3: canvas.draw_line(at+Vector2(0,3),at,Color(color,0.18*pulse),0.8,true)
		elif biome == ArenaData.DESERT:
			var sand := Color("e7cc98")
			canvas.draw_line(at-Vector2(2.5,0.5)*nearby,at+Vector2(2.5,0.5)*nearby,Color(sand,0.23*pulse),1.0,true)
		elif biome == ArenaData.DUEL_ROOM:
			var dust := Color("e3dabf")
			canvas.draw_circle(at,3*nearby,Color(dust,0.035*pulse),true,-1,true)
			canvas.draw_circle(at,0.85*nearby,Color(dust,0.23*pulse),true,-1,true)
		else:
			if i % 4 == 0:
				var leaf := PackedVector2Array([at+Vector2(-2.3,0),at+Vector2(0,-1.4),at+Vector2(3,0.3),at+Vector2(0,1.6)])
				canvas.draw_colored_polygon(leaf,Color("c4b66f",0.26*pulse))
			else:
				var mote := Color("d2df9a")
				canvas.draw_circle(at,3.8*nearby,Color(mote,0.035*pulse),true,-1,true)
				canvas.draw_circle(at,0.9*nearby,Color(mote,0.28*pulse),true,-1,true)
