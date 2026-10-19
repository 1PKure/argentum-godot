extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths: Dictionary = {}
	for id in SpellCatalog.loadout_ids():
		var spell := SpellCatalog.get_spell(id)
		var icon := ArenaIcons.spell(id)
		_check(icon != null and not paths.has(icon.resource_path), "Distinct icon for %s" % spell.name)
		if icon != null: paths[icon.resource_path] = id
		var visual := ArenaSpellVisual.new()
		visual.configure(spell)
		root.add_child(visual)
		if int(spell.fx_id) > 0:
			_check(visual._source != null and visual.source_fx_id == int(spell.fx_id), "Catalogue animation retained: %s" % spell.name)
		if visual._source != null:
			visual.set_age(visual.lifetime * 0.52)
			_check(visual._source.frame > 0 or visual._source.sprite_frames.get_frame_count("default") == 1, "Source animation advances: %s" % spell.name)
			_check(visual._source.offset == visual._source_glow.offset, "Halo stays on the source foot anchor: %s" % spell.name)
			_check(visual._source.material != null and visual._source_glow.material != null, "Subtle emissive finish: %s" % spell.name)
			visual.set_age(visual.lifetime + 0.02)
			_check(visual._source.modulate.a == 0.0 and visual._source_glow.modulate.a == 0.0, "No lingering sprite or halo: %s" % spell.name)
		if id == 53:
			_check(visual.source_fx_id == 13 and visual._source.scale.x > 1.5, "Apocalypse retains its large orange source explosion")
		if id == 51:
			_check(visual.source_fx_id == 11, "Descarga retains its cloud and branching bolts")
		visual.queue_free()
	_check(ArenaIcons.potion("health_potion").resource_path.ends_with("health.svg") and ArenaIcons.potion("mana_potion").resource_path.ends_with("mana.svg"), "Approved potion artwork is unchanged")
	await process_frame
	print("Spell identity checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
