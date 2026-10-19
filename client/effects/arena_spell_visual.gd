class_name ArenaSpellVisual
extends Node2D
## Original arena VFX. Local (0, 0) is always the recipient's feet.
## These are presentation only: a burst never delays or reapplies a server hit.

var family := "arcane"
var spell_id := 0
var lifetime := 1.15
var _age := 0.0
var _power := 1.0

const ELECTRIC := Color("75cfff")
const WHITE := Color("f4fcff")
const GOLD := Color("f3d38b")
const GREEN := Color("76e6b1")
const VIOLET := Color("ad95ef")


func configure(spell: Dictionary) -> void:
	spell_id = int(spell.get("id", 0))
	family = family_for_spell(spell)
	_power = 1.2 if spell_id in [31, 53, 56, 242] else 1.0
	lifetime = 1.25 if family in ["healing", "restoration", "apocalypse", "void"] else 1.05
	set_meta("modern_fx", true)
	set_meta("foot_anchored", true)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


static func family_for_spell(spell: Dictionary) -> String:
	var id := int(spell.get("id", 0))
	if id in [43, 50, 51, 59]: return "electric"
	if id == 53: return "apocalypse"
	if id in [4, 39, 40, 41]: return "fire"
	if id in [25, 26]: return "paralysis"
	if id in [27, 29, 112]: return "release"
	if id == 28: return "stun"
	if id in [113, 350]: return "roots"
	if id in [54, 55, 122, 131, 141]: return "void"
	if id == 243: return "poison"
	if id in [56, 132, 133, 263]: return "holy"
	if id in [242, 268, 269]: return "restoration"
	if str(spell.get("effect", "")) == "healing" or id == 11: return "healing"
	return "arcane"


func set_age(seconds: float) -> void:
	_age = maxf(0.0, seconds)
	queue_redraw()


func _draw() -> void:
	var p := clampf(_age / lifetime, 0.0, 1.0)
	var fade := minf(1.0, _age / 0.035) * clampf((1.0 - p) / 0.32, 0.0, 1.0)
	if fade <= 0.0: return
	match family:
		"electric": _electric(fade, p)
		"apocalypse": _apocalypse(fade, p)
		"fire": _fire(fade, p)
		"healing", "restoration": _healing(fade, p)
		"paralysis": _paralysis(fade, p)
		"release": _release(fade, p)
		"stun": _stun(fade, p)
		"roots": _roots(fade, p)
		"void": _void(fade, p)
		"poison": _poison(fade, p)
		"holy": _holy(fade, p)
		_: _arcane(fade, p)


func _electric(a: float, p: float) -> void:
	var strike := clampf(1.0 - p / 0.64, 0.0, 1.0)
	# A stable center bolt with small animated branches, rather than a flickering screen flash.
	var bolt := PackedVector2Array()
	for i in range(11):
		var x := sin(i * 13.3 + floorf(_age * 18.0) * 2.1) * (9.0 if i > 0 and i < 10 else 0.0)
		bolt.append(Vector2(x, -135.0 + i * 12.8))
	_glow_line(bolt, ELECTRIC, 2.2, a * strike)
	for side in [-1.0, 1.0]:
		var branch := PackedVector2Array([bolt[4], Vector2(side * 19, -70), Vector2(side * 12, -52), Vector2(side * 30, -42)])
		_glow_line(branch, ELECTRIC, 1.0, a * strike * 0.6)
	_ring(Vector2(0, -1), 18.0 + p * 17.0, 0.37, ELECTRIC, a * (1.0 - p) * 0.8, 1.4)
	_sparks(ELECTRIC, a, p, 12, 46.0, 52.0)
	if spell_id == 59:
		_ring(Vector2(0, -34), 18.0, 0.8, VIOLET, a * strike * 0.5, 1.0)


func _apocalypse(a: float, p: float) -> void:
	var impact := sin(clampf(p / 0.72, 0.0, 1.0) * PI)
	var radius := 17.0 + p * 37.0
	_ring(Vector2.ZERO, radius, 0.36, Color("ff7949"), a * (1.0 - p), 2.3)
	_ring(Vector2.ZERO, radius * 0.68, 0.36, GOLD, a * (1.0 - p) * 0.6, 1.0)
	# The ember column has a narrow luminous core; its open edges leave the body readable.
	for side in [-1.0, 1.0]:
		var ribbon := PackedVector2Array()
		for j in range(19):
			var f := j / 18.0
			ribbon.append(Vector2(side * (8.0 + sin(f * 8.0 - _age * 10.0) * 8.0) * sin(f * PI), -f * 128.0 * impact))
		_glow_line(ribbon, Color("ff6d43"), 2.4, a * impact)
	for i in range(8):
		var angle := i * TAU / 8.0 + 0.17
		var direction := Vector2(cos(angle), sin(angle) * 0.35)
		_glow_line(PackedVector2Array([direction * 8, direction * (21 + p * 20), direction.rotated(0.16) * (34 + p * 30)]), Color("f7b45d"), 1.1, a * (1.0 - p) * 0.7)
	_sparks(Color("ffae67"), a, p, 16, 52.0, 114.0)
	_star(Vector2(0, -11), 8.0 * (1.0 - p), GOLD, a * 0.8)


func _fire(a: float, p: float) -> void:
	var storm := spell_id == 41
	var height := 106.0 if storm or spell_id == 4 else 78.0
	_ring(Vector2.ZERO, 23.0 + p * 12.0, 0.32, Color("ffb56a"), a * (1.0 - p) * 0.8, 1.4)
	for i in range(7):
		var cycle := fmod(p * 1.1 + i * 0.137, 1.0)
		var x := (i - 3.0) * 6.7 + sin(_age * 7.0 + i) * 6.0
		if storm: x = cos(i * 1.7 + p * 8.0) * (24.0 - cycle * 12.0)
		var at := Vector2(x, -8.0 - cycle * height)
		var strength := sin(cycle * PI) * a
		_flame(at, 9.0 - cycle * 4.0, 21.0 + cycle * 7.0, Color("fa753f"), strength)
	_sparks(Color("ffbd75"), a * 0.8, p, 12, 39.0, height)
	if storm:
		for i in range(2):
			var ribbon := PackedVector2Array()
			for j in range(30):
				var f := j / 29.0
				ribbon.append(Vector2(sin(f * 10.0 - p * 9.0 + i * PI) * (27.0 - f * 15.0), -f * height))
			_glow_line(ribbon, GOLD, 1.1, a * sin(p * PI) * 0.45)


func _healing(a: float, p: float) -> void:
	var restoring := family == "restoration"
	var color := Color("80dccf") if restoring else GREEN
	_ring(Vector2.ZERO, 22.0 + sin(p * PI) * 5.0, 0.34, color, a * 0.8, 1.5)
	_ring(Vector2(0, -2), 15.0 + p * 8.0, 0.34, GOLD, a * 0.5, 0.9)
	for i in range(7 if restoring else 5):
		var phase := fmod(p * 0.9 + i * 0.193, 1.0)
		var angle := i * 2.4 + p * 3.4
		var at := Vector2(cos(angle) * (19.0 - phase * 5.0), -7.0 - phase * 82.0 * _power)
		var alpha := a * sin(phase * PI)
		_star(at, 3.2 + phase * 1.3, GOLD if i % 3 == 0 else color, alpha)
		var trail := PackedVector2Array([at + Vector2(-3, 13), at + Vector2(1, 7), at])
		_glow_line(trail, color, 1.0, alpha * 0.55)
	# No solid pillar over the character: two open ribbons meet above the shoulders.
	for side in [-1.0, 1.0]:
		var ribbon := PackedVector2Array()
		for j in range(24):
			var f := j / 23.0
			ribbon.append(Vector2(side * sin(f * PI) * (20.0 + sin(_age * 4.0) * 3.0), -f * 78.0))
		_glow_line(ribbon, color, 1.0, a * sin(p * PI) * 0.55)


func _paralysis(a: float, p: float) -> void:
	_ring(Vector2.ZERO, 25.0, 0.36, VIOLET, a * 0.8, 1.5)
	for i in range(5):
		var angle := i * TAU / 5.0 + p * 1.1
		var x := cos(angle) * 22.0
		var depth := sin(angle)
		var points := PackedVector2Array([Vector2(x, -3 + depth * 6), Vector2(x * 0.85, -40), Vector2(x * 0.65, -66)])
		_glow_line(points, ELECTRIC.lerp(VIOLET, 0.65), 1.2, a * (0.35 + (depth + 1.0) * 0.18))
		_diamond(Vector2(x * 0.65, -66), 3.0, VIOLET, a * 0.9)
	_ring(Vector2(0, -37), 22.0, 0.3, VIOLET, a * 0.6, 1.1)
	_ring(Vector2(0, -64), 15.0, 0.35, ELECTRIC, a * 0.5, 0.9)


func _release(a: float, p: float) -> void:
	_ring(Vector2.ZERO, 15.0 + p * 48.0, 0.35, GREEN, a * (1.0 - p), 1.7)
	_ring(Vector2(0, -35), 9.0 + p * 27.0, 0.9, GOLD, a * (1.0 - p) * 0.8, 1.1)
	for i in range(10):
		var angle := i * TAU / 10.0
		var direction := Vector2(cos(angle), sin(angle))
		var at := Vector2(0, -37) + direction * (14.0 + p * 41.0)
		_diamond(at, 3.0 * (1.0 - p), VIOLET.lerp(GREEN, p), a)
		_glow_line(PackedVector2Array([at - direction * 7.0, at]), GOLD, 0.9, a * (1.0 - p))


func _stun(a: float, p: float) -> void:
	_ring(Vector2(0, -72), 19.0, 0.32, GOLD, a * 0.6, 1.0)
	for i in range(4):
		var angle := i * TAU / 4.0 + p * 5.0
		_star(Vector2(cos(angle) * 21.0, -72 + sin(angle) * 7.0), 4.0, GOLD, a)


func _roots(a: float, p: float) -> void:
	_ring(Vector2.ZERO, 23.0, 0.3, GREEN, a * 0.5, 1.0)
	for i in range(5):
		var side := -1.0 if i % 2 == 0 else 1.0
		var height := (34.0 + i * 8.0) * minf(1.0, p / 0.25)
		var vine := PackedVector2Array()
		for j in range(18):
			var f := j / 17.0
			vine.append(Vector2(side * (12.0 + sin(f * 5.0 + i) * 9.0), -f * height))
		_glow_line(vine, Color("8bc899"), 1.5, a * 0.7)
		_diamond(vine[-1], 4.0, GOLD.lerp(GREEN, 0.7), a)


func _void(a: float, p: float) -> void:
	var center := Vector2(0, -32)
	var radius := 28.0 * sin(p * PI) + 7.0
	# Converging dark-violet orbits distinguish implosion from a fire explosion.
	for i in range(3):
		var points := PackedVector2Array()
		for j in range(30):
			var f := j / 29.0
			var angle := i * TAU / 3.0 + f * 4.4 - p * 7.0
			var r := radius * (1.0 - f * 0.85)
			points.append(center + Vector2(cos(angle) * r, sin(angle) * r * 1.2))
		_glow_line(points, VIOLET, 1.7, a * 0.8)
	_ring(Vector2.ZERO, 33.0 * (1.0 - p) + 5.0, 0.33, VIOLET, a * 0.6, 1.0)
	_star(center, 4.0, WHITE, a * sin(p * PI) * 0.8)


func _poison(a: float, p: float) -> void:
	_ring(Vector2.ZERO, 24.0, 0.34, Color("a0bf79"), a * 0.6, 1.3)
	for i in range(9):
		var phase := fmod(p + i * 0.17, 1.0)
		var at := Vector2(sin(i * 3.4 + p * 3.0) * 23.0, -8.0 - phase * 63.0)
		var color := Color("b3c77d") if i % 2 == 0 else VIOLET
		_diamond(at, 2.5 + phase, color, a * sin(phase * PI))


func _holy(a: float, p: float) -> void:
	_ring(Vector2.ZERO, 26.0 + p * 10.0, 0.34, GOLD, a * 0.8, 1.5)
	for i in range(5):
		var x := (i - 2.0) * 9.0
		var phase := fmod(p + i * 0.16, 1.0)
		var at := Vector2(x, -92.0 + phase * 78.0)
		_glow_line(PackedVector2Array([at + Vector2(0, -21), at]), GOLD, 1.2, a * sin(phase * PI) * 0.7)
		_star(at, 3.0, WHITE, a * sin(phase * PI))
	_star(Vector2(0, -57), 8.0, GOLD, a * sin(p * PI) * 0.8)


func _arcane(a: float, p: float) -> void:
	_ring(Vector2.ZERO, 17.0 + p * 19.0, 0.34, VIOLET, a * (1.0 - p), 1.5)
	for i in range(3):
		var phase := clampf((p - i * 0.11) / 0.63, 0.0, 1.0)
		var at := Vector2(sin(phase * PI) * (i - 1.0) * 24.0, -82.0 + phase * 73.0)
		_star(at, 4.5 * sin(phase * PI), ELECTRIC if i == 1 else VIOLET, a)
		_glow_line(PackedVector2Array([at + Vector2(-6, -15), at + Vector2(2, -7), at]), VIOLET, 1.4, a * sin(phase * PI))
	_sparks(VIOLET, a * 0.8, p, 8, 31.0, 54.0)


func _glow_line(points: PackedVector2Array, color: Color, width: float, alpha: float) -> void:
	if alpha <= 0.0 or points.size() < 2: return
	draw_polyline(points, Color(color, alpha * 0.075), width + 8.0, true)
	draw_polyline(points, Color(color, alpha * 0.22), width + 3.0, true)
	draw_polyline(points, Color(color, alpha), width, true)


func _ring(at: Vector2, radius: float, flatten: float, color: Color, alpha: float, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(49):
		var angle := i * TAU / 48.0
		points.append(at + Vector2(cos(angle) * radius, sin(angle) * radius * flatten))
	_glow_line(points, color, width, alpha)


func _star(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	if radius <= 0.1 or alpha <= 0.0: return
	draw_circle(at, radius * 1.8, Color(color, alpha * 0.08), true, -1.0, true)
	var points := PackedVector2Array([at + Vector2(0, -radius * 1.8), at + Vector2(radius * 0.28, -radius * 0.28), at + Vector2(radius, 0), at + Vector2(radius * 0.28, radius * 0.28), at + Vector2(0, radius * 1.8), at + Vector2(-radius * 0.28, radius * 0.28), at + Vector2(-radius, 0), at + Vector2(-radius * 0.28, -radius * 0.28)])
	draw_colored_polygon(points, Color(color, alpha))
	draw_circle(at, radius * 0.22, Color(WHITE, alpha), true, -1.0, true)


func _diamond(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	if radius <= 0.1: return
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius * 1.5), at + Vector2(radius, 0), at + Vector2(0, radius * 1.5), at + Vector2(-radius, 0)]), Color(color, alpha))


func _flame(at: Vector2, width: float, height: float, color: Color, alpha: float) -> void:
	var points := PackedVector2Array([at + Vector2(0, -height), at + Vector2(width * 0.42, -height * 0.43), at + Vector2(width, -height * 0.15), at + Vector2(width * 0.7, height * 0.1), at + Vector2(0, height * 0.28), at + Vector2(-width * 0.72, height * 0.06), at + Vector2(-width * 0.52, -height * 0.45)])
	draw_colored_polygon(points, Color(color, alpha * 0.42))
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -height * 0.59), at + Vector2(width * 0.42, 0), at + Vector2(0, height * 0.17), at + Vector2(-width * 0.37, 0)]), Color(GOLD, alpha * 0.7))
	draw_circle(at, width * 0.23, Color(WHITE, alpha * 0.65), true, -1.0, true)


func _sparks(color: Color, a: float, p: float, count: int, spread: float, height: float) -> void:
	for i in range(count):
		var phase := fmod(p * 1.05 + i * 0.137, 1.0)
		var x := sin(i * 7.3) * spread * (0.35 + phase * 0.65)
		var at := Vector2(x, -5.0 - phase * height)
		var alpha := sin(phase * PI) * a * (0.85 if i % 2 == 0 else 0.5)
		_star(at, 1.6 if i % 3 else 2.5, color, alpha)
