class_name RankingPanel
extends CanvasLayer

const Palette := preload("res://client/ui/arena_presentation_theme.gd")
var _name: LineEdit
var _message: Label
var _rows: VBoxContainer
var _save: Button

func _ready() -> void:
	layer = 32
	var surface := Control.new()
	surface.theme = Palette.create_theme()
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015,0.025,0.05,0.94)
	surface.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	surface.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760,0)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	card.add_child(column)
	_label(column,"Ranking · AO Mini",28)
	_label(column,"100 puntos por victoria · PvP y bot",16)
	var profile := HBoxContainer.new()
	column.add_child(profile)
	_name = LineEdit.new()
	_name.max_length = 20
	_name.placeholder_text = "Tu nombre"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile.add_child(_name)
	_save = _button(profile,"Guardar nombre",func() -> void: RankingNetwork.register_name(_name.text))
	_name.text_submitted.connect(func(_value: String) -> void: RankingNetwork.register_name(_name.text))
	_message = _label(column,"",14)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation",8)
	scroll.add_child(_rows)
	_label(column,"Se actualiza cada 30 segundos y al terminar una ronda.",14)
	_label(column,"Tu perfil se conserva en este navegador o dispositivo.",14)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	_button(footer,"Actualizar",RankingNetwork.refresh)
	_button(footer,"Volver",close)
	RankingNetwork.changed.connect(_refresh)
	hide()

func open() -> void:
	_name.text = RankingNetwork.nickname
	show()
	_refresh()
	RankingNetwork.refresh()

func close() -> void:
	hide()

func _refresh() -> void:
	if not is_instance_valid(_rows): return
	_save.disabled = not RankingNetwork.available or RankingNetwork.pending
	_message.text = RankingNetwork.message
	if not _name.has_focus() and RankingNetwork.registered: _name.text = RankingNetwork.nickname
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row(["#","Jugador","Puntos","PvP","Bot"],false)
	for entry: Dictionary in RankingNetwork.snapshot.get("entries",[]):
		_row([str(entry.rank),str(entry.nickname)+( " · Homenaje" if bool(entry.get("honorary",false)) else ""),_points(int(entry.points)),str(entry.pvp_wins),str(entry.bot_wins)],bool(entry.get("honorary",false)))
	if RankingNetwork.snapshot.is_empty(): _label(_rows,"Conectando con el ranking…",16)

func _row(values: Array, honorary: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	_rows.add_child(row)
	var widths := [30,280,150,60,60]
	for index in values.size():
		var label := _label(row,str(values[index]),15)
		label.custom_minimum_size.x = widths[index]
		if index == 1: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if honorary: label.add_theme_color_override("font_color",Color("eacb7c"))

func _points(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in digits.length():
		if index > 0 and (digits.length()-index) % 3 == 0: result += "."
		result += digits[index]
	return result

func _label(parent: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 36
	Palette.secondary(button)
	parent.add_child(button)
	button.pressed.connect(action)
	return button
