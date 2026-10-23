extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,880)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var index := 0
	for id: String in ArenaData.IDS:
		var panel := Control.new()
		panel.position = Vector2((index%2)*640,floori(index/2.0)*440)
		panel.size = Vector2(640,440)
		panel.clip_contents = true
		root.add_child(panel)
		var world = load("res://client/scenes/client_world.gd").new()
		panel.add_child(world)
		world.scale = Vector2.ONE*0.55
		world.position = Vector2(-10,20)
		world.set_arena(id)
		var first := PlayerState.new(1,"Guerrero",Vector2i(4,5))
		first.class_id = 3
		first.equipped_items = ClassCatalog.default_equipment(3)
		var second := PlayerState.new(2,"Clérigo",Vector2i(15,5))
		second.class_id = 2
		second.equipped_items = ClassCatalog.default_equipment(2)
		world._on_snapshot_received([first.to_dictionary(),second.to_dictionary()])
		world.set_process(false)
		var map := ArenaMinimap.new()
		map.arena_id = id
		map.players = {1:first,2:second}
		map.local_peer_id = 1
		map.position = Vector2(460,330)
		map.size = Vector2(168,100)
		panel.add_child(map)
		index+=1
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := OS.get_environment("AO_UI_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join("arenas-minimaps.png"))
	quit()
