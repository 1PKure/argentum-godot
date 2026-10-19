class_name ArenaMeditationVisual
extends Node2D
## A compact continuous aura. The feet stay its origin even during interpolation.

var _elapsed := 0.0


func _ready() -> void:
	set_meta("modern_fx", true)
	set_meta("foot_anchored", true)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visibility_changed.connect(func() -> void: set_process(visible))


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var blue := Color("8bcff0")
	var gold := Color("e8cb8d")
	var pulse := 0.8 + sin(_elapsed * 2.4) * 0.12
	_ellipse(22.0, blue, pulse * 0.7, 1.2)
	_ellipse(16.0, gold, pulse * 0.5, 0.8)
	for i in range(8):
		var angle := i * TAU / 8.0 - _elapsed * 0.24
		var at := Vector2(cos(angle) * 22.0, sin(angle) * 7.0)
		var direction := Vector2(cos(angle), sin(angle) * 0.34)
		draw_line(at - direction * 1.5, at + direction * 2.5, Color(gold, pulse * 0.7), 1.2, true)
	for i in range(7):
		var phase := fmod(_elapsed * 0.23 + i / 7.0, 1.0)
		var angle := i * 2.4 + _elapsed * 0.65
		var at := Vector2(cos(angle) * (18.0 - phase * 5.0), -5.0 - phase * 68.0)
		var alpha := sin(phase * PI) * 0.8
		var color := gold if i % 3 == 0 else blue
		draw_circle(at, 4.0, Color(color, alpha * 0.08), true, -1.0, true)
		draw_line(at + Vector2(0, -2.4), at + Vector2(0, 2.4), Color(color, alpha), 1.0, true)
		draw_line(at + Vector2(-1.6, 0), at + Vector2(1.6, 0), Color(color, alpha), 1.0, true)
		var trail := PackedVector2Array([at + Vector2(2.0, 10.0), at + Vector2(1.0, 5.0), at])
		draw_polyline(trail, Color(blue, alpha * 0.23), 1.0, true)


func _ellipse(radius: float, color: Color, alpha: float, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(49):
		var angle := i * TAU / 48.0
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.33))
	draw_polyline(points, Color(color, alpha * 0.12), width + 4.0, true)
	draw_polyline(points, Color(color, alpha), width, true)
