class_name SpellPanel
extends CanvasLayer

signal spell_selected(spell_id: int)
signal launch_requested
signal combat_changed(enabled: bool)

var _root: Control
var _selection: OptionButton
var _combat: CheckButton
var _launch: Button
var _stats: Label
var _details: Label
var _status: Label


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 180
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -198
	panel.offset_right = -6
	panel.offset_top = 84
	panel.offset_bottom = 84
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.11, 0.08, 0.96)
	style.border_color = Color(0.48, 0.45, 0.28)
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Hechizos · PvP"
	title.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	column.add_child(title)
	_stats = _label(column)
	_selection = OptionButton.new()
	_selection.focus_mode = Control.FOCUS_NONE
	for spell_id: int in SpellCatalog.SPELLS:
		_selection.add_item("%d · %s" % [spell_id, SpellCatalog.get_spell(spell_id).display_name], spell_id)
	_selection.item_selected.connect(func(index: int) -> void: spell_selected.emit(_selection.get_item_id(index)))
	column.add_child(_selection)
	_details = _label(column)
	_combat = CheckButton.new()
	_combat.text = "Combate (C)"
	_combat.focus_mode = Control.FOCUS_NONE
	_combat.toggled.connect(func(enabled: bool) -> void: combat_changed.emit(enabled))
	column.add_child(_combat)
	_launch = Button.new()
	_launch.text = "Lanzar (E)"
	_launch.focus_mode = Control.FOCUS_NONE
	_launch.pressed.connect(func() -> void: launch_requested.emit())
	column.add_child(_launch)
	_status = _label(column)
	_status.custom_minimum_size.y = 80
	var help := _label(column)
	help.text = "1 / 2: elegir hechizo\nC: combate con clic\nE: preparar lanzamiento\nEsc / clic derecho: cancelar\nCtrl: golpe físico"
	help.add_theme_font_size_override("font_size", 12)
	_root.hide()


func _label(parent: Node) -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 156
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func refresh(state: SpellInputState, player: PlayerState, now_msec: int) -> void:
	_root.visible = player != null
	if player == null:
		return
	var spell: SpellDefinition = SpellCatalog.get_spell(state.selected_spell_id)
	_selection.select(_selection.get_item_index(state.selected_spell_id))
	_combat.set_pressed_no_signal(state.combat_mode)
	_launch.disabled = not player.is_alive or state.pending_request != 0
	_combat.disabled = not player.is_alive
	var remaining := maxi(0, state.cooldown_until_msec - now_msec)
	var recovery := "Listo" if remaining == 0 else "Recarga: %.1f s" % (remaining / 1000.0)
	if state.pending_request != 0:
		recovery = "Lanzando…"
	_stats.text = "Vida %d / %d\nManá %d / %d\n%s" % [player.current_health, player.max_health, player.current_mana, player.max_mana, recovery]
	_details.text = "%d maná · %d casillas\n%d %s" % [spell.mana_cost, spell.range_tiles, spell.amount, "daño" if spell.effect == SpellDefinition.Effect.DAMAGE else "curación"]


func show_message(message: String, is_error := false) -> void:
	_status.text = message
	_status.modulate = Color(1.0, 0.65, 0.5) if is_error else Color(0.8, 0.87, 0.72)

