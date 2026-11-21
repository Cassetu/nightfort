extends CanvasLayer
const BlockIndex = preload("res://scripts/block_index.gd")

const RADIUS := 24
const TERRITORY_PAD := 4.0
const TERRITORY_OUTLINE := Color(0.45, 0.9, 0.88, 0.7)
const SMOOTH := 6.0
const SLACK := 8
const CELL := 4.0
const UPDATE := 0.4
const CELLS_PER_FRAME := 140
const CACHE_LIMIT := 24000
const EVICT_INTERVAL := 3.0
const EDGE := 6.0
const WATER_COLOR := Color(0.2, 0.4, 0.46)
const BACKDROP := Color(0.04, 0.04, 0.05, 1.0)
const GLOOM_COLOR := Color(0.68, 0.3, 0.95, 1.0)
const RAID_COLOR := Color(0.95, 0.2, 0.2, 1.0)
const UNDERGROUND_DEPTH := 3
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
var radius: int = RADIUS
var size_cells: int = RADIUS * 2 + 1
var view_center := Vector2.ZERO
var view_cell: float = CELL
var territory_mode: bool = false
var territory_node
var timer: float = 0.0
var heights := PackedInt32Array()
var cache_h: Dictionary = {}
var cache_c: Dictionary = {}
var incomplete: bool = false
var evict_timer: float = 0.0


func set_blank(on: bool) -> void:
	map.modulate.a = 0.0 if on else 1.0
	set_process(not on)


func setup(p, c, t) -> void:
	player = p
	core = c
	terrain = t
	view_center = Vector2(player.global_position.x, player.global_position.z)
	_ensure_size(RADIUS)
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.draw.connect(_on_draw)
	var frame := map.get_parent() as PanelContainer
	if frame != null:
		var box := frame.get_theme_stylebox("panel")
		if box is StyleBoxFlat:
			var flat := (box as StyleBoxFlat).duplicate() as StyleBoxFlat
			flat.content_margin_left = float(flat.border_width_left)
			flat.content_margin_right = float(flat.border_width_right)
			flat.content_margin_top = float(flat.border_width_top)
			flat.content_margin_bottom = float(flat.border_width_bottom)
			frame.add_theme_stylebox_override("panel", flat)
	terrain.block_broken.connect(_on_terrain_changed)
	_rebuild()


func _ensure_size(r: int) -> void:
	if image != null and r == radius:
		return
	radius = r
	size_cells = r * 2 + 1
	image = Image.create_empty(size_cells, size_cells, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	heights.resize(size_cells * size_cells)
	timer = UPDATE


func _update_view(delta: float) -> void:
	if territory_node == null or not is_instance_valid(territory_node):
		territory_node = get_tree().get_first_node_in_group("territory")
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var target_center := pp
	var target_cell := CELL
	var was_territory := territory_mode
	territory_mode = false
	if territory_node != null and is_instance_valid(core) and territory_node.contains(player.global_position):
		territory_mode = true
		var th: int = territory_node.half
		var span := float(th * 2 + 1) + TERRITORY_PAD * 2.0
		target_center = Vector2(float(territory_node.center_cell.x) + 0.5, float(territory_node.center_cell.y) + 0.5)
		target_cell = minf(map.size.x, map.size.y) / span
		_ensure_size(maxi(RADIUS, th + SLACK))
	elif radius != RADIUS and absf(view_cell - CELL) < 0.05:
		_ensure_size(RADIUS)
	if was_territory != territory_mode:
		timer = UPDATE
	var k := 1.0 - exp(-SMOOTH * delta)
	view_center = view_center.lerp(target_center, k)
	view_cell = lerpf(view_cell, target_cell, k)
	if view_center.distance_to(target_center) < 0.02:
		view_center = target_center
	if absf(view_cell - target_cell) < 0.01:
		view_cell = target_cell


func _process(delta: float) -> void:
	if player == null:
		return
	_update_view(delta)
	timer += delta
	if timer >= UPDATE or incomplete:
		timer = 0.0
		_rebuild()
	evict_timer += delta
	if evict_timer >= EVICT_INTERVAL:
		evict_timer = 0.0
		_evict()
	map.queue_redraw()


func _on_terrain_changed(cell: Vector3i) -> void:
	var key := Vector2i(cell.x, cell.z)
	cache_h.erase(key)
	cache_c.erase(key)


func _evict() -> void:
	if cache_h.size() <= CACHE_LIMIT:
		return
	var pc := Vector2i(floori(player.global_position.x), floori(player.global_position.z))
	for key: Vector2i in cache_h.keys():
		if absi(key.x - pc.x) > radius + 12 or absi(key.y - pc.y) > radius + 12:
			cache_h.erase(key)
			cache_c.erase(key)


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
	var vc := Vector2i(floori(view_center.x), floori(view_center.y))
	origin = vc - Vector2i(radius, radius)
	var pkey := Vector2i(pc.x, pc.y)
	var ph: int
	if cache_h.has(pkey):
		ph = cache_h[pkey]
	else:
		ph = terrain.surface_y(pc.x, pc.y)
	var budget := CELLS_PER_FRAME
	incomplete = false
	for j in size_cells:
		for i in size_cells:
			var key := Vector2i(origin.x + i, origin.y + j)
			var idx := j * size_cells + i
			if cache_h.has(key):
				var h: int = cache_h[key]
				heights[idx] = h
				image.set_pixel(i, j, _shade(cache_c[key], h - ph))
			elif budget > 0:
				budget -= 1
				var h: int = terrain.surface_y(key.x, key.y)
				var id: int = terrain.block_at(key.x, h - 1, key.y)
				var col := _terrain_color(id)
				if h < terrain.water_level:
					col = WATER_COLOR
				cache_h[key] = h
				cache_c[key] = col
				heights[idx] = h
				image.set_pixel(i, j, _shade(col, h - ph))
			else:
				incomplete = true
				heights[idx] = ph
				image.set_pixel(i, j, BACKDROP)
	var px := float(vc.x)
	var pz := float(vc.y)
	for n in BlockIndex.list:
		if n.dying:
			continue
		if absf(n.global_position.x - px) > float(radius) + 3.0 or absf(n.global_position.z - pz) > float(radius) + 3.0:
			continue
		var info: Dictionary = Inventory.BLOCK_TYPES.get(n.block_type, {})
		var base: Color = info.get("color", Color(0.6, 0.6, 0.6))
		var tile := base.lightened(0.12)
		for c: Vector3i in n.cells():
			var i := c.x - origin.x
			var j := c.z - origin.y
			if i < 0 or j < 0 or i >= size_cells or j >= size_cells:
				continue
			var top := c.y + 1
			if top >= heights[j * size_cells + i]:
				heights[j * size_cells + i] = top
				image.set_pixel(i, j, _shade(tile, top - ph))
	texture.update(image)


func _underground(pos: Vector3) -> bool:
	var key := Vector2i(floori(pos.x), floori(pos.z))
	var surface: int
	if cache_h.has(key):
		surface = cache_h[key]
	else:
		surface = terrain.surface_y(key.x, key.y)
	return pos.y < float(surface - UNDERGROUND_DEPTH)


func _to_map(world: Vector3, pp: Vector2, center: Vector2) -> Vector2:
	return center + (Vector2(world.x, world.z) - pp) * view_cell


func _on_draw() -> void:
	if player == null or texture == null:
		return
	var size := map.size
	var center := size * 0.5
	var pp := view_center
	map.draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	map.draw_texture_rect(texture, Rect2(center + (Vector2(origin) - pp) * view_cell, Vector2(size_cells, size_cells) * view_cell), false)
	if territory_mode and territory_node != null:
		var th: float = float(territory_node.half) + 0.5
		var tc := Vector2(float(territory_node.center_cell.x) + 0.5, float(territory_node.center_cell.y) + 0.5)
		var corner := center + (tc - Vector2(th, th) - pp) * view_cell
		map.draw_rect(Rect2(corner, Vector2(th, th) * 2.0 * view_cell), TERRITORY_OUTLINE, false, 1.5)
	var arrow_at := _to_map(player.global_position, pp, center)

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

	for group in ["wild_gloom", "enemy"]:
		var tint := RAID_COLOR if group == "enemy" else GLOOM_COLOR
		for g in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(g) or g.dying:
				continue
			var gv := _to_map(g.global_position, pp, center)
			if absf(gv.x - center.x) > limit.x or absf(gv.y - center.y) > limit.y:
				continue
			if _underground(g.global_position):
				continue
			map.draw_circle(gv, 4.0, OUTLINE)
			map.draw_circle(gv, 3.0, tint)

	var forward: Vector3 = -player.global_transform.basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	if dir.length() < 0.01:
		dir = Vector2(0.0, -1.0)
	var side := Vector2(-dir.y, dir.x)
	var tip := arrow_at + dir * 11.0
	var left := arrow_at - dir * 6.0 + side * 5.0
	var right := arrow_at - dir * 6.0 - side * 5.0
	var notch := arrow_at - dir * 2.5
	var arrow := PackedVector2Array([tip, right, notch, left])
	var shell := PackedVector2Array([tip + dir * 1.5, right - dir * 1.0 - side * 1.2, notch - dir * 0.6, left - dir * 1.0 + side * 1.2])
	map.draw_colored_polygon(shell, OUTLINE)
	map.draw_colored_polygon(arrow, PLAYER_COLOR)
