extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var Legacy=load("res://client/effects/arena_legacy_spell_visual.gd")
 var out:=OS.get_environment("AO_UI_CAPTURE_DIR");DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,800);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var page:=Node2D.new();root.add_child(page)
 for col in range(3):
  var fx:ArenaSpellVisual=ArenaSpellVisual.new() if col==0 else ArenaModernSpellVisual.new() if col==1 else Legacy.new()
  fx.configure(SpellCatalog.get_spell(53));fx.position=Vector2(220+col*400,420);page.add_child(fx);fx.set_age(18.5/24.)
  var label:=Label.new();label.text=["Procedural anterior","Moderna precalculada","Original AO"][col];label.position=Vector2(130+col*400,470);page.add_child(label)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join("compare.png"))
 page.free();quit()
