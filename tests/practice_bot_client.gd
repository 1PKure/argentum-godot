extends SceneTree
var checks := 0
var failures := 0
var main: Node
var hud: Control
var controller: Node
var network: Node
var local_id := 0
var events: Array[Dictionary] = []
var bot_steps: Array[int] = []
var human_steps: Array[int] = []
var completions: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("PlayerNetwork").player_moved.connect(func(data: Dictionary) -> void:
		if int(data.peer_id) == ArenaPracticeBot.BOT_ID:
			bot_steps.append(Time.get_ticks_msec())
		elif int(data.peer_id) == local_id:
			human_steps.append(Time.get_ticks_msec())
	)
	network = root.get_node("BotNetwork")
	network.completed.connect(func(ok: bool, message: String) -> void: completions.append({"ok": ok, "message": message}))
	root.get_node("SpellNetwork").spell_resolved.connect(func(event: Dictionary) -> void: events.append(event))
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	hud = main._hud
	controller = main._spell_controller
	await _wait_for(func() -> bool: return controller.server_ready and int(network.state.human_count) > 0)
	_check(controller.server_ready, "Client negotiates bot protocol with dedicated server")
	if not controller.server_ready:
		await _finish()
		return
	local_id = root.multiplayer.get_unique_id()
	if "--bot-observer" in OS.get_cmdline_user_args():
		await _observer()
		return
	await _click(hud._reserved_buttons[2])
	_check(hud._bot_panel.visible and hud._bot_panel.selector.item_count == 9 and not main._local_input.is_processing(), "Bot panel offers nine classes and blocks movement while choosing")
	await _capture("bot-panel.png")
	await _start(1)
	_check(hud._players.has(ArenaPracticeBot.BOT_ID) and hud._players[ArenaPracticeBot.BOT_ID].is_bot and hud._players[ArenaPracticeBot.BOT_ID].class_id == 1, "GUI activation spawns the selected bot as a real replicated entity")
	_check(hud._players[ArenaPracticeBot.BOT_ID].mana_is_private and not hud._bot_panel.visible and main._local_input.is_processing(), "Bot mana stays private and starting returns controls to gameplay")
	_check(is_equal_approx(main._world._avatars[ArenaPracticeBot.BOT_ID]._move_speed, 48.0 / 0.18) and is_equal_approx(main._world._avatars[local_id]._move_speed, 48.0 / 0.12), "Replicated bot interpolates more slowly than the human avatar")
	var spawn: Vector2i = hud._players[ArenaPracticeBot.BOT_ID].grid_position
	await _wait_for(func() -> bool: return hud._players[ArenaPracticeBot.BOT_ID].grid_position != spawn)
	_check(hud._players[ArenaPracticeBot.BOT_ID].grid_position != spawn, "Bot movement is synchronized from server decisions")
	# Keep the local player walking while the bot attacks and recovers.
	bot_steps.clear()
	human_steps.clear()
	var last_potion := 0
	for direction: Key in [KEY_S, KEY_D, KEY_W, KEY_A]:
		_key(direction, true)
		for step in range(4):
			await create_timer(0.2).timeout
			if hud._players[local_id].is_alive and hud._players[local_id].current_health <= hud._players[local_id].max_health - 27 and Time.get_ticks_msec() - last_potion >= 340:
				_key(KEY_Q, true)
				_key(KEY_Q, false)
				last_potion = Time.get_ticks_msec()
		_key(direction, false)
	var flowing_pairs := 0
	for index in range(1, bot_steps.size()):
		if bot_steps[index] - bot_steps[index - 1] <= 220:
			flowing_pairs += 1
	_check(bot_steps.size() >= 10 and flowing_pairs >= 5, "Replicated bot sustains continuous movement while its opponent walks and drinks")
	var bot_gaps: Array[int] = []
	var human_gaps: Array[int] = []
	for times: Array[int] in [bot_steps, human_steps]:
		var gaps: Array[int] = []
		for index in range(1, times.size()):
			gaps.append(times[index] - times[index - 1])
		gaps.sort()
		if times == bot_steps:
			bot_gaps = gaps
		else:
			human_gaps = gaps
	_check(not bot_gaps.is_empty() and not human_gaps.is_empty() and bot_gaps[bot_gaps.size() / 2] >= 160 and human_gaps[human_gaps.size() / 2] <= 140, "Real WebSocket movement samples confirm the bot steps more slowly than held human input")

	await _wait_for(func() -> bool: return hud._players[local_id].current_health < hud._players[local_id].max_health, 15)
	_check(events.any(func(event: Dictionary) -> bool: return int(event.caster_id) == ArenaPracticeBot.BOT_ID and not event.has("mana_cost")) and hud.console.get_parsed_text().contains("te lanzó"), "Bot casts actual spells with local combat feedback and no leaked mana cost")
	await _capture("bot-mage-combat.png")
	await _wait_for(func() -> bool: return str(network.state.phase) == "lost", 24)
	_check(not hud._players[local_id].is_alive and str(network.state.phase) == "lost", "Player defeat stops practice with an authoritative outcome")
	var stopped: Vector2i = hud._players[ArenaPracticeBot.BOT_ID].grid_position
	await create_timer(0.4).timeout
	_check(hud._players[ArenaPracticeBot.BOT_ID].grid_position == stopped, "Finished bot does not keep moving over a dead player")
	await _click(hud._reserved_buttons[2])
	await _start(8)
	_check(hud._players[local_id].is_alive and hud._players[local_id].current_health == hud._players[local_id].max_health and hud._players[local_id].active_effects.is_empty() and hud._players[ArenaPracticeBot.BOT_ID].class_id == 8, "GUI restart prepares a dead player and replaces the bot class")
	_check(main._world._avatars[local_id].position.distance_to(main._world._grid_to_world(Vector2i(4, 5))) < 0.1, "Practice restart teleports instead of replaying old movement")
	await _capture("bot-hunter-practice.png")
	await _click(hud._reserved_buttons[2])
	await _click(hud._bot_panel.stop_button)
	await _wait_for(func() -> bool: return not bool(network.state.enabled) and not hud._players.has(ArenaPracticeBot.BOT_ID))
	_check(not hud._players.has(ArenaPracticeBot.BOT_ID) and not main._world._avatars.has(ArenaPracticeBot.BOT_ID), "GUI removal clears the bot state and avatar")
	await _click(hud._reserved_buttons[2])
	await _start(3)
	hud.show_spells()
	await _click(hud._spell_buttons[1])
	await _click(hud._launch_button)
	await _click_world(ArenaPracticeBot.BOT_ID)
	await _wait_for(func() -> bool: return hud._players[local_id].current_mana == hud._players[local_id].max_mana - 10)
	_check(hud._players[local_id].current_mana == hud._players[local_id].max_mana - 10 and hud._players[ArenaPracticeBot.BOT_ID].current_health < hud._players[ArenaPracticeBot.BOT_ID].max_health, "Manual Lanzar targets and damages the moving bot with the normal spell cost")
	main._disconnect_from_arena()
	await create_timer(0.4).timeout
	_check(hud._players.is_empty() and not bool(network.state.enabled), "Disconnect clears local bot and pending state")
	await _capture("bot-connection-gold.png")
	main._connect_to_server(NetworkConstants.get_server_url())
	await _wait_for(func() -> bool: return controller.server_ready and int(network.state.human_count) == 1 and hud._players.size() == 1)
	local_id = root.multiplayer.get_unique_id()
	_check(hud._players.size() == 1 and not bool(network.state.enabled), "Reconnect receives no orphan bot from the prior owner session")
	await _click(hud._reserved_buttons[2])
	await _start(8)
	print("BOT_READY_FOR_PEER")
	await _wait_for(func() -> bool: return int(network.state.human_count) == 2 and hud._players.size() == 2, 15)
	_check(int(network.state.human_count) == 2 and not bool(network.state.enabled) and not hud._players.has(ArenaPracticeBot.BOT_ID) and not main._world._avatars.has(ArenaPracticeBot.BOT_ID), "Joining human automatically removes the bot from state and scene")
	await _click(hud._reserved_buttons[2])
	_check(hud._bot_panel.start_button.disabled and hud._bot_panel._summary.text.contains("solo"), "UI disables bot activation while another human is present")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	_check(not hud._bot_panel.visible and main._local_input.is_processing(), "Escape closes the bot panel and restores movement")
	await create_timer(0.5).timeout
	main._disconnect_from_arena()
	await _finish()

func _observer() -> void:
	await _wait_for(func() -> bool: return int(network.state.human_count) == 2 and hud._players.size() == 2)
	_check(not bool(network.state.enabled) and hud._players.values().all(func(player: PlayerState) -> bool: return not player.is_bot), "New human snapshot contains only the two human players")
	network.request_bot(true, 1)
	await _wait_for(func() -> bool: return not completions.is_empty())
	_check(not completions.is_empty() and not completions[-1].ok and completions[-1].message.contains("otro jugador"), "Server rejects a forged activation while two humans are connected")
	await _wait_for(func() -> bool: return int(network.state.human_count) == 1 and hud._players.size() == 1, 15)
	network.request_bot(true, 3)
	await _wait_for(func() -> bool: return bool(network.state.enabled))
	_check(bool(network.state.enabled) and int(network.state.owner_id) == local_id and hud._players.has(ArenaPracticeBot.BOT_ID), "Remaining solo player can create their own clean practice")
	network.request_bot(false, 3)
	await _wait_for(func() -> bool: return not bool(network.state.enabled))
	_check(not bool(network.state.enabled) and not hud._players.has(ArenaPracticeBot.BOT_ID), "New owner can remove their bot without stale ownership")
	main._disconnect_from_arena()
	await _finish()

func _start(id: int) -> void:
	var panel = hud._bot_panel
	panel.selector.select(panel.selector.get_item_index(id))
	await process_frame
	await _click(panel.start_button)
	await _wait_for(func() -> bool: return not network.pending and bool(network.state.enabled) and int(network.state.class_id) == id and not panel.visible)

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
	print("Bot network checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
