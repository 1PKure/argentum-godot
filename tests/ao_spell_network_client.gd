extends SceneTree

var checks := 0
var failures := 0
var main: Node
var hud: Control
var controller: Node
var network: Node
var manager: Node
var world: Node2D
var local_id := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	manager = root.get_node("NetworkManager")
	network = root.get_node("SpellNetwork")
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	hud = main.get_node("CombatHUD")
	controller = main._spell_controller
	world = main._world
	await _wait_for(func() -> bool: return hud._players.size() == 2 and controller.server_ready)
	_check(hud._players.size() == 2 and controller.server_ready, "Two clients negotiate spell support with the dedicated server")
	if hud._players.size() != 2 or not controller.server_ready:
		_finish()
		return
	local_id = root.multiplayer.get_unique_id()
	var opponent := 0
	for id: int in hud._players:
		if id != local_id:
			opponent = id
	if "--spell-target" in OS.get_cmdline_user_args():
		await _wait_for(func() -> bool: return hud._players[local_id].current_health < 500)
		await create_timer(0.1).timeout
		_check(hud._players[local_id].current_health >= 490 and hud._players[local_id].current_health <= 495, "Target receives AO20 Dart damage")
		_check(hud.console.get_parsed_text().contains("Dardo Mágico"), "Target console identifies the actual spell")
		var after_dart: int = hud._players[local_id].current_health
		network.request_cast(1, hud._players[opponent].grid_position, 1)
		await _wait_for(func() -> bool: return hud._players[local_id].current_mana == 2990)
		_check(hud._players[local_id].current_mana == 2990, "Opponent can cast independently with its own resource state")
		await _wait_for(func() -> bool: return hud._players[local_id].current_health <= after_dart - 10)
		_check(hud._players[local_id].current_health == after_dart - 10, "Physical attack remains separate from magic")
		await create_timer(1.0).timeout
		_finish()
		return
	_key(KEY_D, true)
	await create_timer(0.26).timeout
	_key(KEY_D, false)
	await create_timer(0.15).timeout
	controller.bindings.assign([1, 2, 12, 13, 0, 0, 0, 0, 0, 0])
	controller.changed.emit()
	await _click(hud._spell_button)
	await _click(hud._spell_buttons[1])
	_check(controller.selected_spell_id == 1 and controller.aimed_spell_id == 0, "Clicking a spell only selects it")
	_check(hud._players[local_id].current_mana == 3000, "Selecting a spell does not consume mana")
	await _click(hud._launch_button)
	_check(controller.aimed_spell_id == 1 and hud._players[local_id].current_mana == 3000, "Launch activates targeting without spending mana")
	await _click_world(opponent)
	await _wait_for(func() -> bool: return controller.pending_request == 0 and hud._players[local_id].current_mana == 2990)
	_check(hud._players[local_id].current_mana == 2990, "Target click consumes the original spell cost exactly once")
	_check(hud._players[opponent].current_health < 500, "Manual Launch actually affects the rival")
	_check(world._spell_effects.size() > 0, "Confirmed spell spawns its visible AO effect")
	await _capture("ao-manual-cast.png")
	await _wait_for(func() -> bool: return hud._players[local_id].current_health < 500)
	await create_timer(1.3).timeout
	var health_before: int = hud._players[local_id].current_health
	_key(KEY_3, true)
	_key(KEY_3, false)
	await process_frame
	_check(controller.selected_spell_id == 12 and controller.aimed_spell_id == 12, "Numeric hotkey immediately selects and targets its assigned spell")
	_key(KEY_D, true)
	await create_timer(0.36).timeout
	_key(KEY_D, false)
	await create_timer(0.08).timeout
	_check(hud._players[local_id].grid_position.x > 4 and controller.aimed_spell_id == 12, "Holding movement remains responsive while the spell cursor is active")
	_check(hud._players[local_id].current_mana == 2990, "Moving and aiming do not consume mana")
	await _click_world(local_id)
	await _wait_for(func() -> bool: return controller.pending_request == 0 and hud._players[local_id].current_mana == 2985)
	_check(hud._players[local_id].current_health > health_before, "Macro-targeted heal actually restores health")
	_check(hud._players[local_id].current_mana == 2985, "Minor heal consumes five mana")
	await _capture("ao-macro-heal.png")
	_key(KEY_1, true)
	_key(KEY_1, false)
	await process_frame
	var point: Vector2 = world.get_global_transform() * (world.WORLD_ORIGIN + Vector2(24, 24))
	await _click_at(point)
	await _wait_for(func() -> bool: return controller.pending_request == 0)
	_check(hud._players[local_id].current_mana == 2985, "Empty-target rejection does not spend mana")
	_check(hud.console.get_parsed_text().contains("No hay un objetivo vivo"), "Invalid targeting gives an understandable console message")
	_key(KEY_1, true)
	_key(KEY_1, false)
	await process_frame
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	_check(controller.aimed_spell_id == 0, "Escape cancels a hotkey target cursor")
	await _drag(hud._spell_buttons[12], hud._hotkey_buttons[0])
	_check(controller.bindings[0] == 12, "Dragging a spell onto a hotkey reassigns it through the GUI")
	_key(KEY_1, true)
	_key(KEY_1, false)
	await process_frame
	_check(controller.aimed_spell_id == 12, "Reassigned numeric hotkey uses the new spell")
	await _click_at(world.get_global_transform() * (world.WORLD_ORIGIN + Vector2(24, 24)), MOUSE_BUTTON_RIGHT)
	_check(controller.aimed_spell_id == 0, "Right click also cancels targeting")
	controller.assign_hotkey(0, 1)
	_key(KEY_D, true)
	await create_timer(1.2).timeout
	_key(KEY_D, false)
	await create_timer(0.1).timeout
	var rival_health: int = hud._players[opponent].current_health
	_key(KEY_CTRL, true)
	_key(KEY_CTRL, false)
	await _wait_for(func() -> bool: return hud._players[opponent].current_health < rival_health)
	_check(hud._players[opponent].current_health == rival_health - 10, "CTRL retains its physical attack after using spells and menus")
	_check(hud._players[local_id].current_mana == 2985, "CTRL does not consume mana after magic")
	_check(root.gui_get_focus_owner() == null, "Combat UI interactions do not capture movement keys")
	await create_timer(0.2).timeout
	main._disconnect_from_arena()
	_check(controller.aimed_spell_id == 0 and not controller.session_active, "Disconnect clears aiming and pending spell state")
	_finish()


func _wait_for(predicate: Callable, duration: float = 8.0) -> void:
	var deadline := Time.get_ticks_msec() + int(duration * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout


func _click(button: Control) -> void:
	await _click_at(button.get_global_rect().get_center())


func _click_world(peer_id: int) -> void:
	var avatar = world._avatars[peer_id]
	await _click_at(world.get_global_transform() * (avatar.position + Vector2(0, -25)))


func _click_at(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _drag(source: Control, target: Control) -> void:
	var start := source.get_global_rect().get_center()
	var finish := target.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = start
	hover.global_position = start
	Input.parse_input_event(hover)
	await process_frame
	var down := InputEventMouseButton.new()
	down.position = start
	down.global_position = start
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var previous := start
	for point: Vector2 in [start + Vector2(20, 15), finish]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.relative = point - previous
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await process_frame
		previous = point
	var up := InputEventMouseButton.new()
	up.position = finish
	up.global_position = finish
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _key(code: int, pressed: bool) -> void:
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


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)


func _finish() -> void:
	manager.stop()
	print("AO network checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
