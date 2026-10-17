extends SceneTree
var checks := 0
var failures := 0
var registries: Array[Node] = []

func _initialize() -> void:
	call_deferred("_run")

func _fixture() -> Dictionary:
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	registries.append(registry)
	var human: PlayerState = registry.add_player(301)
	var manager := ArenaPracticeBot.new(registry, 2701)
	return {"registry": registry, "human": human, "manager": manager}

func _run() -> void:
	var f := _fixture()
	var registry: PlayerRegistry = f.registry
	var manager: ArenaPracticeBot = f.manager
	var human: PlayerState = f.human
	human.current_health = 20
	var original := human.to_dictionary()
	_check(not manager.request(999, true, 3, 1, 10000).ok and manager.owner_id == 0, "Unknown sender cannot own a bot")
	_check(not manager.request(301, true, 9, 1, 10000).ok and human.to_dictionary() == original, "Unavailable class cannot reset a character or create a bot")
	_check(manager.request(301, true, 8, 2, 10000).ok, "A solo player can activate a hunter bot")
	var bot := registry.get_player(ArenaPracticeBot.BOT_ID)
	_check(bot.is_bot and bot.class_id == 8 and bot.equipped_items.has("weapon") and bot.equipped_items.has("ammunition"), "Bot has a real selected class and equipped inventory")
	_check(human.current_health == human.max_health and human.current_mana == human.max_mana and human.grid_position == Vector2i(4, 5) and bot.grid_position == Vector2i(15, 5), "Starting practice prepares both presets at separate spawn points")
	_check(PlayerState.from_dictionary(bot.to_dictionary()).is_bot, "Bot identity survives snapshots")
	_check(not root.get_node("PlayerNetwork").for_recipient(bot.to_dictionary(), 301).has("current_mana"), "Bot mana stays private on the wire")
	_check(manager.tick(10599).is_empty(), "Reaction delay prevents an instant spawn attack")
	var first := manager.tick(11300)
	_check(not first.is_empty() and bot.grid_position != Vector2i(15, 5), "Bot begins approaching through legal grid moves")
	var pos := bot.grid_position
	_check(manager.tick(11300).is_empty() and bot.grid_position == pos, "Repeated same-time ticks cannot duplicate movement or damage")
	_check(not manager.request(301, true, 1, 2, 11000).ok and bot.class_id == 8, "Replayed command cannot restart practice")
	_check(not manager.request(301, true, 1, 3, 10399).ok, "Rapid reset commands are limited")
	_check(manager.request(301, false, 1, 4, 10400).ok and not registry.has_player(ArenaPracticeBot.BOT_ID), "Stopping immediately removes the bot")
	# Every supported preset must reach and damage a stationary rival via real rules.
	var request_id := 10
	var now := 20000
	for class_id: int in ClassCatalog.all_ids():
		request_id += 1
		_check(manager.request(301, true, class_id, request_id, now).ok, "Class %d can start a practice bot" % class_id)
		bot = registry.get_player(ArenaPracticeBot.BOT_ID)
		var damaged := false
		var legal := true
		for step in range(55):
			var time := now + 1300 + step * ArenaPracticeBot.THINK_MSEC
			registry.advance_runtime(time)
			manager.tick(time)
			legal = legal and ArenaData.is_walkable(registry.get_arena_id(), bot.grid_position) and bot.grid_position != human.grid_position and bot.current_mana >= 0 and bot.current_mana <= bot.max_mana
			if human.current_health < human.max_health:
				damaged = true
				break
		_check(damaged and legal, "Class %d approaches, attacks and keeps legal resources/positions" % class_id)
		now += 10000
	# Standard player casts must be able to target the virtual entity.
	request_id += 1
	manager.request(301, true, 3, request_id, 120000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	var result := registry.try_cast_spell(301, 1, bot.grid_position, 1, 120000)
	_check(result.ok and int(result.event.target_id) == ArenaPracticeBot.BOT_ID and bot.current_health < bot.max_health, "Manual player spell can hit the bot through ordinary targeting")
	request_id += 1
	manager.request(301, true, 3, request_id, 130000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	result = registry.try_cast_spell(301, 25, bot.grid_position, 2, 130000)
	pos = bot.grid_position
	manager.tick(130600)
	_check(result.ok and bot.active_effects.has("Paralizado") and bot.grid_position == pos, "Nonmagical rooted bot cannot bypass movement rules")
	request_id += 1
	manager.request(301, true, 1, request_id, 140000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	manager.tick(141300)
	result = registry.try_cast_spell(301, 25, bot.grid_position, 3, 141400)
	manager.tick(141450)
	_check(result.ok and bot.active_effects.has("Paralizado"), "Magical bot cannot instantly remove the first paralysis")
	var removed_legally := false
	for step in range(1, 15):
		var before := bot.current_mana
		var actions := manager.tick(141450 + step * 150)
		for action: Dictionary in actions:
			if action.kind == "cast" and int(action.result.event.spell_id) == 27:
				removed_legally = step * 150 >= 650 and bot.current_mana == before - int(SpellCatalog.get_spell(27).mana)
	_check(removed_legally and bot.active_effects.is_empty(), "Delayed Remove uses the permitted spell and real mana cost")
	request_id += 1
	manager.request(301, true, 1, request_id, 150000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.current_mana = 0
	bot.current_health = 100
	manager.tick(151300)
	_check(bot.is_meditating and bot.current_health == 100 and bot.current_mana == 0, "Depleted bot starts normal meditation and waits before its first potion")
	manager.tick(152050)
	_check(bot.is_meditating and bot.current_health == 127 and bot.current_mana == 0, "Delayed red potion preserves meditation and restores normal HP")
	manager.tick(152500)
	_check(bot.current_health == 127, "Bot cannot repeat a potion at the player's faster cadence")
	manager.tick(153100)
	_check(bot.is_meditating and bot.current_health == 154, "Bot drinks again only after its slower decision interval")
	registry.advance_runtime(153300)
	_check(bot.current_mana == int(bot.max_mana * 0.05), "Bot meditation regenerates through the same server runtime")
	request_id += 1
	manager.request(301, true, 8, request_id, 160000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.grid_position = Vector2i(10, 5)
	var bow := int(bot.equipped_items.weapon)
	registry.try_inventory_use(ArenaPracticeBot.BOT_ID, bot.inventory.find(bow), bow, bot.inventory_revision, 1)
	for step in range(20):
		manager.tick(161300 + step * 150)
	_check(human.current_health == human.max_health, "Unequipped bow prevents bot shots too")
	bot.apply_damage(bot.max_health)
	_check(manager.tick(164500).is_empty() and manager.phase == "won", "Bot death ends practice with a player victory")
	_check(manager.tick(165000).is_empty() and not bot.is_alive, "Finished practice cannot silently revive or continue attacks")
	request_id += 1
	manager.request(301, true, 3, request_id, 170000)
	human.apply_damage(human.max_health)
	manager.tick(170600)
	_check(manager.phase == "lost" and manager.tick(171000).is_empty(), "Player death ends practice and stops the AI")
	request_id += 1
	manager.request(301, true, 3, request_id, 180000)
	_check(human.is_alive and manager.phase == "active", "Explicit restart prepares a dead player for another practice")
	registry.add_player(302)
	_check(not manager.request(302, false, 3, 1, 181000).ok and manager.owner_id == 301, "Another sender cannot control the owner's bot")
	manager.tick(181000)
	_check(not registry.has_player(ArenaPracticeBot.BOT_ID), "Human population reconciliation removes an orphan bot")
	_check(not manager.request(301, true, 3, request_id + 1, 182000).ok, "Two real players cannot activate a bot")
	registry.remove_player(302)
	manager.request(301, true, 3, request_id + 2, 183000)
	manager.peer_left(301)
	registry.remove_player(301)
	_check(not registry.has_player(ArenaPracticeBot.BOT_ID) and manager.owner_id == 0, "Owner disconnect removes entity and ownership")
	registry.add_player(303)
	_check(manager.request(303, true, 3, 1, 184000).ok, "New solo player can own a clean practice session")
	manager.peer_joining()
	_check(not registry.has_player(ArenaPracticeBot.BOT_ID), "Joining player cleanup happens before their snapshot")
	_test_training_behavior()
	for item: Node in registries:
		item.queue_free()
	await process_frame
	print("Practice bot checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _test_training_behavior() -> void:
	var paths: Dictionary = {}
	var delayed_aim := true
	var stale_aim := true
	var legal_cadence := true
	var bounded_pressure := true
	var potion_cadence := true
	var varied_pacing: Dictionary = {}
	for seed_value in range(1, 9):
		var f := _fixture()
		var registry: PlayerRegistry = f.registry
		var manager := ArenaPracticeBot.new(registry, seed_value)
		manager.request(301, true, 1, 1, 10000)
		var bot := registry.get_player(ArenaPracticeBot.BOT_ID)
		bot.grid_position = Vector2i(10, 5)
		var first := manager.tick(11300)
		delayed_aim = delayed_aim and first.all(func(action: Dictionary) -> bool: return action.kind != "cast")
		# Move away from the cell remembered at aim time before the release.
		f.human.grid_position = Vector2i(4, 9)
		for step in range(1, 5):
			manager.tick(11300 + step * 150)
		stale_aim = stale_aim and f.human.current_health == f.human.max_health and bot.current_mana == bot.max_mana
		manager.request(301, true, 1, 2, 20000)
		bot = registry.get_player(ArenaPracticeBot.BOT_ID)
		f.human.max_health = 10000
		f.human.current_health = 10000
		var path: Array[Vector2i] = []
		var casts: Array[int] = []
		for step in range(120):
			var now := 21300 + step * 150
			registry.advance_runtime(now)
			var actions := manager.tick(now)
			for action: Dictionary in actions:
				if action.kind == "move":
					path.append(bot.grid_position)
				elif action.kind == "cast":
					casts.append(now)
		for index in range(1, casts.size()):
			legal_cadence = legal_cadence and casts[index] - casts[index - 1] >= SpellCatalog.CAST_INTERVAL_MSEC
		bounded_pressure = bounded_pressure and casts.size() >= 4 and casts.size() <= 12
		paths[str(path)] = true
		varied_pacing[str(casts)] = true
		# Red and blue share the bot's slower reaction gate as well as server validation.
		manager.request(301, true, 1, 3, 50000)
		bot = registry.get_player(ArenaPracticeBot.BOT_ID)
		bot.current_health = 50
		bot.current_mana = 0
		var drinks: Array[int] = []
		for step in range(40):
			var now := 51300 + step * 150
			registry.advance_runtime(now)
			for action: Dictionary in manager.tick(now):
				if action.kind == "recovery" and str(action.result.event.action).ends_with("potion"):
					drinks.append(now)
		potion_cadence = potion_cadence and drinks.size() >= 2 and drinks[0] >= 51700
		for index in range(1, drinks.size()):
			potion_cadence = potion_cadence and drinks[index] - drinks[index - 1] >= 750
	_check(delayed_aim, "Ranged bot aims before firing instead of instant perfect targeting")
	_check(stale_aim, "Moving after the bot aims makes its stale cell miss without free damage")
	_check(paths.size() > 1 and varied_pacing.size() > 1, "Fixed independent seeds produce varied paths and attack timings")
	_check(bounded_pressure, "Training casts stay between 4 and 12 in eighteen seconds across eight fixed seeds")
	_check(legal_cadence, "Random AI decisions never bypass the server spell interval")
	_check(potion_cadence, "Bot potion reaction and repetition remain slower than human 300 ms cadence")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)
