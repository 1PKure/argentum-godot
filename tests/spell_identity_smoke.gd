extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths: Dictionary = {}
	var concepts: Dictionary = {}
	for id in SpellCatalog.loadout_ids():
		var spell := SpellCatalog.get_spell(id)
		var icon := ArenaIcons.spell(id)
		_check(icon != null and not paths.has(icon.resource_path), "Distinct icon for %s" % spell.name)
		if icon != null: paths[icon.resource_path] = id
		var visual := ArenaSpellVisual.new()
		visual.configure(spell)
		root.add_child(visual)
		_check(visual.get_child_count() == 0 and visual.get_meta("procedural_only", false), "Entirely modern geometry/particles, no AO sprite: %s" % spell.name)
		_check(not concepts.has(visual.concept), "Individual visual concept: %s" % spell.name)
		concepts[visual.concept] = id
		_check(visual.get_meta("foot_anchored", false) and visual.lifetime <= 1.5, "Foot origin and bounded presentation duration: %s" % spell.name)
		visual.set_age(visual.lifetime * 0.35)
		_check(visual.opacity_at(visual._age) > 0.9 and is_zero_approx(visual.opacity_at(visual.lifetime + 0.02)), "Visible impact fades completely, including after a large frame step: %s" % spell.name)
		if id == 51:
			var early := visual.electric_orb_positions(0.12)
			var late := visual.electric_orb_positions(0.47)
			_check(early[0].distance_to(early[1]) > 95 and late[0].distance_to(late[1]) < 1, "Descarga has TWO separated electric spheres converging at impact")
			_check(early[0].x == -early[1].x and late[0].y < -50, "Symmetric electric convergence stays over the recipient")
		if id == 41:
			var early := visual.storm_particle_positions(0.12)
			var late := visual.storm_particle_positions(0.80)
			var early_bounds := _bounds(early)
			var late_bounds := _bounds(late)
			_check(late.size() == 22 and late_bounds.size.x > early_bounds.size.x * 2.5, "Firestorm opens 22 particles OUT into a broad fan")
			_check(late_bounds.size.x > 160 and late_bounds.position.y < -65 and late_bounds.end.y < 0, "Firestorm spreads around the target rather than a narrow vertical column")
		if id == 53:
			var early := _bounds(visual.apocalypse_outline(0.12))
			var middle := _bounds(visual.apocalypse_outline(0.45))
			_check(middle.size.x > 140 and middle.size.y > 110 and middle.position.y < -205, "Apocalypse forms a LARGE energy-skull/explosion silhouette")
			_check(middle.size.x > early.size.x * 8 and middle.size.x < 180 and middle.position.y > -240, "Apocalypse grows through phases and stays local to its target")
		if id in [12, 13, 31, 242, 268, 269]:
			var early := visual.healing_particle_positions(0.22)
			var late := visual.healing_particle_positions(0.58)
			var rising := true
			for i in range(early.size()): rising = rising and late[i].y < early[i].y
			_check(rising and late.size() <= 13, "Clean healing particles rise without a static/noisy sheet: %s" % spell.name)
		visual.queue_free()
	_check(concepts.size() == 39, "Every one of the 39 supported spells has a modern presentation")
	_check(ArenaIcons.potion("health_potion").resource_path.ends_with("health.svg") and ArenaIcons.potion("mana_potion").resource_path.ends_with("mana.svg"), "Approved potion artwork is unchanged")
	await process_frame
	print("Spell identity checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points: rect = rect.expand(point)
	return rect

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
