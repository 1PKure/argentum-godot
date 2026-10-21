extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func _run() -> void:
	var resources := root.get_node("AOResources")
	var Light = load("res://client/effects/arena_modern_spell_visual.gd")
	var Effect = load("res://client/effects/arena_spell_effect.gd")
	await resources.prewarm_combat_fx()
	var shared_material: Material
	for id: int in SpellCatalog.loadout_ids():
		var visual = Light.new();visual.configure(SpellCatalog.get_spell(id));root.add_child(visual)
		check(visual.get_meta("modern_fx",false) and not visual.get_meta("procedural_only",true),"Atlas modern mode: %d"%id)
		if visual.sprite != null:
			check(visual.sprite.material is ShaderMaterial,"GPU finish without procedural shapes")
			if shared_material == null: shared_material=visual.sprite.material
			check(visual.sprite.material==shared_material,"Material reused across casts")
			var frame_count: int=visual.sprite.sprite_frames.get_frame_count("default")
			visual.set_age(visual.lifetime*0.55)
			check(visual.sprite.frame>0 or frame_count==1,"Original animation advances")
			visual.set_age(visual.lifetime+1)
			check(not visual.sprite.visible,"Animation ends")
		visual.free()
	var effect = Effect.new();effect.event={"spell_id":53,"amount":10,"words":"IN VAS POR"}
	var player := Node2D.new();root.add_child(player);effect.origin_avatar=player;effect.target_avatar=player;root.add_child(effect)
	check(is_instance_of(effect._sprite,Light),"Actual modern spell factory uses light renderer")
	player.position=Vector2(120,130);effect._process(.1)
	check(effect._sprite.position==player.position+Vector2(0,30),"Modern impact follows feet")
	effect._audio.stop();effect._audio.stream=null
	effect.queue_free();player.queue_free()
	await create_timer(.15).timeout
	print("Light FX checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
