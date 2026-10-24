extends SceneTree
var checks := 0
var failures := 0
var registry: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var owner: PlayerState = registry.add_player(501)
	var manager := ArenaPracticeBot.new(registry, 42)
	var outcomes: Array[Dictionary] = []
	manager.status_changed.connect(func(state: Dictionary) -> void: outcomes.append(state))
	manager.request(501, true, 1, 1, 10000)
	var bot: PlayerState = registry.get_player(ArenaPracticeBot.BOT_ID)
	var round_id := str(manager.status().round_id)
	_check(manager.phase == "countdown" and manager.status().countdown == 3 and not round_id.is_empty(), "Round starts at three with a unique identity")
	var before := owner.to_dictionary()
	_check(registry.try_move_player(501, 1, 10010) == null and registry.try_move_player(bot.peer_id, 1, 10010) == null, "Server freezes movement for both participants before GO")
	_check(registry.try_basic_attack(501, 10010) == null and not registry.try_ranged_attack(501, bot.grid_position, 1, 10010).ok and not registry.try_cast_spell(501, 53, bot.grid_position, 1, 10010).ok, "Melee, arrow and spell requests cannot bypass countdown")
	_check(not registry.try_recovery_action(501, "health_potion", 1, 10010).ok and not registry.try_recovery_action(501, "meditate", 2, 10010).ok and registry.apply_damage(501, 50) == null and registry.spend_mana(501, 50) == null, "Recovery and debug mutations are blocked during countdown")
	_check(owner.to_dictionary() == before, "Rejected early actions consume no mana, health, cooldown or position")
	manager.tick(10999)
	_check(manager.status().countdown == 3, "Three remains visible until the first full second")
	manager.tick(11000)
	_check(manager.status().countdown == 2 and manager.phase == "countdown", "Second authoritative tick displays two")
	manager.tick(12000)
	_check(manager.status().countdown == 1, "Third authoritative tick displays one")
	manager.tick(12999)
	_check(registry.is_round_locked(501), "No early unlock at 2999 ms")
	manager.tick(13000)
	_check(manager.phase == "active" and not registry.is_round_locked(501) and not registry.is_round_locked(bot.peer_id), "Both participants unlock together at 3000 ms")
	_check(registry.try_cast_spell(501, 1, bot.grid_position, 1, 13000).ok, "First post-GO spell uses its normal cost and interval")
	bot.apply_damage(bot.max_health)
	_check(manager.settle_round() and manager.phase == "won", "Confirmed bot death resolves a living owner's victory immediately")
	manager.tick(14000)
	manager.settle_round()
	_check(outcomes.filter(func(s: Dictionary) -> bool: return s.phase == "won").size() == 1, "Repeated ticks and result queries cannot emit a second victory")
	var progress := SkinProgress.new()
	progress.storage_path = "user://arena-rewards-test.cfg"
	DirAccess.remove_absolute(progress.storage_path)
	progress.restore()
	_check(progress.wins == 0 and progress.selected == "preset" and not progress.select("explorer"), "New profile has only its original class outfit")
	var reward := progress.award(round_id)
	_check(progress.wins == 1 and reward.unlocked == ["explorer"] and progress.award(round_id).is_empty(), "First victory unlocks Explorer once, even after repeated results")
	_check(progress.select("explorer") and not progress.select("scarlet"), "Only unlocked skins can be equipped")
	var restored := SkinProgress.new()
	restored.storage_path = progress.storage_path
	restored.restore()
	_check(restored.wins == 1 and restored.selected == "explorer" and restored.award(round_id).is_empty(), "A fresh profile restores wins, selection and duplicate protection")
	for id in ["round-2", "round-3", "round-4", "round-5"]:
		restored.award(id)
	_check(restored.wins == 5 and restored.select("light") and SkinCatalog.is_unlocked("scarlet", restored.wins), "Three and five wins unlock the remaining deterministic rewards")
	var stats := ClassCatalog.get_equipped_profile(owner.class_id, owner.equipped_items)
	var equipment := owner.equipped_items.duplicate()
	var health := owner.current_health
	_check(not registry.try_select_skin(501, "unknown", 100).ok and not registry.try_select_skin(501, "light", 0).ok, "Server rejects unknown or unavailable cosmetic IDs")
	_check(registry.try_select_skin(501, "light", 5).ok and owner.skin_id == "light", "Cosmetic selection becomes authoritative player state")
	_check(owner.equipped_items == equipment and owner.current_health == health and ClassCatalog.get_equipped_profile(owner.class_id, owner.equipped_items) == stats, "A cosmetic override changes no equipment, health, damage or defenses")
	_check(PlayerState.from_dictionary(owner.to_dictionary()).skin_id == "light", "Snapshots and updates preserve selected skin for other clients")
	manager.request(501, true, 1, 2, 15000)
	var second := str(manager.status().round_id)
	_check(second != round_id and manager.phase == "countdown" and owner.skin_id == "light", "Restart creates a fresh countdown and preserves selected skin")
	registry.try_select_class(501, 8, 15100)
	manager.restart_after_preset(501, 15100)
	_check(owner.class_id == 8 and owner.skin_id == "preset" and manager.status().round_id != second and manager.phase == "countdown", "Free class selection restarts both presets and countdown without leaking the previous class cosmetic")
	manager.remove_bot()
	_check(not registry.is_round_locked(501) and manager.phase == "idle" and manager.status().round_id == "", "Removing a countdown bot releases movement and clears its reward identity")
	manager.request(501, true, 1, 3, 16000)
	manager.peer_joining()
	_check(not registry.is_round_locked(501) and not registry.has_player(ArenaPracticeBot.BOT_ID), "A joining human cancels the preparation without an orphan lock")
	manager.request(501, true, 1, 4, 17000)
	manager.tick(20000)
	owner.apply_damage(owner.max_health)
	manager.settle_round()
	_check(manager.phase == "lost" and outcomes.filter(func(s: Dictionary) -> bool: return s.phase == "won").size() == 1, "A defeat adds no victory result or cosmetic reward")
	var visual = load("res://client/characters/player_visual.tscn").instantiate()
	root.add_child(visual)
	for skin: Dictionary in SkinCatalog.ENTRIES:
		visual.set_loadout(1, ClassCatalog.default_equipment(1), str(skin.id))
		_check(visual.body.sprite_frames.get_frame_count("walk_down") > 0 and not visual._body_definition.is_empty(), "Outfit %s has renderable AO frames" % skin.name)
	var overlay = load("res://client/ui/round_countdown.gd").new()
	root.add_child(overlay)
	overlay.update_status({"enabled":true,"owner_id":501,"phase":"countdown","round_id":"visual","countdown":3},501)
	_check(overlay.visible and overlay.title.text == "3" and overlay._audio.stream.get_length() > 0, "Countdown presents its number with a short generated tone")
	overlay.update_status({"enabled":true,"owner_id":501,"phase":"active","round_id":"visual","countdown":0},501)
	_check(overlay.title.text == "¡YA!" and overlay._audio.stream.get_length() > 0.2, "GO has a distinct sound and visual tween")
	overlay.clear()
	_check(not overlay.visible and not overlay._audio.playing and overlay._audio.stream == null, "Disconnect/cancellation cleans the overlay and stops its audio")
	DirAccess.remove_absolute(progress.storage_path)
	visual.queue_free()
	overlay.queue_free()
	registry.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("Arena rewards checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)
