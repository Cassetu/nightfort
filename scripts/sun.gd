extends DirectionalLight3D

const DAY_TOP := Color(0.22, 0.45, 0.85)
const DAY_HORIZON := Color(0.62, 0.76, 0.92)
const DUSK_TOP := Color(0.20, 0.22, 0.42)
const DUSK_HORIZON := Color(1.0, 0.52, 0.28)
const NIGHT_TOP := Color(0.015, 0.025, 0.07)
const NIGHT_HORIZON := Color(0.05, 0.07, 0.14)
const DAY_LIGHT := Color(1.0, 0.96, 0.88)
const DUSK_LIGHT := Color(1.0, 0.55, 0.30)
const MOON_LIGHT := Color(0.6, 0.7, 1.0)

@export var day_length_seconds: float = 60.0
@export_range(0.0, 1.0) var phase_offset: float = 0.0
@export var sun_energy: float = 1.2
@export var moon_energy: float = 0.35

var time_multiplier: float
var day_phase: float = 0.0
var moon: DirectionalLight3D

@onready var env = $"../WorldEnvironment".environment
@onready var sky_material = env.sky.sky_material


func _ready():
	time_multiplier = TAU / day_length_seconds
	var dir = -global_transform.basis.z
	var psi = atan2(dir.z, dir.y)
	day_phase = wrapf((psi - PI) / TAU + phase_offset, 0.0, 1.0)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = MOON_LIGHT
	moon.light_energy = 0.0
	moon.shadow_enabled = true
	moon.rotation.y = PI
	add_child(moon)


func _process(delta):
	rotate_x(time_multiplier * delta)
	day_phase = wrapf(day_phase + delta / day_length_seconds, 0.0, 1.0)

	var e = global_transform.basis.z.y
	var night_amt = 1.0 - smoothstep(-0.2, 0.05, e)
	var day_amt = smoothstep(0.05, 0.5, e)
	var dusk_amt = 1.0 - night_amt - day_amt

	var top = NIGHT_TOP * night_amt + DUSK_TOP * dusk_amt + DAY_TOP * day_amt
	var horizon = NIGHT_HORIZON * night_amt + DUSK_HORIZON * dusk_amt + DAY_HORIZON * day_amt
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	sky_material.ground_bottom_color = top.darkened(0.5)
	env.fog_light_color = horizon
	env.ambient_light_energy = lerpf(2.5, 1.0, day_amt)

	light_color = DUSK_LIGHT.lerp(DAY_LIGHT, day_amt)
	light_energy = sun_energy * smoothstep(0.0, 0.2, e)
	visible = light_energy > 0.01

	var moon_amt = smoothstep(0.0, 0.25, -e)
	moon.light_energy = moon_energy * moon_amt
	moon.visible = moon_amt > 0.01
