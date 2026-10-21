class_name ArenaSpeechLayer
extends Node2D
const CHAT_SECONDS := 4.0
var entries: Dictionary = {}
func _ready() -> void:
	z_index = PlayerAvatar.OVERHEAD_Z_INDEX
	process_priority = 80
func say(avatar: Node2D, text: String, kind: String = "chat", seconds: float = CHAT_SECONDS) -> void:
	if not is_instance_valid(avatar): return
	var key := avatar.get_instance_id()
	if entries.has(key):
		var previous: Label = entries[key].label
		remove_child(previous)
		previous.queue_free()
		entries.erase(key)
	if text.is_empty(): return
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",14 if kind=="chat" else 15)
	label.add_theme_color_override("font_color",Color("e6efff") if kind=="chat" else Color("ffe2a0"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_y",1)
	var font := ThemeDB.fallback_font
	var width := clampf(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+12,60,220)
	label.size.x = width
	add_child(label)
	entries[key] = {"avatar":avatar,"label":label,"age":0.0,"duration":seconds,"kind":kind}
	_process(0)
func clear() -> void:
	for entry: Dictionary in entries.values():
		remove_child(entry.label)
		entry.label.queue_free()
	entries.clear()
func _process(delta: float) -> void:
	for key in entries.keys():
		var entry: Dictionary = entries[key]
		entry.age += delta
		if not is_instance_valid(entry.avatar) or entry.avatar.is_queued_for_deletion() or float(entry.age)>=float(entry.duration):
			remove_child(entry.label)
			entry.label.queue_free()
			entries.erase(key)
	var ordered: Array = entries.values()
	# Keep the local player's words above the other player when close together.
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if bool(a.avatar.is_local_player) != bool(b.avatar.is_local_player): return not bool(a.avatar.is_local_player)
		if a.avatar.position.y != b.avatar.position.y: return a.avatar.position.y < b.avatar.position.y
		return a.avatar.get_instance_id() < b.avatar.get_instance_id()
	)
	var placed: Array[Rect2] = []
	for entry: Dictionary in ordered:
		var label: Label = entry.label
		var height := maxf(22,label.get_combined_minimum_size().y)
		label.size.y = height
		var rect := Rect2(entry.avatar.position+Vector2(-label.size.x*0.5,-92-height),Vector2(label.size.x,height))
		for attempt in range(placed.size()+1):
			var moved := false
			for previous: Rect2 in placed:
				if rect.grow(4).intersects(previous):
					rect.position.y = previous.position.y-rect.size.y-9
					moved = true
			if not moved: break
		label.position = rect.position
		label.modulate.a = clampf((float(entry.duration)-float(entry.age))/0.5,0,1)
		placed.append(rect)
