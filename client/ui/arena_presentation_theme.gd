extends RefCounted
## Shared presentation palette; apply explicitly so gameplay UI stays independent.

const BACKGROUND := Color("111722")
const PANEL := Color("1c2533")
const GOLD := Color("d6b66a")
const IVORY := Color("f3f0e8")
const MUTED := Color("aab3c2")
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
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, Color("414858"), 12))
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
	theme.set_stylebox("normal", "LineEdit", box(BACKGROUND, Color("414858")))
	theme.set_stylebox("read_only", "LineEdit", box(Color("171e2a"), Color("414858")))
	theme.set_stylebox("focus", "LineEdit", box(Color.TRANSPARENT, GOLD))
	theme.set_color("font_color", "LineEdit", IVORY)
	theme.set_color("font_uneditable_color", "LineEdit", MUTED)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", Color("695837"))
	return theme
