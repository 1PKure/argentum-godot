extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var Light=load("res://client/effects/arena_modern_spell_visual.gd")
 var Legacy=load("res://client/effects/arena_legacy_spell_visual.gd")
 var Effect=load("res://client/effects/arena_spell_effect.gd")
 await ArenaBakedSpellAtlas.prewarm(self)
 for id:int in ClassCatalog.COMBAT_BOOK_ORDER:
  var visual=Light.new();visual.configure(SpellCatalog.get_spell(id));root.add_child(visual)
  var another=Light.new();another.configure(SpellCatalog.get_spell(id));root.add_child(another)
  var original=Legacy.new();original.configure(SpellCatalog.get_spell(id));root.add_child(original)
  check(visual.sprite!=null,"Modern atlas exists: %d"%id)
  check(visual.get_meta("baked_procedural",false) and not visual.get_meta("procedural_only",true),"No procedural redraw")
  if visual.sprite==null:quit(1);return
  check(visual.sprite.sprite_frames==another.sprite.sprite_frames,"Shared frames")
  var texture:Texture2D=visual.sprite.sprite_frames.get_frame_texture("default",0)
  var original_texture:Texture2D=original.sprite.sprite_frames.get_frame_texture("default",0) if original.sprite!=null else null
  check(texture!=original_texture and visual.concept!="ao_atlas_finish","Distinct modern artwork")
  visual.set_age(visual.lifetime*.55)
  check(visual.sprite.frame>0 and another.sprite.frame==0,"Independent playback")
  visual.set_age(visual.lifetime+1);check(not visual.sprite.visible,"Animation stops")
  visual.free();another.free();original.free()
 var effect=Effect.new();effect.event={"spell_id":53,"amount":10,"words":"IN VAS POR"}
 var player:=Node2D.new();root.add_child(player);effect.origin_avatar=player;effect.target_avatar=player;root.add_child(effect)
 check(is_instance_of(effect._sprite,Light),"Modern factory uses baked renderer")
 player.position=Vector2(120,130);effect._process(.1)
 check(effect._sprite.position==player.position+Vector2(0,30),"Effect follows feet")
 effect._audio.stop();effect._audio.stream=null
 effect.queue_free();player.queue_free();await create_timer(.15).timeout
 ArenaBakedSpellAtlas._frames.clear()
 print("Baked FX checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
