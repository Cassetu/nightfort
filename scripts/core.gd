extends StaticBody3D

signal health_changed(current, maximum)
signal destroyed

@export var max_health: int = 100
@export var marker_min_distance: float = 20.0
@export var build_exclusion_radius: float = 3.0

const GLOW_ALPHA := 0.5
const CORE_HALF := 1.0
const MELEE_MAX_RISE := 1.2

var current_health: int
var dying: bool = false
var sun
var last_text: String = ""

@onready var glow: MeshInstance3D = $Glow
@onready var marker: Node3D = $Marker
@onready var marker_label: Label3D = $Marker/Label


func _ready():
	add_to_group("Core")
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
	glow.visible = night > 0.01
	var mat: StandardMaterial3D = glow.mesh.material
	mat.albedo_color = Color(0.4, 1.0, 1.0, GLOW_ALPHA * night)

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dist := cam.global_position.distance_to(global_position)
	marker.visible = dist >= marker_min_distance
	if not marker.visible:
		return
	var s := maxf(dist / 14.0, 1.0)
	marker.scale = Vector3.ONE * s
	marker.global_position = global_position + Vector3(0.0, 2.2 + s * 0.4, 0.0)
	var text := "Core %du\n▼" % roundi(dist)
	if text != last_text:
		last_text = text
		marker_label.text = text


func take_damage(amount: int, _hit_position = Vector3.INF):
	if dying or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	_pulse()
	if current_health <= 0:
		die()


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
