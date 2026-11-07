extends StaticBody3D

const HEALTH_PER_LEVEL := 25
const UPGRADE_FLOOR := 0.75

signal health_changed(current, maximum)
signal destroyed

@export var max_health: int = 100
@export var marker_min_distance: float = 20.0
@export var build_exclusion_radius: float = 3.0
@export var hide_distance: float = 1.25
@export var night_heal: int = 5

const GLOW_ALPHA := 0.5
const CORE_HALF := 1.0
const MELEE_MAX_RISE := 1.2

var current_health: int
var dying: bool = false
var sun
var last_text: String = ""
var level: int = 1
var base_max_health: int = 100
var base_night_heal: int = 5
var overview: bool = false

@onready var glow: MeshInstance3D = $Glow
@onready var body_mesh: MeshInstance3D = $MeshInstance3D
@onready var mist: CPUParticles3D = $Mist
@onready var marker_label: Label = %Label


func _ready():
	add_to_group("Core")
	base_max_health = max_health
	base_night_heal = night_heal
	current_health = max_health
	sun = get_node_or_null("../Sun")


func blocks_building(cell_center: Vector3) -> bool:
	return cell_center.distance_to(global_position) < build_exclusion_radius


func melee_reachable(feet_y: float) -> bool:
	return feet_y - (global_position.y - CORE_HALF) <= MELEE_MAX_RISE


func _process(_delta: float) -> void:
	var elevation: float = 1.0
	if sun != null:
		elevation = sun.elevation
	var night := 1.0 - smoothstep(-0.2, 0.05, elevation)

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dist := cam.global_position.distance_to(global_position)
	var inside := dist < hide_distance
	body_mesh.visible = not inside
	mist.visible = not inside
	glow.visible = night > 0.01 and not inside
	if glow.visible:
		var mat: StandardMaterial3D = glow.mesh.material
		mat.albedo_color = Color(0.4, 1.0, 1.0, GLOW_ALPHA * night)

	var anchor := global_position + Vector3(0.0, 1.6, 0.0)
	var show_marker := not overview and dist >= marker_min_distance and not cam.is_position_behind(anchor)
	marker_label.visible = show_marker
	if not show_marker:
		return
	var text := "Core %du\n▼" % roundi(dist)
	if text != last_text:
		last_text = text
		marker_label.text = text
		marker_label.reset_size()
	var screen := cam.unproject_position(anchor)
	marker_label.position = screen - Vector2(marker_label.size.x * 0.5, marker_label.size.y)


func take_damage(amount: int, _hit_position = Vector3.INF):
	if dying or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	_pulse()
	if current_health <= 0:
		die()


func set_level(value: int) -> void:
	level = maxi(value, 1)
	max_health = base_max_health + (level - 1) * HEALTH_PER_LEVEL
	night_heal = base_night_heal + (level - 1)
	current_health = mini(current_health, max_health)
	health_changed.emit(current_health, max_health)


func upgrade() -> void:
	set_level(level + 1)
	var floor_hp := roundi(float(max_health) * UPGRADE_FLOOR)
	if current_health < floor_hp:
		current_health = floor_hp
	health_changed.emit(current_health, max_health)


func heal(amount: int) -> void:
	if dying or amount <= 0:
		return
	set_health(current_health + amount)


func set_health(value: int):
	current_health = clampi(value, 0, max_health)
	health_changed.emit(current_health, max_health)


func die():
	dying = true
	destroyed.emit()
	queue_free()


func _pulse():
	var mesh = $MeshInstance3D
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE * 1.1, 0.05)
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.2)
