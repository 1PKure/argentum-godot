class_name ArenaStatusSystem
extends RefCounted

var effects: Dictionary = {}


func is_rooted(peer_id: int, now: int) -> bool:
	for effect: Dictionary in effects.get(peer_id, []):
		if effect.kind == "root" and int(effect.expires) > now:
			return true
	return false


func is_paralyzed(peer_id: int, now: int) -> bool:
	for effect: Dictionary in effects.get(peer_id, []):
		if effect.get("kind") == "root" and int(effect.expires) > now and bool(effect.get("locks_facing",effect.get("name","") == "Paralizado")):
			return true
	return false


func apply_spell(caster: PlayerState, target: PlayerState, spell: Dictionary, now: int) -> Dictionary:
	var raw: Dictionary = spell.raw
	var message := ""
	if SpellCatalog.PERIODIC_HANDLERS.has(int(spell.id)):
		var source: Dictionary = AODataFile.read_sections("res://assets/argentum/source/data/EffectsOverTime.dat").get("EOT%d" % int(spell.eot_id), {})
		if source.is_empty():
			return {"ok": false, "message": "Faltan los datos del efecto periódico."}
		var list: Array = effects.get(target.peer_id, [])
		# AO limit 1 replaces restoration; limit 2 is one instance per caster.
		for index in range(list.size() - 1, -1, -1):
			if list[index].kind == "periodic" and int(list[index].eot_id) == int(spell.eot_id) and (int(source.get("Limit", "1")) == 1 or int(list[index].caster_id) == caster.peer_id):
				list.remove_at(index)
		var interval := int(source.get("TickTime", "1000"))
		var ticks := int(source.get("Ticks", "1"))
		var min_power := int(source.get("TickPowerMin", "0"))
		var max_power := int(source.get("TickPowerMax", "0"))
		if min_power < 0:
			min_power = -ClassCatalog.magic_damage(-min_power, caster.class_id, target.class_id, caster.equipped_items, target.equipped_items, false, int(raw.get("AntiRm", "0")) == 1)
		if max_power < 0:
			max_power = -ClassCatalog.magic_damage(-max_power, caster.class_id, target.class_id, caster.equipped_items, target.equipped_items, false, int(raw.get("AntiRm", "0")) == 1)
		list.append({"kind": "periodic", "name": str(spell.name), "eot_id": int(spell.eot_id),
			"caster_id": caster.peer_id, "negative": int(source.get("BuffType", "1")) == 2,
			"min": min_power, "max": max_power,
			"interval": interval, "next_tick": now + interval, "ticks": ticks, "expires": now + ticks * interval + 1})
		effects[target.peer_id] = list
		message = str(spell.name)
	elif int(raw.get("Paraliza", "0")) == 1 or int(raw.get("Inmoviliza", "0")) == 1:
		var list: Array = effects.get(target.peer_id, [])
		var label := "Paralizado" if int(raw.get("Paraliza", "0")) == 1 else "Inmovilizado"
		for index in range(list.size() - 1, -1, -1):
			if list[index].kind == "root" and bool(list[index].get("locks_facing",list[index].get("name","") == "Paralizado")) == (int(raw.get("Paraliza","0")) == 1):
				list.remove_at(index)
		list.append({"kind": "root", "name": label, "locks_facing": int(raw.get("Paraliza", "0")) == 1, "negative": true, "expires": now + int(float(spell.duration) * 1000.0)})
		effects[target.peer_id] = list
		message = label
	else:
		var list: Array = effects.get(target.peer_id, [])
		var removed := 0
		for index in range(list.size() - 1, -1, -1):
			var entry: Dictionary = list[index]
			var clear_root: bool = int(raw.get("RemoverParalisis", "0")) == 1 and entry.kind == "root"
			var clear_poison: bool = int(raw.get("CuraVeneno", "0")) == 1 and entry.get("kind") == "poison"
			var clear_negative: bool = int(raw.get("Sanacion", "0")) == 1 and bool(entry.negative)
			var clear_one: bool = int(raw.get("RemoveDebuff", "0")) == 1 and bool(entry.negative) and removed == 0
			if clear_root or clear_poison or clear_negative or clear_one:
				list.remove_at(index)
				removed += 1
		if removed == 0 and int(spell.max_amount) == 0:
			return {"ok": false, "message": "El objetivo no tiene un estado que este hechizo pueda remover."}
		effects[target.peer_id] = list
		message = "Efectos removidos: %d" % removed
	_sync_labels(target)
	return {"ok": true, "message": message}


func tick(players: Dictionary, now: int) -> Array[PlayerState]:
	var changed: Array[PlayerState] = []
	for peer_id: int in effects.keys():
		var player: PlayerState = players.get(peer_id)
		if player == null or not player.is_alive:
			effects.erase(peer_id)
			if player != null:
				player.active_effects.clear()
			continue
		var list: Array = effects[peer_id]
		var modified := false
		for index in range(list.size() - 1, -1, -1):
			var entry: Dictionary = list[index]
			if entry.kind == "periodic" and now >= int(entry.next_tick) and now <= int(entry.expires):
				var low := mini(int(entry.min), int(entry.max))
				var high := maxi(int(entry.min), int(entry.max))
				var amount := randi_range(low, high)
				if amount < 0:
					player.apply_damage(-amount)
				else:
					player.restore_health(amount)
				entry.ticks = int(entry.ticks) - 1
				entry.next_tick = now + int(entry.interval)
				modified = true
			if now >= int(entry.expires) or int(entry.get("ticks", 1)) <= 0 or not player.is_alive:
				list.remove_at(index)
				modified = true
		effects[peer_id] = list if player.is_alive else []
		_sync_labels(player)
		if modified:
			changed.append(player)
	return changed


func clear_player(player: PlayerState) -> void:
	effects.erase(player.peer_id)
	player.active_effects.clear()


func _sync_labels(player: PlayerState) -> void:
	player.active_effects.clear()
	for entry: Dictionary in effects.get(player.peer_id, []):
		if not player.active_effects.has(str(entry.name)):
			player.active_effects.append(str(entry.name))
