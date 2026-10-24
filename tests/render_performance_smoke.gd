extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func _run() -> void:
	var diagnostics := root.get_node("NetworkDiagnostics")
	diagnostics.set_process(false)
	diagnostics.last_ping_ms = 38
	var overlay = load("res://client/ui/arena_performance_overlay.gd").new()
	root.add_child(overlay)
	ArenaVisualSettings.uses_original_fx()
	ArenaVisualSettings.metrics = true
	ArenaVisualSettings.diagnostic_details = false
	overlay._process(0.6)
	check(overlay.text.contains("FPS · Ping: 38 ms") and not overlay.text.contains("\n"),"player sees one readable FPS/ping line")
	check(not overlay.text.contains("p95") and not overlay.text.contains("draw"),"technical counters stay out of the player display")
	diagnostics.last_ping_ms = -1
	overlay._process(0.6)
	check(overlay.text.contains("midiendo") and not overlay.text.contains("0 ms"),"missing measurement never invents a zero ping")
	diagnostics.probe_timeouts = 1
	overlay._process(0.6)
	check(overlay.text.contains("sin respuesta"),"missing replies have a readable state")
	ArenaVisualSettings.diagnostic_details = true
	overlay._process(0.02)
	await process_frame
	overlay._process(0.6)
	check(overlay.text.contains("draw") and overlay.text.contains("Movimiento"),"detailed diagnosis remains available on request")
	ArenaVisualSettings.diagnostic_details = false
	overlay._process(0.6)
	check(not overlay.text.contains("\n") and overlay.intervals.is_empty(),"return to simple display drops detailed sampling")
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world.configure_viewport(Vector2(936,540))
	for arena: String in ArenaData.IDS:
		world.set_arena(arena)
		for zoom: float in [0.5,1.0,2.0]:
			world.scale = Vector2.ONE*zoom
			for cell: Vector2i in [Vector2i(0,0),Vector2i(19,11),Vector2i(10,6)]:
				var focus: Vector2 = world._grid_to_world(cell)
				world.position = world._viewport_size*0.5-focus*zoom
				var view: Rect2 = Rect2(-world.position/world.scale,world._viewport_size/world.scale)
				world._arena_ground.set_visible_world_rect(view)
				var cells: Rect2i = world._arena_ground.cell_window()
				var covered: Rect2 = Rect2(world.WORLD_ORIGIN+Vector2(cells.position)*48,Vector2(cells.size)*48)
				check(covered.encloses(view),"camera clipping keeps the viewport filled: %s %s %s"%[arena,zoom,cell])
	var map = load("res://client/ui/arena_minimap.gd").new()
	root.add_child(map)
	map.size = Vector2(264,144)
	var first: ArrayMesh = map._build_terrain()
	check(first != null and first.get_surface_count() == 1,"minimap geometry fits one static mesh")
	world.queue_free()
	map.queue_free()
	overlay.queue_free()
	diagnostics.reset()
	ArenaVisualSettings.metrics = false
	await process_frame
	print("Render performance checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
