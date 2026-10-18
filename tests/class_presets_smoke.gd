extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var resources = root.get_node("AOResources")
	_check(ClassCatalog.all_ids().size() == 9, "Nine selected PvP classes are available")
	for id: int in ClassCatalog.all_ids():
		var profile := ClassCatalog.get_profile(id)
		_check(int(profile.max_health) > 0 and int(profile.max_mana) >= 0, "%s has a real resource profile" % profile.name)
		var preset := PlayerState.new()
		preset.class_id = id
		preset.max_mana = int(profile.max_mana)
		preset.reset_preset_inventory()
		_check(preset.inventory.has(38) and preset.inventory.has(37) == (preset.max_mana > 0), "%s receives blue potions only if it uses mana" % profile.name)
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
					for frame_index in range(frames.get_frame_count("walk_" + direction)):
						var texture := frames.get_frame_texture("walk_" + direction, frame_index) as AtlasTexture
						complete = complete and texture != null and texture.atlas != null
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
	_check(ClassCatalog.physical_damage(3, 3) < ClassCatalog.physical_damage(3, 8), "Armor actually reduces physical damage")
	_check(ClassCatalog.magic_damage(100, 1, 1) != 100, "Weapon magic bonus and helmet resistance affect spell damage")
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var player: PlayerState = registry.add_player(801)
	var target: PlayerState = registry.add_player(802)
	var original := player.to_dictionary()
	_check(not registry.try_select_class(801, 999, 10000).ok and player.to_dictionary() == original, "Unknown class does not mutate state")
	_check(ClassCatalog.get_profile(9).is_empty() and ClassCatalog.get_profile(10).is_empty() and ClassCatalog.get_profile(11).is_empty(), "Worker, pirate and thief cannot be selected")
	player.current_health = 1
	player.current_mana = 0
	player.is_meditating = true
	player.active_effects.assign(["Paralizado"])
	var result: Dictionary = registry.try_recovery_action(801, "class:8", 1, 10000)
	_check(result.ok and player.class_id == 8 and player.max_mana == 0 and player.current_health == player.max_health and player.active_effects.is_empty(), "A depleted meditating character freely switches to a ready hunter")
	_check(PlayerState.from_dictionary(player.to_dictionary()).equipped_items == player.equipped_items, "Inventory and equipment survive a snapshot round trip")
	_check(not registry.try_recovery_action(801, "class:3", 1, 10000).ok and player.class_id == 8, "Duplicate requests cannot reapply a preset")
	_check(not registry.try_cast_spell(801, 1, target.grid_position, 1, 10000).ok, "Forged hunter magic request is rejected")
	_check(not registry.try_recovery_action(801, "meditate", 2, 10000).ok, "Hunter cannot meditate")
	player.grid_position = Vector2i(1, 2)
	target.grid_position = Vector2i(3, 2)
	_check(not registry.try_ranged_attack(801, target.grid_position, 1, 10000).ok, "Aimed arrows are blocked by terrain")
	player.grid_position = Vector2i(4, 5)
	target.grid_position = Vector2i(13, 5)
	_check(not registry.try_ranged_attack(801, target.grid_position, 2, 10000).ok, "Aimed arrows respect eight-tile range")
	target.grid_position = Vector2i(10, 6)
	_check(registry.try_basic_attack(801, 10000) == null and target.current_health == target.max_health, "CTRL's legacy physical RPC cannot fire a hunter arrow")
	result = registry.try_ranged_attack(801, target.grid_position, 3, 10000)
	_check(result.ok and result.event.amount > 0 and player.current_mana == 0, "Click-targeted diagonal arrow applies real damage without mana")
	var health := target.current_health
	_check(not registry.try_ranged_attack(801, target.grid_position, 3, 11200).ok and target.current_health == health, "Arrow request replay cannot duplicate damage")
	_check(not registry.try_ranged_attack(801, target.grid_position, 4, 11199).ok, "Arrow cooldown rejects one millisecond early")
	_check(registry.try_ranged_attack(801, target.grid_position, 5, 11200).ok, "Arrow accepts at its separate 1200 ms boundary")
	var weapon_id := int(player.equipped_items.weapon)
	var weapon_index := player.inventory.find(weapon_id)
	var revision := player.inventory_revision
	result = registry.try_inventory_move(801, weapon_index, 41, weapon_id, revision, 1)
	_check(result.ok and player.inventory[41] == weapon_id and player.equipped_items.weapon == weapon_id, "Moving equipped bow preserves ownership and equip state")
	_check(not registry.try_inventory_move(801, weapon_index, 40, weapon_id, revision, 2).ok and player.inventory.count(weapon_id) == 1, "A stale drag cannot duplicate the old bow")
	result = registry.try_inventory_use(801, 41, weapon_id, player.inventory_revision, 3)
	_check(result.ok and not player.equipped_items.has("weapon") and player.inventory[41] == weapon_id, "Clicking equipped bow unequips it without removing the item")
	_check(not registry.try_ranged_attack(801, target.grid_position, 6, 12000).ok, "Unequipped hunter bow cannot fire")
	_check(registry.try_inventory_use(801, 41, weapon_id, player.inventory_revision, 4).ok and player.equipped_items.weapon == weapon_id, "Clicking moved bow equips it again")
	registry.try_select_class(802, 1, 12000) # Two full arrows can now kill a mage.
	var armor_id := int(target.equipped_items.armor)
	var armor_index := target.inventory.find(armor_id)
	var armored_damage := ClassCatalog.physical_damage(8, 1, player.equipped_items, target.equipped_items)
	registry.try_inventory_use(802, armor_index, armor_id, target.inventory_revision, 1)
	_check(ClassCatalog.physical_damage(8, 1, player.equipped_items, target.equipped_items) > armored_damage, "Unequipping armor changes actual incoming damage")
	_check(not registry.try_inventory_use(801, 41, 1788, player.inventory_revision, 5).ok, "A forged foreign item cannot be equipped")
	player.apply_damage(1)
	_check(registry.try_select_class(801, 3, 10651).ok and player.class_id == 3 and player.current_health == player.max_health, "Preset selection remains free immediately after combat")
	player.is_alive = false
	_check(registry.try_select_class(801, 1, 10652).ok and player.is_alive, "Selecting a preset also prepares a dead test character")
	var preset_revision := player.preset_revision
	_check(registry.try_select_class(801, 1, 10653).ok and player.preset_revision > preset_revision, "Current preset can be reapplied without a wait")
	registry.queue_free()
	var controller = load("res://client/input/spell_targeting_controller.gd").new()
	root.add_child(controller)
	controller.session_active = true
	controller.server_ready = true
	controller.aim_spell(1)
	controller.apply_class(8)
	_check(controller.aimed_spell_id == 0 and controller.bindings[2] == ClassCatalog.ATTACK_BINDING and not controller.can_launch(), "Hunter selection clears the spell cursor and grants a physical attack macro")
	controller.aim_spell(53)
	_check(controller.aimed_spell_id == 0, "A numeric macro cannot arm forbidden hunter magic")
	controller.apply_class(1)
	_check(controller.bindings[0] != 0, "Returning to a caster restores its own macro preset")
	_check(ClassCatalog.get_profile(1).bindings.slice(0, 4) == [25, 27, 51, 31], "Generic mage macros use control, remover, damage and healing order")
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
