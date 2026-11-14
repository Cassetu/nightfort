extends StaticBody3D

const ChipBurst = preload("res://scripts/chip_burst.gd")

const MAX_HP := 8
const BILE := Color(0.36, 0.2, 0.46)
const CRACK_STAGES := 10
const CRACK_WALKERS := 7
const CRACK_STEPS := 18
const CRACK_SIZE := 1.012

static var crack_materials: Array = []
static var crack_mesh: BoxMesh

var hp: int = MAX_HP
var dead: bool = false
var dying: bool = false
var resource_type: String = "flesh"
var resource_amount: int = 0
var ring: int = 0
var column: int = 0
var layer: int = 0
var batch: MultiMesh
var slot: int = 0
var rider
var depth: int = 0
var next_block
var on_break: Callable
var punch: Tween
var crack: MeshInstance3D


func setup(shape: Shape3D, multimesh: MultiMesh, index: int, ring_index: int, column_index: int, layer_index: int) -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("resource")
	add_to_group("flesh_block")
	batch = multimesh
	slot = index
	ring = ring_index
	column = column_index
	layer = layer_index
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)


func take_damage(amount, from: Vector3 = Vector3.INF) -> void:
	if dead or amount <= 0:
		return
	hp -= int(amount)
	var at := global_position
	if from.is_finite():
		var toward := from - global_position
		toward.y = 0.0
		at += toward.normalized() * 1.0
	ChipBurst.spawn(self, at, "gloom_flesh", BILE, 5, 0.12, 0.5, 80.0, 2.0, 4.5, 10.0)
	if hp <= 0:
		_break()
	else:
		_show_crack()


static func _ensure_cracks() -> void:
	if not crack_materials.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 8808
	var ordered: Array = []
	var walkers: Array = []
	for w in CRACK_WALKERS:
		walkers.append([Vector2i(rng.randi_range(2, 13), rng.randi_range(2, 13)), Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))])
	for step in CRACK_STEPS:
		for walker: Array in walkers:
			var pos: Vector2i = walker[0]
			var dir: Vector2i = walker[1]
			if dir == Vector2i.ZERO or rng.randf() < 0.35:
				dir = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			pos = Vector2i(clampi(pos.x + dir.x, 0, 15), clampi(pos.y + dir.y, 0, 15))
			walker[0] = pos
			walker[1] = dir
			ordered.append(pos)
	for stage in CRACK_STAGES:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var shown := int(float(ordered.size()) * float(stage + 1) / float(CRACK_STAGES))
		for i in shown:
			var px: Vector2i = ordered[i]
			img.set_pixelv(px, Color(0.03, 0.0, 0.03, 0.9))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		crack_materials.append(mat)
	crack_mesh = BoxMesh.new()
	crack_mesh.size = Vector3.ONE * CRACK_SIZE


func _show_crack() -> void:
	_ensure_cracks()
	var stage := clampi(int((1.0 - float(hp) / float(MAX_HP)) * float(CRACK_STAGES)), 0, CRACK_STAGES - 1)
	if crack == null:
		crack = MeshInstance3D.new()
		crack.mesh = crack_mesh
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(crack)
	crack.material_override = crack_materials[stage]


func _break() -> void:
	if crack != null:
		crack.queue_free()
		crack = null
	dead = true
	dying = true
	remove_from_group("resource")
	remove_from_group("flesh_block")
	collision_layer = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	if on_break.is_valid():
		on_break.call(self)
	if is_instance_valid(rider):
		rider.take_damage(999)
	ChipBurst.spawn(self, global_position, "gloom_flesh", BILE, 18, 0.18, 1.0, 180.0, 3.0, 7.0, 14.0)
	batch.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
