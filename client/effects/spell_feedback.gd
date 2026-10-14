extends Node2D

var start := Vector2.ZERO
var finish := Vector2.ZERO
var amount := 0
var healing := false
var _elapsed := 0.0
const DURATION := 0.5


func _ready() -> void:
	z_index = 100
	var label := Label.new()
	label.text = ("+" if healing else "−") + str(amount)
	label.position = finish + Vector2(-16, -65)
	label.modulate = Color(0.5, 1.0, 0.55) if healing else Color(0.65, 0.85, 1.0)
	label.add_theme_font_size_override("font_size", 22)
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 28, DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DURATION)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= DURATION:
		queue_free()


func _draw() -> void:
	var color := Color(0.3, 1.0, 0.5) if healing else Color(0.35, 0.7, 1.0)
	color.a = 1.0 - _elapsed / DURATION
	if not healing and _elapsed < 0.2:
		draw_line(start + Vector2(0, -24), finish + Vector2(0, -24), color, 3.0)
	draw_arc(finish, 12.0 + _elapsed * 30.0, 0.0, TAU, 24, color, 3.0)

