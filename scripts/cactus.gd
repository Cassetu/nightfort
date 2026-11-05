extends "res://scripts/resource_node.gd"

const TileArt = preload("res://scripts/tile_art.gd")
const TOUCH_DAMAGE := 2
const TOUCH_INTERVAL := 0.7
const TOUCH_MARGIN := Vector3(0.5, 0.95, 0.5)

var cactus_seed: int = 0
var boxes: Array = []
var touch_timer: float = 0.0
var player


func _configure() -> void:
	resource_type = "cactus"
	chip_color = Color(0.3, 0.45, 0.28)
	max_health = 3
	resource_amount = 2
	add_to_group("cactus")


func _build() -> void:
	player = get_tree().get_first_node_in_group("player")
	var rng := RandomNumberGenerator.new()
	rng.seed = cactus_seed
	var material := TileArt.uv_material("cactus", Color(0.25, 0.4, 0.25), Vector3.ONE)
	var trunk_h := rng.randf_range(1.6, 2.6)
	_part(Vector3(0.0, trunk_h * 0.5, 0.0), Vector3(0.5, trunk_h, 0.5), material)

	var arm_count := rng.randi_range(0, 2)
	var dirs: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	dirs.shuffle()
	for i in arm_count:
		var dir: Vector3 = dirs[i]
		var arm_y := rng.randf_range(0.7, trunk_h - 0.8)
		var reach := rng.randf_range(0.35, 0.5)
		_part(dir * (0.25 + reach * 0.5) + Vector3(0.0, arm_y, 0.0), Vector3(absf(dir.x) * reach + absf(dir.z) * 0.3, 0.3, absf(dir.z) * reach + absf(dir.x) * 0.3), material)
		var rise := rng.randf_range(0.5, 0.9)
		_part(dir * (0.1 + reach) + Vector3(0.0, arm_y + rise * 0.5, 0.0), Vector3(0.3, rise + 0.3, 0.3), material)


func _part(pos: Vector3, size: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = TileArt.box_mesh(size, material)
	mi.position = pos
	visual.add_child(mi)
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = pos
	add_child(shape)
	boxes.append([pos, size])


func _physics_process(delta: float) -> void:
	if dying:
		return
	touch_timer = maxf(touch_timer - delta, 0.0)
	if touch_timer > 0.0 or not is_instance_valid(player) or player.dead:
		return
	var local: Vector3 = global_transform.affine_inverse() * player.global_position
	for entry: Array in boxes:
		var center: Vector3 = entry[0]
		var size: Vector3 = entry[1]
		var d := (local - center).abs()
		var limit := size * 0.5 + TOUCH_MARGIN
		if d.x <= limit.x and d.y <= limit.y and d.z <= limit.z:
			player.take_damage(TOUCH_DAMAGE, global_position)
			touch_timer = TOUCH_INTERVAL
			return
