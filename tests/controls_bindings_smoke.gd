extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed += 1
		print("FAIL: ",message)
func key(code: int, ctrl: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	return event
func _run() -> void:
	var controls := root.get_node("InputBindings")
	var original_profile: String = controls.profile_id
	controls.use_profile("__controls_qa__")
	controls.reset_defaults()
	check(controls.matches(key(KEY_W),"move_up"),"default WASD")
	check(controls.matches(key(KEY_CTRL,true),"basic_attack"),"Ctrl modifier normalized")
	check(controls.matches(key(KEY_SPACE),"use_selected"),"Space default use")
	check(controls.matches(key(KEY_L),"launch_spell"),"L launch selected")
	check(not controls.rebind("macro_0",key(KEY_W)).ok,"duplicate movement rejected")
	check(not controls.rebind("macro_0",key(KEY_K,true)).ok,"Ctrl chord conflicts with standalone attack")
	check(controls.rebind("basic_attack",key(KEY_B)).ok,"rebind attack")
	check(controls.rebind("macro_0",key(KEY_K,true)).ok,"chord allowed once Ctrl free")
	check(not controls.matches(key(KEY_K),"macro_0"),"chord requires Ctrl")
	check(controls.matches(key(KEY_K,true),"macro_0"),"chord matches")
	check(not controls.rebind("basic_attack",key(KEY_CTRL,true)).ok,"reverse modifier conflict rejected")
	check(controls.rebind("use_selected",key(KEY_U)).ok,"rebind hold potion")
	var release := key(KEY_U)
	release.pressed = false
	check(controls.is_release(release,"use_selected"),"release matches rebound hold")
	controls.use_profile("__other_controls_qa__")
	controls.reset_defaults()
	check(controls.matches(key(KEY_SPACE),"use_selected"),"new stable profile independent")
	controls.use_profile("__controls_qa__")
	check(controls.matches(key(KEY_U),"use_selected"),"stable profile reload persisted")
	var controller = load("res://client/input/spell_targeting_controller.gd").new()
	root.add_child(controller)
	controller.apply_class(1,1)
	controller.clear_hotkey(0)
	check(controller.bindings[0] == 0,"macro clears")
	controller.apply_class(1,2)
	check(controller.bindings[0] == 0,"cleared macro survives preset revision")
	controller.apply_class(8,1)
	controller.apply_class(1,3)
	check(controller.bindings[0] == 0,"cleared macro survives class switching")
	var second = load("res://client/input/spell_targeting_controller.gd").new()
	root.add_child(second)
	check(second.bindings[0] == 0,"cleared macro survives controller restart")
	var slot = load("res://client/ui/spell_slot_button.gd").new()
	root.add_child(slot)
	slot.configure(25,0,1)
	var removed: Array[int] = []
	slot.clear_requested.connect(func(index: int) -> void: removed.append(index))
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	slot._gui_input(mouse)
	check(removed == [0],"right click emits macro removal")
	var panel = load("res://client/ui/controls_panel.gd").new()
	root.add_child(panel)
	panel.open_panel()
	panel._begin_capture("macro_1")
	panel._input(key(KEY_ESCAPE))
	check(panel._capture.is_empty() and panel.visible,"Esc cancels capture without closing controls")
	panel._begin_capture("macro_1")
	panel._input(key(KEY_J))
	check(controls.matches(key(KEY_J),"macro_1") and panel._capture.is_empty(),"panel applies rebind")
	for resolution: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size = resolution
		await process_frame
		await process_frame
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(panel._content.get_global_rect()),"controls fits %s" % resolution)
	check(controls.rebind("basic_attack",key(KEY_B)).ok,"free Ctrl before modal capture")
	panel._begin_capture("macro_2")
	panel._input(key(KEY_CTRL,true))
	check(panel._capture == "macro_2","modifier press waits for chord")
	panel._input(key(KEY_H,true))
	check(controls.matches(key(KEY_H,true),"macro_2"),"modal captures full modifier chord")
	check(controls.rebind("macro_2",key(KEY_3)).ok,"free standalone modifier")
	panel._begin_capture("basic_attack")
	panel._input(key(KEY_CTRL,true))
	var ctrl_release := key(KEY_CTRL)
	ctrl_release.pressed = false
	panel._input(ctrl_release)
	# macro_0 still Ctrl+K, so conflict must keep capture active.
	check(not panel._capture.is_empty(),"standalone modifier release conflict explained")
	panel._input(key(KEY_ESCAPE))
	panel.close_panel()
	check(not panel.visible,"panel closes")
	controls.reset_defaults()
	check(controls.matches(key(KEY_1),"macro_0") and controls.matches(key(KEY_CTRL,true),"basic_attack"),"default recovery")
	controls.use_profile(original_profile)
	controller.queue_free()
	second.queue_free()
	slot.queue_free()
	panel.queue_free()
	print("CONTROLS QA checks=",checks," failures=",failed)
	quit(0 if failed == 0 else 1)
