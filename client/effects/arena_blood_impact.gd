class_name ArenaBloodImpact
extends Node2D
## Shared confirmed-impact presentation. Never modifies combat state.
const SECONDS := 0.50
const ANCHOR_OFFSET := Vector2(0,4)
var target_avatar: Node2D
var direction := Vector2.RIGHT
var age := 0.0

func setup(target: Node2D, incoming: Vector2) -> void:
	target_avatar = target
	direction = incoming.normalized() if not incoming.is_zero_approx() else Vector2.RIGHT
	z_index = PlayerAvatar.EFFECT_Z_INDEX
	_update_anchor()

func _process(delta: float) -> void:
	age += maxf(delta,0.0)
	if age >= SECONDS or not is_instance_valid(target_avatar) or target_avatar.is_queued_for_deletion():
		queue_free()
		return
	_update_anchor()
	queue_redraw()

func _update_anchor() -> void:
	if is_instance_valid(target_avatar): position = target_avatar.position + ANCHOR_OFFSET

func _draw() -> void:
	draw_burst(self,Vector2.ZERO,direction,age)

static func draw_burst(canvas: Node2D, origin: Vector2, incoming: Vector2, elapsed: float) -> void:
	var fade := clampf((SECONDS - elapsed) / 0.20,0.0,1.0)
	if elapsed < 0.18:
		var tip := origin + incoming * (14.0 + elapsed * 55.0)
		canvas.draw_line(origin,tip,Color(0.34,0.01,0.03,fade),8.0,false)
		canvas.draw_line(origin,tip,Color(0.94,0.12,0.19,fade),5.0,false)
	for index in range(12):
		var spread := incoming.rotated((index - 5.5) * 0.19)
		var velocity := spread * (75.0 + (index % 4) * 15.0)
		var at := origin + spread * 6.0 + velocity * elapsed + Vector2(0,120.0 * elapsed * elapsed)
		var size_value := 6.0 if index % 3 == 0 else 4.0
		var rect := Rect2(at.round(),Vector2.ONE * size_value)
		var color := Color("f45151") if index % 3 == 0 else Color("c5192d")
		color.a = fade
		canvas.draw_rect(rect.grow(1.0),Color(0.30,0.01,0.03,fade))
		canvas.draw_rect(rect,color)
