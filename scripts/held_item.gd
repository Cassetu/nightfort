extends Node3D

const TileArt = preload("res://scripts/tile_art.gd")

const ITEM_SIZE := 0.62
const THICKNESS := 0.05
const BASE_POS := Vector3(0.38, -0.5, -0.72)
const MODEL_OFFSET := Vector3(0.0, 0.14, 0.0)
const TILT_X := -8.0
const TILT_Y := -25.0
const DIAGONAL_Z := 45.0
const UPRIGHT_Z := 12.0
const UPRIGHT := ["torch", "bow"]
const DRAW_MOVE := Vector3(-0.04, 0.02, 0.2)
const DRAW_ROT := Vector3(6.0, 14.0, 0.0)
const SWING_ROT := Vector3(-62.0, 10.0, 0.0)
const SWING_MOVE := Vector3(-0.1, -0.07, -0.16)
const SWING_IN := 0.09
const SWING_OUT := 0.22
const BOB_RATE := 9.0
const BOB_SIDE := 0.02
const BOB_DEPTH := 0.026
const SIDE_SHADE := 0.72
const TORCH_ENERGY := 1.8

static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D

@onready var model: MeshInstance3D = $Model
@onready var light: OmniLight3D = $Light

var item_id: String = ""
var suppressed: bool = false
var swing: float = 0.0
var draw: float = 0.0
var swing_tween: Tween
var bob_phase: float = 0.0
var bob_amount: float = 0.0
var bob_target: float = 0.0


func _ready() -> void:
	visible = false
	model.layers = 2
	light.visible = false


func set_item(id: String) -> void:
	if id == item_id:
		return
	item_id = id
	visible = id != "" and not suppressed
	light.visible = id == "torch"
	if id == "":
		return
	model.mesh = mesh_for(id)
	var z := UPRIGHT_Z if id in UPRIGHT else DIAGONAL_Z
	model.rotation_degrees = Vector3(TILT_X, TILT_Y, z)
	model.position = MODEL_OFFSET


func set_suppressed(value: bool) -> void:
	suppressed = value
	visible = item_id != "" and not suppressed


func set_motion(amount: float) -> void:
	bob_target = clampf(amount, 0.0, 1.0)


func set_draw(amount: float) -> void:
	draw = clampf(amount, 0.0, 1.0)


func play_swing() -> void:
	if swing_tween:
		swing_tween.kill()
	swing_tween = create_tween()
	swing_tween.tween_property(self, "swing", 1.0, SWING_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(self, "swing", 0.0, SWING_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if item_id == "":
		return
	var t := Time.get_ticks_msec() / 1000.0
	bob_amount = lerpf(bob_amount, bob_target, minf(delta * 8.0, 1.0))
	bob_phase += delta * BOB_RATE * bob_amount
	var bob := Vector3(sin(bob_phase) * BOB_SIDE, -absf(sin(bob_phase)) * BOB_DEPTH, 0.0) * bob_amount
	var idle := Vector3(0.0, sin(t * 1.6) * 0.004, 0.0)
	var shake := Vector3(sin(t * 38.0), cos(t * 31.0), 0.0) * 0.002 * smoothstep(0.8, 1.0, draw)
	position = BASE_POS + bob + idle + SWING_MOVE * swing + DRAW_MOVE * draw + shake
	rotation_degrees = SWING_ROT * swing + DRAW_ROT * draw
	if light.visible:
		light.light_energy = TORCH_ENERGY * (1.0 + 0.1 * sin(t * 9.0) + 0.06 * sin(t * 23.0))


static func mesh_for(id: String) -> ArrayMesh:
	if _meshes.has(id):
		return _meshes[id]
	var mesh: ArrayMesh = null
	var tex: Texture2D = TileArt.icon(id, "")
	if tex != null:
		var img := tex.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			mesh = _extrude(img)
	_meshes[id] = mesh
	return mesh


static func _get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


static func _solid(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a >= 0.5


static func _quad(arrays: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var verts: PackedVector3Array = arrays["verts"]
	var normals: PackedVector3Array = arrays["normals"]
	var colors: PackedColorArray = arrays["colors"]
	var indices: PackedInt32Array = arrays["indices"]
	var base := verts.size()
	verts.push_back(a)
	verts.push_back(b)
	verts.push_back(c)
	verts.push_back(d)
	for i in 4:
		normals.append(normal)
		colors.append(color)
	for offset: int in [0, 1, 2, 0, 2, 3]:
		indices.push_back(base + offset)


static func _extrude(img: Image) -> ArrayMesh:
	var w := img.get_width()
	var h := img.get_height()
	var px := ITEM_SIZE / float(maxi(w, h))
	var half := THICKNESS * 0.5
	var arrays := {
		"verts": PackedVector3Array(),
		"normals": PackedVector3Array(),
		"colors": PackedColorArray(),
		"indices": PackedInt32Array(),
	}
	for y in h:
		for x in w:
			if not _solid(img, x, y):
				continue
			var c := img.get_pixel(x, y)
			c.a = 1.0
			var shade := Color(c.r * SIDE_SHADE, c.g * SIDE_SHADE, c.b * SIDE_SHADE, 1.0)
			var x0 := (float(x) - w * 0.5) * px
			var x1 := x0 + px
			var y1 := (h * 0.5 - float(y)) * px
			var y0 := y1 - px
			_quad(arrays, Vector3(x0, y0, half), Vector3(x0, y1, half), Vector3(x1, y1, half), Vector3(x1, y0, half), Vector3(0, 0, 1), c)
			_quad(arrays, Vector3(x1, y0, -half), Vector3(x1, y1, -half), Vector3(x0, y1, -half), Vector3(x0, y0, -half), Vector3(0, 0, -1), shade)
			if not _solid(img, x - 1, y):
				_quad(arrays, Vector3(x0, y0, -half), Vector3(x0, y1, -half), Vector3(x0, y1, half), Vector3(x0, y0, half), Vector3(-1, 0, 0), shade)
			if not _solid(img, x + 1, y):
				_quad(arrays, Vector3(x1, y0, half), Vector3(x1, y1, half), Vector3(x1, y1, -half), Vector3(x1, y0, -half), Vector3(1, 0, 0), shade)
			if not _solid(img, x, y - 1):
				_quad(arrays, Vector3(x0, y1, half), Vector3(x0, y1, -half), Vector3(x1, y1, -half), Vector3(x1, y1, half), Vector3(0, 1, 0), shade)
			if not _solid(img, x, y + 1):
				_quad(arrays, Vector3(x0, y0, -half), Vector3(x0, y0, half), Vector3(x1, y0, half), Vector3(x1, y0, -half), Vector3(0, -1, 0), shade)
	if arrays["verts"].is_empty():
		return null
	var data: Array = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = arrays["verts"]
	data[Mesh.ARRAY_NORMAL] = arrays["normals"]
	data[Mesh.ARRAY_COLOR] = arrays["colors"]
	data[Mesh.ARRAY_INDEX] = arrays["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	mesh.surface_set_material(0, _get_material())
	return mesh
