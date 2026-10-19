class_name InventorySlotButton
extends Button

signal item_used(action: String)
signal item_dropped(source: int, destination: int, action: String)
signal move_started(source: int, screen_position: Vector2)

var slot_index := 0
var action := ""
var layout: ArenaInventoryLayout
var _equipped_badge: Label
var potion_selected := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	expand_icon = true
	add_theme_constant_override("icon_max_width", 34)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("101a28")
	normal.border_color = Color("2f4054")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("26364b")
	add_theme_stylebox_override("hover", hover)
	var selected := hover.duplicate() as StyleBoxFlat
	selected.border_color = Color("b59b61")
	selected.set_border_width_all(1)
	add_theme_stylebox_override("pressed", selected)
	pressed.connect(_on_pressed)


func configure(index: int, inventory: ArenaInventoryLayout) -> void:
	slot_index = index
	layout = inventory
	action = inventory.actions[index]
	icon = null
	tooltip_text = "Casillero %d · Vacío" % (index + 1)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if action.is_empty() else Control.CURSOR_POINTING_HAND
	if _equipped_badge != null:
		_equipped_badge.visible = false
	if action.begins_with("item:"):
		var item_id := inventory.item_id(index)
		var item := ClassCatalog.get_item(item_id)
		icon = AOResources.get_equipment_icon(item_id)
		var equipped := inventory.equipped_ids.has(item_id)
		tooltip_text = "%s · %s\nClic: equipar / desequipar · Arrastrar con botón derecho: mover" % [item.get("Name", "Objeto"), "Equipado" if equipped else "En inventario"]
		if _equipped_badge == null:
			_equipped_badge = Label.new()
			_equipped_badge.text = "E"
			_equipped_badge.add_theme_font_size_override("font_size", 10)
			_equipped_badge.add_theme_color_override("font_color", Color("f2d47b"))
			_equipped_badge.add_theme_color_override("font_shadow_color", Color.BLACK)
			_equipped_badge.add_theme_constant_override("shadow_offset_x", 1)
			_equipped_badge.add_theme_constant_override("shadow_offset_y", 1)
			_equipped_badge.position = Vector2(29, 25)
			_equipped_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_equipped_badge)
		_equipped_badge.visible = equipped
	elif not action.is_empty():
		var potion := RecoveryRules.get_potion(action)
		icon = ArenaIcons.potion(action)
		tooltip_text = "%s · Provisión de arena ilimitada\nClic: seleccionar y beber · %s: usar seleccionada\nArrastrá con botón derecho para mover o intercambiar" % [potion.get("name", "Poción"),InputBindings.label_for("use_selected")]


func _on_pressed() -> void:
	if not action.is_empty():
		item_used.emit(action)


func _get_drag_data(_position: Vector2) -> Variant:
	# Godot's native drag starts with left click, which remains reserved for Use.
	return null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not action.is_empty():
			move_started.emit(slot_index, get_global_transform() * event.position)
		accept_event()


func move_data() -> Dictionary:
	if action.is_empty():
		return {}
	return {"type": "arena_inventory", "layout_id": layout.get_instance_id(), "source": slot_index, "action": action, "revision": layout.revision}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "arena_inventory" and data.get("layout_id") == layout.get_instance_id() and int(data.get("revision", -1)) == layout.revision and layout.can_move(int(data.get("source", -1)), slot_index, str(data.get("action", "")))


func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		item_dropped.emit(int(data.source), slot_index, str(data.action))


func set_potion_selected(selected_action: String) -> void:
	potion_selected = action in ["health_potion", "mana_potion"] and action == selected_action
	queue_redraw()


func _draw() -> void:
	if potion_selected:
		draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("e9c66f"), false, 2.0)
