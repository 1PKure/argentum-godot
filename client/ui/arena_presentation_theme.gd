extends RefCounted
## Shared presentation palette; apply explicitly so gameplay UI stays independent.

const BACKGROUND := Color("111722")
const PANEL := Color("1c2533")
const GOLD := Color("d6b66a")
const IVORY := Color("f3f0e8")
const MUTED := Color("aab3c2")
const BORDER := Color("344357")
const ERROR := Color("ffab9e")


static func box(color: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", IVORY)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 12))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := GOLD
		if state == "hover":
			fill = Color("ebce88")
		elif state == "pressed":
			fill = Color("b99a54")
		elif state == "disabled":
			fill = Color("444651")
		theme.set_stylebox(state, "Button", box(fill, fill))
		theme.set_color("font_" + state + "_color", "Button", BACKGROUND if state != "disabled" else MUTED)
	theme.set_color("font_color", "Button", BACKGROUND)
	var focus := box(Color.TRANSPARENT, IVORY)
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("normal", "LineEdit", box(BACKGROUND, BORDER))
	theme.set_stylebox("read_only", "LineEdit", box(Color("171e2a"), BORDER))
	theme.set_stylebox("focus", "LineEdit", box(Color.TRANSPARENT, GOLD))
	theme.set_color("font_color", "LineEdit", IVORY)
	theme.set_color("font_uneditable_color", "LineEdit", MUTED)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", Color("695837"))
	for type: String in ["OptionButton"]:
		for state: String in ["normal","hover","pressed","disabled"]:
			theme.set_stylebox(state,type,box(BACKGROUND if state == "normal" else PANEL,BORDER,6))
			theme.set_color("font_color",type,IVORY)
		theme.set_stylebox("focus",type,box(Color.TRANSPARENT,GOLD,6))
	for state: String in ["normal","hover","pressed","disabled"]:
		theme.set_stylebox(state,"CheckButton",box(Color.TRANSPARENT,Color.TRANSPARENT,4))
		theme.set_color("font_"+state+"_color","CheckButton",IVORY)
	theme.set_color("font_color","CheckButton",IVORY)
	theme.set_stylebox("panel","PopupMenu",box(PANEL,BORDER,8))
	theme.set_stylebox("hover","PopupMenu",box(Color("344357"),GOLD,4))
	theme.set_color("font_color","PopupMenu",IVORY)
	theme.set_color("font_hover_color","PopupMenu",IVORY)
	theme.set_stylebox("background","ProgressBar",box(BACKGROUND,BORDER,5))
	theme.set_stylebox("fill","ProgressBar",box(GOLD,GOLD,5))
	theme.set_stylebox("panel","TooltipPanel",box(PANEL,GOLD,6))
	theme.set_color("font_color","TooltipLabel",IVORY)
	theme.set_font_size("font_size","TooltipLabel",13)
	return theme


static func secondary(button: Button) -> void:
	for state: String in ["normal","hover","pressed","disabled"]:
		var selected := state in ["hover","pressed"]
		var style := box(Color("263449") if selected else Color("162131"),GOLD if selected else BORDER,6)
		style.set_content_margin_all(6)
		button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override("font_"+state+"_color",IVORY if state != "disabled" else MUTED.darkened(0.25))
	button.add_theme_color_override("font_color",IVORY)
	button.focus_mode = Control.FOCUS_NONE

static func primary(button: Button) -> void:
	for state: String in ["normal","hover","pressed","disabled"]:
		var color := GOLD if state == "normal" else GOLD.lightened(0.12) if state == "hover" else GOLD.darkened(0.15) if state == "pressed" else Color("394354")
		var style := box(color,color,6)
		style.set_content_margin_all(6)
		button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override("font_"+state+"_color",BACKGROUND if state != "disabled" else MUTED)
	button.add_theme_color_override("font_color",BACKGROUND)
	button.focus_mode = Control.FOCUS_NONE
