extends SceneTree
## Native GL draw-budget regression. This does not estimate browser FPS or ping.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,800)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var results: Array = []
	var failures := 0
	var original_mode := ArenaVisualSettings.uses_original_fx()
	await ArenaBakedSpellAtlas.prewarm(self)
	for arena: String in ArenaData.IDS:
		var hud = load("res://client/ui/combat_hud.gd").new()
		root.add_child(hud)
		var controller = load("res://client/input/spell_targeting_controller.gd").new()
		root.add_child(controller)
		hud.configure_spells(controller)
		var world = load("res://client/scenes/client_world.gd").new()
		root.add_child(world)
		hud.mount_world(world)
		world.set_arena(arena)
		var me := PlayerState.new(1,"Mago",Vector2i(4,5))
		me.class_id = 1
		me.equipped_items = ClassCatalog.default_equipment(1)
		var rival := PlayerState.new(2,"Rival",Vector2i(12,5))
		rival.class_id = 8
		rival.equipped_items = ClassCatalog.default_equipment(8)
		var states := [me.to_dictionary(),rival.to_dictionary()]
		world._on_snapshot_received(states)
		world._local_avatar_peer_id = 1
		world._update_camera()
		hud._on_snapshot_received(states)
		hud._minimap.arena_id = arena
		hud._minimap.queue_redraw()
		world._biome_ambient.set_process(false)
		world._biome_ambient.set_age(19)
		for avatar in world._avatars.values():
			avatar.set_process(false)
			avatar._player_visual.body.stop()
		for frame in range(10):
			await process_frame
			await RenderingServer.frame_post_draw
		var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if calls <= 0 or calls > 350:failures += 1
		results.append({"arena":arena,"hud_draw_calls":calls})
		var output := OS.get_environment("AO_PERF_OUTPUT")
		if not output.is_empty():
			DirAccess.make_dir_recursive_absolute(output)
			root.get_texture().get_image().save_png(output.path_join("hud-"+arena+".png"))
		if arena == ArenaData.DUEL_ROOM:
			for original: bool in [true,false]:
				ArenaVisualSettings._original = original
				for spell_id: int in [53,51]:
					world._on_spell_resolved({"caster_id":1,"target_id":2,"origin_x":4,"origin_y":5,"target_x":12,"target_y":5,"spell_id":spell_id,"amount":100,"words":"IN VAS POR","action":"cast"})
				for effect in world._spell_effects:
					effect.set_process(false)
					effect._process(0.35)
					if effect._audio != null:
						effect._audio.stop()
						effect._audio.stream = null
				for frame in range(5):
					await process_frame
					await RenderingServer.frame_post_draw
				var combat_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				if combat_calls <= 0 or combat_calls > 350:failures += 1
				results.append({"arena":arena,"mode":"original" if original else "modern","two_spells_draw_calls":combat_calls})
				for effect in world._spell_effects.duplicate():effect.free()
		hud.free()
		controller.free()
		await process_frame
	ArenaVisualSettings._original = original_mode
	var report := {"scope":"Native GL Compatibility; idle two-player scene and complete HUD; not browser FPS","samples":results,"failures":failures}
	print(JSON.stringify(report))
	var output := OS.get_environment("AO_PERF_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("hud-draws.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	quit(1 if failures else 0)
