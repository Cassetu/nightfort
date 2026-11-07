extends CanvasLayer

const RADIUS := 20
const SIZE := RADIUS * 2 + 1
const CELL := 4.0
const UPDATE := 0.35
const EDGE := 6.0
const BACKDROP := Color(0.04, 0.04, 0.05, 1.0)
const GLOOM_COLOR := Color(0.68, 0.3, 0.95, 1.0)
const TROOP_COLOR := Color(0.35, 0.62, 1.0, 1.0)
const CORE_COLOR := Color(0.3, 0.78, 1.0, 1.0)
const PLAYER_COLOR := Color(1.0, 0.86, 0.2, 1.0)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.85)

@onready var map: Control = %Map

var player
var core
var terrain
var image: Image
var texture: ImageTexture
var origin := Vector2i.ZERO
var timer: float = 0.0
var heights := PackedInt32Array()


func setup(p, c, t) -> void:
	player = p
	core = c
	terrain = t
	image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	heights.resize(SIZE * SIZE)
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.draw.connect(_on_draw)
	_rebuild()


func _process(delta: float) -> void:
	if player == null:
		return
	timer += delta
	if timer >= UPDATE:
		timer = 0.0
		_rebuild()
	map.queue_redraw()


func _terrain_color(id: int) -> Color:
	if id == terrain.B_GRASS:
		return Color(0.26, 0.38, 0.2)
	if id == terrain.B_DIRT:
		return terrain.COL_DIRT
	if id == terrain.B_STONE:
		return terrain.COL_STONE
	if id == terrain.B_SAND:
		return terrain.COL_SAND.darkened(0.15)
	if id == terrain.B_SNOW:
		return terrain.COL_SNOW.darkened(0.1)
	if id == terrain.B_BEDROCK:
		return terrain.COL_BEDROCK
	if id == terrain.B_COAL:
		return terrain.COL_COAL
	if id == terrain.B_BRICK:
		return Color(0.42, 0.42, 0.46)
	return Color(0.4, 0.4, 0.42)


func _shade(c: Color, rise: int) -> Color:
	var k := clampf(1.0 + float(rise) * 0.04, 0.65, 1.3)
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


func _rebuild() -> void:
	var pc := Vector2i(floori(player.global_position.x), floori(player.global_position.z))
	origin = pc - Vector2i(RADIUS, RADIUS)
	var ph: int = terrain.surface_y(pc.x, pc.y)
	for j in SIZE:
		for i in SIZE:
			var x := origin.x + i
			var z := origin.y + j
			var h: int = terrain.surface_y(x, z)
			var id: int = terrain.block_at(x, h - 1, z)
			heights[j * SIZE + i] = h
			image.set_pixel(i, j, _shade(_terrain_color(id), h - ph))
	for n in get_tree().get_nodes_in_group("block"):
		if n.dying:
			continue
		var info: Dictionary = Inventory.BLOCK_TYPES.get(n.block_type, {})
		var base: Color = info.get("color", Color(0.6, 0.6, 0.6))
		var tile := base.lightened(0.12)
		for c: Vector3i in n.cells():
			var i := c.x - origin.x
			var j := c.z - origin.y
			if i < 0 or j < 0 or i >= SIZE or j >= SIZE:
				continue
			var top := c.y + 1
			if top >= heights[j * SIZE + i]:
				heights[j * SIZE + i] = top
				image.set_pixel(i, j, _shade(tile, top - ph))
	texture.update(image)


func _to_map(world: Vector3, pp: Vector2, center: Vector2) -> Vector2:
	return center + (Vector2(world.x, world.z) - pp) * CELL


func _on_draw() -> void:
	if player == null or texture == null:
		return
	var size := map.size
	var center := size * 0.5
	var pp := Vector2(player.global_position.x, player.global_position.z)
	map.draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	map.draw_texture_rect(texture, Rect2(center + (Vector2(origin) - pp) * CELL, Vector2(SIZE, SIZE) * CELL), false)

	var limit := size * 0.5 - Vector2(EDGE, EDGE)
	if is_instance_valid(core):
		var v := _to_map(core.global_position, pp, center) - center
		if absf(v.x) > limit.x or absf(v.y) > limit.y:
			v *= minf(limit.x / maxf(absf(v.x), 0.001), limit.y / maxf(absf(v.y), 0.001))
		map.draw_circle(center + v, 6.0, OUTLINE)
		map.draw_circle(center + v, 4.5, CORE_COLOR)

	for troop in get_tree().get_nodes_in_group("troop"):
		if not is_instance_valid(troop):
			continue
		var tv := _to_map(troop.global_position, pp, center)
		if absf(tv.x - center.x) > limit.x or absf(tv.y - center.y) > limit.y:
			continue
		var tri := PackedVector2Array([tv + Vector2(0.0, -6.0), tv + Vector2(5.0, 4.0), tv + Vector2(-5.0, 4.0)])
		map.draw_colored_polygon(tri, TROOP_COLOR)
		var ring := PackedVector2Array([tri[0], tri[1], tri[2], tri[0]])
		map.draw_polyline(ring, OUTLINE, 1.0)

	for group in ["enemy", "wild_gloom"]:
		for g in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(g) or g.dying:
				continue
			var gv := _to_map(g.global_position, pp, center)
			if absf(gv.x - center.x) > limit.x or absf(gv.y - center.y) > limit.y:
				continue
			map.draw_circle(gv, 4.0, OUTLINE)
			map.draw_circle(gv, 3.0, GLOOM_COLOR)

	var forward: Vector3 = -player.global_transform.basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	if dir.length() < 0.01:
		dir = Vector2(0.0, -1.0)
	var side := Vector2(-dir.y, dir.x)
	var tip := center + dir * 11.0
	var left := center - dir * 6.0 + side * 5.0
	var right := center - dir * 6.0 - side * 5.0
	var notch := center - dir * 2.5
	var arrow := PackedVector2Array([tip, right, notch, left])
	var shell := PackedVector2Array([tip + dir * 1.5, right - dir * 1.0 - side * 1.2, notch - dir * 0.6, left - dir * 1.0 + side * 1.2])
	map.draw_colored_polygon(shell, OUTLINE)
	map.draw_colored_polygon(arrow, PLAYER_COLOR)
