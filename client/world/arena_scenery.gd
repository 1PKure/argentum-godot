class_name ArenaScenery
extends Node2D

const SCENERY := {
	"cactus": {"texture": preload("res://assets/arena/scenery/cactus.svg"), "size": Vector2(28, 42)},
	"rock": {"texture": preload("res://assets/arena/scenery/rock.svg"), "size": Vector2(32, 25)},
	"pillar": {"texture": preload("res://assets/arena/scenery/pillar.svg"), "size": Vector2(29, 45)},
	"basalt": {"texture": preload("res://assets/arena/scenery/basalt.svg"), "size": Vector2(32, 38)},
	"torch": {"texture": preload("res://assets/arena/scenery/torch.svg"), "size": Vector2(25, 44)},
	"ember": {"texture": preload("res://assets/arena/scenery/ember.svg"), "size": Vector2(30, 34)},
	"tree": {"texture": preload("res://assets/arena/scenery/pine.svg"), "size": Vector2(48, 68)},
}

var kind := "rock"
var variant := 0
var _flame_clock := 0.0

func setup(value: String, at: Vector2, visual_scale: float, seed_value: int = 0) -> void:
	kind = value if SCENERY.has(value) else "rock"
	variant = seed_value
	position = at
	scale = Vector2.ONE * visual_scale
	# Native SVGs are rasterised at twice their display size, retaining the
	# small bevels and silhouettes without widening the collision footprint.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_flame_clock = float(posmod(seed_value, 19)) * 0.47
	set_process(kind in ["torch", "ember"])
	queue_redraw()

func _process(delta: float) -> void:
	_flame_clock += delta
	queue_redraw()

func _draw() -> void:
	var definition: Dictionary = SCENERY[kind]
	var size: Vector2 = definition.size
	draw_texture_rect(definition.texture, Rect2(Vector2(-size.x * 0.5, -size.y + 2), size), false)
	if kind == "torch" or kind == "ember":
		var base_y := -size.y * (0.69 if kind == "torch" else 0.66) + 2
		_draw_flame(Vector2(0, base_y), 1.0 if kind == "torch" else 1.15)

func _draw_flame(at: Vector2, strength: float) -> void:
	var lean := sin(_flame_clock * 2.6) * 0.75
	var lift := 0.45 * sin(_flame_clock * 4.1)
	draw_circle(at + Vector2(0, -4), 10 * strength, Color(1, 0.55, 0.16, 0.035))
	draw_circle(at + Vector2(0, -4), 6 * strength, Color(1, 0.65, 0.2, 0.065))
	var points := PackedVector2Array([
		Vector2(-4.5, 0), Vector2(-5, -2), Vector2(-4.3, -5), Vector2(-2.3, -7),
		Vector2(-1.6, -10), Vector2(lean, -8), Vector2(1.3 + lean, -14 + lift),
		Vector2(3 + lean, -10), Vector2(3, -7), Vector2(4.5, -5),
		Vector2(5, -2), Vector2(3, 0.5), Vector2(0, 1),
	])
	for index in points.size():
		points[index] = at + points[index] * strength
	draw_colored_polygon(points, Color("d68537"))
	points = PackedVector2Array([
		Vector2(-2.7, 0), Vector2(-3, -3), Vector2(-1, -6),
		Vector2(lean * 0.5, -10 + lift * 0.5), Vector2(1.1, -6),
		Vector2(3, -3), Vector2(2, 0.3),
	])
	for index in points.size():
		points[index] = at + points[index] * strength
	draw_colored_polygon(points, Color("f3bd68"))
	draw_circle(at + Vector2(0, -1.5), 1.8 * strength, Color("f9e2a2"))
