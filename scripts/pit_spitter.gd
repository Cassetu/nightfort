extends StaticBody3D

const BileSack = preload("res://scripts/enemies/bile_sack.gd")
const ChipBurst = preload("res://scripts/chip_burst.gd")

const MAX_HEALTH := 30
const RANGE := 52.0
const MIN_RANGE := 8.0
const COOLDOWN := 4.0
const FLIGHT := 1.3
const GRAVITY := 22.0
const BILE := Color(0.36, 0.2, 0.46)

static var pressure: float = 0.0

var health: int = MAX_HEALTH
var dying: bool = false
var timer: float = 0.0
var maw: MeshInstance3D
var swell: Tween


func _ready() -> void:
	collision_layer = 3
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("pit_spitter")
	timer = randf_range(1.0, COOLDOWN)
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.5, 0.16, 0.2)
	flesh.roughness = 0.4
	flesh.emission_enabled = true
	flesh.emission = Color(0.2, 0.03, 0.08)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 0.12, 0.4)
	glow.emission_enabled = true
	glow.emission = BILE
	glow.emission_energy_multiplier = 2.5
	var sack := SphereMesh.new()
	sack.radius = 1.3
	sack.height = 2.2
	sack.material = flesh
	var sack_node := MeshInstance3D.new()
	sack_node.mesh = sack
	sack_node.position = Vector3(0.0, 1.0, 0.0)
	add_child(sack_node)
	var mouth := SphereMesh.new()
	mouth.radius = 0.55
	mouth.height = 0.7
	mouth.material = glow
	maw = MeshInstance3D.new()
	maw.mesh = mouth
	maw.position = Vector3(0.0, 2.1, 0.0)
	add_child(maw)
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	cs.shape = sphere
	cs.position = Vector3(0.0, 1.0, 0.0)
	add_child(cs)


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


func _pick() -> Node3D:
	var best: Node3D = null
	var best_d := RANGE * RANGE
	var from := global_position
	for a in get_tree().get_nodes_in_group("ally_unit"):
		if not is_instance_valid(a):
			continue
		var d := from.distance_squared_to(a.global_position)
		if d < best_d and d > MIN_RANGE * MIN_RANGE:
			best_d = d
			best = a
	return best


func _lob(target: Node3D) -> void:
	var origin := global_position + Vector3(0.0, 2.7, 0.0)
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
	swell.tween_property(maw, "scale", Vector3.ONE * 1.5, 0.12)
	swell.tween_property(maw, "scale", Vector3.ONE, 0.25)
	BileSack.drop(self, origin, v)
