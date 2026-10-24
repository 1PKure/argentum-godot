extends Node2D
## A warm ivory/gold whirlwind inspired by the approved rising spiral.
## Broad, luminous bands wrap the feet and torso before curling upward.
## No blue/red light, source sprite or gameplay timing is used.

const RIBBON_COUNT := 14
const LOOP_SECONDS := 4.0
const RATE := TAU / LOOP_SECONDS
const HEIGHT := 150.0
const MAX_RADIUS := 36.0
const IVORY := Color("fff3cf")
const GOLD := Color("efc96c")
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
	var rise := fmod(seconds / LOOP_SECONDS + index / float(RIBBON_COUNT), 1.0)
	# A broad lower/body spiral, tapering upward. Concentrate bands in the
	# lower 80 px instead of opening an empty cone above the character.
	var height_phase := pow(rise, 1.42)
	var radius := MAX_RADIUS * (0.90 - rise * 0.34) + sin(rise * PI) * 4
	var turn := seconds * RATE * 2 + index * 2.399
	var points := PackedVector2Array()
	for j in range(33):
		var f := j / 32.0
		var angle := turn + f * 2.70
		points.append(Vector2(cos(angle)*radius,-height_phase*HEIGHT+sin(angle)*radius*0.24-f*12))
	return points


func _draw() -> void:
	var pulse := 0.94 + sin(_elapsed * RATE) * 0.04
	_ellipse(22, GOLD, pulse * 0.62, 1.6)
	_ellipse(30, IVORY, pulse * 0.35, 1.0)
	for i in range(RIBBON_COUNT):
		var rise := fmod(_elapsed/LOOP_SECONDS+i/float(RIBBON_COUNT),1.0)
		var fade := smoothstep(0.0,0.055,rise)*(1-smoothstep(0.88,1.0,rise))
		var visibility := (0.78+sin(rise*PI)*0.22)*fade*pulse
		var points := ribbon_points(i,_elapsed)
		var depth := sin(_elapsed*RATE*2+i*2.399+1.35)
		var alpha := visibility*(0.91 if depth>0 else 0.51)
		var thickness := lerpf(7.5,3.1,rise)
		var color := IVORY if i%3==0 else GOLD
		_stroke(points,color,2.8,alpha*0.52)
		_stroke(points.slice(4,29),color,thickness,alpha*0.78)
		draw_polyline(points.slice(10,24),Color(IVORY,alpha*0.87),1.65,true)
	# Longer upward curls join the spiral into one flowing current.
	for side in [-1.0,1.0]:
		for i in range(2):
			var curl := PackedVector2Array()
			for j in range(29):
				var f := j/28.0
				var radius := 27-f*10
				var x: float = side*(radius+sin(f*9-_elapsed*RATE*2+i)*7)
				curl.append(Vector2(x,-f*(137+i*9)))
			_stroke(curl,GOLD,1.2+i*0.4,pulse*0.32)
	for i in range(10):
		var rise := fmod(_elapsed/LOOP_SECONDS+i/10.0,1.0)
		var at := Vector2(sin(i*4.1+_elapsed*RATE)*(20-rise*5),-5-rise*144)
		var alpha := sin(rise*PI)*0.52
		draw_circle(at,3.0,Color(IVORY,alpha*0.11),true,-1,true)
		draw_line(at+Vector2(0,4),at+Vector2(1,-4),Color(IVORY,alpha),1.0,true)


func _stroke(points: PackedVector2Array, color: Color, width: float, alpha: float) -> void:
	draw_polyline(points,Color(color,alpha*0.12),width+10,true)
	draw_polyline(points,Color(color,alpha*0.28),width+4,true)
	draw_polyline(points,Color(color,alpha),width,true)


func _ellipse(radius: float, color: Color, alpha: float, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(49):
		var angle := i*TAU/48
		points.append(Vector2(cos(angle)*radius,sin(angle)*radius*0.28))
	_stroke(points,color,width,alpha)
