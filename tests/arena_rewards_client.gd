extends SceneTree
var checks := 0
var failures := 0
var main: Node
var hud: Control
var controller: Node
var network: Node
var local_id := 0
var rejections: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	network = root.get_node("BotNetwork")
	root.get_node("SpellNetwork").spell_rejected.connect(func(_id: int, message: String, _remaining: int) -> void: rejections.append(message))
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	hud = main._hud
	controller = main._spell_controller
	await _wait_for(func() -> bool: return controller.server_ready and hud._players.size() > 0, 20)
	local_id = root.multiplayer.get_unique_id()
	_check(controller.server_ready, "Exported client negotiates protocol 16 with dedicated server")
	if not controller.server_ready:
		await _finish()
		return
	if "--rewards-observer" in OS.get_cmdline_user_args():
		await _observer()
		return
	var skins = root.get_node("Skins")
	skins.progress.storage_path = "user://rewards-e2e.cfg"
	DirAccess.remove_absolute(skins.progress.storage_path)
	skins.progress.restore()
	skins.changed.emit()
	await _click(hud._reserved_buttons[3])
	_check(hud._skins_panel.visible and hud._skins_panel.buttons.size() == 4 and hud._skins_panel.buttons.explorer.disabled and not main._local_input.is_processing(), "Skins opens four previews, locks rewards and blocks gameplay input")
	await _capture("skins-locked.png")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	_check(not hud._skins_panel.visible and main._local_input.is_processing(), "Escape closes Skins and restores gameplay")
	await _click(hud._reserved_buttons[2])
	hud._bot_panel.selector.select(hud._bot_panel.selector.get_item_index(3))
	await _click(hud._bot_panel.start_button)
	await _wait_for(func() -> bool: return str(network.state.phase) == "countdown" and not network.pending)
	_check(hud._round_countdown.visible and hud._round_countdown.title.text == "3" and controller.input_blocked and not main._local_input.is_processing(), "GUI activation shows three and blocks both input paths")
	await _capture("round-three.png")
	var origin: Vector2i = hud._players[local_id].grid_position
	var mana: int = hud._players[local_id].current_mana
	_key(KEY_D, true)
	for key: Key in [KEY_1, KEY_CTRL, KEY_SPACE]:
		_key(key, true)
		_key(key, false)
	root.get_node("SpellNetwork").request_cast(53, hud._players[ArenaPracticeBot.BOT_ID].grid_position, 100000)
	await _wait_for(func() -> bool: return not rejections.is_empty())
	_check(not rejections.is_empty() and rejections[-1].contains("no empezó") and hud._players[local_id].current_mana == mana and controller.aimed_spell_id == 0, "Dedicated rejects a direct early spell while UI keys consume no resources")
	await _wait_for(func() -> bool: return int(network.state.countdown) == 2)
	_check(hud._round_countdown.title.text == "2" and hud._players[local_id].grid_position == origin, "Two is synchronized and held movement stays frozen")
	_key(KEY_D, false)
	await _wait_for(func() -> bool: return int(network.state.countdown) == 1)
	_check(hud._round_countdown.title.text == "1", "One is synchronized before the round")
	await _wait_for(func() -> bool: return str(network.state.phase) == "active")
	_check(hud._round_countdown.title.text == "¡YA!" and not controller.input_blocked and main._local_input.is_processing(), "GO restores controls with a distinct visual and sound")
	await _capture("round-go.png")
	var casts: int = await _win_round()
	_check(str(network.state.phase) == "won" and casts > 1 and skins.progress.wins == 1, "A real targeted spell victory grants exactly one saved reward")
	if str(network.state.phase) != "won":
		print("Fight diagnostic: phase=",network.state.phase," HP=",hud._players[local_id].current_health," botHP=",hud._players[ArenaPracticeBot.BOT_ID].current_health," mana=",hud._players[local_id].current_mana," console=",hud.console.get_parsed_text())
		await _finish()
		return
	network._request_status.rpc_id(NetworkConstants.SERVER_PEER_ID)
	await create_timer(0.2).timeout
	_check(skins.progress.wins == 1, "Repeated authoritative victory status cannot award twice")
	await _click(hud._reserved_buttons[3])
	_check(not hud._skins_panel.buttons.explorer.disabled and hud._skins_panel.buttons.scarlet.disabled and hud._skins_panel.summary.text.contains("2 para"), "Victory unlocks the first class outfit and shows progress toward the next tier")
	var gear: Dictionary = hud._players[local_id].equipped_items.duplicate()
	await _click(hud._skins_panel.buttons.explorer)
	await _wait_for(func() -> bool: return hud._players[local_id].skin_id == "explorer")
	_check(hud._skins_panel.buttons.explorer.text == "Equipada" and hud._players[local_id].skin_id == "explorer" and hud._players[local_id].equipped_items == gear and main._world._avatars[local_id]._player_visual._skin_id == "explorer", "Equipar changes replicated appearance while preserving the equipped preset")
	await _capture("skins-unlocked.png")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	var restored := SkinProgress.new()
	restored.storage_path = skins.progress.storage_path
	restored.restore()
	_check(restored.wins == 1 and restored.selected == "explorer", "Disk reload preserves earned victory and equipped skin")
	# Seed only this class's already-earned milestones, then win one real extra duel.
	for number in range(2,6):
		skins.progress.award("prior-mage-%d" % number,1)
	skins.changed.emit()
	await _click(hud._reserved_buttons[2])
	await _click(hud._bot_panel.start_button)
	await _wait_for(func() -> bool: return str(network.state.phase) == "countdown")
	await _wait_for(func() -> bool: return str(network.state.phase) == "active")
	await _win_round()
	_check(str(network.state.phase) == "won" and skins.progress.wins == 6 and hud._bot_panel.visible and hud._bot_panel.try_class_button.visible and not main._local_input.is_processing(), "An extra real victory on a complete class opens the invitation and blocks gameplay")
	await _capture("collection-complete-invitation.png")
	await _click(hud._bot_panel.try_class_button)
	_check(hud._class_panel.visible and hud._class_panel.selector.get_selected_id() == 2 and hud._players[local_id].class_id == 1, "Try another class opens an incomplete suggestion without applying it automatically")
	await _click(hud._class_panel.apply_button)
	await _wait_for(func() -> bool: return hud._players[local_id].class_id == 2 and not hud._class_panel.visible)
	await _click(hud._reserved_buttons[3])
	_check(skins.progress.wins == 0 and skins.progress.selected == "preset" and hud._skins_panel.buttons.explorer.disabled and hud._skins_panel.summary.text.contains("0 victorias"), "Suggested class has its own locked collection and zero wins")
	_key(KEY_ESCAPE,true)
	_key(KEY_ESCAPE,false)
	await process_frame
	await _click(hud._reserved_buttons[0])
	hud._class_panel.selector.select(hud._class_panel.selector.get_item_index(1))
	hud._class_panel.selector.item_selected.emit(hud._class_panel.selector.selected)
	await process_frame
	await _click(hud._class_panel.apply_button)
	await _wait_for(func() -> bool: return hud._players[local_id].class_id == 1 and hud._players[local_id].skin_id == "explorer")
	_check(skins.progress.wins == 6 and skins.progress.selected == "explorer", "Returning to the completed class restores its progress and equipped skin")
	main._disconnect_from_arena()
	await create_timer(0.25).timeout
	main._connect_to_server(NetworkConstants.get_server_url())
	await _wait_for(func() -> bool: return controller.server_ready and hud._players.size() == 1 and hud._players.values()[0].skin_id == "explorer")
	local_id = root.multiplayer.get_unique_id()
	_check(hud._players[local_id].skin_id == "explorer" and skins.progress.wins == 6, "Reconnect automatically reapplies the saved cosmetic")
	await _click(hud._reserved_buttons[2])
	await _click(hud._bot_panel.start_button)
	await _wait_for(func() -> bool: return str(network.state.phase) == "countdown")
	print("REWARDS_READY_FOR_PEER")
	await _wait_for(func() -> bool: return int(network.state.human_count) == 2 and hud._players.size() == 2, 15)
	_check(not bool(network.state.enabled) and not hud._round_countdown.visible and not controller.input_blocked and skins.progress.wins == 6, "Joining human cancels countdown and grants no unfinished-round reward")
	await _wait_for(func() -> bool: return hud._players.values().any(func(p: PlayerState) -> bool: return p.peer_id != local_id and p.grid_position.y == 6), 20)
	main._disconnect_from_arena()
	await _finish()

func _win_round() -> int:
	var next_cast := Time.get_ticks_msec()
	var next_potion := 0
	var casts := 0
	var deadline := Time.get_ticks_msec() + 25000
	while str(network.state.phase) == "active" and Time.get_ticks_msec() < deadline:
		var now := Time.get_ticks_msec()
		var human: PlayerState = hud._players[local_id]
		var bot: PlayerState = hud._players[ArenaPracticeBot.BOT_ID]
		if now >= next_cast and controller.pending_request == 0:
			next_cast = now + 1000
			var spell := 25 if casts == 0 else 53 if casts == 1 else 51
			controller.aim_spell(spell)
			await _click_world(ArenaPracticeBot.BOT_ID)
			casts += 1
		if now >= next_potion:
			next_potion = now + 300
			if human.current_health <= human.max_health - 27:
				root.get_node("RecoveryNetwork").request_action("health_potion")
			elif human.current_mana <= human.max_mana - 800:
				root.get_node("RecoveryNetwork").request_action("mana_potion")
		await create_timer(0.03).timeout
	return casts

func _observer() -> void:
	await _wait_for(func() -> bool: return hud._players.size() == 2)
	var others: Array = hud._players.values().filter(func(state: PlayerState) -> bool: return state.peer_id != local_id)
	_check(others.size() == 1 and others[0].skin_id == "explorer", "Second client snapshot receives the owner's selected cosmetic")
	if not others.is_empty():
		_check(main._world._avatars[others[0].peer_id]._player_visual._skin_id == "explorer", "Second client renders the same cosmetic body")
	_check(not bool(network.state.enabled) and not hud._round_countdown.visible, "New human joins without a bot or stale countdown")
	root.get_node("PlayerNetwork").request_move(MovementRules.Direction.SOUTH)
	await _wait_for(func() -> bool: return hud._players[local_id].grid_position.y == 6)
	await create_timer(0.6).timeout
	main._disconnect_from_arena()
	await _finish()

func _wait_for(predicate: Callable, seconds: float = 8) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout

func _click(button: Control) -> void:
	await _click_at(button.get_global_rect().get_center())

func _click_world(id: int) -> void:
	var world = main._world
	await _click_at(world.get_global_transform() * (world._avatars[id].position + Vector2(0, -25)))

func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("AO_UI_CAPTURE_DIR")
	if not directory.is_empty():
		root.get_texture().get_image().save_png(directory.path_join(filename))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func _finish() -> void:
	root.get_node("NetworkManager").stop()
	main._world.clear_session()
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Rewards network checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
