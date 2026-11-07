extends "res://scripts/resource_node.gd"

const TileArt = preload("res://scripts/tile_art.gd")

const SUPPORT_INTERVAL := 0.25
const REINFORCE_HP := 2.5
const DARKEN := 0.55
const DECAL_TILE := "reinforced_decal"
const WET_ROUGHNESS := 0.32
const WET_DARKEN := 0.26
const WET_COAT := 0.3
const WET_COAT_ROUGHNESS := 0.3

var block_type: String = "wood"
var needs_support: bool = false
var support_timer: float = 0.0
var terrain
var structural: bool = true
var falls: bool = false
var weight: int = 2
var max_load: int = 99
var collapsing: bool = false
var falling_now: bool = false
var zone_break: bool = false
var reinforced: bool = false
var wet: bool = false
var base_health: int = 0
var body_mesh: MeshInstance3D
var decal_mesh: MeshInstance3D

static var _materials: Dictionary = {}
static var _dark_materials: Dictionary = {}
static var _decal_material: StandardMaterial3D
static var _wet_materials: Dictionary = {}
static var _wet_bases: Dictionary = {}
static var wet_level: float = 0.0


func _configure() -> void:
	var info: Dictionary = Inventory.BLOCK_TYPES[block_type]
	resource_type = info["resource"]
	resource_amount = Inventory.BLOCK_COST
	max_health = info["health"]
	base_health = max_health
	chip_color = info["color"]
	add_to_group("block")
	terrain = get_tree().get_first_node_in_group("terrain")
	structural = info.get("structural", true)
	falls = info.get("falls", false)
	weight = int(info.get("weight", 2))
	max_load = int(info.get("max_load", 99))
	_mark_stability()


func _build() -> void:
	var mesh := BoxMesh.new()
	mesh.material = _material_for(block_type)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	visual.add_child(mi)
	body_mesh = mi

	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	add_child(col)


func _process(delta: float) -> void:
	if not needs_support or dying:
		return
	support_timer += delta
	if support_timer < SUPPORT_INTERVAL:
		return
	support_timer = 0.0
	if not _supported():
		take_damage(max_health)


func _supported() -> bool:
	var cx := floori(global_position.x)
	var cy := floori(global_position.y)
	var cz := floori(global_position.z)
	if terrain != null and terrain.block_at(cx, cy - 1, cz) != 0:
		return true
	var below := Vector3(cx + 0.5, cy - 0.5, cz + 0.5)
	for n in get_tree().get_nodes_in_group("block"):
		if n != self and not n.dying and n.covers(below):
			return true
	return false


func cells() -> Array:
	var base := Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))
	var height := int(Inventory.BLOCK_TYPES[block_type].get("height", 1))
	var out: Array = []
	for i in height:
		out.append(base + Vector3i(0, i, 0))
	for extra: Vector3i in extra_cells():
		out.append(base + extra)
	return out


func extra_cells() -> Array:
	return []


func is_brick() -> bool:
	return body_mesh != null and block_type.ends_with("_brick") and block_type != "ruined_brick"


func set_reinforced(value: bool) -> void:
	if value == reinforced or body_mesh == null:
		return
	reinforced = value
	var ratio := float(current_health) / float(maxi(max_health, 1))
	max_health = roundi(base_health * REINFORCE_HP) if value else base_health
	current_health = clampi(roundi(ratio * max_health), 1, max_health)
	if value:
		decal_mesh = MeshInstance3D.new()
		decal_mesh.mesh = TileArt.box_mesh(Vector3.ONE * 1.004, _get_decal_material())
		decal_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(decal_mesh)
	elif decal_mesh != null:
		decal_mesh.queue_free()
		decal_mesh = null
	_apply_material()


func set_wet(value: bool) -> void:
	if value == wet or body_mesh == null:
		return
	wet = value
	_apply_material()


func _apply_material() -> void:
	if wet:
		body_mesh.material_override = _wet_material_for(block_type, reinforced)
	elif reinforced:
		body_mesh.material_override = _dark_material_for(block_type)
	else:
		body_mesh.material_override = null


static func _wet_material_for(type: String, dark: bool) -> StandardMaterial3D:
	var key := type + ("_dark" if dark else "")
	if not _wet_materials.has(key):
		var base: StandardMaterial3D = _dark_material_for(type) if dark else _material_for(type)
		var mat: StandardMaterial3D = base.duplicate()
		mat.clearcoat_enabled = true
		_wet_bases[key] = base
		_wet_materials[key] = mat
		_tune_wet(mat, base)
	return _wet_materials[key]


static func _tune_wet(mat: StandardMaterial3D, base: StandardMaterial3D) -> void:
	var k := 1.0 - WET_DARKEN * wet_level
	mat.albedo_color = Color(base.albedo_color.r * k, base.albedo_color.g * k, base.albedo_color.b * k, base.albedo_color.a)
	mat.roughness = lerpf(base.roughness, WET_ROUGHNESS, wet_level)
	mat.clearcoat = WET_COAT * wet_level
	mat.clearcoat_roughness = WET_COAT_ROUGHNESS


static func apply_wetness(level: float) -> void:
	if absf(level - wet_level) < 0.004:
		return
	wet_level = level
	for key in _wet_materials:
		_tune_wet(_wet_materials[key], _wet_bases[key])


static func _dark_material_for(type: String) -> StandardMaterial3D:
	if not _dark_materials.has(type):
		var mat: StandardMaterial3D = _material_for(type).duplicate()
		mat.albedo_color = mat.albedo_color * Color(DARKEN, DARKEN, DARKEN * 1.05, 1.0)
		_dark_materials[type] = mat
	return _dark_materials[type]


static func _get_decal_material() -> StandardMaterial3D:
	if _decal_material == null:
		_decal_material = StandardMaterial3D.new()
		_decal_material.albedo_texture = TileArt.texture(DECAL_TILE, Color(0, 0, 0, 0))
		_decal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_decal_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_decal_material.roughness = 1.0
	return _decal_material


func _mark_stability() -> void:
	if is_inside_tree():
		get_tree().call_group("stability", "mark_dirty")


func _die() -> void:
	super()
	_mark_stability()


func _exit_tree() -> void:
	if structural and is_inside_tree():
		_mark_stability()


func begin_collapse(delay: float) -> void:
	if collapsing or dying:
		return
	collapsing = true
	var tween := create_tween().set_loops(int(delay / 0.12) + 1)
	tween.tween_property(visual, "rotation:z", 0.04, 0.06)
	tween.tween_property(visual, "rotation:z", -0.04, 0.06)
	get_tree().create_timer(delay).timeout.connect(_finish_collapse.bind(tween))


func _finish_collapse(tween: Tween) -> void:
	if tween != null:
		tween.kill()
	if dying or not is_inside_tree():
		return
	visual.rotation = Vector3.ZERO
	var stability := get_tree().get_first_node_in_group("stability")
	if stability != null and not stability.is_unstable(self):
		collapsing = false
		return
	if stability != null and extra_cells().is_empty():
		var base: Vector3i = cells()[0]
		var landing: Vector3i = stability.landing_cell(self)
		if landing.y < base.y:
			collapsing = false
			fall_to(landing)
			return
		var below = stability.cell_map.get(base + Vector3i.DOWN)
		if below != null and stability.is_unstable(below):
			collapsing = false
			begin_collapse(0.35)
			return
	if randf() < 0.5:
		resource_amount = 0
	take_damage(max_health)


func fall_to(target_cell: Vector3i) -> void:
	if falling_now or dying:
		return
	falling_now = true
	var core = get_tree().get_first_node_in_group("Core")
	if core != null:
		var shift = target_cell - cells()[0]
		for c: Vector3i in cells():
			if core.blocks_building(Vector3(c + shift) + Vector3(0.5, 0.5, 0.5)):
				zone_break = true
				break
	var target_y := float(target_cell.y) + 0.5
	var drop := maxf(global_position.y - target_y, 0.0)
	var time := maxf(sqrt(2.0 * drop / 22.0), 0.12)
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", target_y, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_landed)


func _landed() -> void:
	falling_now = false
	if zone_break:
		zone_break = false
		take_damage(max_health + 1, global_position)
		return
	_mark_stability()


func covers(p: Vector3) -> bool:
	var d := (p - global_position).abs()
	return d.x < 0.6 and d.y < 0.6 and d.z < 0.6


static func _material_for(type: String) -> StandardMaterial3D:
	if not _materials.has(type):
		var info: Dictionary = Inventory.BLOCK_TYPES[type]
		_materials[type] = TileArt.block_material(info.get("tile", type), info["color"])
	return _materials[type]
