extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL: ",label)
func _run()->void:
	var lobby_net:=root.get_node("LobbyNetwork")
	var players:=root.get_node("PlayerNetwork")
	var World=load("res://client/scenes/client_world.gd")
	var Hud=load("res://client/ui/combat_hud.gd")
	var Panel=load("res://client/ui/lobby_panel.gd")
	var room:=ArenaLobbyRoom.new(42,"Ghost duel","forest")
	room.add_member(1);room.add_member(2)
	room.set_ready(1,true,room.revision,10000);room.set_ready(2,true,room.revision,10000)
	room.tick(13000)
	room.registry.get_player(2).grid_position=Vector2i(7,5)
	room.registry.get_player(2).apply_damage(10000)
	check(room.settle_round() and room.phase=="result","authority settles death as result")
	var world=World.new();root.add_child(world)
	var hud=Hud.new();root.add_child(hud);hud.mount_world(world);hud.start_session(1)
	var panel=Panel.new();root.add_child(panel)
	panel._active=true;panel._view_room_id=42;panel._arena_view=true
	lobby_net.room=room.state();lobby_net.changed.emit()
	players.snapshot_received.emit([room.registry.get_player(1).to_dictionary(),room.registry.get_player(2).to_dictionary()])
	await process_frame
	check(not panel._surface.visible and hud._round_strip.visible,"result leaves arena visible with inline rematch")
	var ghost=world._avatars[2]
	check(ghost.is_ghost and ghost._player_visual._visual_is_ghost,"opponent death reaches ghost visual")
	check(not ghost._player_visual.head.visible and not ghost._player_visual.body.visible and ghost._player_visual._ghost_sprite.visible,"ghost replaces living body and head")
	check(ghost._player_visual._equipment.values().all(func(sprite:AnimatedSprite2D)->bool:return not sprite.visible),"ghost hides living equipment")
	check(hud._experience_bar.value==100 and hud._experience_label.text.contains("50"),"full level-50 preset bar")
	check(hud._minimap.position.y>hud._footer_back.position.y+hud._footer_back.size.y,"minimap sits at lower right")
	if not OS.get_environment("AO_UI_CAPTURE_DIR").is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("AO_UI_CAPTURE_DIR").path_join("ghost-result.png"))
	panel.show_room();check(panel._surface.visible,"menu can explicitly return to room lobby")
	panel._arena_view=true
	check(room.registry.try_select_class(2,6,14000).ok,"dead player can choose a new class between rounds")
	room.invalidate_ready();lobby_net.room=room.state();lobby_net.changed.emit()
	check(not panel._surface.visible,"class editing does not force a lobby transition")
	room.set_ready(1,true,room.revision,15000);room.set_ready(2,true,room.revision,15000)
	check(room.phase=="countdown","both ready start rematch in same room")
	check(room.registry.get_player(2).is_alive,"rematch resets defeated player")
	room.tick(18000)
	room.registry.get_player(1).apply_damage(10000)
	room.settle_round()
	check(room.registry.get_player(1).is_ghost,"host can also be the defeated ghost")
	players.player_stats_updated.emit(room.registry.get_player(1).to_dictionary())
	check(hud._stats_button.text.contains("Revancha"),"menu death action readies next round instead of rejected respawn")
	var changed: Dictionary = room.arena.change(1,"desert",room.arena.revision,1,19000)
	check(changed.ok and room.registry.get_arena_id()=="desert","ghost host can change arena between rounds")
	room.invalidate_ready();lobby_net.room=room.state();lobby_net.changed.emit()
	check(not panel._surface.visible,"arena editing preserves in-arena preparation view")
	world.queue_free();hud.queue_free();panel.queue_free();room.dispose()
	lobby_net.room.clear();await process_frame
	print("Round view checks: %d; failures: %d"%[checks,failures]);quit(1 if failures else 0)
