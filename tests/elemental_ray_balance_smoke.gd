extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var registry := PlayerRegistry.new()
	root.add_child(registry)
	var caster := registry.add_player(901)
	var target := registry.add_player(902)
	registry.try_select_class(901, 6, 10000)
	caster.grid_position = Vector2i(5, 5)
	target.grid_position = Vector2i(6, 5)
	target.max_health = 10000
	target.current_health = 10000
	caster.current_mana = 799
	var denied := registry.try_cast_spell(901, 59, target.grid_position, 1, 20000)
	check(not denied.ok and caster.current_mana == 799 and target.current_health == 10000, "The previous cheap budget cannot cast Elemental Ray or spend resources.")
	caster.current_mana = 800
	var cast := registry.try_cast_spell(901, 59, target.grid_position, 2, 22000)
	check(cast.ok and caster.current_mana == 0, "The authoritative cast consumes the new800mana cost.")
	var old_minimum := ClassCatalog.magic_damage(77, caster.class_id, target.class_id, caster.equipped_items, target.equipped_items)
	check(cast.ok and int(cast.event.amount) < old_minimum, "Even the new maximum roll deals less damage than the previous minimum against the same target.")
	check(SpellCatalog.get_spell(53).mana == 1000, "Apocalypse retains its existing mana cost.")
	registry.queue_free()
	await process_frame
	print("Elemental Ray balance checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
