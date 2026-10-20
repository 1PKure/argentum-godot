class_name ArenaMeditationVisual
extends Node2D
## Procedural interpretation of the approved AO meditation: a compact gold/ivory
## rising whirlwind, fine blue energy veins and an open, readable center.
## Local zero remains the feet; no source sprite or gameplay timing is used.

const RIBBON_COUNT := 12
const HEIGHT := 100.0
const MAX_RADIUS := 32.0
const IVORY := Color("f5eac1")
const GOLD := Color("dfc784")
const BLUE := Color("a5d4f5")
var _elapsed := 0.0


func _ready() -> void:
	set_meta("modern_fx", true)
	set_meta("procedural_only", true)
	set_meta("foot_anchored", true)
	set_meta("concept", "golden_rising_whirlwind")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visibility_changed.connect(func() -> void: set_process(visible))


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func set_age(seconds: float) -> void:
	_elapsed = maxf(0, seconds)
	queue_redraw()


func ribbon_points(index: int, seconds: float) -> PackedVector2Array:
	var rise := fmod(seconds * 0.20 + index / float(RIBBON_COUNT), 1.0)
	var radius := 9.0 + rise * (MAX_RADIUS - 9.0)
	var turn := seconds * 1.65 + index * 2.399
	var points := PackedVector2Array()
	for j in range(29):
		var f := j / 28.0
		var angle := turn + f * 2.35
		var taper := sin(f * PI) * (1.0 - rise * 0.16)
		points.append(Vector2(cos(angle) * radius * (0.82 + taper * 0.18), -rise * HEIGHT + sin(angle) * radius * 0.27 - f * 10))
	return points


func _draw() -> void:
	var pulse := 0.87 + sin(_elapsed * 2.3) * 0.07
	# Soft grounded light grows into revolving crescents, like the original
	# golden meditation funnel. The silhouette stays hollow over the body.
	_ellipse(15, GOLD, pulse * 0.42, 1.4)
	_ellipse(22, IVORY, pulse * 0.22, 0.8)
	for i in range(RIBBON_COUNT):
		var rise := fmod(_elapsed * 0.20 + i / float(RIBBON_COUNT), 1.0)
		var visibility := sin(rise * PI) * pulse
		var points := ribbon_points(i, _elapsed)
		var color := IVORY if i % 3 == 0 else GOLD
		# Layer three connected curves instead of hundreds of tiny segments:
		# a soft full crescent, a broader center and a warm ivory highlight.
		var depth := sin(_elapsed * 1.65 + i * 2.399 + 1.17)
		var alpha := visibility * (0.92 if depth > 0 else 0.50)
		_stroke(points, color, 2.2, alpha * 0.48)
		_stroke(points.slice(4,25), color, 4.9 * (1-rise*0.25), alpha * 0.72)
		draw_polyline(points.slice(9,21), Color(IVORY, alpha * 0.72), 1.3, true)
	# Thin upward frays give the gold current its flame/wind identity.
	for side in [-1.0, 1.0]:
		for i in range(3):
			var fray := PackedVector2Array()
			for j in range(24):
				var f := j / 23.0
				var x: float = side * (6 + f * 23 + sin(f * 8 - _elapsed * 2 + i) * 5)
				fray.append(Vector2(x, -f * (84 + i * 5)))
			_stroke(fray, GOLD, 0.8 + i * 0.25, pulse * 0.27)
	# Blue lightning is subordinate to the warm ribbons, as in FX120.
	for i in range(3):
		var vein := PackedVector2Array()
		for j in range(13):
			var f := j / 12.0
			var x := sin(f * 12 + floorf(_elapsed * 5) * 0.7 + i * 2.3) * (5 + f * 7)
			vein.append(Vector2(x + (i-1) * 5, -8 - f * 74))
		_stroke(vein, BLUE, 0.8, pulse * (0.20 + sin(_elapsed * 2 + i) * 0.06))
	for i in range(8):
		var rise := fmod(_elapsed * 0.24 + i / 8.0, 1.0)
		var at := Vector2(sin(i * 4.1 + _elapsed) * (9 + rise * 19), -4-rise*96)
		var alpha := sin(rise*PI) * 0.4
		draw_circle(at, 2.0, Color(IVORY, alpha*0.18), true, -1, true)
		draw_line(at+Vector2(0,3),at+Vector2(1,-3),Color(IVORY,alpha),0.8,true)


func _stroke(points: PackedVector2Array, color: Color, width: float, alpha: float) -> void:
	draw_polyline(points, Color(color, alpha * 0.10), width + 9, true)
	draw_polyline(points, Color(color, alpha * 0.25), width + 4, true)
	draw_polyline(points, Color(color, alpha), width, true)


func _ellipse(radius: float, color: Color, alpha: float, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(49):
		var angle := i * TAU / 48.0
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.28))
	_stroke(points, color, width, alpha)
