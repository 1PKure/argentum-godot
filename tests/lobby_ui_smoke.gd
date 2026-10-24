extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed += 1; print("FAIL: ",label)
func _run() -> void:
	var net := root.get_node("LobbyNetwork")
	net.available = true
	var panel = load("res://client/ui/lobby_panel.gd").new()
	root.add_child(panel)
	panel.open_browser()
	for resolution: Vector2i in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600)]:
		root.size = resolution
		await process_frame
		await process_frame
		_check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(panel._content.get_global_rect()),"browser fits %s" % resolution)
		_check(not panel._name.get_global_rect().intersects(panel._arena.get_global_rect()),"browser controls separate %s" % resolution)
	net.room = {"id":1,"title":"Sala de prueba","arena_id":"forest","owner_id":1,"members":[{"peer_id":1,"name":"Player 1","class_id":1,"ready":false},{"peer_id":2,"name":"Player 2","class_id":8,"ready":true}],"phase":"waiting","revision":0,"bot_enabled":false,"bot_class":1,"round_id":"qa","countdown":0,"winner_id":0,"result_text":""}
	net.changed.emit()
	for resolution: Vector2i in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600)]:
		root.size = resolution
		await process_frame
		await process_frame
		_check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(panel._content.get_global_rect()),"room fits %s" % resolution)
		_check(panel._room_content.visible and not panel._browser.visible,"only active room shown %s" % resolution)
	root.size = Vector2i(1280,800)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/29d5597384d5/lobby-room-qa.png")
	net.room.phase = "countdown"
	net.room.countdown = 3
	net.changed.emit()
	_check(not panel._surface.visible and panel._countdown.visible,"countdown replaces lobby panel")
	net.room.phase = "fighting"
	net.room.countdown = 0
	net.changed.emit()
	_check(not panel._surface.visible,"gameplay hides lobby surface")
	net.room.phase = "result"
	net.room.result_text = "Victoria"
	net.changed.emit()
	_check(not panel._surface.visible,"result keeps arena visible for in-place rematch")
	for outcome in [[1,"Victoria"],[2,"Derrota"],[0,"Ronda interrumpida"]]:
		net.room.winner_id = outcome[0]
		net.changed.emit()
		await process_frame
		_check(_contains_label(panel._room_content,str(outcome[1])),"result identifies the local outcome: %s" % outcome[1])
	net.room = {}
	net.changed.emit()
	await process_frame
	await process_frame
	_check(panel._browser.visible,"leaving returns to room browser")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/scratch/29d5597384d5/lobby-browser-qa.png")
	root.get_node("SpellNetwork").server_capabilities_received.emit(false)
	_check(panel._message.text.contains("Versión incompatible"),"incompatible server has explicit feedback")
	_check(panel.layer < 15,"preset and skin windows can draw above lobby")
	panel.close_session()
	_check(not panel.visible,"disconnect hides lobby")
	await create_timer(0.8).timeout
	panel.queue_free()
	await process_frame
	print("Lobby UI checks: %d; failures: %d" % [checks,failed])
	quit(1 if failed else 0)

func _contains_label(node: Node, value: String) -> bool:
	if node is Label and node.text == value: return true
	for child in node.get_children():
		if _contains_label(child,value): return true
	return false
