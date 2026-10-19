class_name ArenaScenery
extends Node2D

var kind := "rock"
var variant := 0

func setup(value: String, at: Vector2, visual_scale: float, seed_value: int = 0) -> void:
	kind = value
	variant = seed_value
	position = at
	scale = Vector2.ONE * visual_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(kind in ["torch","ember"])
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_ellipse_shadow()
	match kind:
		"cactus":
			draw_rect(Rect2(-4,-33,8,33),Color("3e6840"))
			draw_rect(Rect2(-12,-23,8,5),Color("4f7848"))
			draw_rect(Rect2(-12,-30,4,12),Color("4f7848"))
			draw_rect(Rect2(4,-18,9,5),Color("355535"))
			draw_rect(Rect2(9,-27,4,14),Color("355535"))
			draw_line(Vector2(-1,-31),Vector2(-1,-2),Color("97aa65"),2)
		"pillar","basalt":
			var base := Color("757d88") if kind == "pillar" else Color("403b49")
			draw_rect(Rect2(-8,-35,16,35),base)
			draw_rect(Rect2(-11,-37,22,5),base.lightened(0.14))
			draw_rect(Rect2(-10,-4,20,5),base.darkened(0.14))
			draw_line(Vector2(-5,-30),Vector2(-5,-6),base.lightened(0.16),2)
			draw_line(Vector2(5,-30),Vector2(5,-6),base.darkened(0.22),2)
		"torch","ember":
			draw_rect(Rect2(-3,-20,6,20),Color("44372e"))
			var flicker := sin(Time.get_ticks_msec()*0.008 + variant)*1.3
			draw_circle(Vector2(0,-24),12,Color(1,0.45,0.12,0.07))
			draw_colored_polygon(PackedVector2Array([Vector2(-7,-19),Vector2(-3,-29-flicker),Vector2(0,-24),Vector2(3,-32+flicker),Vector2(8,-19)]),Color("e47d26"))
			draw_colored_polygon(PackedVector2Array([Vector2(-3,-19),Vector2(0,-28),Vector2(4,-19)]),Color("ffcf72"))
		"tree":
			draw_rect(Rect2(-3,-25,6,25),Color("58412d"))
			draw_colored_polygon(PackedVector2Array([Vector2(-17,-10),Vector2(0,-46),Vector2(17,-10)]),Color("294b32"))
			draw_colored_polygon(PackedVector2Array([Vector2(-12,-24),Vector2(0,-49),Vector2(12,-24)]),Color("3e6441"))
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(-13,-2),Vector2(-10,-13),Vector2(2,-18),Vector2(14,-8),Vector2(10,1)]),Color("8d8063"))
			draw_colored_polygon(PackedVector2Array([Vector2(-10,-13),Vector2(2,-18),Vector2(7,-12),Vector2(-2,-9)]),Color("a89a79"))

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.35))
	draw_circle(Vector2.ZERO,13,Color(0,0,0,0.2))
	draw_set_transform(Vector2.ZERO)
