extends SceneTree

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var registry := PlayerRegistry.new()
	root.add_child(registry)
	var caster := registry.add_player(100)
	var target := registry.add_player(200)
	caster.grid_position = Vector2i(4, 5)
	target.grid_position = Vector2i(10, 5)
	var result := registry.try_cast_spell(100, SpellCatalog.DAMAGE, 200, 1000)
	_expect(result["success"] and target.current_health == 80 and caster.current_mana == 85, "Damage and mana are applied by the authoritative registry at the range boundary.")
	_expect(result["event"]["amount"] == 20, "The cast event reports actual applied damage.")
	result = registry.try_cast_spell(100, SpellCatalog.HEAL, 200, 1001)
	_expect(result["reason"] == "cooldown" and caster.current_mana == 85 and target.current_health == 80, "Switching spell cannot bypass the shared cooldown.")
	result = registry.try_cast_spell(100, SpellCatalog.HEAL, 200, 1750)
	_expect(result["success"] and target.current_health == 100 and caster.current_mana == 73, "Healing caps health and accepts the exact cooldown boundary.")
	_expect(result["event"]["amount"] == 20, "Healing feedback reports the effective amount, not an over-heal.")
	result = registry.try_cast_spell(100, SpellCatalog.HEAL, 200, 2500)
	_expect(result["reason"] == "full_health" and caster.current_mana == 73, "Healing a full target consumes no mana.")
	result = registry.try_cast_spell(100, SpellCatalog.DAMAGE, 100, 2500)
	_expect(result["reason"] == "self_target" and caster.current_mana == 73, "Offensive self-targeting is rejected.")
	caster.current_health = 60
	result = registry.try_cast_spell(100, SpellCatalog.HEAL, 100, 2500)
	_expect(result["success"] and caster.current_health == 85 and caster.current_mana == 61, "Self-healing reuses the same cast pipeline.")
	target.grid_position = Vector2i(11, 5)
	result = registry.try_cast_spell(100, SpellCatalog.DAMAGE, 200, 3250)
	_expect(result["reason"] == "range" and caster.current_mana == 61, "Targets beyond range consume no resources.")
	caster.grid_position = Vector2i(1, 2)
	target.grid_position = Vector2i(3, 2)
	result = registry.try_cast_spell(100, SpellCatalog.DAMAGE, 200, 3250)
	_expect(result["reason"] == "blocked" and caster.current_mana == 61, "Arena obstacles stop spells.")
	_expect(not SpellRules.has_line_of_sight(Vector2i(1, 2), Vector2i(2, 1), ArenaData.FOREST), "Diagonal casts cannot cross a blocked corner.")
	caster.grid_position = Vector2i(4, 5)
	target.grid_position = Vector2i(5, 5)
	caster.current_mana = 14
	result = registry.try_cast_spell(100, SpellCatalog.DAMAGE, 200, 3250)
	_expect(result["reason"] == "mana" and target.current_health == 100, "Insufficient mana cannot damage a player.")
	caster.current_mana = 100
	result = registry.try_cast_spell(100, 999, 200, 3250)
	_expect(result["reason"] == "unknown_spell" and caster.current_mana == 100, "An unknown spell ID is rejected without resource changes.")
	result = registry.try_cast_spell(100, SpellCatalog.DAMAGE, 999, 3250)
	_expect(result["reason"] == "invalid_target", "A missing target is rejected.")
	target.current_health = 10
	result = registry.try_cast_spell(100, SpellCatalog.DAMAGE, 200, 3250)
	_expect(result["success"] and target.is_ghost and result["event"]["amount"] == 10, "Lethal damage uses the existing death and ghost state.")
	result = registry.try_cast_spell(100, SpellCatalog.HEAL, 200, 4000)
	_expect(result["reason"] == "invalid_target", "Healing cannot resurrect a dead target.")
	caster.apply_damage(1000)
	result = registry.try_cast_spell(100, SpellCatalog.DAMAGE, 200, 4000)
	_expect(result["reason"] == "caster_dead", "Dead casters cannot cast.")
	registry.remove_player(100)
	caster = registry.add_player(100)
	caster.grid_position = Vector2i(4, 5)
	target.is_alive = true
	target.current_health = 100
	result = registry.try_cast_spell(100, SpellCatalog.DAMAGE, 200, 1)
	_expect(result["success"], "Disconnecting removes the old spell cooldown.")

	var input_state := SpellInputState.new()
	_expect(input_state.begin_request(1000) == 0, "Manual mode does not cast before Lanzar.")
	input_state.manual_armed = true
	var request_id := input_state.begin_request(1000)
	_expect(request_id > 0 and input_state.begin_request(1000) == 0, "One click creates one request and duplicate pending clicks are blocked.")
	_expect(input_state.finish_request(request_id, false, 0, 1000) and input_state.manual_armed, "An invalid manual cast stays armed so the player can correct the aim.")
	request_id = input_state.begin_request(1000)
	input_state.finish_request(request_id, true, 750, 1000)
	_expect(not input_state.manual_armed, "A successful manual cast exits targeting.")
	input_state.combat_mode = true
	_expect(input_state.begin_request(1749) == 0, "Combat clicks respect cooldown locally.")
	request_id = input_state.begin_request(1750)
	input_state.finish_request(request_id, true, 750, 1750)
	_expect(input_state.combat_mode and input_state.is_targeting(), "Combat mode remains ready for repeated aimed casts.")
	input_state.reset_session()
	input_state.combat_mode = true
	var new_id := input_state.begin_request(1)
	_expect(new_id != request_id and not input_state.finish_request(request_id, true, 0, 2), "A late reply from an old session cannot complete a new request.")
	input_state.cancel_targeting()
	_expect(not input_state.is_targeting(), "Cancel exits both modes of targeting.")

	var scene: Node = load("res://client/scenes/client_main.tscn").instantiate()
	# Disable the connection startup; this section exercises actual scene controls.
	scene.set_script(null)
	root.add_child(scene)
	await process_frame
	var world = scene.get_node("ClientWorld")
	var local := PlayerState.new(1, "Local", Vector2i(4, 5))
	world._on_snapshot_received([local.to_dictionary()])
	await process_frame
	var panel_rect: Rect2 = world._spell_panel._root.get_child(0).get_global_rect()
	var viewport_rect: Rect2 = root.get_visible_rect()
	_expect(panel_rect.position.x >= 0 and panel_rect.position.y >= 0 and panel_rect.end.x <= viewport_rect.end.x and panel_rect.end.y <= viewport_rect.end.y, "The spell panel remains inside the playable viewport.")
	world._spell_panel._launch.pressed.emit()
	_expect(world._spell_input.manual_armed, "The actual Lanzar button arms targeting.")
	world._spell_panel._combat.toggled.emit(true)
	_expect(world._spell_input.combat_mode and not world._spell_input.manual_armed, "The actual combat control switches to direct clicks.")
	_expect(world._target_at_position(world._avatars[1].position + Vector2(0, -30)) == 1, "A click on the visible character body resolves its stable actor ID.")
	_expect(world._target_at_position(Vector2(0, 0)) == 0, "Empty space does not resolve a player.")
	world._reset_combat_session()
	_expect(world._local_state == null and not world._spell_input.is_targeting(), "Disconnect clears actors and targeting.")
	scene.queue_free()
	registry.queue_free()
	print("Spell gameplay checks: %d; failures: %d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
