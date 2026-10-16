class_name InventorySlotButton
extends Button

signal item_used(action: String)
signal item_dropped(source: int, destination: int, action: String)

var slot_index := 0
var action := ""
var layout: ArenaInventoryLayout
var _drag_started := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	expand_icon = true
	add_theme_constant_override("icon_max_width", 28)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.7, 0.6, 0.3, 0.15)
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
	if not action.is_empty():
		var potion := RecoveryRules.get_potion(action)
		icon = AOResources.get_icon_texture(int(potion.get("icon_grh", 0)))
		tooltip_text = "%s · Provisión de arena ilimitada\nClic para usar · Arrastrá para mover o intercambiar" % potion.get("name", "Poción")


func _on_pressed() -> void:
	if not _drag_started and not action.is_empty():
		item_used.emit(action)


func _get_drag_data(_position: Vector2) -> Variant:
	if action.is_empty():
		return null
	_drag_started = true
	var preview := TextureRect.new()
	preview.texture = icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(32, 32)
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"type": "arena_inventory", "layout_id": layout.get_instance_id(), "source": slot_index, "action": action}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "arena_inventory" and data.get("layout_id") == layout.get_instance_id() and layout.can_move(int(data.get("source", -1)), slot_index, str(data.get("action", "")))


func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		item_dropped.emit(int(data.source), slot_index, str(data.action))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# Releasing a drag (even outside the grid) must never drink the item.
		set_deferred("_drag_started", false)
