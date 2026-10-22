extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
	root.size=Vector2i(1280,800)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var results:Array=[]
	var failed:=false
	for biome:String in ArenaData.IDS:
		var ambient:=ArenaBiomeAmbient.new();root.add_child(ambient)
		ambient.setup(biome,Rect2(0,0,1280,800))
		for i in range(40):await process_frame;await RenderingServer.frame_post_draw
		var calls:=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		results.append({"biome":biome,"particles":ambient.particle_count,"batches":ambient._batches.size(),"draw_calls":calls})
		failed = failed or calls<1 or calls>8 or ambient._batches.size()!=2
		ambient.queue_free();await process_frame
	var folder:=OS.get_environment("AO_UI_CAPTURE_DIR")
	if not folder.is_empty():
		var f:=FileAccess.open(folder.path_join("ambient-batches.json"),FileAccess.WRITE)
		f.store_string(JSON.stringify({"environment":"Native GL Compatibility / Mesa llvmpipe; isolated ambient only, not browser FPS","samples":results},"\t"));f.close()
	print("Ambient render: ",JSON.stringify(results))
	quit(1 if failed else 0)
