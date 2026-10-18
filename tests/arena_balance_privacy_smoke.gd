extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var profiles := {1: Vector2i(363, 2487), 2: Vector2i(412, 1809), 3: Vector2i(510, 0), 4: Vector2i(437, 927), 5: Vector2i(412, 1809), 6: Vector2i(412, 1809), 7: Vector2i(486, 927), 8: Vector2i(486, 0), 12: Vector2i(437, 698)}
	for id: int in profiles:
		var p := ClassCatalog.get_profile(id)
		_check(Vector2i(p.max_health, p.max_mana) == profiles[id], "%s uses AO20 human level-50 mean resources" % p.name)
		print("PROFILE %s HP=%s MP=%s physical=%s armor=%s" % [p.name, p.max_health, p.max_mana, p.physical_power, p.armor_points])
	_check(ClassCatalog.physical_damage_range(8, 1) == Vector2i(181, 200), "Hunter's actual equipped damage range against mage is 181-200")
	_check(ClassCatalog.physical_damage_range(8, 3).x < 181, "Warrior's torso armor absorbs more than a mage robe")
	var no_armor := ClassCatalog.default_equipment(1)
	no_armor.erase("armor")
	_check(ClassCatalog.physical_damage_range(8, 1, ClassCatalog.default_equipment(8), no_armor) == Vector2i(211, 230), "Unequipping the robe removes exactly 30 points of absorption")
	_check(ClassCatalog.magic_damage(92, 1, 1) == 223 and ClassCatalog.magic_damage(98, 1, 1) == 238, "Level-50 Apocalypse includes the original +3 percent per level")
	_check(ClassCatalog.magic_damage(92, 1, 1, null, null, false) == 89, "Periodic effects do not inherit the direct-hit level bonus")
	_check(ClassCatalog.magic_damage(92, 1, 1, null, null, true, true) == 251, "AntiRm spells bypass resistance but retain level and weapon bonuses")
	_check(SpellCatalog.direct_damage(53, ClassCatalog.magic_damage(92, 1, 1)) == 205 and SpellCatalog.direct_damage(53, ClassCatalog.magic_damage(98, 1, 1)) == 219, "Arena Apocalypse is reduced eight percent after equipment and resistance")
	_check(SpellCatalog.direct_damage(51, ClassCatalog.magic_damage(70, 1, 1)) == 156 and SpellCatalog.direct_damage(51, ClassCatalog.magic_damage(76, 1, 1)) == 169, "Arena Discharge is reduced eight percent after equipment and resistance")
	_check(SpellCatalog.direct_damage(3, 170) == 170 and SpellCatalog.get_spell(53).min_amount == 92 and SpellCatalog.get_spell(51).max_amount == 76, "Other spells and imported AO20 data keep their original damage values")
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var caster: PlayerState = registry.add_player(701)
	var target: PlayerState = registry.add_player(702)
	target.max_health = 10000
	target.current_health = 10000
	var tuned := true
	for index in range(20):
		caster.current_mana = caster.max_mana
		var id := 53 if index % 2 == 0 else 51
		var result: Dictionary = registry.try_cast_spell(701, id, target.grid_position, index + 1, 10000 + index * 1000)
		var lower := 205 if id == 53 else 156
		var upper := 219 if id == 53 else 169
		tuned = tuned and result.ok and int(result.event.amount) >= lower and int(result.event.amount) <= upper and caster.current_mana == caster.max_mana - int(SpellCatalog.get_spell(id).mana)
	_check(tuned, "Real authoritative casts apply tuned damage with original mana costs to both combat actors")
	registry.queue_free()
	var state := PlayerState.new(7, "Rival")
	state.current_mana = 73
	var net = root.get_node("PlayerNetwork")
	var own: Dictionary = net.for_recipient(state.to_dictionary(), 7)
	var rival: Dictionary = net.for_recipient(state.to_dictionary(), 8)
	_check(own.current_mana == 73 and not rival.has("current_mana") and rival.mana_is_private, "Recipient serialization sends actual mana only to its owner")
	_check(state.current_mana == 73 and state.to_dictionary().current_mana == 73, "Redaction never mutates canonical server state")
	var parsed := PlayerState.from_dictionary(rival)
	_check(parsed.mana_is_private and parsed.current_mana == 0, "Redacted mana stays unknown in parsed remote state")
	var hud = load("res://client/ui/combat_hud.gd").new()
	root.add_child(hud)
	hud.start_session(8)
	hud.console.clear_session()
	var event := {"caster_id": 7, "target_id": 7, "caster_name": "Rival", "target_name": "Rival", "spell_name": "Curación", "amount": 20, "effect": "healing"}
	hud._on_spell_event(event)
	hud._on_recovery_event({"peer_id": 7, "player_name": "Rival", "action": "mana_potion", "message": "Usó poción azul (+124)."})
	_check(hud.console.entries.is_empty(), "Rival self-heal and potion feedback are excluded")
	event.target_id = 8
	event.spell_name = "Paralizar"
	event.amount = 0
	event.effect = "status"
	hud._on_spell_event(event)
	_check(hud.console.entries.size() == 1 and hud.console.entries[0].text == "Rival te lanzó Paralizar.", "Incoming spell identifies the attacker and spell concisely")
	event.caster_id = 8
	event.target_id = 7
	event.spell_name = "Descarga"
	event.amount = 90
	hud._on_spell_event(event)
	_check(hud.console.entries[-1].text == "Lanzaste Descarga a Rival · 90.", "Own spell feedback identifies target and confirmed amount")
	_check(hud._pixel_scale == 1 and hud._controls_hint.text.is_empty(), "Default view is zoomed out and has no persistent keyboard tutorial")
	hud.queue_free()
	await process_frame
	print("Balance/privacy checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
