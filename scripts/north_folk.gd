extends Node3D

const AllySkin = preload("res://scripts/ally_skin.gd")
const ARCHER := preload("res://scenes/archer.tscn")
const SOLDIER := preload("res://scenes/soldier.tscn")
const WALK_SPEED := 1.3
const SWING := 0.55

var walker: bool = false
var rects: Array = []
var lo: Vector2 = Vector2.ZERO
var hi: Vector2 = Vector2.ZERO
var floor_y: float = 0.0
var model: Node3D
var arm_r: Node3D
var arm_l: Node3D
var leg_r: Node3D
var leg_l: Node3D
var body: Node3D
var time: float = 0.0
var target: Vector3 = Vector3.ZERO
var wait: float = 0.0
var moving: bool = false
var look_timer: float = 0.0
var look_yaw: float = 0.0
var base_yaw: float = 0.0
var ring_center: Vector2 = Vector2.ZERO
var ring_lo: float = 0.0
var ring_hi: float = 0.0


func setup(kind: String, ground: float, facing: Vector3, wander: bool, blocked: Array, area_lo: Vector2, area_hi: Vector2) -> void:
	walker = wander
	rects = blocked
	lo = area_lo
	hi = area_hi
	floor_y = ground
	var scene: PackedScene = SOLDIER if kind == "soldier" else ARCHER
	model = scene.instantiate()
	add_child(model)
	arm_r = model.get_node_or_null("ArmR")
	arm_l = model.get_node_or_null("ArmL")
	leg_r = model.get_node_or_null("LegR")
	leg_l = model.get_node_or_null("LegL")
	body = model.get_node_or_null("Body")
	AllySkin.apply(model)
	var pick := model.get_node_or_null("ArmR/Pick")
	if pick != null:
		pick.visible = false
	if wander:
		var bow := model.get_node_or_null("ArmL/Bow")
		if bow != null:
			bow.visible = false
		var hood := model.get_node_or_null("Body/Hood")
		if hood != null:
			hood.visible = randf() < 0.5
		model.scale = Vector3.ONE * randf_range(0.88, 1.04)
	time = randf() * 10.0
	if facing.length() > 0.01:
		base_yaw = atan2(-facing.x, -facing.z)
		rotation.y = base_yaw
	wait = randf_range(0.5, 6.0)
	position.y = ground


func set_ring(center: Vector2, inner: float, outer: float) -> void:
	ring_center = center
	ring_lo = inner
	ring_hi = outer


func _process(delta: float) -> void:
	time += delta
	if walker:
		_wander(delta)
	else:
		_guard(delta)
	var swing := 0.0
	if moving:
		swing = sin(time * 7.0) * SWING
	if leg_r != null:
		leg_r.rotation.x = swing
	if leg_l != null:
		leg_l.rotation.x = -swing
	if arm_r != null:
		arm_r.rotation.x = -swing * 0.7
	if arm_l != null and walker:
		arm_l.rotation.x = swing * 0.7
	if body != null:
		body.position.y = absf(sin(time * 7.0)) * 0.03 if moving else sin(time * 1.4) * 0.008


func _guard(delta: float) -> void:
	look_timer -= delta
	if look_timer <= 0.0:
		look_timer = randf_range(3.0, 9.0)
		look_yaw = randf_range(-0.9, 0.9)
	rotation.y = lerp_angle(rotation.y, base_yaw + look_yaw, minf(delta * 1.2, 1.0))


func _wander(delta: float) -> void:
	if not moving:
		wait -= delta
		if wait > 0.0:
			return
		_pick_target()
		return
	var flat := Vector3(target.x - position.x, 0.0, target.z - position.z)
	if flat.length() < 0.3:
		moving = false
		wait = randf_range(2.0, 9.0)
		return
	var step := flat.normalized() * WALK_SPEED * delta
	position += step
	position.y = floor_y
	rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(delta * 5.0, 1.0))


func _pick_target() -> void:
	for attempt in 10:
		var p := Vector3(randf_range(lo.x, hi.x), floor_y, randf_range(lo.y, hi.y))
		if ring_hi > 0.0:
			var ang := randf() * TAU
			var rad := randf_range(ring_lo, ring_hi)
			p = Vector3(ring_center.x + cos(ang) * rad, floor_y, ring_center.y + sin(ang) * rad)
		if _blocked(p) or not _path_clear(position, p):
			continue
		target = p
		moving = true
		return
	wait = 1.5


func _blocked(p: Vector3) -> bool:
	if ring_hi > 0.0:
		var d := Vector2(p.x, p.z).distance_to(ring_center)
		if d < ring_lo or d > ring_hi:
			return true
	for r: Rect2 in rects:
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false


func _path_clear(a: Vector3, b: Vector3) -> bool:
	for i in 12:
		var t := float(i) / 11.0
		if _blocked(a.lerp(b, t)):
			return false
	return true
