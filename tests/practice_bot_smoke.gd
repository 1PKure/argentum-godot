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
	_check(not _start(manager, 999, true, 3, 1, 10000).ok and manager.owner_id == 0, "Unknown sender cannot own a bot")
	_check(not _start(manager, 301, true, 9, 1, 10000).ok and human.to_dictionary() == original, "Unavailable class cannot reset a character or create a bot")
	_check(_start(manager, 301, true, 8, 2, 10000).ok, "A solo player can activate a hunter bot")
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
	_check(not _start(manager, 301, true, 1, 2, 11000).ok and bot.class_id == 8, "Replayed command cannot restart practice")
	_check(not _start(manager, 301, true, 1, 3, 10399).ok, "Rapid reset commands are limited")
	_check(_start(manager, 301, false, 1, 4, 10400).ok and not registry.has_player(ArenaPracticeBot.BOT_ID), "Stopping immediately removes the bot")
	# Every supported preset must reach and damage a stationary rival via real rules.
	var request_id := 10
	var now := 20000
	for class_id: int in ClassCatalog.all_ids():
		request_id += 1
		_check(_start(manager, 301, true, class_id, request_id, now).ok, "Class %d can start a practice bot" % class_id)
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
	_start(manager, 301, true, 3, request_id, 120000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	var result := registry.try_cast_spell(301, 1, bot.grid_position, 1, 120000)
	_check(result.ok and int(result.event.target_id) == ArenaPracticeBot.BOT_ID and bot.current_health < bot.max_health, "Manual player spell can hit the bot through ordinary targeting")
	request_id += 1
	_start(manager, 301, true, 3, request_id, 130000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	result = registry.try_cast_spell(301, 25, bot.grid_position, 2, 130000)
	pos = bot.grid_position
	manager.tick(130600)
	_check(result.ok and bot.active_effects.has("Paralizado") and bot.grid_position == pos, "Nonmagical rooted bot cannot bypass movement rules")
	request_id += 1
	_start(manager, 301, true, 1, request_id, 140000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	manager.tick(141300)
	result = registry.try_cast_spell(301, 25, bot.grid_position, 3, 141400)
	manager.tick(141450)
	_check(result.ok and bot.active_effects.has("Paralizado"), "Magical bot cannot instantly remove the first paralysis")
	var removed_legally := false
	for step in range(1, 15):
		var before := bot.current_mana
		var actions := manager.tick(141450 + step * 150)
		var mana_recovered := 0
		for action: Dictionary in actions:
			if action.kind == "recovery" and action.result.event.action == "mana_potion":
				mana_recovered += int(action.result.event.amount)
		for action: Dictionary in actions:
			if action.kind == "cast" and int(action.result.event.spell_id) == 27:
				removed_legally = step * 150 >= 520 and bot.current_mana == before - int(SpellCatalog.get_spell(27).mana) + mana_recovered
	_check(removed_legally and bot.active_effects.is_empty(), "Delayed Remove uses the permitted spell and real mana cost")
	request_id += 1
	_start(manager, 301, true, 1, request_id, 150000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.current_mana = 0
	bot.current_health = 100
	manager.tick(151300)
	_check(bot.is_meditating and bot.current_health == 100 and bot.current_mana == 0, "Depleted bot starts normal meditation and waits before its first potion")
	manager.tick(151600)
	_check(bot.is_meditating and bot.current_health == 127 and bot.current_mana == 0, "Delayed red potion preserves meditation and restores normal HP")
	manager.tick(151849)
	_check(bot.current_health == 127, "Bot cannot repeat a potion before its recovery interval")
	manager.tick(152000)
	_check(bot.is_meditating and bot.current_health == 154, "Bot repeats potion recovery close to the normal player cadence")
	registry.advance_runtime(153300)
	_check(bot.current_mana == int(bot.max_mana * 0.05), "Bot meditation regenerates through the same server runtime")
	request_id += 1
	_start(manager, 301, true, 8, request_id, 160000)
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
	_start(manager, 301, true, 3, request_id, 170000)
	human.apply_damage(human.max_health)
	manager.tick(170600)
	_check(manager.phase == "lost" and manager.tick(171000).is_empty(), "Player death ends practice and stops the AI")
	request_id += 1
	_start(manager, 301, true, 3, request_id, 180000)
	_check(human.is_alive and manager.phase == "active", "Explicit restart prepares a dead player for another practice")
	registry.add_player(302)
	_check(not _start(manager, 302, false, 3, 1, 181000).ok and manager.owner_id == 301, "Another sender cannot control the owner's bot")
	manager.tick(181000)
	_check(not registry.has_player(ArenaPracticeBot.BOT_ID), "Human population reconciliation removes an orphan bot")
	_check(not _start(manager, 301, true, 3, request_id + 1, 182000).ok, "Two real players cannot activate a bot")
	registry.remove_player(302)
	_start(manager, 301, true, 3, request_id + 2, 183000)
	manager.peer_left(301)
	registry.remove_player(301)
	_check(not registry.has_player(ArenaPracticeBot.BOT_ID) and manager.owner_id == 0, "Owner disconnect removes entity and ownership")
	registry.add_player(303)
	_check(_start(manager, 303, true, 3, 1, 184000).ok, "New solo player can own a clean practice session")
	manager.peer_joining()
	_check(not registry.has_player(ArenaPracticeBot.BOT_ID), "Joining player cleanup happens before their snapshot")
	_test_training_behavior()
	_test_spell_rhythm()
	_test_combos_and_paths()
	_test_exchange()
	for item: Node in registries:
		item.queue_free()
	await process_frame
	print("Practice bot checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _test_training_behavior() -> void:
	var paths: Dictionary = {}
	var static_hits := 0
	var moving_hits := 0
	var total_attempts := 0
	var smooth_steps := 0
	var simultaneous := 0
	var legal_casts := true
	var legal_moves := true
	var legal_potions := true
	var quick_potions := true
	var both_colors := true
	var recovery_windows := true
	for seed_value in range(1, 9):
		var path: Array[Vector2i] = []
		for mobile in [false, true]:
			var f := _fixture()
			var registry: PlayerRegistry = f.registry
			var human: PlayerState = f.human
			var manager := ArenaPracticeBot.new(registry, seed_value)
			_start(manager, 301, true, 1, 1, 10000)
			var bot := registry.get_player(ArenaPracticeBot.BOT_ID)
			human.max_health = 10000
			human.current_health = 10000
			var last_cast := 0
			var last_move := 0
			var last_attempt := manager._next_offense
			var removal_due := 0
			var removal_id := 0
			var next_human_move := 11000
			var vertical := MovementRules.Direction.SOUTH
			for step in range(1200):
				var now := 10000 + step * 20
				registry.advance_runtime(now)
				if mobile and not human.active_effects.is_empty():
					if removal_due == 0:
						removal_due = now + 400
					elif now >= removal_due:
						removal_id += 1
						registry.try_cast_spell(301, 27, human.grid_position, removal_id, now)
						removal_due = now + 80
				else:
					removal_due = 0
				if mobile and now >= next_human_move:
					next_human_move = now + MovementRules.MOVE_INTERVAL_MSEC
					if human.grid_position.y >= 8:
						vertical = MovementRules.Direction.NORTH
					elif human.grid_position.y <= 3:
						vertical = MovementRules.Direction.SOUTH
					registry.try_move_player(301, vertical, now)
				var actions := manager.tick(now)
				var moved := false
				var cast := false
				if mobile and last_attempt != manager._next_offense:
					total_attempts += 1
					last_attempt = manager._next_offense
				for action: Dictionary in actions:
					if action.kind == "move":
						moved = true
						if last_move > 0:
							legal_moves = legal_moves and now - last_move >= ArenaPracticeBot.MOVE_INTERVAL_MSEC
							if now - last_move <= 200:
								smooth_steps += 1
						last_move = now
						if not mobile:
							path.append(bot.grid_position)
					elif action.kind == "cast":
						cast = true
						if last_cast > 0:
							legal_casts = legal_casts and now - last_cast >= ArenaPracticeBot.CAST_INTERVAL_MSEC
						last_cast = now
						if int(action.result.event.target_id) == 301:
							if mobile:
								moving_hits += 1
							else:
								static_hits += 1
				if cast and moved:
					simultaneous += 1
			paths[str(path)] = true
		# Under pressure it must alternate resources and drink at the real interval.
		var f := _fixture()
		var registry: PlayerRegistry = f.registry
		var manager := ArenaPracticeBot.new(registry, seed_value)
		_start(manager, 301, true, 1, 1, 50000)
		var bot := registry.get_player(ArenaPracticeBot.BOT_ID)
		bot.current_health = 100
		bot.current_mana = 0
		var drinks: Array[int] = []
		var colors: Dictionary = {}
		for step in range(300):
			var now := 51300 + step * 20
			registry.advance_runtime(now)
			for action: Dictionary in manager.tick(now):
				if action.kind == "recovery" and str(action.result.event.action).ends_with("potion"):
					drinks.append(now)
					colors[str(action.result.event.action)] = true
		both_colors = both_colors and colors.size() == 2
		quick_potions = quick_potions and drinks.size() >= 10 and drinks[0] >= 51400 and drinks[0] <= 51500
		for index in range(1, drinks.size()):
			legal_potions = legal_potions and drinks[index] - drinks[index - 1] >= ArenaPracticeBot.POTION_INTERVAL_MSEC
			quick_potions = quick_potions and drinks[index] - drinks[index - 1] <= 320
		# A melee bot has to leave the attack->potion window to actually recover.
		_start(manager, 301, true, 3, 2, 60000)
		bot = registry.get_player(ArenaPracticeBot.BOT_ID)
		bot.grid_position = Vector2i(5, 5)
		registry.try_basic_attack(ArenaPracticeBot.BOT_ID, 61000)
		bot.current_health = 80
		var recovered := false
		for step in range(120):
			var now := 61020 + step * 20
			for action: Dictionary in manager.tick(now):
				if action.kind == "recovery" and action.result.event.action == "health_potion":
					recovered = true
		recovery_windows = recovery_windows and recovered and bot.current_health > 80
	print("Agite metrics: static_hits=%d moving_hits=%d moving_attempts=%d continuous_steps=%d cast_and_move=%d" % [static_hits, moving_hits, total_attempts, smooth_steps, simultaneous])
	_check(paths.size() > 1, "Movement bursts vary between seeds rather than repeating a fixed approach/up pattern")
	_check(smooth_steps >= 300 and legal_moves, "Bot sustains continuous steps at its configured legal cadence")
	_check(simultaneous >= 8, "Casting and movement can happen together instead of freezing for every attack")
	_check(static_hits >= 80, "Stationary opponents receive sustained combat pressure across eight seeds")
	_check(moving_hits >= 40 and moving_hits < total_attempts, "Moving opponents can be hit and can also evade delayed perception")
	_check(legal_casts, "All attacks and defensive spells respect the same slower bot spell interval")
	_check(legal_potions and quick_potions, "Bot repeats potions at 250 ms with a human reaction window and legal click/Use lanes")
	_check(both_colors, "Under pressure the bot recovers health and mana instead of starving one resource")
	_check(recovery_windows, "Wounded melee bots defend and recover through the real attack-potion gap")

func _test_spell_rhythm() -> void:
	var f := _fixture()
	var registry: PlayerRegistry = f.registry
	var manager: ArenaPracticeBot = f.manager
	_start(manager, 301, true, 1, 1, 10000)
	var bot := registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.grid_position = Vector2i(9, 5)
	f.human.max_health = 10000
	f.human.current_health = 10000
	var last_cast := 0
	var rooted_at := 0
	var removed_at := 0
	var legal := true
	for step in range(450):
		var now := 11000 + step * 20
		if last_cast > 0 and rooted_at == 0:
			if registry.try_cast_spell(301, 25, bot.grid_position, 1, now).ok:
				rooted_at = now
		for action: Dictionary in manager.tick(now):
			if action.kind == "cast":
				if last_cast > 0:
					legal = legal and now - last_cast >= ArenaPracticeBot.CAST_INTERVAL_MSEC
				last_cast = now
				if int(action.result.event.spell_id) == 27:
					removed_at = now
	_check(rooted_at > 0 and removed_at - rooted_at >= 520, "The first root remains for at least 520 ms before the bot can Remove")
	_check(removed_at > 0 and legal, "Remove and offensive casts share the bot's 1150 ms floor instead of bypassing it")
	# Recovery starts on the first useful red, without spending scarce turns on blue.
	_start(manager, 301, true, 1, 2, 30000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.current_health = 140
	bot.current_mana = 0
	var colors: Array[String] = []
	for step in range(45):
		for action: Dictionary in manager.tick(31300 + step * 20):
			if action.kind == "recovery" and str(action.result.event.action).ends_with("potion"):
				colors.append(str(action.result.event.action))
	_check(colors.size() >= 3 and colors.slice(0, 3) == ["health_potion", "health_potion", "health_potion"], "A wounded bot prioritizes consecutive reds over blues after a combo")
	_start(manager, 301, true, 1, 3, 40000)
	bot = registry.get_player(ArenaPracticeBot.BOT_ID)
	bot.current_health -= 27
	var before := bot.current_health
	manager.tick(41300)
	manager.tick(41520)
	_check(bot.current_health == before + 27, "Bot starts a useful red after the first 27 missing HP instead of waiting for 78 percent health")


func _test_combos_and_paths() -> void:
	var combos := true
	var variants: Dictionary = {}
	var longest_vertical := 0
	var both_axes := true
	for seed_value in range(1, 9):
		var f := _fixture()
		var registry: PlayerRegistry = f.registry
		var manager := ArenaPracticeBot.new(registry, seed_value)
		_start(manager, 301, true, 1, 1, 10000)
		var bot := registry.get_player(ArenaPracticeBot.BOT_ID)
		f.human.grid_position = Vector2i(9, 5)
		f.human.max_health = 10000
		f.human.current_health = 10000
		bot.grid_position = Vector2i(13, 5)
		var offensive: Array[int] = []
		var vertical := 0
		var axes: Dictionary = {}
		var path: Array[Vector2i] = []
		for step in range(800):
			var now := 10000 + step * 20
			var previous := bot.grid_position
			for action: Dictionary in manager.tick(now):
				if action.kind == "cast" and int(action.result.event.target_id) == 301:
					offensive.append(int(action.result.event.spell_id))
				elif action.kind == "move":
					var delta := bot.grid_position - previous
					var axis := 0 if delta.y != 0 else 1
					axes[axis] = true
					vertical = vertical + 1 if axis == 0 else 0
					longest_vertical = maxi(longest_vertical, vertical)
					path.append(bot.grid_position)
		combos = combos and offensive.size() >= 4 and offensive.slice(0, 2) == [53, 53] and offensive.has(51) and offensive.count(41)<=1
		both_axes = both_axes and axes.size() == 2
		variants[str(path)] = true
	_check(combos, "Across eight seeds, mage prioritizes double Apocalypse before Discharge and mana rebuilding")
	_check(both_axes and variants.size() >= 6, "Comfortable-range movement uses both axes with distinct trajectories across seeds")
	_check(longest_vertical <= 6, "The bot breaks extended up-down patterns instead of staying on one vertical line")
	for class_id: int in [2, 5, 6]:
		var f := _fixture()
		var manager: ArenaPracticeBot = f.manager
		var registry: PlayerRegistry = f.registry
		_start(manager, 301, true, class_id, 1, 10000)
		var bot := registry.get_player(ArenaPracticeBot.BOT_ID)
		bot.grid_position = Vector2i(9, 5)
		f.human.max_health = 10000
		f.human.current_health = 10000
		var offensive: Array[int] = []
		for step in range(260):
			for action: Dictionary in manager.tick(10000 + step * 20):
				if action.kind == "cast" and int(action.result.event.target_id) == 301:
					offensive.append(int(action.result.event.spell_id))
		var class_legal := true
		for id in offensive: class_legal = class_legal and ClassCatalog.can_cast(class_id,id)
		var sequence := offensive.size() >= 2 and offensive.slice(0,2) == [59,59] if class_id == 6 else offensive.size() >= 2 and offensive[0] == 25 and offensive.has(51)
		_check(class_legal and sequence, "Class %d follows its legal caster or hybrid tactic and affordable spells" % class_id)
	print("Movement variation: %d paths, longest vertical run %d tiles" % [variants.size(), longest_vertical])


func _test_exchange() -> void:
	var returned_hits := 0
	var recoveries := 0
	var received_arrows := 0
	var human_wins := 0
	for seed_value in range(4):
		var f := _fixture()
		var registry: PlayerRegistry = f.registry
		var human: PlayerState = f.human
		registry.try_select_class(301, 8, 1000)
		var manager := ArenaPracticeBot.new(registry, 900 + seed_value)
		_start(manager, 301, true, 1, 1, 10000)
		var next_walk := 11000
		var next_shot := 12000
		var next_potion := 11000
		var shot_id := 0
		var potion_id := 0
		var vertical := MovementRules.Direction.SOUTH
		for step in range(1200):
			var now := 10000 + step * 20
			registry.advance_runtime(now)
			var bot := registry.get_player(ArenaPracticeBot.BOT_ID)
			if not human.is_alive or not bot.is_alive:
				if not bot.is_alive:
					human_wins += 1
				break
			if now >= next_walk:
				next_walk = now + MovementRules.MOVE_INTERVAL_MSEC
				if human.grid_position.y >= 8:
					vertical = MovementRules.Direction.NORTH
				elif human.grid_position.y <= 3:
					vertical = MovementRules.Direction.SOUTH
				registry.try_move_player(301, vertical, now)
			if now >= next_shot:
				next_shot = now + CombatRules.RANGED_ATTACK_COOLDOWN_MSEC + 100
				shot_id += 1
				if registry.try_ranged_attack(301, bot.grid_position, shot_id, now).ok:
					received_arrows += 1
			if now >= next_potion and human.current_health <= human.max_health - 27:
				next_potion = now + 320
				potion_id += 1
				registry.try_recovery_action(301, "health_potion", potion_id, now)
			for action: Dictionary in manager.tick(now):
				if action.kind == "cast" and int(action.result.event.target_id) == 301:
					returned_hits += 1
				elif action.kind == "recovery" and str(action.result.event.action).ends_with("potion"):
					recoveries += 1
	print("Exchange metrics: player_arrows=%d bot_hits=%d bot_potions=%d player_wins=%d/4" % [received_arrows, returned_hits, recoveries, human_wins])
	_check(received_arrows >= 12 and returned_hits >= 8 and recoveries >= 20, "Real ranged damage makes the bot alternate retaliation, movement and recovery")
	_check(human_wins > 0, "An active player using legal movement, arrows and potions can defeat the bot")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

# Existing cadence scenarios run after the new preparation phase. The countdown
# and its action locks are exercised separately by arena_rewards_smoke.gd.
func _start(manager: ArenaPracticeBot, peer_id: int, enabled: bool, class_id: int, request_id: int, now: int) -> Dictionary:
	var result := manager.request(peer_id, enabled, class_id, request_id, now - ArenaPracticeBot.COUNTDOWN_MSEC)
	if result.ok:
		manager.tick(now)
	return result
