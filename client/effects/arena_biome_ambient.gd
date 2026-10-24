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
var _batches: Array[MultiMeshInstance2D] = []
const BATCH_SHADER := preload("res://client/effects/shaders/biome_batch.gdshader")
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
	if is_inside_tree(): _build_batches()


func _ready() -> void:
	z_index=-1
	_foreground=Node2D.new()
	_foreground.z_index=2
	add_child(_foreground)
	if bounds.has_area(): _build_batches()


func _process(delta: float) -> void:
	_elapsed+=delta
	_sync_age()


func set_age(seconds: float) -> void:
	_elapsed=maxf(0,seconds)
	_sync_age()


func particle_position(index: int, seconds: float) -> Vector2:
	if index<0 or index>=_seeds.size(): return bounds.position
	var seed_value := _seeds[index]
	var drift := Vector2(3,11)
	if biome==ArenaData.DESERT: drift=Vector2(11,28)
	elif biome==ArenaData.LAVA: drift=Vector2(2,14)
	elif biome==ArenaData.FOREST: drift=Vector2(5,18)
	var extent := Vector2(maxf(bounds.size.x,1),maxf(bounds.size.y,1))
	return bounds.position+Vector2(fposmod(seed_value.x*extent.x+seconds*drift.x*seed_value.z+sin(seconds*0.55+index)*6,extent.x),fposmod(seed_value.y*extent.y+seconds*drift.y*seed_value.z+sin(seconds*0.30+index)*2,extent.y))



func _sync_age() -> void:
	for batch in _batches: (batch.material as ShaderMaterial).set_shader_parameter("elapsed",_elapsed)

func _build_batches() -> void:
	if _foreground == null: return
	for batch in _batches: batch.queue_free()
	_batches.clear()
	for front: bool in [false,true]:
		var selected: Array[int] = []
		for i in range(particle_count):
			if (i%5==0)==front: selected.append(i)
		var data := MultiMesh.new()
		data.transform_format = MultiMesh.TRANSFORM_2D
		data.use_colors = true
		data.use_custom_data = true
		var quad := QuadMesh.new()
		quad.size = Vector2(7,4) if biome=="forest" else Vector2(3,3)
		data.mesh = quad
		data.instance_count = selected.size()
		for slot in range(selected.size()):
			var i: int = selected[slot]
			var seed: Vector3 = _seeds[i]
			data.set_instance_transform_2d(slot,Transform2D.IDENTITY)
			data.set_instance_custom_data(slot,Color(seed.x,seed.y,seed.z,float(i)))
			var color := Color("d7ca87") if biome=="forest" else Color("f8e4ba") if biome=="desert" else Color("ffb879") if biome=="lava" else Color("eee3c9")
			color.a = 0.52 if front else 0.38
			data.set_instance_color(slot,color)
		var material := ShaderMaterial.new()
		material.shader = BATCH_SHADER
		material.set_shader_parameter("bounds_origin",bounds.position)
		material.set_shader_parameter("bounds_size",bounds.size)
		material.set_shader_parameter("drift",Vector2(11,28) if biome=="desert" else Vector2(2,14) if biome=="lava" else Vector2(5,18) if biome=="forest" else Vector2(3,11))
		material.set_shader_parameter("leaf",biome=="forest")
		var batch := MultiMeshInstance2D.new()
		batch.multimesh = data
		batch.material = material
		(_foreground if front else self).add_child(batch)
		RenderingServer.canvas_item_set_custom_rect(batch.get_canvas_item(),true,bounds.grow(10))
		_batches.append(batch)
	_sync_age()
