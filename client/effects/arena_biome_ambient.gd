class_name ArenaBiomeAmbient
extends Node2D
## Bounded, falling atmosphere. Stratified seeds keep a visible sprinkling
## throughout the playable view; two small depth planes inherit room pause.

var biome := "forest"
var particle_count := 104
var bounds := Rect2()
var _elapsed := 0.0
var _foreground: Node2D
var _seeds: Array[Vector3] = []
const MAX_PARTICLES := 128


func setup(arena_id: String, world_bounds: Rect2) -> void:
	biome = arena_id
	bounds = world_bounds
	_elapsed = 0.0
	particle_count = 120 if biome==ArenaData.DESERT else (96 if biome==ArenaData.LAVA else (80 if biome==ArenaData.DUEL_ROOM else 104))
	_seeds.clear()
	var rows := ceili(particle_count/12.0)
	for i in range(particle_count):
		var jitter_x := fposmod(sin(i*127.1+9.3)*43758.5453,1.0)
		var jitter_y := fposmod(sin(i*311.7+4.9)*22641.319,1.0)
		_seeds.append(Vector3((i%12+0.15+jitter_x*0.70)/12.0,(floori(i/12.0)+0.15+jitter_y*0.70)/rows,0.72+(i%7)*0.10))
	queue_redraw()
	if _foreground!=null: _foreground.queue_redraw()


func _ready() -> void:
	z_index=-1
	_foreground=Node2D.new()
	_foreground.z_index=2
	_foreground.draw.connect(func() -> void: _draw_particles(_foreground,true))
	add_child(_foreground)


func _process(delta: float) -> void:
	_elapsed+=delta
	queue_redraw()
	_foreground.queue_redraw()


func set_age(seconds: float) -> void:
	_elapsed=maxf(0,seconds)
	queue_redraw()
	if _foreground!=null: _foreground.queue_redraw()


func particle_position(index: int, seconds: float) -> Vector2:
	if index<0 or index>=_seeds.size(): return bounds.position
	var seed_value := _seeds[index]
	var drift := Vector2(3,11)
	if biome==ArenaData.DESERT: drift=Vector2(11,28)
	elif biome==ArenaData.LAVA: drift=Vector2(2,14)
	elif biome==ArenaData.FOREST: drift=Vector2(5,18)
	var extent := Vector2(maxf(bounds.size.x,1),maxf(bounds.size.y,1))
	return bounds.position+Vector2(fposmod(seed_value.x*extent.x+seconds*drift.x*seed_value.z+sin(seconds*0.55+index)*6,extent.x),fposmod(seed_value.y*extent.y+seconds*drift.y*seed_value.z+sin(seconds*0.30+index)*2,extent.y))


func _draw() -> void:
	_draw_particles(self,false)


func _draw_particles(canvas: Node2D, front: bool) -> void:
	if not bounds.has_area(): return
	for i in range(particle_count):
		if (i%5==0)!=front: continue
		var at := particle_position(i,_elapsed)
		var nearby := 1.18 if front else 0.84
		var pulse := 0.84+sin(_elapsed*0.75+i*1.8)*0.12
		if biome==ArenaData.LAVA:
			var color := Color("ffd49b") if i%5==0 else Color("d7d3cd")
			canvas.draw_circle(at,3.1*nearby,Color(color,0.07*pulse),true,-1,true)
			canvas.draw_circle(at,1.65*nearby,Color(color,0.57*pulse),true,-1,true)
			if i%5==0: canvas.draw_line(at-Vector2(0,3),at,Color("ffae55",0.35*pulse),1,true)
		elif biome==ArenaData.DESERT:
			var sand := Color("f8e4ba") if i%3 else Color("8e7043")
			canvas.draw_line(at-Vector2(1.4,2)*nearby,at+Vector2(1.4,2)*nearby,Color(sand,0.55*pulse),1.25,true)
		else:
			if biome==ArenaData.FOREST:
				var flutter := sin(_elapsed*1.3+i)*0.7
				var direction := Vector2(cos(flutter),sin(flutter))
				var normal := direction.rotated(PI/2)
				var leaf := PackedVector2Array([at-direction*3.5*nearby,at-normal*1.65*nearby,at+direction*3.5*nearby,at+normal*1.65*nearby])
				var color := Color("d7ca87") if i%3 else Color("bdd593")
				canvas.draw_colored_polygon(leaf,Color(color,0.54*pulse))
				if front: canvas.draw_line(at-direction*2,at+direction*2,Color("f1e7ba",0.45*pulse),0.7,true)
			else:
				var dust := Color("eee3c9")
				canvas.draw_circle(at,3.5*nearby,Color(dust,0.06*pulse),true,-1,true)
				canvas.draw_circle(at,1.45*nearby,Color(dust,0.49*pulse),true,-1,true)
