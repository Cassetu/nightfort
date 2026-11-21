extends Control

const SQRT3: float = 1.7320508
const GROW_END := 1.4
const STAR_T0 := 0.6
const IMPACT := 2.7
const ZOOM_T0 := 1.0
const ZOOM_T1 := 4.2
const ZOOM_MAX := 4.2
const GRID_FADE_0 := 3.4
const GRID_FADE_1 := 5.2
const GATHER_T0 := 3.0
const TEXT_IN := 4.2
const OUT_START := 6.6
const TOTAL := 7.4
const TRAIL_STEPS := 30
const SPARK_COUNT := 90
const SPORE_COUNT := 40
const FLECK_COUNT := 110
const STREAK_COUNT := 70
const WAVE_SPEED := 520.0

var t: float = 0.0
var tech: Color = Color(0.35, 0.85, 1.0)
var nature: Color = Color(0.55, 0.9, 0.5)
var warm: Color = Color(1.0, 0.78, 0.45)
var seed_value: int = 1337
var text_rect: Rect2 = Rect2()

var hex_r: float = 80.0
var centers := PackedVector2Array()
var ring_of := PackedInt32Array()
var kinds := PackedInt32Array()
var phases := PackedFloat32Array()
var heat := PackedFloat32Array()
var hex_unit := PackedVector2Array()
var sparks: Array = []
var spores: Array = []
var flecks: Array = []
var streaks: Array = []
var last_t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in 7:
		var ang: float = float(k % 6) * (TAU / 6.0)
		hex_unit.append(Vector2(cos(ang), sin(ang)))
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not hex_unit.is_empty():
		_rebuild()


func _rebuild() -> void:
	var view: Vector2 = size
	if view.x < 8.0 or view.y < 8.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	hex_r = minf(view.x, view.y) / 13.0
	var half_diag: float = view.length() * 0.5
	var n: int = ceili(half_diag / (hex_r * 1.5)) + 2
	centers.clear()
	ring_of.clear()
	kinds.clear()
	phases.clear()
	for q in range(-n, n + 1):
		for r in range(-n, n + 1):
			var ring: int = floori(float(absi(q) + absi(r) + absi(q + r)) * 0.5)
			if ring > n:
				continue
			centers.append(Vector2(hex_r * 1.5 * float(q), hex_r * SQRT3 * (float(r) + float(q) * 0.5)))
			ring_of.append(ring)
			var roll: float = rng.randf()
			var kind: int = 0
			if roll < 0.34:
				kind = 1
			elif roll > 0.92:
				kind = 2
			kinds.append(kind)
			phases.append(rng.randf() * TAU)
	heat.resize(centers.size())
	heat.fill(0.0)
	sparks.clear()
	for i in SPARK_COUNT:
		sparks.append([rng.randf_range(0.04, 1.0), Vector2.from_angle(rng.randf() * TAU), rng.randf_range(1.2, 3.2), rng.randi() % 3])
	spores.clear()
	for i in SPORE_COUNT:
		spores.append([rng.randf(), rng.randf(), rng.randf_range(0.01, 0.035), rng.randf() * TAU, rng.randf_range(1.2, 3.0), rng.randi() % 2])
	flecks.clear()
	for i in FLECK_COUNT:
		flecks.append([rng.randf() * TAU, rng.randf_range(0.55, 0.95), rng.randf(), rng.randf(), rng.randf_range(0.0, 0.9), rng.randf_range(0.8, 1.1), rng.randf_range(-70.0, 70.0), rng.randf_range(3.0, 7.0), rng.randi() % 3])
	streaks.clear()
	for i in STREAK_COUNT:
		streaks.append([rng.randf() * TAU, rng.randf(), rng.randf_range(0.5, 1.3), rng.randf_range(40.0, 170.0), rng.randi() % 3])


func _kind_color(kind: int) -> Color:
	if kind == 0:
		return tech
	if kind == 1:
		return nature
	return warm


func _star_at(p: float) -> Vector2:
	var a := Vector2(-0.6 * size.x, -0.62 * size.y)
	var c := Vector2(0.15 * size.x, -0.25 * size.y)
	var q: float = 1.0 - p
	return a * q * q + c * 2.0 * q * p


func _star_progress() -> float:
	var u: float = clampf((t - STAR_T0) / (IMPACT - STAR_T0), 0.0, 1.0)
	return pow(u, 1.7)


func _ring_heat(dist: float, wave: float, width: float) -> float:
	if wave <= 0.0:
		return 0.0
	return maxf(0.0, 1.0 - absf(dist - wave) / (width * 1.3))


func _hex_ring(at: Vector2, radius: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for k in 7:
		pts.append(at + hex_unit[k] * radius)
	draw_polyline(pts, color, width, true)


func _draw_sprig(c: Vector2, r: float, col: Color, px: float) -> void:
	draw_line(c + Vector2(0.0, r * 0.55), c + Vector2(0.0, -r * 0.55), col, 1.2 * px)
	for k in 3:
		var y: float = r * (0.3 - 0.28 * float(k))
		var spread: float = r * (0.32 - 0.05 * float(k))
		draw_line(c + Vector2(0.0, y), c + Vector2(-spread, y - r * 0.26), col, 1.0 * px)
		draw_line(c + Vector2(0.0, y), c + Vector2(spread, y - r * 0.26), col, 1.0 * px)


func _draw_trace(c: Vector2, r: float, phase: float, col: Color, px: float) -> void:
	var corner: int = int(floorf(phase / TAU * 6.0)) % 6
	var ang: float = float(corner) * TAU / 6.0
	var dir := Vector2(cos(ang), sin(ang))
	var tip: Vector2 = c + dir * r * 0.62
	var knee: Vector2 = c + dir * r * 0.3 + dir.orthogonal() * r * 0.12
	draw_line(c, knee, col, 1.1 * px)
	draw_line(knee, tip, col, 1.1 * px)
	draw_rect(Rect2(tip - Vector2.ONE * 2.2 * px, Vector2.ONE * 4.4 * px), col)
	draw_circle(c, r * 0.05, col)


func _draw() -> void:
	if centers.is_empty():
		return
	var dt: float = clampf(t - last_t, 0.0, 0.1)
	last_t = t
	var view: Vector2 = size
	var center: Vector2 = view * 0.5
	var half_diag: float = view.length() * 0.5
	var zoom_u: float = smoothstep(0.0, 1.0, clampf((t - ZOOM_T0) / (ZOOM_T1 - ZOOM_T0), 0.0, 1.0))
	var zoom: float = lerpf(1.0, ZOOM_MAX, zoom_u) + maxf(t - ZOOM_T1, 0.0) * 0.03
	var rot: float = 0.16 * zoom_u
	var cam := Transform2D(rot, Vector2(zoom, zoom), 0.0, center)
	var px: float = 1.0 / zoom
	var p: float = _star_progress()
	var head_off: Vector2 = _star_at(p)
	var head_world: Vector2 = cam.affine_inverse() * (center + head_off)
	var star_on: bool = t >= STAR_T0 and t < IMPACT
	var wave_a: float = (t - IMPACT) * WAVE_SPEED
	var wave_b: float = (t - IMPACT - 0.3) * WAVE_SPEED
	var reach: float = hex_r * 2.2
	for i in centers.size():
		var cc: Vector2 = centers[i]
		var target: float = 0.0
		if star_on:
			var d: float = cc.distance_to(head_world)
			if d < reach:
				target = pow(1.0 - d / reach, 2.0)
		if t > IMPACT:
			var dc: float = cc.length()
			target = maxf(target, _ring_heat(dc, wave_a, hex_r))
			target = maxf(target, _ring_heat(dc, wave_b, hex_r) * 0.7)
		heat[i] = maxf(target, heat[i] - dt * 0.85)

	draw_set_transform_matrix(cam)
	var grid_alpha: float = 1.0 - 0.82 * smoothstep(GRID_FADE_0, GRID_FADE_1, t)
	var margin: float = hex_r * zoom * 1.3
	var inner: float = hex_r * 0.93
	for i in centers.size():
		var reveal: float = smoothstep(0.0, 0.5, t - 0.1 - float(ring_of[i]) * 0.09)
		if reveal <= 0.01:
			continue
		var c: Vector2 = centers[i]
		var sp: Vector2 = cam * c
		if sp.x < -margin or sp.x > view.x + margin or sp.y < -margin or sp.y > view.y + margin:
			continue
		var h: float = heat[i]
		var pulse: float = 0.5 + 0.5 * sin(t * 1.6 + phases[i])
		var base_col: Color = _kind_color(kinds[i])
		var col: Color = base_col.lerp(Color.WHITE, h * 0.35)
		var a: float = reveal * grid_alpha * (0.13 + 0.12 * pulse + h * 0.85)
		var pts := PackedVector2Array()
		for k in 7:
			pts.append(c + hex_unit[k] * inner)
		draw_polyline(pts, Color(col.r, col.g, col.b, a), (1.5 + h * 1.8) * px, true)
		if h > 0.12:
			draw_colored_polygon(pts.slice(0, 6), Color(col.r, col.g, col.b, h * 0.16 * grid_alpha * reveal))
		var detail: Color = Color(col.r, col.g, col.b, a * (0.7 + h))
		if kinds[i] == 1:
			_draw_sprig(c, inner, detail, px)
		elif kinds[i] == 0:
			_draw_trace(c, inner, phases[i], detail, px)
		else:
			draw_circle(c, inner * (0.1 + 0.05 * pulse), Color(col.r, col.g, col.b, minf(a * 1.4, 1.0)))

	var fade: float = 1.0 - smoothstep(IMPACT, IMPACT + 0.45, t)
	if t >= IMPACT:
		var since: float = t - IMPACT
		for wave: Array in [[since, 1.0], [since - 0.3, 0.7]]:
			var wa: float = wave[0]
			if wa <= 0.0 or wa > 1.8:
				continue
			var radius: float = wa * WAVE_SPEED
			var ring_a: float = (1.0 - wa / 1.8) * float(wave[1])
			var shift := Vector2(3.0, 0.0) * px
			_hex_ring(-shift, radius, Color(1.0, 0.3, 0.35, ring_a * 0.5), 3.0 * px)
			_hex_ring(Vector2.ZERO, radius, Color(0.3, 1.0, 0.6, ring_a * 0.6), 3.0 * px)
			_hex_ring(shift, radius, Color(0.35, 0.5, 1.0, ring_a * 0.5), 3.0 * px)

	draw_set_transform_matrix(Transform2D.IDENTITY)
	if t >= STAR_T0:
		for spark: Array in sparks:
			var s: float = spark[0]
			if p < s:
				continue
			var age: float = p - s
			var life: float = (1.0 - age / 0.3) * (1.0 - smoothstep(IMPACT, IMPACT + 0.6, t))
			if life <= 0.0:
				continue
			var dir: Vector2 = spark[1]
			var pos: Vector2 = center + _star_at(s) + dir * (10.0 + age * 220.0)
			var scol: Color = _kind_color(int(spark[3]))
			draw_circle(pos, float(spark[2]) * life, Color(scol.r, scol.g, scol.b, life * 0.9))
	if t >= STAR_T0 and fade > 0.0:
		var head: Vector2 = center + head_off
		var prev: Vector2 = head
		for k in range(1, TRAIL_STEPS + 1):
			var pk: float = maxf(p - float(k) * 0.011, 0.0)
			var cur: Vector2 = center + _star_at(pk)
			var f: float = 1.0 - float(k) / float(TRAIL_STEPS)
			draw_line(prev, cur, Color(tech.r, tech.g, tech.b, 0.55 * f * f * fade), 9.0 * f + 1.0)
			draw_line(prev, cur, Color(1.0, 1.0, 1.0, 0.8 * f * f * fade), 2.6 * f + 0.4)
			prev = cur
		draw_circle(head, 34.0, Color(tech.r, tech.g, tech.b, 0.05 * fade))
		draw_circle(head, 16.0, Color(tech.r, tech.g, tech.b, 0.12 * fade))
		draw_circle(head, 7.0, Color(tech.r, tech.g, tech.b, 0.4 * fade))
		draw_circle(head, 3.0, Color(1.0, 1.0, 1.0, fade))
		draw_line(head - Vector2(40.0, 0.0), head + Vector2(40.0, 0.0), Color(1.0, 1.0, 1.0, 0.35 * fade), 1.2)
		draw_line(head - Vector2(0.0, 40.0), head + Vector2(0.0, 40.0), Color(1.0, 1.0, 1.0, 0.35 * fade), 1.2)
	if t >= IMPACT:
		var flash_age: float = t - IMPACT
		var flash: float = maxf(0.0, 1.0 - flash_age / 0.55)
		for k in 6:
			draw_circle(center, 40.0 + float(k) * 70.0 * (0.3 + flash_age * 2.0), Color(1.0, 1.0, 1.0, flash * 0.07))
	var streak_i: float = smoothstep(ZOOM_T0 + 0.3, IMPACT, t) * (1.0 - smoothstep(IMPACT + 0.1, IMPACT + 1.2, t))
	if streak_i > 0.02:
		for st: Array in streaks:
			var sdir: Vector2 = Vector2.from_angle(float(st[0]))
			var ph: float = fposmod(float(st[1]) + t * float(st[2]), 1.0)
			var r0: float = lerpf(0.18, 1.0, ph * ph) * half_diag
			var length: float = float(st[3]) * streak_i * (0.4 + ph)
			var stcol: Color = _kind_color(int(st[4]))
			draw_line(center + sdir * r0, center + sdir * (r0 + length), Color(stcol.r, stcol.g, stcol.b, 0.35 * streak_i * ph), 1.2)
	var spore_a: float = smoothstep(0.3, 1.2, t) * (1.0 - smoothstep(GRID_FADE_0, GRID_FADE_1 + 0.6, t) * 0.7)
	for sporelet: Array in spores:
		var sy: float = fposmod(float(sporelet[1]) - t * float(sporelet[2]), 1.0)
		var sx: float = float(sporelet[0]) + sin(t * 0.7 + float(sporelet[3])) * 0.015
		var tw: float = 0.5 + 0.5 * sin(t * 2.2 + float(sporelet[3]) * 3.0)
		var pcol: Color = nature if int(sporelet[5]) == 0 else warm
		draw_circle(Vector2(sx * view.x, sy * view.y), float(sporelet[4]) * (0.7 + 0.5 * tw), Color(pcol.r, pcol.g, pcol.b, spore_a * (0.12 + 0.4 * tw)))
	var meld: float = smoothstep(TEXT_IN, TEXT_IN + 1.0, t)
	if t >= GATHER_T0 and meld < 1.0:
		for fleck: Array in flecks:
			var pf: float = clampf((t - GATHER_T0 - float(fleck[4])) / float(fleck[5]), 0.0, 1.0)
			if pf <= 0.0:
				continue
			var eased: float = 1.0 - pow(1.0 - pf, 3.0)
			var start: Vector2 = center + Vector2.from_angle(float(fleck[0])) * float(fleck[1]) * half_diag
			var dest: Vector2 = text_rect.position + Vector2(float(fleck[2]) * text_rect.size.x, float(fleck[3]) * text_rect.size.y)
			var swirl: Vector2 = (dest - start).orthogonal().normalized() * sin(pf * PI) * float(fleck[6])
			var fpos: Vector2 = start.lerp(dest, eased) + swirl
			var fa: float = minf(pf * 3.0, 1.0) * (1.0 - meld)
			var fcol: Color = _kind_color(int(fleck[8]))
			_hex_ring(fpos, float(fleck[7]) * (1.0 - 0.4 * eased), Color(fcol.r, fcol.g, fcol.b, fa * 0.85), 1.2)
	if meld > 0.0:
		var tc: Vector2 = text_rect.get_center()
		draw_set_transform(tc, 0.0, Vector2(1.0, 0.22))
		var rad: float = text_rect.size.x * 0.62
		for k in 6:
			draw_circle(Vector2.ZERO, rad * (0.35 + float(k) * 0.13), Color(tech.r, tech.g, tech.b, 0.025 * meld))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var uy: float = text_rect.end.y + 14.0
		var ulen: float = text_rect.size.x * 0.5 * (1.0 - pow(1.0 - meld, 3.0))
		draw_line(Vector2(tc.x - ulen, uy), Vector2(tc.x + ulen, uy), Color(nature.r, nature.g, nature.b, 0.55 * meld), 1.5)
		_hex_ring(Vector2(tc.x - ulen, uy), 5.0, Color(tech.r, tech.g, tech.b, 0.8 * meld), 1.2)
		_hex_ring(Vector2(tc.x + ulen, uy), 5.0, Color(tech.r, tech.g, tech.b, 0.8 * meld), 1.2)
