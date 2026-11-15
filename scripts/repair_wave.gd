extends Node3D

const BlockIndex = preload("res://scripts/block_index.gd")
const SPEED := 9.0
const BAND := 2.2
const DECAL_HEIGHT := 40.0
const PULSE_PEAK := 0.62
const PULSE_IN := 0.18
const PULSE_OUT := 0.7
const TEX_SIZE := 128
const TINT := Color(0.35, 0.8, 1.0)

static var pulse_mesh: BoxMesh
static var pulse_material: StandardMaterial3D
static var ring_texture: ImageTexture

var origin := Vector3.ZERO
var reach := 13.0
var radius: float = 0.0
var pending: Array = []
var decal: Decal


static func start(parent: Node, core: Node3D, half: float) -> void:
	var wave := (load("res://scripts/repair_wave.gd") as GDScript).new() as Node3D
	parent.add_child(wave)
	wave.begin(core.global_position, half + 1.0)


func begin(center: Vector3, half: float) -> void:
	origin = center
	reach = half
	global_position = center
	for node in BlockIndex.list:
		if not is_instance_valid(node) or node.dying or node.falling_now:
			continue
		var d := maxf(absf(node.global_position.x - center.x), absf(node.global_position.z - center.z))
		if d > reach + 1.0:
			continue
		pending.append({"block": node, "d": d})
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d"] < b["d"])
	_make_decal()


func _make_decal() -> void:
	decal = Decal.new()
	decal.texture_albedo = _ring()
	decal.texture_emission = _ring()
	decal.emission_energy = 1.6
	decal.albedo_mix = 0.6
	decal.modulate = Color(TINT.r, TINT.g, TINT.b, 0.75)
	decal.upper_fade = 0.3
	decal.lower_fade = 0.3
	decal.size = Vector3(1.0, DECAL_HEIGHT, 1.0)
	decal.position = Vector3(0.0, DECAL_HEIGHT * 0.35, 0.0)
	add_child(decal)


static func _ring() -> ImageTexture:
	if ring_texture != null:
		return ring_texture
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var u := absf((float(x) + 0.5) / float(TEX_SIZE) * 2.0 - 1.0)
			var v := absf((float(y) + 0.5) / float(TEX_SIZE) * 2.0 - 1.0)
			var m := maxf(u, v)
			var edge := smoothstep(0.78, 0.97, m) * (1.0 - smoothstep(0.97, 1.0, m))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, edge))
	ring_texture = ImageTexture.create_from_image(img)
	return ring_texture


static func _pulse_assets() -> void:
	if pulse_mesh != null:
		return
	pulse_mesh = BoxMesh.new()
	pulse_mesh.size = Vector3.ONE * 1.03
	pulse_material = StandardMaterial3D.new()
	pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pulse_material.albedo_color = Color(TINT.r, TINT.g, TINT.b, 0.55)


func _process(delta: float) -> void:
	radius += SPEED * delta
	var r := maxf(radius + BAND, 1.0)
	decal.size = Vector3(r * 2.0, DECAL_HEIGHT, r * 2.0)
	var fade := 1.0 - smoothstep(reach - 2.0, reach + BAND, radius)
	decal.modulate = Color(TINT.r, TINT.g, TINT.b, 0.75 * fade)
	while not pending.is_empty() and float(pending[0]["d"]) <= radius:
		var entry: Dictionary = pending.pop_front()
		_touch(entry["block"])
	if radius > reach + BAND + 1.0 and pending.is_empty():
		queue_free()


func _touch(block: Node) -> void:
	if not is_instance_valid(block) or block.dying:
		return
	if block.has_method("repair"):
		block.repair()
	var parent: Node3D = block.get("visual")
	if parent == null or not is_instance_valid(parent):
		return
	_pulse_assets()
	var glow := MeshInstance3D.new()
	glow.mesh = pulse_mesh
	glow.material_override = pulse_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.transparency = 1.0
	parent.add_child(glow)
	var tween := glow.create_tween()
	tween.tween_property(glow, "transparency", 1.0 - PULSE_PEAK, PULSE_IN)
	tween.tween_property(glow, "transparency", 1.0, PULSE_OUT)
	tween.tween_callback(glow.queue_free)
