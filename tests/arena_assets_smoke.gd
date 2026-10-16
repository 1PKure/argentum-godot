extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = load("res://shared/gameplay/spell_catalog.gd")
	var resources = root.get_node("AOResources")
	for id in catalog.loadout_ids():
		var spell: Dictionary = catalog.get_spell(id)
		_check(resources.get_icon_texture(catalog.display_icon_grh(id)) != null, "Exported icon loads: %s" % spell.name)
		var fx_id: int = int(spell.fx_id)
		if fx_id == 0 and spell.effect == "healing":
			fx_id = 9
		if fx_id > 0:
			var sprite = resources.create_fx_sprite(fx_id, false, true)
			_check(sprite != null, "All frames load for FX: %s" % spell.name)
			if sprite != null:
				_check(_all_visible_bases_anchored(sprite), "Visible frame bases are grounded: %s" % spell.name)
				sprite.free()
		if int(spell.sound_id) > 0:
			var path := "res://assets/argentum/source/audio/%d.wav" % int(spell.sound_id)
			if not ResourceLoader.exists(path):
				path = "res://assets/argentum/source/audio/16.wav"
			_check(load(path) is AudioStream, "Compatible audio loads: %s" % spell.name)
	var meditation = resources.create_fx_sprite(120)
	_check(meditation != null, "Original meditation animation loads")
	if meditation != null:
		meditation.free()
	_check(load("res://assets/argentum/source/audio/135.wav") is AudioStream, "Original potion audio loads")
	print("Arena asset checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)


func _all_visible_bases_anchored(sprite: AnimatedSprite2D) -> bool:
	for index in range(sprite.sprite_frames.get_frame_count("default")):
		sprite.frame = index
		var texture := sprite.sprite_frames.get_frame_texture("default", index)
		var used := texture.get_image().get_used_rect()
		if used.has_area() and not is_zero_approx(sprite.offset.y - texture.get_height() * 0.5 + used.end.y):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + message)
