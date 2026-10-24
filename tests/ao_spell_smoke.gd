extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog = load("res://shared/gameplay/spell_catalog.gd")
	_check(catalog.get_spell(1).name == "Dardo Mágico", "Spell names come from the original AO20 DAT")
	_check(catalog.get_spell(1).mana == 10 and catalog.get_spell(1).min_amount == 5 and catalog.get_spell(1).max_amount == 10, "Dart keeps original AO20 cost and damage")
	_check(catalog.get_spell(12).mana == 5 and catalog.get_spell(12).effect == "healing", "Minor heal keeps original AO20 cost and effect")
	_check(catalog.get_spell(13).mana == 60 and catalog.get_spell(13).max_amount == 40, "Major heal keeps original AO20 values")
	_check(not catalog.is_available(7), "Unsupported spells cannot be granted by a request")
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var caster: PlayerState = registry.add_player(101)
	var target: PlayerState = registry.add_player(102)
	caster.max_health = 100
	caster.current_health = 100
	caster.max_mana = 100
	caster.current_mana = 100
	target.max_health = 100
	target.current_health = 100
	var result: Dictionary = registry.try_cast_spell(101, 1, target.grid_position, 1)
	_check(result.ok, "A valid spell resolves on the server")
	_check(target.current_health >= 76 and target.current_health <= 88, "Server applies DAT damage with AO20 level and equipped modifiers")
	_check(caster.current_mana == 90, "A successful cast consumes mana exactly once")
	_check(result.event.spell_id == 1 and result.event.caster_id == 101, "Confirmed event identifies spell and actual caster")
	var remaining_health := target.current_health
	result = registry.try_cast_spell(101, 1, target.grid_position, 1)
	_check(not result.ok and target.current_health == remaining_health and caster.current_mana == 90, "Duplicate request cannot double-spend or double-hit")
	result = registry.try_cast_spell(101, 1, target.grid_position, 2)
	_check(not result.ok and result.remaining_msec > 0 and caster.current_mana == 90, "Spell interval rejects an early repeat without spending mana")
	_check(registry.try_basic_attack(101) == null, "Spell-to-attack interval is enforced")
	result = registry.try_cast_spell(101, 1, Vector2i(5, 0), 3)
	_check(not result.ok and caster.current_mana == 90, "Empty target does not consume mana")
	result = registry.try_cast_spell(101, 1, Vector2i(50, 50), 4)
	_check(not result.ok, "Targets outside the arena are rejected")
	result = registry.try_cast_spell(101, 7, target.grid_position, 5)
	_check(not result.ok, "A spell outside the loadout is rejected")
	result = registry.try_cast_spell(101, 1, caster.grid_position, 6)
	_check(not result.ok, "Offensive targeting requires a rival")
	registry._last_spell_time[101] = -2000
	caster.apply_damage(30)
	result = registry.try_cast_spell(101, 12, caster.grid_position, 7)
	_check(result.ok and caster.current_health >= 75 and caster.current_health <= 90, "Minor heal can target the caster")
	_check(caster.current_mana == 85 and result.event.effect == "healing", "Heal resolves with correct cost and event")
	registry._last_spell_time[101] = -2000
	caster.current_mana = 0
	remaining_health = target.current_health
	result = registry.try_cast_spell(101, 2, target.grid_position, 8)
	_check(not result.ok and target.current_health == remaining_health and caster.current_mana == 0, "Insufficient mana has no effect on either actor")
	caster.current_mana = 100
	registry._last_attack_time[101] = Time.get_ticks_msec()
	result = registry.try_cast_spell(101, 1, target.grid_position, 9)
	_check(not result.ok and caster.current_mana == 100, "Attack-to-spell interval is enforced")
	registry._last_attack_time[101] = -2000
	target.apply_damage(100)
	result = registry.try_cast_spell(101, 12, target.grid_position, 10)
	_check(not result.ok and caster.current_mana == 100, "A dead target cannot consume spell resources")
	caster.apply_damage(100)
	result = registry.try_cast_spell(101, 12, caster.grid_position, 11)
	_check(not result.ok and caster.current_mana == 100, "Ghosts cannot cast spells")
	registry.queue_free()
	await process_frame
	var hud = load("res://client/ui/combat_hud.gd").new()
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	root.add_child(hud)
	hud.mount_world(world)
	var controller = load("res://client/input/spell_targeting_controller.gd").new()
	root.add_child(controller)
	controller.setup(world, hud.game_area)
	hud.configure_spells(controller)
	controller.session_active = true
	controller.server_ready = true
	controller.select_spell(12)
	_check(controller.selected_spell_id == 12 and controller.aimed_spell_id == 0, "Manual spell selection does not arm or cast")
	controller.aim_selected()
	_check(controller.aimed_spell_id == 12, "Launch arms the selected spell for one target click")
	controller.cancel_targeting()
	_check(controller.aimed_spell_id == 0, "Cancel releases targeting")
	controller.bindings[0] = 1
	hud.show_inventory()
	controller.aim_hotkey(0)
	_check(hud._inventory_panel.visible and not hud._spell_panel.visible, "Preparing a macro keeps the chosen inventory tab")
	_check(controller.selected_spell_id == 1 and controller.aimed_spell_id == 1, "Numeric macro selects and arms in a single action")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	controller._unhandled_key_input(key)
	_check(controller.aimed_spell_id == 0, "Escape cancels the target cursor")
	controller.server_ready = false
	controller.aim_hotkey(0)
	_check(controller.aimed_spell_id == 0, "Unavailable server cannot enable casting")
	_check(hud._spell_buttons.has(25) and hud._spell_buttons.has(51) and not hud._spell_buttons.has(4) and hud._hotkey_buttons.size() == 10, "Spellbook and hotkey bar are populated")
	var player_network = root.get_node("PlayerNetwork")
	var sample := PlayerState.new(101, "Mati", Vector2i(4, 5))
	player_network.snapshot_received.emit([sample.to_dictionary()])
	var avatar = world._avatars[101]
	var pointer: Vector2 = world.get_global_transform() * (avatar.position + Vector2(0, -30))
	_check(world.target_grid_at(pointer) == sample.grid_position, "Targeting accounts for scaled/reparented AO20 game viewport")
	controller.end_session()
	controller.queue_free()
	hud.queue_free()
	world.queue_free()
	await process_frame
	print("AO spell checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
