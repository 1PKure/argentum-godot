extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var resources = root.get_node("AOResources")
	_check(ClassCatalog.all_ids().size() == 12, "All twelve public AO20 classes are available")
	for id: int in ClassCatalog.all_ids():
		var profile := ClassCatalog.get_profile(id)
		_check(int(profile.max_health) > 0 and int(profile.max_mana) >= 0, "%s has a real resource profile" % profile.name)
		var body: Dictionary = resources.get_body_definition(int(profile.body_id))
		_check(not body.is_empty() and resources.get_texture(int(body.file_num)) != null, "%s has an available original armor atlas" % profile.name)
		for slot: String in ["weapon", "shield", "helmet"]:
			var animation_id := int(profile[slot + "_animation"])
			if animation_id <= 0:
				continue
			var frames: SpriteFrames = resources.get_equipment_frames(slot, animation_id)
			var complete := frames != null
			if frames != null:
				for direction: String in ["up", "down", "left", "right"]:
					complete = complete and frames.get_frame_count("walk_" + direction) > 0
			_check(complete, "%s %s renders in all four directions" % [profile.name, slot])
		for slot: String in ["armor", "weapon", "helmet", "shield", "accessory", "ammunition"]:
			if int(profile[slot]) > 0:
				_check(resources.get_equipment_icon(int(profile[slot])) != null, "%s %s has a usable equipment icon" % [profile.name, slot])
		for spell_id: int in profile.spells:
			_check(ClassCatalog.can_cast(id, spell_id) and int(SpellCatalog.get_spell(spell_id).mana) <= int(profile.max_mana), "%s can fund granted spell %d" % [profile.name, spell_id])
	_check(ClassCatalog.get_profile(8).max_mana == 0 and ClassCatalog.get_profile(8).spells.is_empty(), "Hunter has no magic or mana")
	_check(ClassCatalog.get_profile(3).max_health > ClassCatalog.get_profile(1).max_health, "Warrior has more health than mage")
	_check(ClassCatalog.get_profile(1).max_mana > ClassCatalog.get_profile(7).max_mana, "Mage has more mana than paladin")
	_check(ClassCatalog.physical_damage(3, 1) > ClassCatalog.physical_damage(1, 1), "Warrior equipment and class improve physical damage")
	_check(ClassCatalog.physical_damage(3, 3) < ClassCatalog.physical_damage(3, 11), "Armor actually reduces physical damage")
	_check(ClassCatalog.magic_damage(100, 1, 1) != 100, "Weapon magic bonus and helmet resistance affect spell damage")
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var player: PlayerState = registry.add_player(801)
	var target: PlayerState = registry.add_player(802)
	var original := player.to_dictionary()
	_check(not registry.try_select_class(801, 999, 10000).ok and player.to_dictionary() == original, "Unknown class does not mutate state")
	target.current_mana -= 1
	_check(not registry.try_select_class(802, 3, 10000).ok and target.current_mana == 2999, "Changing class cannot refill missing mana")
	target.current_mana = target.max_mana
	var result: Dictionary = registry.try_recovery_action(801, "class:8", 1, 10000)
	_check(result.ok and player.class_id == 8 and player.max_mana == 0, "Recovery RPC dispatch applies hunter preset on the server")
	_check(PlayerState.from_dictionary(player.to_dictionary()).class_id == 8, "Class survives a network snapshot round trip")
	_check(not registry.try_recovery_action(801, "class:3", 1, 10000).ok and player.class_id == 8, "Duplicate selection requests cannot switch class")
	_check(not registry.try_cast_spell(801, 1, target.grid_position, 1, 10000).ok and target.current_health == target.max_health, "Forged hunter magic request is rejected without effect")
	_check(not registry.try_recovery_action(801, "meditate", 2, 10000).ok and not player.is_meditating, "Nonmagical classes cannot meditate")
	_check(not ClassCatalog.can_cast(5, 113) and ClassCatalog.can_cast(6, 113), "Druid and bard have distinct spell presets")
	player.grid_position = Vector2i(1, 2)
	player.facing_direction = MovementRules.Direction.EAST
	target.grid_position = Vector2i(3, 2)
	_check(registry.try_basic_attack(801, 7000) == null and target.current_health == target.max_health, "Blocked terrain stops a hunter arrow before its target")
	player.grid_position = Vector2i(4, 5)
	target.grid_position = Vector2i(13, 5)
	_check(registry.try_basic_attack(801, 8000) == null, "Hunter cannot hit past its eight-tile range")
	var blocker: PlayerState = registry.add_player(803)
	blocker.grid_position = Vector2i(6, 5)
	target.grid_position = Vector2i(10, 5)
	_check(registry.try_basic_attack(801, 9000) == blocker and target.current_health == target.max_health, "Hunter hits the first living rival in the facing line")
	registry.remove_player(803)
	player.grid_position = Vector2i(4, 5)
	player.facing_direction = MovementRules.Direction.EAST
	target.grid_position = Vector2i(10, 5)
	_check(registry.try_basic_attack(801, 10000) == target and target.current_health < target.max_health, "Hunter hits an aligned rival six tiles away")
	_check(not registry.try_select_class(801, 3, 19999).ok, "Combat lock blocks switching at 9999 ms")
	var cooldown: int = registry._last_attack_time[801]
	_check(registry.try_select_class(801, 3, 20000).ok and player.class_id == 3, "Class switch accepts the exact ten-second peace boundary")
	_check(registry._last_attack_time[801] == cooldown, "Class selection preserves existing action cooldowns")
	_check(registry.try_basic_attack(801, 21000) == null, "Warrior cannot reuse the hunter's ranged attack")
	player.apply_damage(1)
	_check(not registry.try_select_class(801, 1, 40000).ok, "Changing class cannot refill missing health")
	player.current_health = player.max_health
	player.active_effects.assign(["Paralizado"])
	_check(not registry.try_select_class(801, 1, 40000).ok, "Changing class cannot remove an active status")
	player.active_effects.clear()
	player.is_alive = false
	_check(not registry.try_select_class(801, 1, 40000).ok, "Ghosts cannot change class to resurrect")
	registry.try_recovery_action(801, "respawn", 3, 40000)
	_check(player.class_id == 3 and player.max_health == int(ClassCatalog.get_profile(3).max_health), "Respawn keeps the selected class and equipment")
	registry.queue_free()
	var controller = load("res://client/input/spell_targeting_controller.gd").new()
	root.add_child(controller)
	controller.session_active = true
	controller.server_ready = true
	controller.aim_spell(1)
	controller.apply_class(8)
	_check(controller.aimed_spell_id == 0 and controller.bindings.count(0) == 10 and not controller.can_launch(), "Hunter selection clears the spell cursor and grants an empty macro preset")
	controller.aim_spell(53)
	_check(controller.aimed_spell_id == 0, "A numeric macro cannot arm forbidden hunter magic")
	controller.apply_class(1)
	_check(controller.bindings[0] != 0, "Returning to a caster restores its own macro preset")
	controller.queue_free()
	var visual = load("res://client/characters/player_visual.tscn").instantiate()
	root.add_child(visual)
	for id: int in ClassCatalog.all_ids():
		visual.set_class_id(id)
		for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			visual.set_movement(direction, true)
			for sprite: AnimatedSprite2D in visual._equipment.values():
				if sprite.visible:
					_check(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) != null, "Visible %s equipment has a directional frame" % ClassCatalog.get_profile(id).name)
	visual.queue_free()
	await process_frame
	print("Class preset checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
