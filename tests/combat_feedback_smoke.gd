extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_inventory()
	await _test_effects()
	# Give the audio server time to release playback after its owner is freed.
	await create_timer(0.15).timeout
	print("Combat feedback checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _test_inventory() -> void:
	var layout := ArenaInventoryLayout.new()
	layout.storage_path = "user://inventory-feedback-test.cfg"
	_check(layout.move_item(0, 41, "health_potion") and layout.actions[0] == "" and layout.actions[41] == "health_potion", "Potion moves into the final empty inventory slot")
	_check(layout.move_item(41, 1, "health_potion") and layout.actions[1] == "health_potion" and layout.actions[41] == "mana_potion", "Dropping onto another potion swaps rather than overwrites it")
	_check(not layout.move_item(41, 0, "health_potion"), "Stale drag payload cannot move a different item")
	_check(not layout.move_item(-1, 0, "mana_potion") and not layout.move_item(41, 42, "mana_potion"), "Out-of-range inventory drops are rejected")
	_check(layout.actions.count("health_potion") == 1 and layout.actions.count("mana_potion") == 1, "Rearrangement never creates or destroys arena supplies")
	_check(layout.save() == OK, "Inventory arrangement can be saved")
	var restored := ArenaInventoryLayout.new()
	restored.storage_path = layout.storage_path
	restored.restore()
	_check(restored.actions == layout.actions, "A fresh inventory restores the saved arrangement")
	var invalid := ConfigFile.new()
	var duplicate := layout.actions.duplicate()
	duplicate[0] = "health_potion"
	invalid.set_value("arena", "slots", duplicate)
	invalid.save(layout.storage_path)
	var clean := ArenaInventoryLayout.new()
	clean.storage_path = layout.storage_path
	clean.restore()
	_check(clean.actions[0] == "health_potion" and clean.actions[1] == "mana_potion" and clean.actions.count("health_potion") == 1, "Corrupt saved data falls back to the two original supplies")
	DirAccess.remove_absolute(layout.storage_path)


func _test_effects() -> void:
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.configure_viewport(Vector2(900, 600))
	var caster := PlayerState.new(1, "Lanzador", Vector2i(4, 5))
	var target := PlayerState.new(2, "Objetivo", Vector2i(7, 5))
	caster.is_meditating = true
	world._on_snapshot_received([caster.to_dictionary(), target.to_dictionary()])
	var caster_avatar = world._avatars[1]
	var target_avatar = world._avatars[2]
	caster_avatar.set_process(false)
	target_avatar.set_process(false)
	var med: AnimatedSprite2D = caster_avatar._meditation_fx
	_check(med != null and med.visible and med.z_index > caster_avatar.get_node("PlayerVisual").z_index, "Meditation renders in front of the character")
	_check(med.scale.is_equal_approx(Vector2.ONE * 1.05), "Meditation is thirty percent smaller than its previous size")
	_check(med.modulate.a < 1.0, "Continuous meditation leaves the character visible through its effect")
	_check(caster_avatar._name_label.z_index > med.z_index and caster_avatar._status_bars.z_index > med.z_index, "Name and health/mana bars remain above meditation")
	_check(caster_avatar._name_label.position.y > caster_avatar._status_bars.position.y + PlayerStatusBars.HEALTH_BAR_HEIGHT + PlayerStatusBars.BAR_GAP + PlayerStatusBars.MANA_BAR_HEIGHT and caster_avatar._name_label.text == caster.display_name, "Clean character name sits below both resource bars, away from incantations")
	_check(_frame_bottom_is_anchored(med), "Meditation's frame bottom is anchored to the feet")
	_check(not med.has_meta("visible_bottoms") and is_equal_approx(med.modulate.a, 0.72), "Accepted meditation layout and opacity are unchanged")
	world._on_spell_resolved({"spell_id": 13, "amount": 20, "words": "EN COR SANCTIS", "caster_id": 1, "target_id": 2, "origin_x": 4, "origin_y": 5, "target_x": 7, "target_y": 5})
	var effect = world._spell_effects[-1]
	effect.set_process(false)
	_check(effect._sprite != null and not effect._sprite.sprite_frames.get_animation_loop("default"), "Healing uses a single original AO animation")
	_check(_visible_base_is_anchored(effect._sprite), "Healing FX grounds its actual pixels rather than transparent canvas")
	_check(effect.process_priority > target_avatar.process_priority and effect.process_priority < world.process_priority, "Effects follow interpolation before the camera moves")
	var initial_target: Vector2 = target_avatar.position
	target_avatar.apply_server_position(Vector2i(8, 5), initial_target + Vector2(48, 0))
	target_avatar._process(0.06)
	caster_avatar.position += Vector2(0, -24)
	effect._process(0.06)
	_check(effect.target.is_equal_approx(initial_target + Vector2(24, 0)), "Impact follows the rendered half-step rather than the server's next tile")
	_check(effect.origin.is_equal_approx(caster_avatar.position), "Caster words track their own independently moving avatar")
	_check(effect._words.position.is_equal_approx(caster_avatar.position + Vector2(-100, -107)), "Incantation stays above the caster")
	_check(is_equal_approx(effect._text.position.x + 80, target_avatar.position.x), "Floating result follows the target horizontally")
	_check(is_equal_approx(effect._text.position.y, target_avatar.position.y - 85 - 0.06 * 24), "Floating result follows the target and keeps its upward animation")
	_check(effect._sprite.position.is_equal_approx(target_avatar.position + Vector2(0, 30)), "Healing graphic stays on the moving character's feet")
	effect._sprite.pause()
	effect._sprite.frame = effect._sprite.sprite_frames.get_frame_count("default") - 1
	_check(effect._sprite.offset.y > -48 and _visible_base_is_anchored(effect._sprite), "The final healing pillar compensates its transparent bottom margin")
	await _capture("spell-feet-healing.png")
	world._on_spell_resolved({"spell_id": 53, "amount": 95, "words": "Rahma Nañarak O Al", "caster_id": 1, "target_id": 2, "origin_x": 4, "origin_y": 5, "target_x": 8, "target_y": 5})
	var apocalypse = world._spell_effects[-1]
	apocalypse.set_process(false)
	apocalypse._sprite.pause()
	apocalypse._sprite.frame = mini(7, apocalypse._sprite.sprite_frames.get_frame_count("default") - 1)
	_check(_visible_base_is_anchored(apocalypse._sprite), "Apocalypse also rests its visible graphic on the feet")
	effect.visible = false
	await _capture("spell-feet-apocalypse.png")
	world._on_spell_resolved({"action": "shot", "spell_id": 247, "amount": 190, "words": "", "caster_id": 1, "target_id": 2, "origin_x": 4, "origin_y": 5, "target_x": 8, "target_y": 5})
	var arrow = world._spell_effects[-1]
	arrow.set_process(false)
	_check(arrow._audio != null and arrow._audio.stream.resource_path.ends_with("arrow_hit.wav") and not arrow._audio.playing, "Confirmed arrow prepares the uploaded arrow sound without playing it before impact")
	arrow._process(0.17)
	_check(not arrow._shot_sound_played and not arrow._audio.playing, "Arrow travel does not prematurely play its impact sound")
	arrow._process(0.02)
	_check(arrow._shot_sound_played and arrow._audio.playing and not arrow._projectile.visible, "Reaching the target plays arrow feedback exactly at visible impact")
	_check(arrow._lifetime >= 0.18 + arrow._audio.stream.get_length(), "Arrow effect leaves enough time to finish its original audio")
	world._on_player_despawned(2)
	effect._process(0.0)
	_check(not effect._sprite.visible and not effect._text.visible and effect._words.visible, "A despawn hides only the missing target's visual feedback")
	world._on_player_spawned(target.to_dictionary())
	effect._process(0.0)
	_check(not effect._sprite.visible, "Old effects cannot attach to a newly spawned avatar reusing the peer ID")
	world.clear_session()
	await process_frame
	_check(world._spell_effects.is_empty(), "Disconnect clears attached effects as well as avatars")
	world.queue_free()
	await process_frame


func _frame_bottom_is_anchored(sprite: AnimatedSprite2D) -> bool:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return is_zero_approx(sprite.offset.y + texture.get_height() * 0.5)


func _visible_base_is_anchored(sprite: AnimatedSprite2D) -> bool:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var used := texture.get_image().get_used_rect()
	return not used.has_area() or is_zero_approx(sprite.offset.y - texture.get_height() * 0.5 + used.end.y)


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var directory := OS.get_environment("AO_UI_CAPTURE_DIR")
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(filename))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
