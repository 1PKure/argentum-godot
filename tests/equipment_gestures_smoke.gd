extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ",message)
func _run() -> void:
	var avatar = load("res://client/characters/player_avatar.tscn").instantiate()
	root.add_child(avatar)
	avatar.set_process(false)
	var state := PlayerState.new(7,"Equipo",Vector2i(5,5))
	var visual = avatar._player_visual
	for class_id in [3,1]:
		state.class_id = class_id
		state.equipped_items = ClassCatalog.default_equipment(class_id)
		avatar.setup(state,true,Vector2(240,240))
		visual.set_process(false)
		for direction: Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
			visual.set_movement(direction,false)
			var body_before: Transform2D = visual.body.transform
			var head_before: Transform2D = visual.head.transform
			var avatar_before: Transform2D = avatar.transform
			check(visual.play_melee_swing() if class_id == 3 else visual.play_spell_cast(),"equipped gesture starts in direction %s class%d" % [direction,class_id])
			visual.set_process(false)
			visual._process(0.08)
			var weapon: AnimatedSprite2D = visual._equipment.weapon
			check(not weapon.position.is_zero_approx() and not is_zero_approx(weapon.rotation),"weapon visibly moves class%d %s" % [class_id,direction])
			var pose := weapon.transform
			visual.set_movement(direction,true)
			check(weapon.transform.is_equal_approx(pose),"walking frame sync preserves gesture")
			check(visual.body.transform == body_before and visual.head.transform == head_before and avatar.transform == avatar_before and avatar.grid_position == Vector2i(5,5),"gesture cannot move body, head or hitbox")
			visual._process(0.4)
			check(weapon.position.is_zero_approx() and is_zero_approx(weapon.rotation) and visual._equipment_action.is_empty(),"weapon returns exactly to original grip")
	visual.play_spell_cast()
	visual._process(0.1)
	visual.play_spell_cast()
	check(visual._equipment_action_elapsed == 0.0 and visual._equipment.weapon.position.is_zero_approx(),"rapid confirmed casts restart without stacked transforms")
	visual.set_ghost_mode(true)
	check(not visual.play_spell_cast() and visual._equipment_action.is_empty(),"ghost cancels gestures and cannot start one")
	visual.set_ghost_mode(false)
	visual.play_spell_cast()
	visual.set_loadout(3,ClassCatalog.default_equipment(3))
	check(visual._equipment_action.is_empty() and visual._equipment.weapon.position.is_zero_approx(),"class/equipment switch clears pending pose")
	avatar.queue_free()
	var world = load("res://client/scenes/client_world.gd").new()
	root.add_child(world)
	world._spawn_player(PlayerState.new(7,"Actor",Vector2i(4,5)).to_dictionary())
	world._spawn_player(PlayerState.new(8,"Rival",Vector2i(5,5)).to_dictionary())
	var actor = world._avatars[7]
	world._on_melee_resolved({"caster_id":7,"target_id":8,"amount":0})
	check(actor._player_visual._equipment_action.is_empty(),"miss/rejection produces no sword animation")
	world._on_melee_resolved({"caster_id":7,"target_id":8,"amount":10})
	check(actor._player_visual._equipment_action == "melee" and world._melee_audio.size() == 1,"confirmed hit animates weapon with existing approved audio")
	actor._player_visual._clear_equipment_gesture()
	var event := {"caster_id":7,"target_id":7,"spell_id":31,"origin_x":4,"origin_y":5,"target_x":4,"target_y":5,"amount":40,"words":"Sana"}
	world._on_spell_resolved(event)
	check(actor._player_visual._equipment_action == "cast","confirmed self-heal animates caster weapon")
	actor._player_visual._clear_equipment_gesture()
	event.action = "shot"
	event.spell_id = 247
	event.target_id = 8
	event.target_x = 5
	world._on_spell_resolved(event)
	check(actor._player_visual._equipment_action.is_empty(),"arrow event does not pretend to be a staff cast")
	actor.play_spell_cast()
	world.set_game_paused(true)
	var age: float = actor._player_visual._equipment_action_elapsed
	await create_timer(0.1).timeout
	check(actor._player_visual._equipment_action_elapsed == age,"bot pause freezes equipment animation")
	world.set_game_paused(false)
	await create_timer(0.4).timeout
	check(actor._player_visual._equipment_action.is_empty(),"resume finishes equipment animation normally")
	world.clear_session()
	world.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("Equipment gestures checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
