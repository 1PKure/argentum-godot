extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",message)
func _run() -> void:
	var registry := PlayerRegistry.new()
	root.add_child(registry)
	var actor: PlayerState = registry.add_player(71)
	var rival: PlayerState = registry.add_player(72)
	actor.grid_position = Vector2i(5,5)
	rival.grid_position = Vector2i(6,5)
	actor.facing_direction = MovementRules.Direction.NORTH
	registry._status_system.effects[72] = [{"kind":"root","expires":20000}]
	var changed: PlayerState = registry.try_move_player(71,MovementRules.Direction.EAST,1000)
	_check(changed == actor and actor.grid_position == Vector2i(5,5) and actor.facing_direction == MovementRules.Direction.EAST,"turn toward adjacent rooted enemy without moving")
	var attack_time: int = registry._last_attack_time[71]
	var spell_time: int = registry._last_spell_time[71]
	_check(registry.try_move_player(71,MovementRules.Direction.WEST,1000) == null and actor.grid_position == Vector2i(5,5),"turn cannot be followed by a same-clock step")
	_check(registry.try_move_player(71,MovementRules.Direction.EAST,1120) == null and registry._last_move_time[71] == 1000,"held blocked direction produces no redundant updates")
	var before_hp := rival.current_health
	_check(registry.try_basic_attack(71,1120) == rival and rival.current_health < before_hp,"melee hits adjacent enemy after turning without walking away")
	_check(registry.try_basic_attack(71,1121) == null,"turn did not bypass melee cooldown")
	_check(spell_time == registry._last_spell_time[71] and attack_time != registry._last_attack_time[71],"only actual melee advances attack time; facing leaves spell clock untouched")
	actor.grid_position = Vector2i(0,5)
	actor.facing_direction = MovementRules.Direction.SOUTH
	_check(registry.try_move_player(71,MovementRules.Direction.WEST,1240) == actor and actor.grid_position == Vector2i(0,5),"boundary turn does not leave map")
	actor.grid_position = Vector2i(1,2)
	_check(registry.try_move_player(71,MovementRules.Direction.EAST,1360) == actor and actor.grid_position == Vector2i(1,2),"wall turn preserves collision")
	registry._status_system.effects[71] = [{"kind":"root","expires":20000}]
	_check(registry.try_move_player(71,MovementRules.Direction.NORTH,1480) == actor and actor.grid_position == Vector2i(1,2),"rooted actor can rotate but cannot step onto open tile")
	_check(registry._status_system.is_rooted(71,1480),"turn does not remove paralysis")
	registry.set_round_locked(71,true)
	_check(registry.try_move_player(71,MovementRules.Direction.SOUTH,1600) == null and actor.facing_direction == MovementRules.Direction.NORTH,"countdown/map transition lock forbids turning")
	registry.set_round_locked(71,false)
	_check(registry.try_move_player(71,99,1600) == null and registry.try_move_player(99,0,1600) == null,"invalid direction and peer rejected")
	registry._status_system.effects.erase(71)
	actor.grid_position = Vector2i(4,5)
	registry._last_move_time[71] = 2000
	_check(registry.try_move_player(71,MovementRules.Direction.EAST,2100) == actor and registry._last_move_time[71] == 2120,"turning keeps existing jitter scheduling")
	_check(registry.try_move_player(71,MovementRules.Direction.WEST,2100) == null,"jitter tolerance cannot stack a second step")
	var avatar = load("res://client/characters/player_avatar.tscn").instantiate()
	root.add_child(avatar)
	avatar.set_process(false)
	actor.grid_position = Vector2i(5,5)
	actor.facing_direction = MovementRules.Direction.NORTH
	avatar.setup(actor,false,Vector2(240,240))
	_check(avatar._player_visual.current_direction == Vector2.UP,"remote avatar spawn uses server facing")
	actor.facing_direction = MovementRules.Direction.WEST
	avatar.apply_server_stats(actor)
	avatar._process(0.02)
	_check(avatar._player_visual.current_direction == Vector2.LEFT and avatar.position == Vector2(240,240),"stationary remote turn is visible without displacement")
	actor.facing_direction = MovementRules.Direction.EAST
	avatar.apply_server_position(Vector2i(6,5),Vector2(288,240))
	avatar.apply_server_stats(actor)
	avatar._process(0.06)
	actor.facing_direction = MovementRules.Direction.NORTH
	avatar.apply_server_position(Vector2i(6,5),Vector2(288,240))
	avatar.apply_server_stats(actor)
	avatar._process(0.06)
	_check(avatar.position == Vector2(288,240) and avatar._player_visual.current_direction == Vector2.UP,"turn received during interpolation survives completed waypoint")
	avatar._process(0.2)
	_check(avatar._player_visual.current_direction == Vector2.UP,"idle animation does not overwrite authoritative turn")
	avatar.queue_free()
	registry.queue_free()
	await process_frame
	print("Facing checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
