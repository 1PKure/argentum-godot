extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ambient := ArenaBiomeAmbient.new()
	root.add_child(ambient)
	ambient.set_process(false)
	var bounds := Rect2(120, 80, 960, 576)
	var signatures: Dictionary = {}
	for biome in ArenaData.IDS:
		ambient.setup(biome, bounds)
		_check(ambient.particle_count <= ambient.MAX_PARTICLES and ambient.particle_count >= 80, "Bounded, visible falling atmosphere: %s" % biome)
		var stays_inside := true
		var animates := false
		for i in range(ambient.particle_count):
			for seconds in [0.0, 1.0, 600.0]: stays_inside = stays_inside and bounds.has_point(ambient.particle_position(i, seconds))
			animates = animates or ambient.particle_position(i, 0) != ambient.particle_position(i, 1)
		_check(stays_inside and animates, "Atmosphere drifts and wraps within its own arena: %s" % biome)
		var visible := 0
		var falling := true
		var view := Rect2(bounds.get_center()-Vector2(320,180),Vector2(640,360))
		for i in range(ambient.particle_count):
			if view.has_point(ambient.particle_position(i,7.0)): visible += 1
			var delta_y := ambient.particle_position(i,0.5).y-ambient.particle_position(i,0.0).y
			if delta_y<0: delta_y += bounds.size.y
			falling = falling and delta_y>2 and delta_y<25
		_check(falling, "Every particle falls downward like snow: %s" % biome)
		_check(visible >= 24, "Typical gameplay view contains visible distributed particles: %s (%d)" % [biome,visible])
		var signature := str(ambient.particle_position(2, 10)) + str(ambient.particle_count)
		_check(not signatures.has(signature), "Biome has its own motion/density: %s" % biome)
		signatures[signature] = true
	_check(ambient.z_index == -1 and ambient._foreground.z_index == 2, "Two subtle depth planes straddle avatar rendering")
	ambient.queue_free()
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	var layer = world._biome_ambient
	for biome in ArenaData.IDS:
		world.set_arena(biome)
		_check(world._biome_ambient == layer and layer.biome == biome and layer.bounds.position == world.WORLD_ORIGIN, "Arena selection reuses and resets one world-anchored ambient layer: %s" % biome)
	world.set_game_paused(true)
	var age: float = layer._elapsed
	await create_timer(0.04).timeout
	_check(layer._elapsed == age, "Solo pause freezes environmental particles with the room")
	world.set_game_paused(false)
	await create_timer(0.04).timeout
	_check(layer._elapsed > age, "Ambient motion resumes after solo pause")
	world.queue_free()
	await process_frame
	print("Biome ambient checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
