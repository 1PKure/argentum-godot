class_name ArenaSpellVisual
extends Node2D
## Every spell is newly drawn, animated light/particles. AO artwork is a concept
## reference only; no original sprite, texture atlas or animation is displayed.
## Local zero is the recipient's feet. Gameplay timing stays server-owned.

var family := "arcane"
var spell_id := 0
var lifetime := 1.15
var source_fx_id := 0 # Reference/attribution only, never loaded or drawn.
var concept := "arcane_dart"
var _age := 0.0
var _power := 1.0

const ELECTRIC := Color("75cfff")
const WHITE := Color("f4fcff")
const GOLD := Color("f3d38b")
const GREEN := Color("76e6b1")
const VIOLET := Color("ad95ef")
const FIRE := Color("ff8050")
const CONCEPTS := {
	1: "arcane_dart", 2: "arcane_arrow", 3: "arcane_missiles", 4: "dragon_breath",
	11: "cleanse_poison", 12: "minor_healing", 13: "major_healing", 25: "paralysis_cage",
	26: "binding_vines", 27: "shatter_paralysis", 28: "dizzy_stars", 29: "restore_motion",
	31: "critical_healing", 39: "flying_ember", 40: "igneous_flare", 41: "opening_firestorm",
	43: "electric_arrow", 50: "electric_impact", 51: "converging_electric_orbs", 53: "apocalypse_skull_burst",
	54: "implosion", 55: "banshee_wail", 56: "final_judgement", 59: "elemental_ray",
	112: "dispel_magic", 113: "thorn_burst", 122: "mortal_word", 131: "banishment_gate",
	132: "divine_prayer", 133: "supplication", 141: "abyssal_vortex", 242: "greater_restoration",
	243: "putrefaction", 247: "physical_arrow_reference", 263: "blessing_shield",
	268: "lesser_restoration", 269: "restoration", 291: "arcane_wave", 350: "entangling_roots",
}


func configure(spell: Dictionary) -> void:
	spell_id = int(spell.get("id", 0))
	source_fx_id = int(spell.get("fx_id", 0))
	concept = str(CONCEPTS.get(spell_id, "arcane_dart"))
	family = family_for_spell(spell)
	_power = 1.2 if spell_id in [31, 53, 56, 242] else 1.0
	lifetime = 1.28 if family in ["healing", "restoration", "void"] else 1.12
	if spell_id == 53: lifetime = 1.5
	if spell_id == 51: lifetime = 1.2
	set_meta("modern_fx", true)
	set_meta("procedural_only", true)
	set_meta("concept", concept)
	set_meta("foot_anchored", true)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


static func family_for_spell(spell: Dictionary) -> String:
	var id := int(spell.get("id", 0))
	if id in [43, 50, 51, 59]: return "electric"
	if id == 53: return "apocalypse"
	if id in [4, 39, 40, 41]: return "fire"
	if id == 25: return "paralysis"
	if id in [27, 29, 112]: return "release"
	if id == 28: return "stun"
	if id in [26, 113, 350]: return "roots"
	if id in [54, 55, 122, 131, 141]: return "void"
	if id == 243: return "poison"
	if id in [56, 132, 133, 263]: return "holy"
	if id in [242, 268, 269]: return "restoration"
	if str(spell.get("effect", "")) == "healing" or id == 11: return "healing"
	return "arcane"


func set_age(seconds: float) -> void:
	_age = maxf(0.0, seconds)
	queue_redraw()


func opacity_at(seconds: float) -> float:
	var progress := clampf(seconds / lifetime, 0.0, 1.0)
	return minf(1.0, maxf(0, seconds) / 0.04) * clampf((1.0 - progress) / 0.28, 0.0, 1.0)


func _draw() -> void:
	var p := clampf(_age / lifetime, 0.0, 1.0)
	var a := opacity_at(_age)
	if a <= 0.0: return
	match family:
		"electric": _electric(a, p)
		"apocalypse": _apocalypse(a, p)
		"fire": _fire(a, p)
		"healing", "restoration": _healing(a, p)
		"paralysis": _paralysis(a, p)
		"release": _release(a, p)
		"stun": _stun(a, p)
		"roots": _roots(a, p)
		"void": _void(a, p)
		"poison": _poison(a, p)
		"holy": _holy(a, p)
		_: _arcane(a, p)


# These paths drive the actual drawing and also let QA check the movement,
# rather than merely asserting a descriptive family/name flag.
func electric_orb_positions(p: float) -> PackedVector2Array:
	var approach := smoothstep(0.0, 0.48, p)
	var separation := lerpf(63.0, 0.0, approach)
	var height := lerpf(-89.0, -55.0, approach)
	return PackedVector2Array([Vector2(-separation, height), Vector2(separation, height)])


func storm_particle_positions(p: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(22):
		var angle := -PI * 0.93 + i * PI * 0.86 / 21.0 + sin(i * 7.1) * 0.065
		var delay := (i % 4) * 0.027 + (sin(i * 1.7) + 1) * 0.018
		var travel := clampf((p - delay) / 0.82, 0.0, 1.0)
		var speed := 0.69 + (i % 7) * 0.062
		var drift := Vector2(sin(i * 3.1) * 5, sin(i * 4.7) * 3)
		points.append(Vector2(0, -8) + drift + Vector2(cos(angle), sin(angle)) * (12.0 + travel * 103.0 * speed) + Vector2(0, travel * travel * 17))
	return points


func apocalypse_outline(p: float) -> PackedVector2Array:
	var growth := smoothstep(0.08, 0.40, p)
	var center := Vector2(0, -130 - growth * 26)
	var points := PackedVector2Array()
	for i in range(49):
		var angle := i * TAU / 48.0
		var lobe := 1.0 + sin(angle * 7 + p * 2) * 0.08
		points.append(center + Vector2(cos(angle) * 73, sin(angle) * 58) * growth * lobe)
	return points


func healing_particle_positions(p: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := 6 if spell_id == 12 else (13 if spell_id in [31, 242] else 9)
	for i in range(count):
		var phase := clampf((p - (i % 4) * 0.055) / 0.78, 0.0, 1.0)
		var spread := 19.0 if spell_id == 12 else 28.0
		var x := sin(i * 5.7) * spread + sin(phase * PI + i) * 4
		points.append(Vector2(x, -4.0 - phase * (72.0 if spell_id == 12 else 103.0)))
	return points


func _electric(a: float, p: float) -> void:
	if spell_id == 51:
		var orbs := electric_orb_positions(p)
		var approaching := 1.0 - smoothstep(0.46, 0.62, p)
		for i in range(2):
			var at := orbs[i]
			_orb(at, 14 + sin(p * 15 + i) * 1.5, ELECTRIC, a * approaching)
			_ring(at, 10, 1.0, ELECTRIC, a * approaching * 0.7, 1)
			_ring(at, 13, 0.35, WHITE, a * approaching * 0.5, 0.7)
			for branch in range(3):
				var angle := branch * TAU / 3 + p * 5 + i * PI
				var direction := Vector2.from_angle(angle)
				_lightning(at + direction * 7, at + direction * 27, ELECTRIC, a * approaching * 0.8, i + branch)
		if p < 0.5: _lightning(orbs[0], orbs[1], ELECTRIC, a * 0.8, 2)
		var burst := clampf((p - 0.43) / 0.57, 0, 1)
		if p > 0.43:
			_orb(Vector2(0, -55), 17 * (1-burst), WHITE, a * (1-burst))
			for i in range(9):
				var direction := Vector2.from_angle(i * TAU / 9 + 0.12)
				_lightning(Vector2(0, -55) + direction * 7, Vector2(0, -55) + direction * (21 + burst * 49), ELECTRIC, a * (1-burst), i)
			_lightning(Vector2(0, -55), Vector2(0, -2), ELECTRIC, a * (1-burst), 1)
			_ring(Vector2.ZERO, 16 + burst * 29, 0.33, ELECTRIC, a * (1-burst) * 0.65, 1.2)
		return
	if spell_id == 43:
		var at := Vector2(0, lerpf(-115.0, -23.0, smoothstep(0, 0.55, p)))
		_lightning(at + Vector2(0, -38), at + Vector2(0, 13), ELECTRIC, a, 1)
		_glow_line(PackedVector2Array([at + Vector2(-10, 0), at + Vector2(0, 13), at + Vector2(10, 0)]), ELECTRIC, 1.8, a)
		_sparks(ELECTRIC, a * 0.7, p, 8, 26, 55)
		return
	var center := Vector2(0, -33)
	if spell_id == 59:
		var top := Vector2(sin(p * PI) * 12, -151)
		_lightning(top, Vector2(0, -3), ELECTRIC, a * (1-p), 5)
		for i in range(3):
			var at := center + Vector2.from_angle(i * TAU / 3 - p * 5) * (32 * (1-p))
			_orb(at, 5, [ELECTRIC, GOLD, VIOLET][i], a)
	else:
		for i in range(8):
			var direction := Vector2.from_angle(i * TAU / 8)
			_lightning(center + direction * 5, center + direction * (12 + p * 42), ELECTRIC, a * (1-p), i)
		_orb(center, 11 * (1-p), ELECTRIC, a)
	_sparks(ELECTRIC, a * 0.6, p, 10, 37, 69)


func _apocalypse(a: float, p: float) -> void:
	var birth := smoothstep(0.0, 0.18, p)
	var blast := clampf((p-0.15) / 0.75, 0, 1)
	var sustain := 1.0 - smoothstep(0.66, 1.0, p)
	# A huge ember plume resolves into an energy skull, then disintegrates.
	# It occupies the target's vicinity, never a screen-wide white flash.
	for side in [-1.0, 1.0]:
		var trunk := PackedVector2Array()
		for i in range(22):
			var f := i / 21.0
			trunk.append(Vector2(side * (8 + sin(f * 8 - p * 7) * 10) * sin(f * PI), -f * 146 * birth))
		_glow_line(trunk, FIRE, 5.0, a * sustain * 0.75)
	var skull := apocalypse_outline(p)
	if p > 0.085: draw_colored_polygon(skull, Color(FIRE, a * sustain * 0.18))
	_glow_line(skull, FIRE.lerp(GOLD, 0.35), 3.5, a * sustain)
	var grow := smoothstep(0.08, 0.40, p)
	var center := Vector2(0, -130 - grow * 26)
	for i in range(11):
		var angle := PI + i * PI / 10
		var at := center + Vector2(cos(angle) * 67, sin(angle) * 51) * grow
		var warmth := FIRE.lerp(GOLD, (i % 3) * 0.22)
		# Wide soft energy lobes, not a row of white beads along the skull.
		for layer in range(4, 0, -1):
			draw_circle(at, (12 + layer * 4) * grow, Color(warmth, a * sustain * (0.07 if layer > 1 else 0.13)), true, -1, true)
		if i % 2 == 0:
			var plume := PackedVector2Array([at, at + Vector2(sin(i + p*6)*9, -17*grow), at + Vector2(sin(i*2 + p*4)*14, -32*grow)])
			_glow_line(plume, warmth, 1.8, a * sustain * 0.5)
	if grow > 0.05:
		for side in [-1.0, 1.0]:
			var eye := PackedVector2Array([Vector2(side * 10, -5), Vector2(side * 43, -15), Vector2(side * 32, 8)])
			for i in range(eye.size()): eye[i] = center + eye[i] * grow
			draw_colored_polygon(eye, Color("25172c", a * sustain * 0.9))
			_glow_line(PackedVector2Array([eye[0], eye[1], eye[2]]), GOLD, 1.5, a * sustain)
			var cheek := PackedVector2Array([center + Vector2(side * 59, 12) * grow, center + Vector2(side * 31, 38) * grow, center + Vector2(side * 24, 59) * grow])
			_glow_line(cheek, FIRE, 3.0, a * sustain)
		for i in range(5):
			var at := center + Vector2((i-2)*9, 39) * grow
			_glow_line(PackedVector2Array([at, at + Vector2(0, 16)*grow]), GOLD, 2, a * sustain * 0.8)
		var nose := PackedVector2Array([center + Vector2(0, 8)*grow, center + Vector2(-8, 24)*grow, center + Vector2(8, 24)*grow])
		draw_colored_polygon(nose, Color("25172c", a * sustain * 0.85))
	for i in range(28):
		var angle := i * TAU / 28 + 0.05
		var direction := Vector2(cos(angle), sin(angle) * 0.64)
		var start := Vector2(0, -83) + direction * 14
		var at := start + direction * blast * (65 + i%4 * 12) + Vector2(0, blast*blast*31)
		_glow_line(PackedVector2Array([at - direction * (8 + 8*(1-blast)), at]), GOLD if i%3 == 0 else FIRE, 1.7, a * (1-blast) * 0.8)
	_ring(Vector2.ZERO, 16 + blast * 89, 0.31, FIRE, a * (1-blast) * 0.8, 2)
	_sparks(GOLD, a * 0.6, p, 17, 65, 183)


func _fire(a: float, p: float) -> void:
	if spell_id == 41:
		var particles := storm_particle_positions(p)
		# Unequal warm puffs/embers open away from the body. Avoid evenly spaced
		# spokes: the original concept is a spreading fire cloud, not a radial UI.
		for i in range(particles.size()):
			var at := particles[i]
			var size_value := 5.0 + (i * 7 % 11) * 0.65
			var strength := a * (0.88 - p * 0.30) * (0.68 + (i % 3) * 0.12)
			var color := FIRE.lerp(GOLD, (i % 5) * 0.12)
			for layer in range(5, 0, -1):
				var radius := size_value * (0.35 + layer * 0.28)
				draw_circle(at, radius, Color(color, strength * (0.11 if layer > 2 else 0.18)), true, -1, true)
			if i % 4 == 1:
				_flame(at + Vector2(0, 3), size_value * 0.5, size_value * 1.6, color, strength * 0.65)
			elif i % 4 == 0:
				var drift := Vector2(sin(i * 5.2) * 4, -5 - i % 3)
				_glow_line(PackedVector2Array([at-drift, at]), GOLD, 1.0, strength * 0.5)
		return
	if spell_id == 4:
		for i in range(16):
			var phase := clampf((p - (i%4)*0.04) / 0.75, 0, 1)
			var at := Vector2(sin(i*4.1) * (8+phase*34), -7-phase*139)
			_flame(at, 5+phase*7, 17+phase*12, FIRE, a * sin(phase*PI))
		_sparks(GOLD, a, p, 15, 47, 142)
		return
	if spell_id == 39:
		var t := smoothstep(0, 0.65, p)
		var at := Vector2(lerpf(-61, 7, t), lerpf(-91, -30, t))
		_glow_line(PackedVector2Array([at + Vector2(-26,-25), at+Vector2(-12,-8), at]), FIRE, 4, a)
		_flame(at, 9, 25, FIRE, a)
		_sparks(GOLD, a * 0.65, p, 7, 32, 61)
		return
	# Resplandor is a compact sunburst, distinct from storm and breath.
	var center := Vector2(0,-39)
	_orb(center, 9 + sin(p*PI)*13, FIRE, a * (1-p*0.5))
	for i in range(12):
		var direction := Vector2.from_angle(i*TAU/12 + 0.08)
		var inner := 10 + p*15
		_glow_line(PackedVector2Array([center + direction*inner, center+direction*(inner+15+p*17)]), GOLD, 1.7, a*(1-p))


func _healing(a: float, p: float) -> void:
	if spell_id == 11:
		# Poison fragments leave the body and dissolve; fresh mint light remains.
		for i in range(8):
			var angle := i*TAU/8
			var at := Vector2(0,-31) + Vector2(cos(angle),sin(angle)*0.7)*(12+p*38)
			_diamond(at, 3*(1-p), Color("b6cc7d").lerp(GREEN,p), a*(1-p))
		_sparks(GREEN,a,p,7,23,75)
		return
	var restoring := family == "restoration"
	var color := Color("8bdfd4") if restoring else GREEN
	var points := healing_particle_positions(p)
	for i in range(points.size()):
		var at := points[i]
		var strength := sin(clampf((p-(i%4)*0.055)/0.78,0,1)*PI)
		var radius := 2.4 if spell_id == 12 else (3.7 if spell_id in [31,242] else 3.0)
		_star(at, radius, GOLD if i%4 == 0 else color, a*strength)
		_glow_line(PackedVector2Array([at+Vector2(0,9),at]),color,0.9,a*strength*0.45)
	if restoring:
		# Gentle open helixes denote regeneration; no filled pillar/noisy sprites.
		for side in [-1.0,1.0]:
			var trail := PackedVector2Array()
			for j in range(24):
				var f := j/23.0
				trail.append(Vector2(sin(f*TAU-p*3)*side*18,-f*86))
			_glow_line(trail,color,1,a*sin(p*PI)*0.36)
	elif spell_id == 31:
		for side in [-1.0,1.0]:
			var sweep := PackedVector2Array()
			for j in range(20):
				var f := j/19.0
				sweep.append(Vector2(side*(18+sin(f*PI)*14),-f*91))
			_glow_line(sweep,GOLD,1.2,a*sin(p*PI)*0.65)
	# Only a faint foot shimmer, not a ring repeated as the main graphic.
	_ring(Vector2.ZERO,17 if spell_id == 12 else 23,0.25,color,a*sin(p*PI)*0.28,0.8)


func _paralysis(a: float, p: float) -> void:
	for i in range(6):
		var angle := i*TAU/6 + p*0.45
		var x := cos(angle)*24
		var base := Vector2(x,sin(angle)*7)
		var top := Vector2(x*0.78,-73)
		_glow_line(PackedVector2Array([base,base.lerp(top,0.4)+Vector2(sin(p*9+i)*3,0),top]),VIOLET,1.6,a*(0.55+sin(angle)*0.15))
		_diamond(top,3.2,VIOLET,a)
	_ring(Vector2(0,-71),19,0.33,ELECTRIC,a*0.6,1)
	_ring(Vector2.ZERO,25,0.31,VIOLET,a*0.65,1.1)


func _release(a: float, p: float) -> void:
	if spell_id == 29:
		for side in [-1.0,1.0]:
			var ribbon := PackedVector2Array()
			for j in range(25):
				var f := j/24.0
				ribbon.append(Vector2(side*(9+sin(f*PI)*17),-f*83 + p*9))
			_glow_line(ribbon,GREEN,1.5,a*sin(p*PI))
		_sparks(GOLD,a*0.7,p,7,25,84)
		return
	if spell_id == 112:
		for i in range(12):
			var angle := i*TAU/12 + 0.22
			var direction := Vector2.from_angle(angle)
			var at := Vector2(0,-36)+direction*(7+p*47)
			_glow_line(PackedVector2Array([at-direction*8,at]),GOLD.lerp(GREEN,p),1.2,a*(1-p))
		_star(Vector2(0,-36),8*(1-p),WHITE,a*(1-p))
		return
	# Broken cage fragments visibly separate instead of silently disappearing.
	for i in range(10):
		var angle := i*TAU/10
		var direction := Vector2(cos(angle),sin(angle))
		var at := Vector2(0,-35)+direction*(18+p*41)
		var tangent := direction.rotated(PI/2)
		_glow_line(PackedVector2Array([at-tangent*5,at,at+direction*7]),VIOLET.lerp(GREEN,p),1.7,a*(1-p))
	_ring(Vector2.ZERO,13+p*34,0.29,GREEN,a*(1-p)*0.5,1)


func _stun(a: float, p: float) -> void:
	_ring(Vector2(0,-74),20,0.31,GOLD,a*0.5,1)
	for i in range(5):
		var angle := i*TAU/5+p*5
		_star(Vector2(cos(angle)*22,-74+sin(angle)*7),3.5,GOLD,a)


func _roots(a: float, p: float) -> void:
	if spell_id == 113:
		for i in range(9):
			var angle := i*TAU/9+0.15
			var direction := Vector2(cos(angle),sin(angle)*0.7)
			var at := Vector2(0,-30)+direction*(5+p*48)
			var thorn := PackedVector2Array([at-direction*14,at+direction*7,at+direction.rotated(PI/2)*4])
			draw_colored_polygon(thorn,Color(GREEN,a*(1-p)*0.75))
			_glow_line(PackedVector2Array([thorn[0],thorn[1]]),GOLD,0.8,a*(1-p))
		return
	var growth := smoothstep(0,0.32,p)
	for i in range(5 if spell_id == 350 else 3):
		var side := -1.0 if i%2 == 0 else 1.0
		var vine := PackedVector2Array()
		for j in range(23):
			var f := j/22.0
			var x := side*(12+sin(f*7+i)*11)
			vine.append(Vector2(x,-f*(49+i*6)*growth))
		_glow_line(vine,Color("86c79b"),1.8,a*0.8)
		for j in [7,13,19]:
			var at := vine[j]
			_diamond(at+Vector2(side*3,-1),3.8,GREEN,a*0.8)


func _void(a: float, p: float) -> void:
	if spell_id == 55:
		var center := Vector2(0,-60-sin(p*PI)*12)
		var face := PackedVector2Array()
		for i in range(25):
			var angle := PI+i*PI/24
			face.append(center+Vector2(cos(angle)*20,sin(angle)*25))
		for at in [Vector2(15,24),Vector2(6,16),Vector2(0,27),Vector2(-7,16),Vector2(-15,24)]: face.append(center+at)
		draw_colored_polygon(face,Color(VIOLET,a*0.12))
		_glow_line(face,VIOLET,1.4,a*0.85)
		for side in [-1.0,1.0]: _glow_line(PackedVector2Array([center+Vector2(side*12,-7),center+Vector2(side*5,-3)]),WHITE,1.3,a)
		_ring(center+Vector2(0,8),4,1.7,VIOLET,a,1.5)
		for i in range(3): _ring(center+Vector2(0,8),15+p*(22+i*18),0.85,VIOLET,a*(1-p)*0.42,1)
		return
	if spell_id == 131:
		var gate := PackedVector2Array()
		for i in range(49):
			var angle := i*TAU/48
			gate.append(Vector2(cos(angle)*(23+p*10),-40+sin(angle)*38))
		_glow_line(gate,VIOLET,1.8,a)
		for i in range(10):
			var direction := Vector2.from_angle(i*TAU/10)
			var at := Vector2(0,-40)+direction*(44*(1-p))
			_glow_line(PackedVector2Array([at,at+direction*6]),VIOLET,1,a)
		return
	if spell_id == 122:
		var center := Vector2(0,-47)
		_ring(center,18,1.1,VIOLET,a,1.8)
		for side in [-1.0,1.0]: _star(center+Vector2(side*7,-2),3,WHITE,a)
		_glow_line(PackedVector2Array([center+Vector2(-9,10),center+Vector2(-7,20),center+Vector2(7,20),center+Vector2(9,10)]),VIOLET,1.8,a)
		_sparks(VIOLET,a*0.5,p,7,25,79)
		return
	var center := Vector2(0,-40)
	if spell_id == 54:
		# Implosion: warm explosive fragments rush IN, then a compact ember core.
		for i in range(18):
			var angle := i*TAU/18+0.12
			var direction := Vector2(cos(angle),sin(angle)*0.8)
			var distance := lerpf(91,5,smoothstep(0,0.65,p))
			var at := center+direction*distance
			_glow_line(PackedVector2Array([at+direction*15,at]),FIRE.lerp(VIOLET,0.25),2,a*(1-p))
		_orb(center,6+sin(p*PI)*9,FIRE,a)
		if p>0.58: _ring(center,(p-0.58)*78,0.8,GOLD,a*(1-p),1)
		return
	# The abyss stays a cold, swirling void rather than an orange fire spell.
	for i in range(4):
		var trail := PackedVector2Array()
		for j in range(32):
			var f := j/31.0
			var angle := i*TAU/4+f*4.4-p*7
			var radius := (38+sin(p*PI)*12)*(1-f*0.88)
			trail.append(center+Vector2(cos(angle)*radius,sin(angle)*radius*0.85))
		_glow_line(trail,VIOLET,1.6,a*0.8)
	_orb(center,5,VIOLET,a*0.5)


func _poison(a: float, p: float) -> void:
	for i in range(12):
		var phase := fmod(p*0.85+i*0.083,1)
		var at := Vector2(sin(i*3.4+p*2)*23,-6-phase*75)
		var alpha := a*sin(phase*PI)
		_orb(at,2.2+phase*2,Color("b2c878") if i%3 else VIOLET,alpha*0.5)
		if i%3 == 0: _diamond(at+Vector2(2,-4),2.4,Color("a7bd79"),alpha)


func _holy(a: float, p: float) -> void:
	if spell_id == 263:
		var shield := PackedVector2Array([Vector2(-22,-65),Vector2(0,-74),Vector2(22,-65),Vector2(19,-31),Vector2(0,-13),Vector2(-19,-31),Vector2(-22,-65)])
		draw_colored_polygon(shield,Color(GOLD,a*0.08))
		_glow_line(shield,GOLD,1.6,a*sin(p*PI))
		_star(Vector2(0,-45),8,GOLD,a)
		_sparks(GOLD,a*0.6,p,7,31,83)
		return
	if spell_id == 56:
		var strike := sin(clampf(p/0.8,0,1)*PI)
		for i in range(7):
			var x := (i-3)*10.0
			var top := Vector2(x,-156+(i%3)*10)
			var bottom := Vector2(x*0.25,-8)
			_glow_line(PackedVector2Array([top,bottom]),GOLD,1.6,a*strike*0.55)
		_star(Vector2(0,-67),12,GOLD,a*strike)
		_ring(Vector2.ZERO,18+p*42,0.29,GOLD,a*(1-p),1.4)
		return
	if spell_id == 132:
		for side in [-1.0,1.0]:
			var wing := PackedVector2Array()
			for j in range(24):
				var f := j/23.0
				wing.append(Vector2(side*(10+sin(f*PI)*34),-20-f*71))
			_glow_line(wing,GOLD,1.5,a*sin(p*PI))
			for i in range(4):
				var at := Vector2(side*(16+i*6),-40-i*11)
				_glow_line(PackedVector2Array([at,at+Vector2(side*6,-13)]),GOLD,1,a*0.6)
		_star(Vector2(0,-78),6,WHITE,a)
	else:
		# Plegaria is a small halo with ascending motes, not Judgement's rays.
		_ring(Vector2(0,-84),18,0.31,GOLD,a*sin(p*PI),1.4)
		_sparks(GOLD,a,p,10,23,82)


func _arcane(a: float, p: float) -> void:
	if spell_id == 291:
		for i in range(3):
			var arc := PackedVector2Array()
			for j in range(35):
				var angle := PI+j*PI/34
				arc.append(Vector2(0,-12)+Vector2.from_angle(angle)*(12+p*(43+i*12)))
			_glow_line(arc,VIOLET.lerp(ELECTRIC,i*0.3),1.4,a*(1-p)*0.85)
		return
	if spell_id == 247:
		# Physical arrows are normally rendered by ArenaSpellEffect's projectile.
		_glow_line(PackedVector2Array([Vector2(-5,-25),Vector2(0,-36),Vector2(5,-25)]),GOLD,1,a)
		return
	var count := 3 if spell_id == 3 else 1
	for i in range(count):
		var travel := smoothstep(0.02+i*0.08,0.60+i*0.08,p)
		var at := Vector2((i-(count-1)*0.5)*17*sin(travel*PI),lerpf(-107,-25,travel))
		if spell_id == 2:
			_glow_line(PackedVector2Array([at+Vector2(-9,-11),at+Vector2(0,3),at+Vector2(9,-11)]),VIOLET,2,a)
			_glow_line(PackedVector2Array([at+Vector2(0,-28),at+Vector2(0,3)]),VIOLET,2,a)
		elif spell_id == 3:
			_orb(at,5,ELECTRIC,a)
			_glow_line(PackedVector2Array([at+Vector2(0,-17),at]),VIOLET,1.3,a*0.6)
		else:
			_star(at,4.5,ELECTRIC,a)
			_glow_line(PackedVector2Array([at+Vector2(0,-25),at]),VIOLET,1.6,a*0.7)
	_sparks(VIOLET,a*0.5,p,6,26,51)


func _lightning(start: Vector2, end: Vector2, color: Color, alpha: float, seed_value: int) -> void:
	var points := PackedVector2Array()
	var tangent := (end-start).normalized().rotated(PI/2)
	for i in range(9):
		var f := i/8.0
		var jitter := sin(i*8.3+floorf(_age*22)*1.7+seed_value*2.5)*sin(f*PI)*6
		points.append(start.lerp(end,f)+tangent*jitter)
	_glow_line(points,color,1.6,alpha)
	_glow_line(points,WHITE,0.6,alpha*0.65)


func _orb(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	if radius<=0.1 or alpha<=0: return
	for i in range(5,0,-1):
		var f := i/5.0
		draw_circle(at,radius*(0.7+f*1.3),Color(color,alpha*(1-f*0.7)*0.12),true,-1,true)
	draw_circle(at,radius*0.63,Color(color,alpha*0.5),true,-1,true)
	draw_circle(at,radius*0.26,Color(WHITE,alpha*0.85),true,-1,true)


func _glow_line(points: PackedVector2Array, color: Color, width: float, alpha: float) -> void:
	if alpha<=0.0 or points.size()<2: return
	draw_polyline(points,Color(color,alpha*0.075),width+8,true)
	draw_polyline(points,Color(color,alpha*0.22),width+3,true)
	draw_polyline(points,Color(color,alpha),width,true)


func _ring(at: Vector2, radius: float, flatten: float, color: Color, alpha: float, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(49):
		var angle := i*TAU/48
		points.append(at+Vector2(cos(angle)*radius,sin(angle)*radius*flatten))
	_glow_line(points,color,width,alpha)


func _star(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	if radius<=0.1 or alpha<=0: return
	draw_circle(at,radius*1.8,Color(color,alpha*0.08),true,-1,true)
	var points := PackedVector2Array([at+Vector2(0,-radius*1.8),at+Vector2(radius*0.28,-radius*0.28),at+Vector2(radius,0),at+Vector2(radius*0.28,radius*0.28),at+Vector2(0,radius*1.8),at+Vector2(-radius*0.28,radius*0.28),at+Vector2(-radius,0),at+Vector2(-radius*0.28,-radius*0.28)])
	draw_colored_polygon(points,Color(color,alpha))
	draw_circle(at,radius*0.22,Color(WHITE,alpha),true,-1,true)


func _diamond(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	if radius<=0.1: return
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-radius*1.5),at+Vector2(radius,0),at+Vector2(0,radius*1.5),at+Vector2(-radius,0)]),Color(color,alpha))


func _flame(at: Vector2, width: float, height: float, color: Color, alpha: float) -> void:
	var points := PackedVector2Array([at+Vector2(0,-height),at+Vector2(width*0.42,-height*0.43),at+Vector2(width,-height*0.15),at+Vector2(width*0.7,height*0.1),at+Vector2(0,height*0.28),at+Vector2(-width*0.72,height*0.06),at+Vector2(-width*0.52,-height*0.45)])
	draw_colored_polygon(points,Color(color,alpha*0.42))
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-height*0.59),at+Vector2(width*0.42,0),at+Vector2(0,height*0.17),at+Vector2(-width*0.37,0)]),Color(GOLD,alpha*0.7))
	draw_circle(at,width*0.23,Color(WHITE,alpha*0.65),true,-1,true)


func _sparks(color: Color, a: float, p: float, count: int, spread: float, height: float) -> void:
	for i in range(count):
		var phase := fmod(p*1.05+i*0.137,1)
		var at := Vector2(sin(i*7.3)*spread*(0.35+phase*0.65),-5-phase*height)
		_star(at,1.6 if i%3 else 2.5,color,a*sin(phase*PI)*(0.85 if i%2==0 else 0.5))
