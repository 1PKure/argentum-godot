extends SceneTree
const FPS:=24
const SIZE:=Vector2i(320,384)
const ORIGIN:=Vector2i(160,320)
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var viewport:=SubViewport.new();viewport.size=SIZE;viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var metadata:Dictionary={"fps":FPS,"spells":{}}
 var metadata_only:=OS.get_cmdline_user_args().has("--metadata-only")
 for id:int in ArenaSpellVisual.CONCEPTS:
  if id==247 or id==56:continue
  var fx:=ArenaSpellVisual.new();fx.configure(SpellCatalog.get_spell(id));fx.position=Vector2(ORIGIN);viewport.add_child(fx)
  var count:=ceili(fx.lifetime*FPS)
  var frames:Array[Image]=[]
  var bounds:=Rect2i()
  for index in range(count):
   fx.set_age((index+.5)/FPS)
   await process_frame;await RenderingServer.frame_post_draw
   var image:=viewport.get_texture().get_image();frames.append(image)
   var used:=image.get_used_rect()
   if used.has_area():bounds=used if not bounds.has_area() else bounds.merge(used)
  bounds=bounds.grow(3).intersection(Rect2i(Vector2i.ZERO,SIZE))
  if not bounds.has_area():push_error("Empty effect %d"%id);quit(1);return
  var file:="res://client/effects/modern_atlas/spell_%d.png"%id
  if not metadata_only:
   var sheet:=Image.create(bounds.size.x*8,bounds.size.y*ceili(count/8.0),false,Image.FORMAT_RGBA8)
   for index in range(count):sheet.blit_rect(frames[index],bounds,Vector2i(index%8,index/8)*bounds.size)
   sheet.save_png(file)
  else:
   var stored:=Image.load_from_file(file)
   if stored.get_size()!=bounds.size*Vector2i(8,ceili(count/8.0)):
    push_error("Atlas bounds mismatch: %d"%id);quit(1);return
  metadata.spells[str(id)]={"file":file,"size":[bounds.size.x,bounds.size.y],"offset":[bounds.position.x-ORIGIN.x,bounds.position.y-ORIGIN.y],"count":count,"lifetime":fx.lifetime,"concept":fx.concept}
  fx.free();print("Baked ",id," ",bounds.size," x",count)
 FileAccess.open("res://client/effects/modern_atlas/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
 viewport.queue_free();quit()
