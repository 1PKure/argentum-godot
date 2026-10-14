class_name SpellRules
extends RefCounted


static func validate(caster: PlayerState, target: PlayerState, spell: SpellDefinition, arena_id: String) -> String:
	if caster == null or not caster.is_alive:
		return "caster_dead"
	if spell == null:
		return "unknown_spell"
	if target == null or not target.is_alive:
		return "invalid_target"
	if caster.peer_id == target.peer_id and not spell.can_target_self:
		return "self_target"
	if spell.effect == SpellDefinition.Effect.HEAL and target.current_health >= target.max_health:
		return "full_health"
	if caster.current_mana < spell.mana_cost:
		return "mana"
	var delta := target.grid_position - caster.grid_position
	if maxi(absi(delta.x), absi(delta.y)) > spell.range_tiles:
		return "range"
	if not has_line_of_sight(caster.grid_position, target.grid_position, arena_id):
		return "blocked"
	return ""


static func has_line_of_sight(start: Vector2i, finish: Vector2i, arena_id: String) -> bool:
	# Integer grid traversal, including the cells on either side of diagonal corners.
	if not ArenaData.is_walkable(arena_id, start) or not ArenaData.is_walkable(arena_id, finish):
		return false
	var cell := start
	var delta := Vector2i(absi(finish.x - start.x), absi(finish.y - start.y))
	var step := Vector2i(signi(finish.x - start.x), signi(finish.y - start.y))
	var error := delta.x - delta.y
	while cell != finish:
		var doubled := error * 2
		var move_x := doubled > -delta.y
		var move_y := doubled < delta.x
		if move_x and move_y:
			if not ArenaData.is_walkable(arena_id, cell + Vector2i(step.x, 0)):
				return false
			if not ArenaData.is_walkable(arena_id, cell + Vector2i(0, step.y)):
				return false
		if move_x:
			error -= delta.y
			cell.x += step.x
		if move_y:
			error += delta.x
			cell.y += step.y
		if not ArenaData.is_walkable(arena_id, cell):
			return false
	return true


static func get_message(reason: String) -> String:
	match reason:
		"caster_dead": return "Estás muerto. No podés lanzar hechizos."
		"unknown_spell": return "Hechizo desconocido."
		"invalid_target": return "Elegí un jugador vivo."
		"self_target": return "Ese hechizo requiere otro jugador."
		"full_health": return "El objetivo ya tiene la vida completa."
		"mana": return "No tenés suficiente maná."
		"range": return "El objetivo está fuera de alcance."
		"blocked": return "Hay un obstáculo entre vos y el objetivo."
		"cooldown": return "El hechizo todavía se está recuperando."
	return "No se pudo lanzar el hechizo."

