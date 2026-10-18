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
var received_states: Array[Dictionary] = []
var received_spells: Array[Dictionary] = []
var received_recovery: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	manager = root.get_node("NetworkManager")
	network = root.get_node("SpellNetwork")
	root.get_node("PlayerNetwork").player_stats_updated.connect(func(data: Dictionary) -> void: received_states.append(data))
	network.spell_resolved.connect(func(data: Dictionary) -> void: received_spells.append(data))
	root.get_node("RecoveryNetwork").action_resolved.connect(func(data: Dictionary) -> void: received_recovery.append(data))
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	hud = main._hud
	controller = main._spell_controller
	world = main._world
	await _wait_for(func() -> bool: return hud._players.size() == 2 and controller.server_ready)
	_check(hud._players.size() == 2 and controller.server_ready, "Two clients negotiate protocol 11")
	if hud._players.size() != 2 or not controller.server_ready:
		await _finish()
		return
	local_id = root.multiplayer.get_unique_id()
	var opponent := 0
	for id: int in hud._players:
		if id != local_id:
			opponent = id
	_check(hud._players[opponent].mana_is_private and hud._players[opponent].current_mana == 0 and hud._players[local_id].current_mana == hud._players[local_id].max_mana, "Snapshot preserves own mana and hides rival mana")
	if "--spell-target" in OS.get_cmdline_user_args():
		root.get_node("PlayerNetwork").request_move(MovementRules.Direction.SOUTH)
		await _wait_for(func() -> bool: return hud._players[opponent].class_id == 8)
		_check(hud._players[opponent].class_id == 8, "Remote client sees free hunter selection")
		await _wait_for(func() -> bool: return not hud._players[opponent].equipped_items.has("weapon"))
		_check(not world._avatars[opponent]._player_visual._equipped_items.has("weapon"), "Remote client removes an unequipped bow")
		await _wait_for(func() -> bool: return hud._players[opponent].equipped_items.has("weapon"))
		_check(world._avatars[opponent]._player_visual._equipped_items.has("weapon"), "Remote client restores a reequipped bow")
		_check(received_spells.any(func(event: Dictionary) -> bool: return int(event.spell_id) == 25 and not event.has("mana_cost")) and hud.console.get_parsed_text().contains("te lanzó Paralizar"), "Target receives named Paralizar feedback without the opponent's mana cost")
		_check(received_recovery.is_empty(), "Rival class and recovery confirmations are never sent to this client")
		_check(not received_spells.is_empty() and not received_spells[0].has("mana_cost"), "Rival shot event exposes no mana cost")
		_check(hud.console.entries.all(func(entry: Dictionary) -> bool: return not str(entry.text).contains("Preset") and not str(entry.text).contains("Usó")), "Other player's preset and recovery notices never enter the console")
		_check(received_states.all(func(data: Dictionary) -> bool: return int(data.peer_id) == local_id or not data.has("current_mana")), "All remote stat payloads omit current mana")
		await _wait_for(func() -> bool: return hud._players[opponent].class_id == 4)
		_check(hud._players[opponent].inventory.has(1108) and world._avatars[opponent]._player_visual._class_id == 4, "Remote client receives assassin inventory and visual")
		await _wait_for(func() -> bool: return hud._players.size() == 1, 20)
		await _finish()
		return
	_check(controller.bindings[0] == 25 and controller.bindings[1] == 27 and controller.bindings[2] == 51 and controller.bindings[3] == 31, "Fresh mage macro bar follows control, remover, damage, healing")
	_check(hud._inventory_layout.actions.count("item:519") == 1 and hud._inventory_layout.equipped_ids.has(519), "Equipped mage armor is an inventory item")
	_check(_sharp_scale(1), "Default 1x gives the wider AO reference field of view")
	var player_network = root.get_node("PlayerNetwork")
	for step in range(6):
		player_network.request_move(MovementRules.Direction.EAST)
		await create_timer(0.14).timeout
	await _wait_for(func() -> bool: return hud._players[opponent].grid_position.y == 6)
	var mana_before: int = hud._players[local_id].current_mana
	_key(KEY_1, true)
	_key(KEY_1, false)
	await _click_world(opponent)
	await _wait_for(func() -> bool: return controller.pending_request == 0 and hud._players[local_id].current_mana < mana_before)
	_check(hud._players[local_id].current_mana == mana_before - 375 and received_spells[-1].mana_cost == 375, "Only the casting player receives their spell cost and actual remaining mana")
	await _choose_class(8)
	_check(hud._players[local_id].class_id == 8 and not hud._class_panel.visible, "Choosing hunter applies immediately without resource or timer restrictions")
	_check(not hud._players[local_id].inventory.has(37) and not hud._inventory_layout.actions.has("mana_potion") and hud._mana_potion_button.disabled, "Hunter inventory and HUD contain no blue potion supply")
	_check(controller.bindings[2] == -1 and hud._hotkey_buttons[2].icon != null, "Hunter macro 3 contains its physical bow action")
	var health: int = hud._players[opponent].current_health
	_key(KEY_CTRL, true)
	_key(KEY_CTRL, false)
	await process_frame
	_check(controller.aimed_attack and hud._players[opponent].current_health == health, "CTRL arms the bow cursor without firing or spending resources")
	await _click_at(hud.game_area.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	_check(not controller.aimed_attack and hud._players[opponent].current_health == health, "Right click cancels the bow without a shot")
	_key(KEY_3, true)
	_key(KEY_3, false)
	await process_frame
	_check(controller.aimed_attack, "Macro 3 arms the same hunter targeting mode")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	_check(not controller.aimed_attack, "Escape cancels physical targeting")
	_key(KEY_CTRL, true)
	_key(KEY_CTRL, false)
	_key(KEY_A, true)
	await create_timer(0.16).timeout
	_key(KEY_A, false)
	_check(controller.aimed_attack, "Hunter keeps aiming while moving")
	await _click_world(opponent)
	await _wait_for(func() -> bool: return controller.pending_request == 0 and hud._players[opponent].current_health < health)
	_check(hud._players[opponent].current_health < health and not controller.aimed_attack and hud._players[local_id].current_mana == 0, "Clicking a diagonal rival confirms physical damage with zero mana")
	_check(world._spell_effects.size() > 0, "Confirmed arrow creates visible projectile feedback")
	var arrow = world._spell_effects[-1]
	_check(arrow._is_shot and arrow._audio != null and arrow._audio.stream.resource_path.ends_with("2542.ogg"), "Real hunter hit loads the original AO20 arrow sound")
	_check(health - hud._players[opponent].current_health >= 181 and health - hud._players[opponent].current_health <= 200, "Equipped hunter deals 181-200 damage to the equipped mage")
	var protected_health: int = hud._players[opponent].current_health
	var spam_start := Time.get_ticks_msec()
	var attempts := 0
	while Time.get_ticks_msec() - spam_start < 750:
		if attempts % 2 == 0:
			_key(KEY_CTRL, true)
			_key(KEY_CTRL, false)
		else:
			_key(KEY_3, true)
			_key(KEY_3, false)
		await _click_world(opponent)
		await _wait_for(func() -> bool: return controller.pending_request == 0)
		attempts += 1
	_check(attempts >= 4 and hud._players[opponent].current_health == protected_health and hud.console.get_parsed_text().contains("intervalo del arco"), "Repeated CTRL/macro clicks cannot land another arrow during the dedicated server cooldown")
	_check(is_instance_valid(arrow) and arrow._shot_sound_played and arrow._audio.playing, "Confirmed arrow plays its audio after reaching the target")
	await _capture("refined-bow-shot.png")
	await _click(hud._inventory_button)
	var weapon_id: int = hud._players[local_id].equipped_items.weapon
	var source: int = hud._players[local_id].inventory.find(weapon_id)
	var hp: int = hud._players[local_id].current_health
	await _drag(hud._inventory_slots[source], hud._inventory_slots[41])
	await _wait_for(func() -> bool: return hud._players[local_id].inventory[41] == weapon_id)
	_check(hud._players[local_id].inventory[41] == weapon_id and hud._players[local_id].equipped_items.weapon == weapon_id and hud._players[local_id].current_health == hp, "Dragging equipped bow moves its server item without unequipping or using a potion")
	await _click(hud._inventory_slots[41])
	await _wait_for(func() -> bool: return not hud._players[local_id].equipped_items.has("weapon"))
	_check(not world._avatars[local_id]._player_visual._equipped_items.has("weapon") and not hud._inventory_slots[41]._equipped_badge.visible, "Inventory click unequips moved bow in state, avatar and badge")
	await create_timer(0.25).timeout
	_key(KEY_CTRL, true)
	_key(KEY_CTRL, false)
	await _click_world(opponent)
	await _wait_for(func() -> bool: return controller.pending_request == 0)
	_check(hud.console.get_parsed_text().contains("Equipá el arco"), "Unequipped bow is rejected with useful server feedback")
	await _click(hud._inventory_slots[41])
	await _wait_for(func() -> bool: return hud._players[local_id].equipped_items.has("weapon"))
	_check(hud._inventory_slots[41]._equipped_badge.visible, "Click reequips the same inventory object")
	await create_timer(0.25).timeout
	player_network.request_debug_damage()
	await _wait_for(func() -> bool: return hud._players[local_id].current_health < hp)
	await _choose_class(4)
	_check(hud._players[local_id].class_id == 4 and hud._players[local_id].current_health == hud._players[local_id].max_health, "Injured hunter switches directly to a fully prepared assassin")
	_check(controller.bindings[0] == 25 and controller.bindings[1] == 27 and controller.bindings[2] == 3 and controller.bindings[3] == 31, "Hybrid macro bar keeps the same action categories with its allowed damage spell")
	_check(not hud._players[local_id].inventory.has(1876) and hud._players[local_id].inventory.has(1108), "Changing preset replaces old equipment rather than accumulating free items")
	await _capture("refined-inventory-equipped.png")
	await _click(hud._reserved_buttons[0])
	_check(hud._class_panel.selector.item_count == 9, "Selector excludes worker, pirate and thief")
	await _capture("refined-class-preview.png")
	hud._class_panel.close_panel()
	await _click(hud._reserved_buttons[1])
	_check(_sharp_scale(2), "Zoom control switches the world to exact 2x")
	await _click(hud._reserved_buttons[1])
	_check(_sharp_scale(1), "Zoom control restores exact 1x")
	root.size = Vector2i(1280, 720)
	hud._fit_interface()
	await process_frame
	await process_frame
	_check(_sharp_scale(1), "Fractional window resize still preserves an integer source-pixel scale")
	await _capture("refined-pixel-resized.png")
	main._disconnect_from_arena()
	await _finish()

func _sharp_scale(expected: float) -> bool:
	return absf(world.get_screen_transform().get_scale().x * float(world.VISUAL_SCALE) - expected) < 0.01

func _choose_class(id: int) -> void:
	await _click(hud._reserved_buttons[0])
	var panel = hud._class_panel
	panel.selector.select(panel.selector.get_item_index(id))
	panel.selector.item_selected.emit(panel.selector.selected)
	await process_frame
	await process_frame
	await _click(panel.apply_button)
	await _wait_for(func() -> bool: return hud._players[local_id].class_id == id)

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
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var previous := start
	for point: Vector2 in [start + Vector2(20, 15), finish]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.relative = point - previous
		motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
		Input.parse_input_event(motion)
		await process_frame
		previous = point
	var up := InputEventMouseButton.new()
	up.position = finish
	up.global_position = finish
	up.button_index = MOUSE_BUTTON_RIGHT
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
	# Release active FX/audio while the engine is still processing frames.
	# Immediate process exit can leave an audio playback pending in the mixer.
	world.clear_session()
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Preset interaction checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
