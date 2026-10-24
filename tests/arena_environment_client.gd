extends SceneTree
var checks := 0
var failures := 0
var main: Node
var hud: Control
var network: Node
var local_id := 0
var rejection := ""
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	network = root.get_node("ArenaNetwork")
	network.completed.connect(func(ok: bool,message: String) -> void:
		if not ok: rejection = message
	)
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	hud = main._hud
	await _wait_for(func() -> bool: return main._spell_controller.server_ready and not network.state.is_empty() and not hud._players.is_empty(),20)
	_check(main._spell_controller.server_ready and not network.state.is_empty(),"Client negotiates protocol 16 and authoritative arena state")
	if network.state.is_empty():
		await _finish()
		return
	local_id = root.multiplayer.get_unique_id()
	if "--arena-observer" in OS.get_cmdline_user_args():
		await _observer()
	else:
		await _actor()
	await _finish()
func _actor() -> void:
	var bot_network = root.get_node("BotNetwork")
	_check(int(network.state.owner_id) == local_id,"First human owns the shared arena")
	bot_network.request_bot(true,8)
	await _wait_for(func() -> bool: return str(bot_network.state.phase) == "countdown" and not bot_network.pending)
	var previous_round: String = bot_network.state.round_id
	var wins: int = root.get_node("Skins").progress.wins
	await _click(hud._menu_button)
	await _click(hud._menu_arenas_button)
	_check(hud._arena_panel.visible and not main._local_input.is_processing() and hud._arena_panel.buttons.size() == 4,"Menu opens four arena choices and blocks gameplay input")
	await _click(hud._arena_panel.buttons.desert)
	await _wait_for(func() -> bool: return str(network.state.arena_id) == "desert" and not network.pending)
	await create_timer(0.2).timeout
	_check(not hud._arena_panel.visible and main._world._arena_id == "desert","GUI selection changes the map and closes the selector")
	_check(str(bot_network.state.phase) == "countdown" and str(bot_network.state.round_id) != previous_round and root.get_node("Skins").progress.wins == wins,"Changing map restarts bot countdown without a skin reward")
	await _wait_for(func() -> bool: return not bool(network.state.transitioning))
	_check(main._spell_controller.input_blocked and not main._local_input.is_processing(),"Map transition does not release the longer bot countdown")
	print("ENVIRONMENTS_READY_FOR_PEER")
	await _wait_for(func() -> bool: return hud._players.size() == 2 and not bool(bot_network.state.enabled),20)
	_check(hud._players.size() == 2 and not hud._players.has(ArenaPracticeBot.BOT_ID),"Late human replaces the bot in the selected arena")
	await create_timer(1.0).timeout
	for id: String in ["lava","duel_room","forest","desert"]:
		root.get_node("PlayerNetwork").request_debug_damage()
		root.get_node("PlayerNetwork").request_debug_mana_spend()
		await create_timer(0.15).timeout
		var original_class: int = hud._players[local_id].class_id
		var skin: String = hud._players[local_id].skin_id
		var old_avatar: Node = main._world._avatars[local_id]
		hud._open_arenas()
		await _click(hud._arena_panel.buttons[id])
		await _wait_for(func() -> bool: return str(network.state.arena_id) == id and not network.pending)
		await _wait_for(func() -> bool: return not bool(network.state.transitioning))
		await create_timer(0.2).timeout
		_check(main._world._arena_id == id and hud._minimap.arena_id == id and hud._session_title.text.contains(ArenaData.get_display_name(id).to_upper()),"%s matches world, minimap and HUD" % id)
		var player: PlayerState = hud._players[local_id]
		_check(player.grid_position == Vector2i(4,5) and player.current_health == player.max_health and player.current_mana == player.max_mana and player.class_id == original_class and player.skin_id == skin,"%s reset restores resources/spawn and preserves class/skin" % id)
		_check(not is_instance_valid(old_avatar) and main._world._avatars.size() == 2 and main._world._spell_effects.is_empty(),"%s replaces old avatars and effects" % id)
		_check(not main._spell_controller.input_blocked and main._local_input.is_processing(),"%s transition resumes human controls" % id)
		await _capture("arena-%s.png" % id)
	# Confirm movement is still aimed and presented in the same coordinate space.
	root.get_node("PlayerNetwork").request_move(MovementRules.Direction.EAST)
	await _wait_for(func() -> bool: return hud._players[local_id].grid_position == Vector2i(5,5))
	await create_timer(0.2).timeout
	var avatar: Node2D = main._world._avatars[local_id]
	_check(avatar.global_position.distance_to(hud.game_area.get_global_rect().get_center()) < 1.5,"Camera follows the avatar after repeated map changes")
	_check(main._world.target_grid_at(avatar.global_position) == Vector2i(5,5),"Targeting uses the followed camera transform")
	hud._open_arenas()
	for resolution: Vector2i in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600)]:
		root.size = resolution
		hud._fit_interface()
		await process_frame
		await process_frame
		_check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud._arena_panel.card.get_global_rect()),"Arena selector fits %s" % resolution)
	await _capture("arena-selector.png")
	hud._arena_panel.close_panel()
	await create_timer(1.0).timeout
	main._disconnect_from_arena()
	_check(network.state.is_empty() and main._world._avatars.is_empty(),"Explicit disconnect clears map state and avatars")
func _observer() -> void:
	var host := int(network.state.owner_id)
	_check(str(network.state.arena_id) == "desert" and main._world._arena_id == "desert" and hud._players.size() == 2,"Late join receives selected map and current human snapshot")
	hud._open_arenas()
	_check(hud._arena_panel.buttons.values().all(func(button: Button) -> bool: return button.disabled),"Guest choices are read-only")
	network.select_arena("lava")
	await _wait_for(func() -> bool: return not network.pending)
	_check(not rejection.is_empty() and int(network.state.revision) == 1,"Server rejects a guest request bypassing disabled buttons")
	hud._arena_panel.close_panel()
	for revision in range(2,6):
		await _wait_for(func() -> bool: return int(network.state.revision) >= revision and not bool(network.state.transitioning),15)
		await create_timer(0.1).timeout
		var id: String = ["lava","duel_room","forest","desert"][revision-2]
		_check(str(network.state.arena_id) == id and main._world._arena_id == id and hud._minimap.arena_id == id and hud._players[local_id].grid_position == Vector2i(15,5),"Guest receives %s with the same map and spawn" % id)
	await _wait_for(func() -> bool: return hud._players.has(host) and hud._players[host].grid_position == Vector2i(5,5))
	_check(hud._players[host].grid_position == Vector2i(5,5),"Guest receives movement on the new map")
	await _wait_for(func() -> bool: return int(network.state.owner_id) == local_id and hud._players.size() == 1,20)
	_check(int(network.state.owner_id) == local_id,"Departing host transfers authority to the remaining human")
	network.select_arena("lava")
	await _wait_for(func() -> bool: return not network.pending and str(network.state.arena_id) == "lava")
	_check(str(network.state.arena_id) == "lava","New owner can change the arena")
func _wait_for(predicate: Callable, seconds: int = 8) -> void:
	var deadline := Time.get_ticks_msec()+seconds*1000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout
func _click(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame
func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("AO_UI_CAPTURE_DIR")
	if not directory.is_empty(): root.get_texture().get_image().save_png(directory.path_join(filename))
func _check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func _finish() -> void:
	main._disconnect_from_arena()
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Arena environment network checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
