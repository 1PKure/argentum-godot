extends SceneTree

var checks := 0
var failures := 0
var main: Node
var hud: Control
var controller: Node
var recovery: Node
var local_id := 0
var drinks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	recovery = root.get_node("RecoveryNetwork")
	recovery.action_resolved.connect(func(event: Dictionary) -> void:
		if str(event.action).ends_with("potion"):
			drinks.append(event.duplicate(true))
	)
	main = load("res://client/scenes/client_main.tscn").instantiate()
	root.add_child(main)
	hud = main._hud
	controller = main._spell_controller
	hud._inventory_layout.storage_path = ""
	await _wait_for(func() -> bool: return controller.server_ready and hud._players.size() == 1)
	_check(controller.server_ready and hud._players.size() == 1, "Potion client connects to the matching dedicated protocol")
	if not controller.server_ready:
		await _finish()
		return
	local_id = root.multiplayer.get_unique_id()
	_check(recovery.selected_potion == "health_potion" and hud._inventory_slots[0].potion_selected, "Red potion starts selected with a visible inventory marker")
	_check(hud._inventory_panel.get_children().all(func(child: Node) -> bool: return not child is Label), "Inventory contains no persistent class or equipment summary text")
	await _spend(80)
	var mana := _mana()
	await _click(hud._inventory_slots[1])
	await _wait_for(func() -> bool: return _mana() > mana)
	_check(_mana() == mana + 124 and recovery.selected_potion == "mana_potion" and hud._inventory_slots[1].potion_selected, "Click selects blue and drinks its real server amount")
	controller.bindings[0] = 12
	controller.changed.emit()
	_key(KEY_1, true)
	_key(KEY_1, false)
	await create_timer(0.35).timeout
	drinks.clear()
	_key(KEY_SPACE, true, true)
	await create_timer(1.1).timeout
	_key(KEY_SPACE, false)
	await create_timer(0.15).timeout
	var single_count := drinks.size()
	_check(single_count >= 3 and single_count <= 5 and drinks.all(func(event: Dictionary) -> bool: return event.source == "use"), "Holding Space, including with CTRL, repeats the selected potion at the normal Use cadence")
	_check(controller.aimed_spell_id == 12 and hud._inventory_panel.visible, "Space potions preserve the macro cursor and inventory tab")
	mana = _mana()
	await create_timer(0.4).timeout
	_check(_mana() == mana and not recovery.using_selected, "Releasing Space stops potion repetition")
	await _spend(100)
	await create_timer(0.35).timeout
	drinks.clear()
	_key(KEY_SPACE, true)
	await create_timer(0.21).timeout
	await _click(hud._inventory_slots[1])
	await create_timer(0.4).timeout
	await _click(hud._inventory_slots[1])
	await create_timer(0.45).timeout
	_key(KEY_SPACE, false)
	await create_timer(0.15).timeout
	print("Potion rhythm: Space=%d; click+Space=%d" % [single_count, drinks.size()])
	_check(drinks.size() > single_count and drinks.any(func(event: Dictionary) -> bool: return event.source == "click") and drinks.any(func(event: Dictionary) -> bool: return event.source == "use"), "Combining inventory clicks and held Use produces more confirmed potions than Use alone")
	_check(controller.aimed_spell_id == 12 and hud._inventory_panel.visible, "Combined potions keep the prepared spell ready")
	await create_timer(0.4).timeout
	mana = _mana()
	var inventory: Array[int] = hud._players[local_id].inventory.duplicate()
	await _drag(hud._inventory_slots[1], hud._inventory_slots[8], MOUSE_BUTTON_LEFT)
	_check(hud._players[local_id].inventory == inventory and _mana() == mana, "Left-button pointer movement cannot rearrange or accidentally consume a potion")
	await _mouse(hud._inventory_slots[1].get_global_rect().get_center(), true, MOUSE_BUTTON_RIGHT)
	await _mouse(hud._inventory_slots[1].get_global_rect().get_center(), false, MOUSE_BUTTON_RIGHT)
	_check(hud._players[local_id].inventory == inventory and _mana() == mana, "A right click without dragging neither moves nor drinks the potion")
	await _drag(hud._inventory_slots[1], hud._inventory_slots[8])
	_check(hud._inventory_slots[8].action == "mana_potion" and hud._inventory_slots[8].potion_selected and not hud._inventory_slots[1].potion_selected and _mana() == mana, "Dragging a selected potion preserves selection by item and never drinks it")
	await _mouse(hud._inventory_slots[8].get_global_rect().get_center(), true, MOUSE_BUTTON_RIGHT)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _mouse(hud._inventory_slots[9].get_global_rect().get_center(), false, MOUSE_BUTTON_RIGHT)
	_check(hud._inventory_move.is_empty() and hud._inventory_slots[8].action == "mana_potion" and _mana() == mana and controller.aimed_spell_id == 12, "Escape cancels an inventory move without consuming the potion or cancelling the prepared spell")
	await _mouse(hud._inventory_slots[8].get_global_rect().get_center(), true, MOUSE_BUTTON_RIGHT)
	hud._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _mouse(hud._inventory_slots[9].get_global_rect().get_center(), false, MOUSE_BUTTON_RIGHT)
	_check(hud._inventory_move.is_empty() and hud._inventory_slots[8].action == "mana_potion", "Focus loss cancels a right-button inventory move")
	await _mouse(hud._inventory_slots[8].get_global_rect().get_center(), true, MOUSE_BUTTON_RIGHT)
	# A held mouse button owns GUI mouse focus; open the modal through its public
	# action to exercise cancellation independently of that pointer capture.
	hud.set_menu_opened(true)
	await _mouse(hud._inventory_slots[9].get_global_rect().get_center(), false, MOUSE_BUTTON_RIGHT)
	_check(hud._menu_panel.visible and hud._inventory_move.is_empty() and hud._inventory_slots[8].action == "mana_potion", "Opening a modal cancels a pending inventory move")
	await _click(hud._menu_close_button)
	controller.aim_spell(12)
	await _click(hud._use_button)
	await _wait_for(func() -> bool: return _mana() > mana)
	_check(_mana() == mana + 124 and controller.aimed_spell_id == 12, "The visible Use button drinks the moved selected potion without losing aim")
	mana = _mana()
	await _click(hud._inventory_slots[0])
	await _click(hud._use_button)
	await create_timer(0.3).timeout
	_check(recovery.selected_potion == "health_potion" and hud._inventory_slots[0].potion_selected and _mana() == mana, "A full resource potion can still be selected without consuming the other resource")
	await _click(hud._inventory_slots[8])
	await create_timer(0.35).timeout
	await _spend(100)
	_key(KEY_SPACE, true)
	await create_timer(0.1).timeout
	await _click(hud._menu_button)
	await create_timer(0.15).timeout
	mana = _mana()
	await create_timer(0.45).timeout
	_check(hud._menu_panel.visible and not recovery.using_selected and _mana() == mana, "Opening a modal stops held Use and clears queued potion inputs")
	await _click(hud._menu_close_button)
	await create_timer(0.35).timeout
	_check(_mana() == mana, "Closing the modal does not resume a key that was already held")
	_key(KEY_SPACE, false)
	_key(KEY_SPACE, true)
	await create_timer(0.1).timeout
	recovery._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await create_timer(0.15).timeout
	mana = _mana()
	await create_timer(0.4).timeout
	_check(not recovery.using_selected and _mana() == mana, "Losing application focus stops held Use")
	_key(KEY_SPACE, false)
	hud.show_spells()
	hud._spell_search.grab_focus()
	mana = _mana()
	_key(KEY_SPACE, true)
	await create_timer(0.3).timeout
	_key(KEY_SPACE, false)
	_check(not recovery.using_selected and _mana() == mana, "Space typed into spell search does not drink potions")
	await _click(hud._spell_buttons[1])
	_check(root.gui_get_focus_owner() == null, "Choosing a spell releases text focus so gameplay keys resume")
	hud.show_inventory()
	await _capture()
	await _choose_class(3)
	_check(recovery.selected_potion == "health_potion" and not hud._players[local_id].inventory.has(37) and hud._inventory_slots[0].potion_selected, "Switching from a selected blue to a nonmagical preset selects its red supply")
	_key(KEY_E, true)
	_key(KEY_E, false)
	await process_frame
	_check(recovery.selected_potion == "health_potion", "The blue hotkey cannot select an absent potion on a nonmagical class")
	var hp := int(hud._players[local_id].current_health)
	root.get_node("PlayerNetwork").request_debug_damage()
	await _wait_for(func() -> bool: return int(hud._players[local_id].current_health) < hp)
	_key(KEY_SPACE, true)
	await _wait_for(func() -> bool: return int(hud._players[local_id].current_health) == hp)
	_key(KEY_SPACE, false)
	_check(int(hud._players[local_id].current_health) == hp, "Space remains usable on the warrior red preset after changing classes")
	main._disconnect_from_arena()
	_check(not recovery.using_selected and recovery.selected_potion == "health_potion" and recovery._pending_potion == 0, "Disconnect clears selection, held input and pending recovery state")
	# Let the last potion sound finish before destroying the test's audio player.
	await create_timer(1.0).timeout
	await _finish()

func _spend(count: int) -> void:
	var before := _mana()
	var actual := mini(count, maxi(0, (before - 20) / 10))
	for index in range(actual):
		root.get_node("PlayerNetwork").request_debug_mana_spend()
	await _wait_for(func() -> bool: return _mana() == before - actual * 10)

func _mana() -> int:
	return hud._players[local_id].current_mana

func _wait_for(predicate: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 7000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout

func _click(button: Control) -> void:
	await _mouse(button.get_global_rect().get_center(), true)
	await _mouse(button.get_global_rect().get_center(), false)
	await process_frame

func _mouse(point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _drag(source: Control, target: Control, button: MouseButton = MOUSE_BUTTON_RIGHT) -> void:
	var a := source.get_global_rect().get_center()
	var b := target.get_global_rect().get_center()
	await _mouse(a, true, button)
	var previous := a
	for step in range(1, 7):
		var motion := InputEventMouseMotion.new()
		motion.position = a.lerp(b, float(step) / 6)
		motion.global_position = motion.position
		motion.relative = motion.position - previous
		previous = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await process_frame
	await _mouse(b, false, button)
	await create_timer(0.15).timeout

func _choose_class(id: int) -> void:
	await _click(hud._reserved_buttons[0])
	var panel = hud._class_panel
	panel.selector.select(panel.selector.get_item_index(id))
	panel.selector.item_selected.emit(panel.selector.selected)
	await process_frame
	await _click(panel.apply_button)
	await _wait_for(func() -> bool: return int(hud._players[local_id].class_id) == id)


func _key(code: Key, pressed: bool, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.ctrl_pressed = control
	event.physical_keycode = code
	event.pressed = pressed
	if code == KEY_SPACE and pressed:
		event.unicode = 32
	Input.parse_input_event(event)

func _capture() -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var directory := OS.get_environment("AO_UI_CAPTURE_DIR")
		if not directory.is_empty():
			root.get_texture().get_image().save_png(directory.path_join("selected-potion-use.png"))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func _finish() -> void:
	root.get_node("NetworkManager").stop()
	main.queue_free()
	await process_frame
	print("Potion Use checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
