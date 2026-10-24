class_name ArenaBloodImpact
extends Node2D
## Shared confirmed-impact presentation. Never modifies combat state.
const SECONDS := 0.50
const MAX_DROPLETS := 10
const PALETTE := [Color("6b0c16"),Color("94121d"),Color("b51c24")]
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
	if elapsed < 0 or elapsed >= SECONDS:return
	var axis := incoming.normalized() if not incoming.is_zero_approx() else Vector2.RIGHT
	var side := axis.orthogonal()
	var fade := 1.0-smoothstep(0.16,SECONDS,elapsed)
	var batch := ArenaCanvasBatch.new()
	# A short, uneven cut, followed by thin directional drops. No pink blocks.
	if elapsed < 0.09:
		var flash := 1.0-elapsed/0.09
		batch.polygon(PackedVector2Array([origin-side*2,origin+axis*8,origin+side*3,origin-axis*3]),Color(PALETTE[0],flash*0.8))
	for index in range(MAX_DROPLETS):
		var spread := axis.rotated((index-4.5)*0.21+sin(index*7.1)*0.035)
		var speed := 65.0+float((index*13)%47)
		var at := origin+side*float(index%3-1)*1.5+spread*(3.0+speed*elapsed)+Vector2(0,90.0*elapsed*elapsed)
		var travel := (spread+Vector2(0,elapsed*1.8)).normalized()
		var perpendicular := travel.orthogonal()
		var length := (5.0+float(index%4))*1.15*lerpf(1.0,0.4,elapsed/SECONDS)
		var width := (0.90+float(index%3)*0.30)*1.20
		var tail := at-travel*length*0.55
		batch.polygon(PackedVector2Array([at+travel*length,tail+perpendicular*width,tail-travel,tail-perpendicular*width]),Color(PALETTE[index%PALETTE.size()],fade))
	var geometry := batch.mesh()
	if geometry != null:
		# Canvas commands reference RIDs; retain this frame's single mesh.
		canvas.set_meta("blood_geometry",geometry)
		canvas.draw_mesh(geometry,null)
