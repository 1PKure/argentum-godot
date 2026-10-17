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
	var manager := ArenaPracticeBot.new(registry)
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
	var first := manager.tick(10600)
	_check(not first.is_empty() and bot.grid_position != Vector2i(15, 5), "Bot begins approaching through legal grid moves")
	var pos := bot.grid_position
	_check(manager.tick(10600).is_empty() and bot.grid_position == pos, "Repeated same-time ticks cannot duplicate movement or damage")
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
		for step in range(35):
			var time := now + 600 + step * ArenaPracticeBot.THINK_MSEC
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
	result = registry.try_cast_spell(301, 25, bot.grid_position, 3, 140000)
	manager.tick(140600)
	_check(result.ok and bot.active_effects.is_empty() and bot.current_mana == bot.max_mana - int(SpellCatalog.get_spell(27).mana), "Magical bot removes paralysis with its allowed spell and actual mana cost")
	request_id += 1
	manager.request(301, true, 1, request_id, 150000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.current_mana = 0
	bot.current_health = 100
	manager.tick(150600)
	_check(bot.is_meditating and bot.current_health == 127 and bot.current_mana == 0, "Depleted bot drinks red potion and starts normal meditation without free mana")
	manager.tick(151050)
	_check(bot.is_meditating and bot.current_health == 154 and bot.current_mana == 0, "Bot potion use preserves meditation and its warmup")
	registry.advance_runtime(152600)
	_check(bot.current_mana == int(bot.max_mana * 0.05), "Bot meditation regenerates through the same server runtime")
	request_id += 1
	manager.request(301, true, 8, request_id, 160000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.grid_position = Vector2i(10, 5)
	var bow := int(bot.equipped_items.weapon)
	registry.try_inventory_use(ArenaPracticeBot.BOT_ID, bot.inventory.find(bow), bow, bot.inventory_revision, 1)
	manager.tick(160600)
	_check(human.current_health == human.max_health, "Unequipped bow prevents bot shots too")
	bot.apply_damage(bot.max_health)
	_check(manager.tick(161000).is_empty() and manager.phase == "won", "Bot death ends practice with a player victory")
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
	for item: Node in registries:
		item.queue_free()
	await process_frame
	print("Practice bot checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)
