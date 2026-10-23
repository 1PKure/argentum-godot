extends Node
## Local preferences deliberately use a stable profile, never the transient network peer ID.
signal changed
signal save_failed(message: String)
const FILE := "user://controls.cfg"
const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "basic_attack", "launch_spell", "meditate", "health_potion", "mana_potion", "use_selected", "menu"]
const TITLES := {"move_up":"Mover arriba", "move_down":"Mover abajo", "move_left":"Mover izquierda", "move_right":"Mover derecha", "basic_attack":"Golpear / apuntar arco", "launch_spell":"Lanzar hechizo seleccionado", "meditate":"Meditar", "health_potion":"Poción de vida", "mana_potion":"Poción de maná", "use_selected":"Usar objeto seleccionado", "menu":"Menú"}
const DEFAULTS := [KEY_W, KEY_S, KEY_A, KEY_D, KEY_CTRL, KEY_L, KEY_M, KEY_Q, KEY_E, KEY_SPACE, KEY_ESCAPE]
var profile_id := "local"
var _events: Dictionary = {}

func _ready() -> void:
	_load()

func all_actions() -> Array[String]:
	var result: Array[String] = []
	result.assign(ACTIONS)
	for slot in range(10): result.append(macro_action(slot))
	return result

func macro_action(slot: int) -> String:
	return "macro_%d" % slot

func title_for(action: String) -> String:
	return str(TITLES.get(action, "Macro %d" % ((int(action.trim_prefix("macro_")) + 1) % 10)))

func label_for(action: String) -> String:
	return (_events[action] as InputEventKey).as_text_keycode() if _events.has(action) else "—"

func matches(event: InputEvent, action: String) -> bool:
	if not event is InputEventKey or not _events.has(action): return false
	var expected: InputEventKey = _events[action]
	return _code(event) == expected.keycode and _modifiers(event) == _modifiers(expected)

func is_release(event: InputEvent, action: String) -> bool:
	return event is InputEventKey and not event.pressed and _events.has(action) and _code(event) == (_events[action] as InputEventKey).keycode

func rebind(action: String, event: InputEventKey) -> Dictionary:
	if not action in all_actions(): return {"ok":false, "message":"Acción desconocida."}
	var candidate := InputEventKey.new()
	candidate.keycode = _code(event)
	candidate.ctrl_pressed = event.ctrl_pressed and candidate.keycode != KEY_CTRL
	candidate.shift_pressed = event.shift_pressed and candidate.keycode != KEY_SHIFT
	candidate.alt_pressed = event.alt_pressed and candidate.keycode != KEY_ALT
	candidate.meta_pressed = event.meta_pressed and candidate.keycode != KEY_META
	if candidate.keycode == 0: return {"ok":false,"message":"Elegí una tecla válida."}
	for other: String in _events:
		if other == action: continue
		var existing: InputEventKey = _events[other]
		if _conflicts(candidate, existing):
			return {"ok":false,"message":"Esa tecla entra en conflicto con %s." % title_for(other)}
	var previous: InputEventKey = _events[action]
	_events[action] = candidate
	if _save() != OK:
		_events[action] = previous
		return {"ok":false,"message":"No se pudo guardar el atajo. Revisá el almacenamiento del navegador."}
	_apply()
	changed.emit()
	return {"ok":true,"message":"Atajo actualizado."}

func _conflicts(a: InputEventKey, b: InputEventKey) -> bool:
	if a.keycode == b.keycode and _modifiers(a) == _modifiers(b): return true
	# A standalone modifier fires before any chord containing it; reject both orders.
	for pair in [[a,b],[b,a]]:
		var modifier: InputEventKey = pair[0]
		var chord: InputEventKey = pair[1]
		if modifier.keycode == KEY_CTRL and chord.ctrl_pressed: return true
		if modifier.keycode == KEY_SHIFT and chord.shift_pressed: return true
		if modifier.keycode == KEY_ALT and chord.alt_pressed: return true
		if modifier.keycode == KEY_META and chord.meta_pressed: return true
	return false

func reset_defaults() -> void:
	var previous := _events.duplicate()
	_defaults()
	if _save() != OK:
		_events = previous
		save_failed.emit("No se pudieron guardar los controles.")
		return
	_apply()
	changed.emit()

func use_profile(stable_id: String) -> void:
	profile_id = stable_id if not stable_id.is_empty() else "local"
	_load()
	changed.emit()

func _defaults() -> void:
	_events.clear()
	for index in range(ACTIONS.size()):
		var event := InputEventKey.new()
		event.keycode = DEFAULTS[index]
		_events[ACTIONS[index]] = event
	for slot in range(10):
		var event := InputEventKey.new()
		event.keycode = KEY_0 if slot == 9 else KEY_1 + slot
		_events[macro_action(slot)] = event

func _load() -> void:
	_defaults()
	var config := ConfigFile.new()
	if config.load(FILE) == OK:
		var section := "profile:" + profile_id
		var loaded: Dictionary = {}
		for action in all_actions():
			if not config.has_section_key(section,action): continue
			var saved: Variant = config.get_value(section, action)
			if saved is InputEventKey and _code(saved) != 0:
				loaded[action] = saved
		# Validate complete profiles atomically so corrupt or old data cannot lock controls.
		if loaded.size() == _events.size():
			var valid := true
			var keys := loaded.keys()
			for i in range(keys.size()):
				for j in range(i + 1, keys.size()):
					if _conflicts(loaded[keys[i]],loaded[keys[j]]): valid = false
			if valid: _events = loaded
	_apply()

func _save() -> Error:
	var config := ConfigFile.new()
	config.load(FILE)
	for action: String in _events: config.set_value("profile:" + profile_id, action, _events[action])
	return config.save(FILE)

func release_all() -> void:
	for action: String in _events:
		if InputMap.has_action(action): Input.action_release(action)
	RecoveryNetwork.cancel_use()

func _apply() -> void:
	for action: String in _events:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		var mapped := (_events[action] as InputEventKey).duplicate() as InputEventKey
		mapped.physical_keycode = mapped.keycode
		mapped.keycode = 0
		InputMap.action_add_event(action, mapped)
	RecoveryNetwork.cancel_use()

func _code(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != 0 else event.keycode

func _modifiers(event: InputEventKey) -> int:
	return (1 if event.ctrl_pressed and _code(event) != KEY_CTRL else 0) | (2 if event.shift_pressed and _code(event) != KEY_SHIFT else 0) | (4 if event.alt_pressed and _code(event) != KEY_ALT else 0) | (8 if event.meta_pressed and _code(event) != KEY_META else 0)
