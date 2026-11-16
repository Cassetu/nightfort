extends Node3D

const RISE_TIME := 7.0
const SINK_TIME := 4.0
const BURIED := -3.2

const NestModel = preload("res://scripts/nest_model.gd")

const BILE_LIGHT := Color(0.55, 0.25, 0.75)

var tween: Tween
var sinking: bool = false


func _ready() -> void:
	NestModel.build(self, Vector3.ZERO, int(get_meta("seed", 5)), true)

	var drip := CPUParticles3D.new()
	var bead := SphereMesh.new()
	bead.radius = 0.07
	bead.height = 0.14
	bead.radial_segments = 6
	bead.rings = 3
	bead.material = NestModel.bile_material
	drip.mesh = bead
	drip.amount = 10
	drip.lifetime = 3.0
	drip.direction = Vector3.UP
	drip.spread = 25.0
	drip.gravity = Vector3(0.0, 0.4, 0.0)
	drip.initial_velocity_min = 0.2
	drip.initial_velocity_max = 0.6
	drip.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drip.emission_sphere_radius = 1.6
	drip.position = Vector3(0.0, 0.8, 0.0)
	add_child(drip)

	var glow := OmniLight3D.new()
	glow.light_color = BILE_LIGHT
	glow.light_energy = 0.7
	glow.omni_range = 7.0
	glow.shadow_enabled = false
	glow.position = Vector3(0.0, 1.0, 0.0)
	add_child(glow)

	position.y = _ground_y() + BURIED
	rise()


func rise() -> void:
	if tween != null:
		tween.kill()
	sinking = false
	var target := _ground_y()
	tween = create_tween()
	tween.tween_property(self, "position:y", target, RISE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func sink() -> void:
	if sinking:
		return
	sinking = true
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "position:y", _ground_y() + BURIED, SINK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _ground_y() -> float:
	return get_meta("ground_y", 0.0)
