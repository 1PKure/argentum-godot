extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ", label)
func _run() -> void:
	var resources := root.get_node("AOResources")
	var Legacy = load("res://client/effects/arena_legacy_spell_visual.gd")
	var Effect = load("res://client/effects/arena_spell_effect.gd")
	var Meditation = load("res://client/effects/arena_meditation_visual.gd")
	check(ArenaVisualSettings.default_original(true) and not ArenaVisualSettings.default_original(false), "web original/native modern defaults")
	await resources.prewarm_combat_fx()
	var cache_count: int = resources._fx_frame_cache.size()
	for id: int in SpellCatalog.loadout_ids():
		var spell := SpellCatalog.get_spell(id)
		var visual = Legacy.new();visual.configure(spell);root.add_child(visual)
		if int(spell.fx_id)>0 or spell.effect=="healing":
			check(visual.sprite!=null,"Original atlas loads: "+spell.name)
			if visual.sprite!=null:
				var frames: SpriteFrames = visual.sprite.sprite_frames
				check(visual.lifetime>=0.4 and frames.get_frame_count("default")>0,"Actual atlas duration")
				visual.set_age(visual.lifetime*0.6)
				check(visual.sprite.frame>0 or frames.get_frame_count("default")==1,"Frames advance")
				check(visual.sprite.get_meta("visible_bottoms").size()==frames.get_frame_count("default"),"Visible bases grounded")
				var duplicate = resources.create_fx_sprite(visual.source_fx_id,false,true)
				check(duplicate.sprite_frames==frames,"Cached frames reused")
				duplicate.frame=0
				check(duplicate.frame!=visual.sprite.frame or frames.get_frame_count("default")==1,"Independent playback")
				duplicate.free()
		visual.set_age(visual.lifetime+0.1)
		check(visual.sprite==null or not visual.sprite.visible,"FX hides at animation end")
		check(not visual.get_meta("procedural_only",true),"No procedural drawing")
		visual.free()
	check(resources._fx_frame_cache.size()==cache_count,"Prewarm covers combat FX")
	var effect = Effect.new();effect.event={"spell_id":53,"amount":120,"words":"IN VAS POR","action":"cast"}
	var caster := Node2D.new();root.add_child(caster)
	var target := Node2D.new();root.add_child(target)
	effect.origin_avatar=caster;effect.target_avatar=target;root.add_child(effect)
	check(is_instance_of(effect._sprite,Legacy),"Factory respects original override")
	target.position=Vector2(200,150);effect._process(0.05)
	check(effect._sprite.position==target.position+Vector2(0,30),"FX follows target feet")
	check(effect._words.position==caster.position+Vector2(-100,-107),"Words follow caster")
	check(effect._audio!=null and effect._audio.volume_db == -12.0 and effect._audio.playback_type==AudioServer.PLAYBACK_TYPE_STREAM,"Audio preserved for A/B")
	var meditation = Meditation.new();root.add_child(meditation)
	check(meditation._legacy!=null and meditation._legacy.sprite_frames.get_animation_loop("default"),"Original looping meditation")
	meditation.hide();check(not meditation.is_processing(),"Hidden meditation wrapper stops")
	var overlay = load("res://client/ui/arena_performance_overlay.gd").new();root.add_child(overlay)
	ArenaVisualSettings.metrics=true
	ArenaVisualSettings.diagnostic_details=true
	for i in range(650): overlay._process(0.016)
	check(overlay.intervals.size()==600 and overlay.text.contains("p95"),"Bounded frame meter")
	ArenaVisualSettings.metrics=false;ArenaVisualSettings.diagnostic_details=false;overlay._process(0.016)
	check(overlay.intervals.is_empty() and not overlay.visible,"Hidden meter clears samples")
	effect._audio.stop()
	effect._audio.stream = null
	for node in [effect,caster,target,meditation,overlay]:node.queue_free()
	await create_timer(0.15).timeout
	print("Web FX checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
