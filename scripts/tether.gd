extends "res://scripts/blocks/block.gd"

const TetherRope = preload("res://scripts/tether_rope.gd")

const POLE_HEIGHT := 0.8
const STAKE_WIDTH := 0.09
const RING_LOCAL := Vector3(0.0, 0.1, 0.085)
const GEM_LOCAL := Vector3(0.0, 0.345, 0.0)
const HIP_BACK := 0.2
const CHECK_INTERVAL := 0.08
const CRUMB_STEP := 0.12
const MAX_TRAIL := 96
const MAX_PIVOTS := 64
const SEARCH_STEPS := 7
const MERGE_DISTANCE := 0.05
const SLIDE_MIN := 0.05
const IDLE_DISTANCE := 0.02
const MAX_LENGTH := 96.0
const WARN_LENGTH := 80.0
const WARN_RESET := 70.0

var hooked: bool = false
var wearer: CharacterBody3D
var pivots: PackedVector3Array = PackedVector3Array()
var trail: PackedVector3Array = PackedVector3Array()
var ignore: Array[RID] = []
var rope
var clock: float = 0.0
var last_checked: Vector3 = Vector3.INF
var warned: bool = false


func _init() -> void:
	block_type = "tether"


func _configure() -> void:
	super()
	add_to_group("tether")
	needs_support = true


func _build() -> void:
	var wood: StandardMaterial3D = TileArt.uv_material("plank", Color(0.42, 0.33, 0.22), Vector3.ONE).duplicate() as StandardMaterial3D
	wood.albedo_color = Color(0.6, 0.55, 0.5)
	var stone: StandardMaterial3D = TileArt.uv_material("stone", Color(0.5, 0.5, 0.52), Vector3.ONE).duplicate() as StandardMaterial3D
	stone.albedo_color = Color(0.7, 0.7, 0.74)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.5, 0.52, 0.56)
	iron.metallic = 0.7
	iron.roughness = 0.45
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.12, 0.3, 0.16)
	glow.emission_enabled = true
	glow.emission = Color(0.42, 1.0, 0.58)
	glow.emission_energy_multiplier = 2.6

	var collar := MeshInstance3D.new()
	collar.mesh = TileArt.box_mesh(Vector3(0.26, 0.05, 0.26), stone)
	collar.position = Vector3(0.0, -0.475, 0.0)
	visual.add_child(collar)

	var stake := MeshInstance3D.new()
	stake.mesh = TileArt.box_mesh(Vector3(STAKE_WIDTH, 0.71, STAKE_WIDTH), wood)
	stake.position = Vector3(0.0, -0.095, 0.0)
	visual.add_child(stake)

	var cap := MeshInstance3D.new()
	cap.mesh = TileArt.box_mesh(Vector3(0.14, 0.04, 0.14), iron)
	cap.position = Vector3(0.0, 0.28, 0.0)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(cap)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.028
	ring_mesh.outer_radius = 0.045
	ring_mesh.rings = 14
	ring_mesh.ring_segments = 6
	ring_mesh.material = iron
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.position = RING_LOCAL
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(ring)

	var gem_mesh := BoxMesh.new()
	gem_mesh.size = Vector3(0.07, 0.07, 0.07)
	gem_mesh.material = glow
	var gem := MeshInstance3D.new()
	gem.mesh = gem_mesh
	gem.position = GEM_LOCAL
	gem.rotation_degrees = Vector3(45.0, 45.0, 0.0)
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(gem)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.45, 1.0, 0.62)
	lamp.light_energy = 0.45
	lamp.light_specular = 0.0
	lamp.omni_range = 4.5
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = false
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 24.0
	lamp.distance_fade_length = 8.0
	lamp.position = GEM_LOCAL
	add_child(lamp)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.26, POLE_HEIGHT, 0.26)
	col.shape = box
	col.position = Vector3(0.0, -0.1, 0.0)
	add_child(col)

	rope = TetherRope.new()
	rope.pole = self
	add_child(rope)


func ring_point() -> Vector3:
	return global_transform * RING_LOCAL


func _body_point(who: Node3D) -> Vector3:
	return who.global_position


func _hip_point(who: Node3D) -> Vector3:
	return who.global_position + who.global_transform.basis.z * HIP_BACK


func hook(who: CharacterBody3D) -> void:
	wearer = who
	hooked = true
	warned = false
	clock = 0.0
	last_checked = Vector3.INF
	ignore = [get_rid(), who.get_rid()]
	pivots = PackedVector3Array()
	trail = PackedVector3Array([_body_point(who)])


func unhook() -> void:
	hooked = false
	wearer = null
	pivots = PackedVector3Array()
	trail = PackedVector3Array()


func toggle(who: CharacterBody3D) -> String:
	if dying:
		return ""
	if hooked and wearer == who:
		unhook()
		return "Unhooked"
	hook(who)
	return "Hooked"


func rope_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.append(ring_point())
	out.append_array(pivots)
	if is_instance_valid(wearer):
		out.append(_hip_point(wearer))
	return out


func rope_length() -> float:
	var pts: PackedVector3Array = rope_points()
	var total: float = 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


func export_rope() -> Dictionary:
	var list: Array = []
	for p in pivots:
		list.append([p.x, p.y, p.z])
	return {"on": hooked, "pivots": list}


func import_rope(d: Dictionary) -> void:
	if not bool(d.get("on", false)):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	hook(player)
	for p in d.get("pivots", []):
		pivots.append(Vector3(float(p[0]), float(p[1]), float(p[2])))


func _play_death() -> void:
	unhook()
	super()


func _physics_process(delta: float) -> void:
	if not hooked:
		return
	if dying or not is_instance_valid(wearer) or wearer.get("dead") == true:
		unhook()
		return
	var here: Vector3 = _body_point(wearer)
	if trail.is_empty():
		trail = PackedVector3Array([here])
	if here.distance_squared_to(trail[trail.size() - 1]) >= CRUMB_STEP * CRUMB_STEP:
		trail.append(here)
		if trail.size() > MAX_TRAIL:
			trail = trail.slice(trail.size() - MAX_TRAIL)
	clock += delta
	if clock < CHECK_INTERVAL:
		return
	clock = 0.0
	if here.distance_squared_to(last_checked) < IDLE_DISTANCE * IDLE_DISTANCE:
		return
	last_checked = here
	_tighten(here)
	_watch_length()


func _tail() -> Vector3:
	if pivots.is_empty():
		return ring_point()
	return pivots[pivots.size() - 1]


func _before_tail() -> Vector3:
	if pivots.size() < 2:
		return ring_point()
	return pivots[pivots.size() - 2]


func _tighten(here: Vector3) -> void:
	while not pivots.is_empty():
		if not _clear(_before_tail(), here):
			break
		pivots.remove_at(pivots.size() - 1)
		trail = PackedVector3Array([here])

	var anchor: Vector3 = _tail()
	if _clear(anchor, here):
		if not pivots.is_empty():
			_relax(pivots.size() - 1, here)
		trail = PackedVector3Array([here])
		return

	var pts: PackedVector3Array = trail.duplicate()
	pts.append(here)
	var guard: int = 0
	while guard < 6 and not _clear(anchor, here):
		guard += 1
		var k: int = 1
		while k < pts.size() and _clear(anchor, pts[k]):
			k += 1
		if k >= pts.size():
			break
		var lo: Vector3 = pts[k - 1]
		var hi: Vector3 = pts[k]
		for i in SEARCH_STEPS:
			var mid: Vector3 = lo.lerp(hi, 0.5)
			if _clear(anchor, mid):
				lo = mid
			else:
				hi = mid
		if not pivots.is_empty() and lo.distance_to(anchor) < MERGE_DISTANCE:
			break
		if pivots.size() >= MAX_PIVOTS:
			_snap()
			return
		pivots.append(lo)
		anchor = lo
		var rest := PackedVector3Array([lo])
		for j in range(k, pts.size()):
			rest.append(pts[j])
		pts = rest

	for i in range(maxi(0, pivots.size() - 2), pivots.size()):
		_relax(i, here)
	if _clear(_tail(), here):
		trail = PackedVector3Array([here])
	else:
		trail = pts


func _relax(index: int, here: Vector3) -> void:
	var prev: Vector3 = ring_point() if index < 1 else pivots[index - 1]
	var next: Vector3 = here if index + 1 >= pivots.size() else pivots[index + 1]
	var current: Vector3 = pivots[index]
	var best: Vector3 = current
	var best_length: float = prev.distance_to(current) + current.distance_to(next)
	for side in 2:
		var target: Vector3 = prev if side == 0 else next
		var other: Vector3 = next if side == 0 else prev
		if current.distance_to(target) < SLIDE_MIN:
			continue
		var lo: float = 0.0
		var hi: float = 1.0
		for i in SEARCH_STEPS:
			var mid: float = (lo + hi) * 0.5
			if _clear(current.lerp(target, mid), other):
				lo = mid
			else:
				hi = mid
		var moved: Vector3 = current.lerp(target, lo)
		var moved_length: float = prev.distance_to(moved) + moved.distance_to(next)
		if moved_length < best_length - 0.000001:
			best = moved
			best_length = moved_length
	pivots[index] = best


func _watch_length() -> void:
	var length: float = rope_length()
	if length >= MAX_LENGTH:
		_snap()
	elif length >= WARN_LENGTH and not warned:
		warned = true
		_notify("Rope Taut")
	elif length < WARN_RESET:
		warned = false


func _snap() -> void:
	_notify("Rope Snapped")
	unhook()


func _notify(text: String) -> void:
	if is_instance_valid(wearer) and wearer.has_signal("notice"):
		wearer.emit_signal("notice", text)


func _clear(a: Vector3, b: Vector3) -> bool:
	if a.distance_squared_to(b) < 0.0001:
		return true
	return _ray(a, b)


func _ray(a: Vector3, b: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var skip: Array[RID] = []
	skip.append_array(ignore)
	for i in 4:
		var query := PhysicsRayQueryParameters3D.create(a, b, 1)
		query.exclude = skip
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return true
		if _stops_rope(hit["collider"]):
			return false
		skip.append(hit["rid"])
	return false


func _stops_rope(body: Object) -> bool:
	var node := body as Node
	if node == null:
		return false
	if node.is_in_group("tether") or node.is_in_group("torch"):
		return false
	if node.is_in_group("door") and node.get("is_open") == true:
		return false
	return node.is_in_group("terrain_body") or node.is_in_group("resource")
