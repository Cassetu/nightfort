extends Node3D

const SPEED := 34.0
const GRAVITY := 4.0
const LIFE := 2.5
const HIT_MASK := 3

var velocity := Vector3.ZERO
var damage: int = 2
var age: float = 0.0
var ignore: Array = []


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.6, 0.45)
	mat.roughness = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, 0.5)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func launch(from: Vector3, dir: Vector3, dmg: int, speed: float = SPEED) -> void:
	global_position = from
	velocity = dir.normalized() * speed
	damage = dmg
	if velocity.length() > 0.1:
		look_at(from + velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	age += delta
	if age > LIFE:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	query.exclude = ignore
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target = hit["collider"]
		if target.is_in_group("enemy") or target.is_in_group("wild_gloom"):
			target.take_damage(damage, from - velocity.normalized() * 2.0)
		queue_free()
		return
	global_position = to
	velocity.y -= GRAVITY * delta
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)
