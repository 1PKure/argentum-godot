extends SceneTree
## Approved gold whirlwind from commit041426b, bounded and baked for runtime.
const FPS := 24
const COUNT := 96
const SIZE := Vector2i(128,160)
const ORIGIN := Vector2i(64,144)
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var visual = load("res://tools/meditation_fx/approved_source.gd").new()
	visual.position = Vector2(ORIGIN)
	visual.scale = Vector2.ONE*0.65
	viewport.add_child(visual)
	visual.set_process(false)
	var frames: Array[Image] = []
	var bounds := Rect2i()
	for index in range(COUNT):
		visual.set_age(float(index)/FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image()
		frames.append(frame)
		var used := frame.get_used_rect()
		if used.has_area():bounds = used if not bounds.has_area() else bounds.merge(used)
	bounds = bounds.grow(2).intersection(Rect2i(Vector2i.ZERO,SIZE))
	var atlas := Image.create(bounds.size.x*8,bounds.size.y*12,false,Image.FORMAT_RGBA8)
	for index in range(COUNT):atlas.blit_rect(frames[index],bounds,Vector2i(index%8,index/8)*bounds.size)
	atlas.save_png("res://client/effects/modern_atlas/meditation.png")
	var metadata := {"source_commit":"041426b","fps":FPS,"count":COUNT,"columns":8,"size":[bounds.size.x,bounds.size.y],"offset":[bounds.position.x-ORIGIN.x,bounds.position.y-ORIGIN.y],"loop_seconds":4.0,"concept":"golden_rising_whirlwind"}
	FileAccess.open("res://client/effects/modern_atlas/meditation.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
	print(JSON.stringify(metadata))
	viewport.free()
	quit()
