extends StaticBody3D

const BileSack = preload("res://scripts/enemies/bile_sack.gd")
const ChipBurst = preload("res://scripts/chip_burst.gd")
const TileArt = preload("res://scripts/tile_art.gd")
const ARCHER_SCENE = preload("res://scenes/archer.tscn")

const MAX_HEALTH := 30
const RANGE := 52.0
const MIN_RANGE := 8.0
const MERLON_RANGE := 1.35
const COOLDOWN := 4.0
const FLIGHT := 1.3
const GRAVITY := 22.0
const BILE := Color(0.36, 0.2, 0.46)
const FLESH := Color(0.55, 0.16, 0.2)
const RAG := Color(0.13, 0.1, 0.12)
const BODY_SCALE := Vector3(1.0, 1.22, 1.0)
const DRAW_ANGLE := -0.9
const RELEASE_ANGLE := -1.6

static var pressure: float = 0.0

var health: int = MAX_HEALTH
var dying: bool = false
var timer: float = 0.0
var maw: MeshInstance3D
var covered: bool = false
var model: Node3D
var arm_r: Node3D
var arm_l: Node3D
var turn: Tween
var swell: Tween


func _ready() -> void:
	collision_layer = 3
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("pit_spitter")
	timer = randf_range(1.0, COOLDOWN)
	_build_model()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 2.3
	cs.shape = cap
	cs.position = Vector3(0.0, 1.15, 0.0)
	add_child(cs)


func _flesh_material() -> StandardMaterial3D:
	return TileArt.uv_material("gloom_flesh", FLESH, Vector3.ONE, false)


func _rag_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = TileArt.block_material("rags", RAG).duplicate()
	m.albedo_color = Color(0.85, 0.8, 0.85)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.03, 0.01, 0.04)
	return m


func _glow_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = TileArt.block_material("bile", Color(0.3, 0.12, 0.4)).duplicate()
	m.emission_enabled = true
	m.emission = BILE
	m.emission_energy_multiplier = 2.5
	return m


func _mesh_of(node: Node, path: String) -> MeshInstance3D:
	return node.get_node_or_null(path) as MeshInstance3D


func _skin(node: Node, path: String, mat: Material) -> void:
	var mi := _mesh_of(node, path)
	if mi != null:
		mi.material_override = mat


func _shred(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


func _build_model() -> void:
	var flesh := _flesh_material()
	var rag := _rag_material()
	var glow := _glow_material()
	var body := Node3D.new()
	body.scale = BODY_SCALE
	body.rotation.x = 0.12
	add_child(body)
	model = ARCHER_SCENE.instantiate()
	body.add_child(model)
	_skin(model, "Body/Head", flesh)
	_skin(model, "Body/Chest", flesh)
	_skin(model, "LegR/Mesh", flesh)
	_skin(model, "LegL/Mesh", flesh)
	_skin(model, "ArmR/Mesh", flesh)
	_skin(model, "ArmL/Mesh", flesh)
	_skin(model, "Body/Tabard", rag)
	_skin(model, "Body/Hood", rag)
	_skin(model, "ArmL/Bow/Limb", TileArt.block_material("bone", Color(0.8, 0.76, 0.64)))
	_skin(model, "ArmL/Bow/String", glow)
	var tabard := _mesh_of(model, "Body/Tabard")
	if tabard != null:
		tabard.scale = Vector3(0.45, 0.8, 1.0)
		tabard.position = Vector3(0.12, 0.8, 0.0)
		tabard.rotation.z = 0.12
	var hood := _mesh_of(model, "Body/Hood")
	if hood != null:
		hood.scale = Vector3(0.8, 1.4, 1.1)
		hood.position = Vector3(-0.04, 1.86, 0.08)
		hood.rotation = Vector3(0.35, 0.0, -0.3)
	var head := _mesh_of(model, "Body/Head")
	if head != null:
		head.rotation = Vector3(0.0, 0.0, 0.32)
		head.position = Vector3(0.04, 1.7, 0.0)
		for side in [-1.0, 1.0]:
			_shred(head, Vector3(0.07, 0.04, 0.03), Vector3(side * 0.08, 0.02, -0.17), Vector3.ZERO, glow)
	var torso := model.get_node_or_null("Body") as Node3D
	if torso != null:
		_shred(torso, Vector3(0.62, 0.16, 0.36), Vector3(-0.04, 1.36, 0.0), Vector3(0.0, 0.0, 0.5), rag)
		_shred(torso, Vector3(0.16, 0.55, 0.34), Vector3(-0.24, 1.1, 0.0), Vector3(0.0, 0.0, -0.2), rag)
		_shred(torso, Vector3(0.1, 0.5, 0.03), Vector3(-0.1, 0.52, -0.16), Vector3(0.1, 0.0, 0.15), rag)
		_shred(torso, Vector3(0.09, 0.32, 0.03), Vector3(0.06, 0.58, -0.16), Vector3(-0.1, 0.0, -0.2), rag)
		_shred(torso, Vector3(0.12, 0.6, 0.03), Vector3(0.2, 0.46, -0.16), Vector3(0.05, 0.0, 0.1), rag)
		_shred(torso, Vector3(0.1, 0.42, 0.03), Vector3(-0.02, 0.48, 0.16), Vector3(-0.1, 0.0, 0.1), rag)
	var long_arm := _mesh_of(model, "ArmR/Mesh")
	if long_arm != null:
		long_arm.scale = Vector3(1.2, 1.5, 1.2)
		long_arm.position = Vector3(0.0, -0.42, 0.0)
	arm_r = model.get_node_or_null("ArmR")
	arm_l = model.get_node_or_null("ArmL")
	if arm_l != null:
		arm_l.rotation.x = -1.3
	if arm_r != null:
		arm_r.rotation.x = DRAW_ANGLE
	var bow := model.get_node_or_null("ArmL/Bow") as Node3D
	var globe := SphereMesh.new()
	globe.radius = 0.16
	globe.height = 0.32
	globe.material = glow
	maw = MeshInstance3D.new()
	maw.mesh = globe
	maw.position = Vector3(0.0, 0.0, 0.1)
	if bow != null:
		bow.add_child(maw)
	else:
		add_child(maw)


func take_damage(amount, from: Vector3 = Vector3.INF) -> void:
	if dying or amount <= 0:
		return
	health -= int(amount)
	ChipBurst.spawn(self, global_position + Vector3(0.0, 1.5, 0.0), "gloom_flesh", BILE, 6, 0.12, 0.5, 80.0, 2.0, 4.5, 10.0)
	if health <= 0:
		dying = true
		remove_from_group("enemy")
		remove_from_group("pit_spitter")
		ChipBurst.spawn(self, global_position + Vector3(0.0, 1.5, 0.0), "gloom_flesh", BILE, 22, 0.18, 1.0, 180.0, 3.0, 7.0, 14.0)
		queue_free()


func _physics_process(delta: float) -> void:
	if dying:
		return
	timer -= delta * (1.0 + pressure)
	if timer > 0.0:
		return
	var target := _pick()
	if target == null:
		timer = 0.5
		return
	timer = COOLDOWN
	_lob(target)


static var player_claim = null
static var player_claim_until: float = 0.0


func _pick() -> Node3D:
	var best: Node3D = null
	var reach := RANGE * (MERLON_RANGE if covered else 1.0)
	var best_d := reach * reach
	var from := global_position
	for a in get_tree().get_nodes_in_group("ally_unit"):
		if not is_instance_valid(a):
			continue
		var d := from.distance_squared_to(a.global_position)
		if d < best_d and d > MIN_RANGE * MIN_RANGE:
			best_d = d
			best = a
	var p = get_tree().get_first_node_in_group("player")
	if p != null and is_instance_valid(p) and not p.dead:
		var pd := from.distance_squared_to(p.global_position)
		var now := float(Time.get_ticks_msec()) / 1000.0
		var open: bool = player_claim == null or not is_instance_valid(player_claim) or player_claim == self or player_claim.dying or now > player_claim_until
		if open and pd < best_d and pd > MIN_RANGE * MIN_RANGE:
			best = p
			player_claim = self
			player_claim_until = now + COOLDOWN * 1.6
	return best


func _lob(target: Node3D) -> void:
	_face(target.global_position)
	var origin := maw.global_position + Vector3(0.0, 0.2, 0.0)
	var aim := target.global_position + Vector3(0.0, 0.5, 0.0)
	var lead := Vector3.ZERO
	if target is CharacterBody3D:
		lead = (target as CharacterBody3D).velocity * FLIGHT * 0.6
		lead.y = 0.0
	aim += lead
	var offset := aim - origin
	var v := Vector3(offset.x / FLIGHT, offset.y / FLIGHT + 0.5 * GRAVITY * FLIGHT, offset.z / FLIGHT)
	if swell != null:
		swell.kill()
	maw.scale = Vector3.ONE
	swell = create_tween()
	swell.tween_property(maw, "scale", Vector3.ONE * 2.2, 0.12)
	swell.parallel().tween_property(arm_r, "rotation:x", RELEASE_ANGLE, 0.12)
	swell.tween_property(maw, "scale", Vector3.ONE, 0.25)
	swell.parallel().tween_property(arm_r, "rotation:x", DRAW_ANGLE, 0.25)
	BileSack.drop(self, origin, v)


func _face(point: Vector3) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	var yaw := atan2(-to.x, -to.z)
	if turn != null:
		turn.kill()
	turn = create_tween()
	turn.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, yaw), 0.2)
