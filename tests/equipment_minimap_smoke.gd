extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(message)
func _run() -> void:
	var resources := root.get_node("AOResources")
	var item := ClassCatalog.get_item(int(ClassCatalog.get_profile(3).weapon))
	check(int(ClassCatalog.get_profile(3).weapon)==126 and int(item.Anim)==4,"warrior uses silver sword with matching existing icon and equipped animation")
	var blade: Texture2D = resources.get_equipment_icon(126)
	check(blade is AtlasTexture and blade.atlas.resource_path.ends_with("/112.png"),"sword icon comes from verified equipment sheet rather than bat animation")
	var shield: Texture2D = resources.get_equipment_icon(2933)
	var frames: SpriteFrames = resources.get_equipment_frames("shield",83)
	var original := frames.get_frame_texture("walk_down",0).get_image()
	var correct := original.get_region(original.get_used_rect())
	check(shield.get_image().get_data()==correct.get_data(),"silver shield uses exact visible equipped metal shield frame")
	check(resources.get_equipment_icon(2933)==shield,"corrected icon is cached across inventory refreshes")
	var map := ArenaMinimap.new()
	root.add_child(map)
	map.size = Vector2(168,100)
	for id: String in ArenaData.IDS:
		map.arena_id=id
		var area := map.map_rect()
		check(Rect2(Vector2.ZERO,map.size).encloses(area) and is_equal_approx(area.size.x/area.size.y,20.0/12.0),"minimap preserves real playable aspect ratio: "+id)
		var inside := true
		for cell: Vector2i in ArenaData.get_definition(id).blocked_cells: inside = inside and area.has_point(map.point_for(cell))
		check(inside and area.has_point(map.point_for(Vector2i(0,0))) and area.has_point(map.point_for(Vector2i(19,11))),"all obstacles and edge tiles map inside frame: "+id)
	map.queue_free()
	await process_frame
	print("Equipment/minimap checks: %d; failures: %d"%[checks,failures])
	quit(1 if failures else 0)
