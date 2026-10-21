extends SceneTree
## Native GL comparison; never represents browser performance or audio.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var Legacy = load("res://client/effects/arena_legacy_spell_visual.gd")
	var output := OS.get_environment("AO_UI_CAPTURE_DIR")
	if output.is_empty(): push_error("AO_UI_CAPTURE_DIR required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("17212b"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results := {"environment":"Native Linux GL Compatibility / Xvfb software rendering; no audio/network. Not browser performance.","samples":[]}
	for mode: String in ["baseline","modern","original"]:
		var page := Node2D.new();root.add_child(page)
		var visuals: Array[ArenaSpellVisual] = []
		if mode!="baseline":
			for column in range(2):
				var avatar = load("res://client/characters/player_visual.tscn").instantiate()
				avatar.position=Vector2(400+column*400,500);page.add_child(avatar)
				var visual: ArenaSpellVisual = Legacy.new() if mode=="original" else ArenaSpellVisual.new()
				visual.configure(SpellCatalog.get_spell(53));visual.position=avatar.position+Vector2(0,30)
				page.add_child(visual);visuals.append(visual)
		var calls: Array[float]=[];var intervals: Array[float]=[]
		var last := Time.get_ticks_usec()
		for index in range(150):
			for visual in visuals:visual.set_age(fmod(index/60.0,visual.lifetime))
			await process_frame;await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			if index>=30:
				calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));intervals.append((now-last)/1000.0)
			last=now
			if index==45:root.get_texture().get_image().save_png(output.path_join(mode+"-double-apocalypse.png"))
		calls.sort();intervals.sort()
		results.samples.append({"mode":mode,"frames":calls.size(),"draw_calls_median":calls[calls.size()/2],"draw_calls_p95":calls[ceili(calls.size()*.95)-1],"frame_interval_p50_ms":intervals[intervals.size()/2],"frame_interval_p95_ms":intervals[ceili(intervals.size()*.95)-1]})
		page.queue_free();await process_frame
	var file := FileAccess.open(output.path_join("comparison.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print(JSON.stringify(results));quit()
