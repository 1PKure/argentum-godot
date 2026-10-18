extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var visual = load("res://client/characters/player_visual.tscn").instantiate()
	root.add_child(visual)
	var registry = load("res://server/systems/player_registry.gd").new()
	root.add_child(registry)
	var player: PlayerState = registry.add_player(701)
	for id: int in ClassCatalog.all_ids():
		registry.try_select_class(701, id)
		var original := ClassCatalog.get_equipped_profile(id, player.equipped_items)
		visual.set_loadout(id, player.equipped_items, "preset")
		var fingerprints: Array[String] = [_fingerprint(visual.body.sprite_frames)]
		var bodies: Array[int] = [int(original.body_id)]
		var skins := SkinCatalog.for_class(id)
		_check(skins.size() == 4, "Class %d has its preset and three resolved rewards" % id)
		for skin: Dictionary in skins.slice(1):
			var body_id := int(skin.body_id)
			_check(not bodies.has(body_id), "Class %d reward %s differs from preset and earlier body IDs" % [id, skin.name])
			bodies.append(body_id)
			visual.set_loadout(id, player.equipped_items, str(skin.id))
			var fingerprint := _fingerprint(visual.body.sprite_frames)
			_check(not fingerprint.is_empty() and not fingerprints.has(fingerprint), "Class %d reward %s has distinct visible animation pixels" % [id, skin.name])
			fingerprints.append(fingerprint)
			var before := player.to_dictionary()
			_check(registry.try_select_skin(701, str(skin.id), int(skin.wins)).ok and player.equipped_items == before.equipped_items and player.current_health == int(before.current_health) and ClassCatalog.get_equipped_profile(id, player.equipped_items) == original, "Class %d cosmetic selection preserves equipment and combat statistics" % id)
			_check(visual._body_definition == root.get_node("AOResources").get_body_definition(body_id), "Class %d renderer resolves its own reward body" % id)
			if id == 1 or id == 6:
				_check(body_id >= 100 and body_id <= 156, "Caster class %d reward remains a robe" % id)
	_check(SkinCatalog.get_skin("explorer", 8).body_id != ClassCatalog.get_profile(8).body_id, "Hunter's first win cannot repeat its starter armor")
	_check(SkinCatalog.for_class(9).is_empty(), "Discarded classes have no cosmetic catalog")
	# v1 IDs and the same storage file retain previously earned wins/selection.
	var progress := SkinProgress.new()
	progress.storage_path = "user://class-skin-migration-test.cfg"
	var config := ConfigFile.new()
	config.set_value("skins", "wins", 3)
	config.set_value("skins", "selected", "scarlet")
	config.set_value("skins", "claimed", ["earned-before-class-skins"])
	config.save(progress.storage_path)
	progress.restore()
	_check(progress.wins == 3 and progress.selected == "scarlet" and progress.award("earned-before-class-skins").is_empty(), "Existing saves retain wins, equipped tier and claimed rewards")
	for id: int in ClassCatalog.all_ids():
		_check(SkinCatalog.is_unlocked(progress.selected, progress.wins, id), "Saved tier resolves to a valid unlocked outfit for class %d" % id)
	DirAccess.remove_absolute(progress.storage_path)
	visual.queue_free()
	registry.queue_free()
	await process_frame
	print("Class skin checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _fingerprint(frames: SpriteFrames) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for animation: StringName in frames.get_animation_names():
		for index in range(frames.get_frame_count(animation)):
			var image := frames.get_frame_texture(animation, index).get_image()
			if image == null or not image.get_used_rect().has_area():
				return ""
			image = image.get_region(image.get_used_rect())
			context.update(image.get_data())
	return context.finish().hex_encode()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)
