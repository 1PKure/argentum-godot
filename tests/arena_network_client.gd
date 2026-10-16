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
	# Keep test drags deterministic and out of the real saved preference.
	hud._inventory_layout.storage_path = ""
	hud._inventory_layout.actions = ArenaInventoryLayout.new().actions
	for index in range(hud._inventory_slots.size()):
		hud._inventory_slots[index].configure(index, hud._inventory_layout)
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
		network.request_cast(350, hud._players[opponent].grid_position, 2)
		await _wait_for(func() -> bool: return hud._players[opponent].active_effects.has("Inmovilizado"))
		_check(hud._players[opponent].active_effects.has("Inmovilizado"), "Root status is synchronized to the other client")
		await _wait_for(func() -> bool: return not hud._players[opponent].active_effects.has("Inmovilizado"))
		await create_timer(1.3).timeout
		network.request_cast(53, hud._players[opponent].grid_position, 3)
		await _wait_for(func() -> bool: return hud._players[local_id].current_mana == 1810)
		_check(hud._players[local_id].current_mana == 1810, "Remote Apocalypse keeps its original 1000 mana cost")
		await _wait_for(func() -> bool: return hud._players[opponent].is_meditating)
		var med_health: int = hud._players[opponent].current_health
		var med_mana: int = hud._players[opponent].current_mana
		_check(hud._players[opponent].is_meditating and world._avatars[opponent]._meditation_fx.visible, "Other client sees the confirmed meditation and its FX")
		await _wait_for(func() -> bool: return hud._players[opponent].current_health > med_health)
		_check(hud._players[opponent].current_health == med_health + 27 and hud._players[opponent].is_meditating, "Other client sees a red potion without a meditation interruption")
		await _wait_for(func() -> bool: return hud._players[opponent].current_mana > med_mana)
		_check(hud._players[opponent].current_mana == med_mana + 150 and hud._players[opponent].is_meditating, "Other client sees a blue potion without a meditation interruption")
		await _wait_for(func() -> bool: return hud._players.size() == 1, 35.0)
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
	var healing_fx = world._spell_effects[-1]
	_key(KEY_D, true)
	await create_timer(0.15).timeout
	_key(KEY_D, false)
	await process_frame
	_check(is_instance_valid(healing_fx) and healing_fx.target.is_equal_approx(world._avatars[local_id].position), "Healing FX follows the actual moving avatar after a confirmed cast")
	_check(is_instance_valid(healing_fx) and healing_fx._words.position.is_equal_approx(world._avatars[local_id].position + Vector2(-100, -107)), "Incantation follows the moving caster through the scrolling camera")
	await _capture("ao-macro-heal.png")
	_key(KEY_1, true)
	_key(KEY_1, false)
	await process_frame
	# Pick an empty tile visible from the current camera. Tile (0, 0) can be
	# outside the game viewport after the additional healing-follow movement.
	var empty_tile: Vector2i = hud._players[local_id].grid_position + Vector2i(0, 2)
	var point: Vector2 = world.get_global_transform() * world._grid_to_world(empty_tile)
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
	await _click_at(point, MOUSE_BUTTON_RIGHT)
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
	await _wait_for(func() -> bool: return hud._players[local_id].active_effects.has("Inmovilizado"))
	_check(hud._players[local_id].active_effects.has("Inmovilizado"), "Opponent root is visible in local authoritative state")
	var rooted_tile: Vector2i = hud._players[local_id].grid_position
	_key(KEY_A, true)
	await create_timer(0.2).timeout
	_key(KEY_A, false)
	_check(hud._players[local_id].grid_position == rooted_tile, "Movement input cannot bypass an authoritative root")
	await create_timer(0.85).timeout
	await _search_spell(27)
	await _click(hud._launch_button)
	await _click_world(local_id)
	await _wait_for(func() -> bool: return hud._players[local_id].active_effects.is_empty())
	_check(hud._players[local_id].active_effects.is_empty(), "Manual Remove Paralysis works while the caster is rooted")
	await _wait_for(func() -> bool: return hud._players[local_id].current_health < 450)
	var life_before: int = hud._players[local_id].current_health
	await _click(hud._health_potion_button)
	await _wait_for(func() -> bool: return hud._players[local_id].current_health > life_before)
	_check(hud._players[local_id].current_health == life_before + 27, "Actual GUI red potion restores 27 health on the server")
	await create_timer(0.42).timeout
	var mana_before: int = hud._players[local_id].current_mana
	_key(KEY_E, true)
	_key(KEY_E, false)
	await _wait_for(func() -> bool: return hud._players[local_id].current_mana > mana_before)
	_check(hud._players[local_id].current_mana == mana_before + 150, "Blue-potion hotkey restores 5 percent of 3000 mana")
	hud.show_inventory()
	var drag_health: int = hud._players[local_id].current_health
	var drag_mana: int = hud._players[local_id].current_mana
	await _drag(hud._inventory_slots[0], hud._inventory_slots[8])
	_check(hud._inventory_slots[0].action == "" and hud._inventory_slots[8].action == "health_potion", "Actual GUI drag moves a potion into an empty inventory slot")
	await _drag(hud._inventory_slots[8], hud._inventory_slots[1])
	_check(hud._inventory_slots[1].action == "health_potion" and hud._inventory_slots[8].action == "mana_potion", "Actual GUI drag swaps occupied potion slots")
	await _drag(hud._inventory_slots[8], hud._name_label)
	_check(hud._inventory_slots[8].action == "mana_potion", "Dropping outside inventory leaves the potion in its original slot")
	await _drag(hud._inventory_slots[8], hud._hotkey_buttons[0])
	_check(hud._inventory_slots[8].action == "mana_potion" and controller.bindings[0] == 1, "Potion drag cannot replace a spell hotkey")
	_check(hud._players[local_id].current_health == drag_health and hud._players[local_id].current_mana == drag_mana, "Moving, swapping and cancelling drags never drinks a potion")
	_check(hud._inventory_layout.actions.count("health_potion") == 1 and hud._inventory_layout.actions.count("mana_potion") == 1, "GUI rearrangement preserves exactly one supply of each type")
	# Leave enough room to test both potions plus a meditation tick.
	for index in range(60):
		root.get_node("PlayerNetwork").request_debug_mana_spend()
	await _wait_for(func() -> bool: return hud._players[local_id].current_mana == drag_mana - 600)
	mana_before = hud._players[local_id].current_mana
	_key(KEY_M, true)
	_key(KEY_M, false)
	await _wait_for(func() -> bool: return hud._players[local_id].is_meditating)
	await create_timer(0.3).timeout
	_check(hud._players[local_id].is_meditating and hud._players[local_id].current_mana == mana_before, "Meditation key starts its warmup with no instant mana")
	await _click(hud._inventory_slots[1])
	await _wait_for(func() -> bool: return hud._players[local_id].current_health > drag_health)
	_check(hud._players[local_id].current_health == drag_health + 27 and hud._players[local_id].is_meditating, "Clicking the moved red potion restores health while meditation continues")
	await create_timer(0.42).timeout
	await _click(hud._inventory_slots[8])
	await _wait_for(func() -> bool: return hud._players[local_id].current_mana > mana_before)
	_check(hud._players[local_id].current_mana == mana_before + 150 and hud._players[local_id].is_meditating, "Clicking the moved blue potion restores mana while meditation continues")
	await _wait_for(func() -> bool: return hud._players[local_id].current_mana >= mana_before + 300)
	_check(hud._players[local_id].current_mana == mana_before + 300 and hud._players[local_id].is_meditating, "Meditation still regenerates after both potions")
	_check(world._avatars[local_id]._meditation_fx != null and world._avatars[local_id]._meditation_fx.visible, "Confirmed meditation displays the original AO20 looping FX")
	_check(world._avatars[local_id]._meditation_fx.scale == Vector2.ONE * 1.05 and world._avatars[local_id]._meditation_fx.z_index > 0, "Live meditation uses the smaller effect in front of the avatar")
	await _capture("arena-meditation.png")
	_key(KEY_A, true)
	await create_timer(0.15).timeout
	_key(KEY_A, false)
	await _wait_for(func() -> bool: return not hud._players[local_id].is_meditating)
	_check(not hud._players[local_id].is_meditating and not world._avatars[local_id]._meditation_fx.visible, "Walking stops synchronized meditation and its effect")
	await create_timer(0.2).timeout
	var avatar_point: Vector2 = world.get_global_transform() * world._avatars[local_id].position
	_check(avatar_point.distance_to(hud.game_area.get_global_rect().get_center()) < 1.0, "Following camera keeps the interpolated local tile centered")
	await _search_spell(53)
	await _click(hud._launch_button)
	mana_before = hud._players[local_id].current_mana
	var target_life: int = hud._players[opponent].current_health
	await _click_world(opponent)
	await _wait_for(func() -> bool: return hud._players[local_id].current_mana == mana_before - 1000)
	var apoc_damage: int = target_life - hud._players[opponent].current_health
	_check(hud._players[local_id].current_mana == mana_before - 1000 and apoc_damage >= 92 and apoc_damage <= 98, "Search, Launch and camera-adjusted target resolve original Apocalypse")
	await _capture("arena-apocalypse.png")
	await _click(hud._show_catalog)
	await _search_spell(7)
	_check(hud._spell_buttons[7].visible and hud._launch_button.disabled and hud._spell_status.text.contains("invocaciones"), "Full catalog discloses unavailable summons and disables Launch")
	var player_network = root.get_node("PlayerNetwork")
	for index in range(50):
		player_network.request_debug_damage()
	await _wait_for(func() -> bool: return not hud._players[local_id].is_alive)
	_check(not hud._players[local_id].is_alive and not hud._stats_button.disabled, "Death enables the arena Respawn action")
	await _click(hud._stats_button)
	await _wait_for(func() -> bool: return hud._players[local_id].is_alive)
	_check(hud._players[local_id].is_alive and hud._players[local_id].current_health == 500 and hud._players[local_id].current_mana == 3000, "GUI Respawn restores the server test profile")
	await create_timer(0.15).timeout
	_check(world._avatars[local_id].position.distance_to(world._grid_to_world(hud._players[local_id].grid_position)) < 0.1, "Respawn teleports instead of replaying the old movement path")
	for resolution: Vector2i in [Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1280, 720)]:
		root.size = resolution
		hud._fit_interface()
		await process_frame
		var frame_rect := Rect2(hud._frame.position, hud._frame.size * hud._frame.scale)
		_check(frame_rect.size.distance_to(hud.get_viewport_rect().size) < 0.5, "Interface fills the entire viewport at %s" % resolution)
	await _capture("arena-responsive-catalog.png")
	await create_timer(0.2).timeout
	main._disconnect_from_arena()
	_check(controller.aimed_spell_id == 0 and not controller.session_active, "Disconnect clears aiming and pending spell state")
	_finish()


func _search_spell(id: int) -> void:
	hud.show_spells()
	await _click(hud._spell_search)
	_key(KEY_A, true, true)
	_key(KEY_A, false, true)
	for character in str(id):
		var key := InputEventKey.new()
		key.keycode = character.unicode_at(0)
		key.unicode = character.unicode_at(0)
		key.pressed = true
		Input.parse_input_event(key)
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
	await process_frame
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	await process_frame
	await process_frame
	await _click(hud._spell_buttons[id])


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


func _key(code: int, pressed: bool, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = control
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
