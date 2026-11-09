extends StaticBody3D

const BileSack = preload("res://scripts/bile_sack.gd")
const TileArt = preload("res://scripts/tile_art.gd")

const SPEED := 9.0
const DIVE_SPEED := 22.0
const DIVE_TRIGGER := 5.0
const HEALTH := 3
const FLAP_RATE := 1.6
const IMPACT_RADIUS := 4.0
const IMPACT_BLOCK := 8
const IMPACT_UNIT := 10
const IMPACT_PLAYER := 12
const IMPACT_CORE := 18
const BILE := Color(0.38, 0.2, 0.48)

static var flesh_material: StandardMaterial3D
static var wing_material: StandardMaterial3D
static var eye_material: StandardMaterial3D
static var sack_material: StandardMaterial3D

var core
var health: int = HEALTH
var dying: bool = false
var diving: bool = false
var age: float = 0.0
var fall_speed: float = 0.0
var fall_time: float = 0.0
var leaving: bool = false
var heading := Vector3.FORWARD
var wing_l: Node3D
var wing_r: Node3D
var tip_l: Node3D
var tip_r: Node3D
var sack: MeshInstance3D


func setup(target_core) -> void:
	core = target_core


static func _ensure_materials() -> void:
	if flesh_material != null:
		return
	flesh_material = TileArt.uv_material("gloom_flesh", Color(0.2, 0.08, 0.11), Vector3.ONE)
	wing_material = StandardMaterial3D.new()
	wing_material.albedo_color = Color(0.11, 0.05, 0.09)
	wing_material.roughness = 0.9
	wing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	eye_material = StandardMaterial3D.new()
	eye_material.albedo_color = Color(0.1, 0.0, 0.0)
	eye_material.emission_enabled = true
	eye_material.emission = Color(0.9, 0.2, 0.5)
	eye_material.emission_energy_multiplier = 1.6
	sack_material = StandardMaterial3D.new()
	sack_material.albedo_color = Color(0.22, 0.1, 0.28)
	sack_material.emission_enabled = true
	sack_material.emission = BILE
	sack_material.emission_energy_multiplier = 0.8
	sack_material.roughness = 0.25


func _ready() -> void:
	_ensure_materials()
	add_to_group("gloom_bird")
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	shape.shape = sphere
	add_child(shape)
	_build()
	scale = Vector3.ONE * 1.35


func _part(mesh: Mesh, parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build() -> void:
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	body.radial_segments = 10
	body.rings = 5
	body.material = flesh_material
	var torso := _part(body, self, Vector3.ZERO)
	torso.scale = Vector3(0.7, 0.55, 1.2)

	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	head.radial_segments = 8
	head.rings = 4
	head.material = flesh_material
	_part(head, self, Vector3(0.0, 0.08, -0.62))

	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.09
	beak.height = 0.34
	beak.radial_segments = 6
	beak.rings = 1
	beak.material = wing_material
	_part(beak, self, Vector3(0.0, 0.04, -0.9), Vector3(-PI * 0.5, 0.0, 0.0))

	var eye := SphereMesh.new()
	eye.radius = 0.04
	eye.height = 0.08
	eye.radial_segments = 6
	eye.rings = 3
	eye.material = eye_material
	_part(eye, self, Vector3(-0.1, 0.14, -0.74))
	_part(eye, self, Vector3(0.1, 0.14, -0.74))

	var tail := PrismMesh.new()
	tail.size = Vector3(0.45, 0.7, 0.04)
	tail.material = wing_material
	_part(tail, self, Vector3(0.0, 0.0, 0.95), Vector3(PI * 0.5, 0.0, 0.0))

	var arm := BoxMesh.new()
	arm.size = Vector3(1.3, 0.05, 0.55)
	arm.material = wing_material
	var tip := BoxMesh.new()
	tip.size = Vector3(1.0, 0.04, 0.4)
	tip.material = wing_material
	var bone := BoxMesh.new()
	bone.size = Vector3(1.3, 0.07, 0.07)
	bone.material = flesh_material

	wing_l = Node3D.new()
	wing_l.position = Vector3(-0.28, 0.1, -0.05)
	add_child(wing_l)
	_part(arm, wing_l, Vector3(-0.65, 0.0, 0.1))
	_part(bone, wing_l, Vector3(-0.65, 0.03, -0.14))
	tip_l = Node3D.new()
	tip_l.position = Vector3(-1.3, 0.0, 0.0)
	wing_l.add_child(tip_l)
	_part(tip, tip_l, Vector3(-0.5, 0.0, 0.18))

	wing_r = Node3D.new()
	wing_r.position = Vector3(0.28, 0.1, -0.05)
	add_child(wing_r)
	_part(arm, wing_r, Vector3(0.65, 0.0, 0.1))
	_part(bone, wing_r, Vector3(0.65, 0.03, -0.14))
	tip_r = Node3D.new()
	tip_r.position = Vector3(1.3, 0.0, 0.0)
	wing_r.add_child(tip_r)
	_part(tip, tip_r, Vector3(0.5, 0.0, 0.18))

	var bag := SphereMesh.new()
	bag.radius = 0.32
	bag.height = 0.64
	bag.radial_segments = 10
	bag.rings = 5
	bag.material = sack_material
	sack = _part(bag, self, Vector3(0.0, -0.55, 0.05))
	sack.scale = Vector3(1.0, 1.15, 1.0)

	var cord := CylinderMesh.new()
	cord.top_radius = 0.04
	cord.bottom_radius = 0.07
	cord.height = 0.3
	cord.radial_segments = 5
	cord.rings = 1
	cord.material = flesh_material
	_part(cord, self, Vector3(0.0, -0.3, 0.05))


func _animate(delta: float) -> void:
	age += delta
	var flap := sin(age * TAU * FLAP_RATE * (2.0 if diving else 1.0))
	wing_l.rotation.z = -flap * 0.55
	wing_r.rotation.z = flap * 0.55
	tip_l.rotation.z = -flap * 0.35
	tip_r.rotation.z = flap * 0.35
	if sack != null:
		sack.position.y = -0.55 - 0.03 * sin(age * 3.1)


func _physics_process(delta: float) -> void:
	if dying:
		_fall(delta)
		return
	if core == null or not is_instance_valid(core):
		core = get_tree().get_first_node_in_group("Core")
		if core == null:
			return
	_animate(delta)
	var c: Vector3 = core.global_position
	var flat := Vector2(c.x - global_position.x, c.z - global_position.z).length()
	if not diving and flat < DIVE_TRIGGER:
		diving = true
	var target := c + Vector3(0.0, 1.8, 0.0)
	if not diving:
		target.y = global_position.y
	var to_target := target - global_position
	if diving and to_target.length() < 1.8:
		_impact(target)
		return
	heading = heading.lerp(to_target.normalized(), clampf(delta * 3.0, 0.0, 1.0)).normalized()
	global_position += heading * (DIVE_SPEED if diving else SPEED) * delta
	if not diving:
		global_position.y += sin(age * 1.7) * 0.4 * delta
	if absf(heading.y) < 0.97:
		look_at(global_position + heading, Vector3.UP)


func _impact(pos: Vector3) -> void:
	dying = true
	collision_layer = 0
	BileSack.splash(self, pos, IMPACT_RADIUS, IMPACT_BLOCK, IMPACT_UNIT, IMPACT_PLAYER, IMPACT_CORE)
	var ChipBurst = load("res://scripts/chip_burst.gd")
	ChipBurst.spawn(self, pos, "", BILE, 18, 0.16, 0.9, 85.0, 3.0, 6.0, 12.0)
	queue_free()


func take_damage(amount, _from = Vector3.INF) -> void:
	if dying or amount <= 0:
		return
	health -= int(amount)
	if health > 0:
		return
	dying = true
	collision_layer = 0
	if sack != null:
		sack.visible = false
	BileSack.drop(self, global_position + Vector3(0.0, -0.8, 0.0), heading * 2.0)
	fall_speed = 0.0


func dissolve() -> void:
	if dying:
		return
	dying = true
	leaving = true
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 1.0)
	tween.tween_callback(queue_free)


func _fall(delta: float) -> void:
	if leaving:
		return
	fall_speed += 20.0 * delta
	global_position += Vector3(heading.x, 0.0, heading.z) * 2.0 * delta + Vector3(0.0, -fall_speed * delta, 0.0)
	rotate_z(delta * 6.0)
	fall_time += delta
	if fall_time > 3.0 or global_position.y < -70.0:
		queue_free()
