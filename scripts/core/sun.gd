extends DirectionalLight3D

const LightBudget := preload("res://scripts/core/light_budget.gd")
const SHADOW_DISTANCE: float = 70.0
const DAY_TOP := Color(0.27, 0.36, 0.45)
const DAY_HORIZON := Color(0.50, 0.56, 0.54)
const DUSK_TOP := Color(0.20, 0.22, 0.42)
const DUSK_HORIZON := Color(0.70, 0.44, 0.30)
const NIGHT_TOP := Color(0.03, 0.015, 0.075)
const NIGHT_HORIZON := Color(0.17, 0.05, 0.24)
const DAY_LIGHT := Color(1.0, 0.96, 0.88)
const DUSK_LIGHT := Color(1.0, 0.55, 0.30)
const MOON_LIGHT := Color(0.6, 0.7, 1.0)

@export var day_length_seconds: float = 600.0
@export_range(0.0, 1.0) var phase_offset: float = 0.0
@export var sun_energy: float = 1.2
@export var moon_energy: float = 0.05
@export var night_ambient_energy: float = 3.5
@export_range(0.05, 0.9) var night_fraction: float = 0.25
@export var night_start_elevation: float = -0.1
@export var dawn_elevation: float = 0.03
@export_range(0.0, 1.0) var shadow_softness: float = 0.78
@export var day_ambient_energy: float = 1.25

const WARP_STEPS := 720
const WARP_FROM := -0.3
const WARP_TO := 0.1

var time_multiplier: float
var warp_ratio: float = 1.0
var warp_base: float = 1.0
var day_phase: float = 0.0
var moon: DirectionalLight3D
var elevation: float = 1.0

@onready var env = $"../WorldEnvironment".environment
@onready var sky_material = env.sky.sky_material


func _ready():
	directional_shadow_max_distance = SHADOW_DISTANCE
	var budget: Node = LightBudget.new()
	budget.name = "LightBudget"
	add_child(budget)
	_calibrate_warp()
	var dir = -global_transform.basis.z
	var psi = atan2(dir.z, dir.y)
	day_phase = wrapf((psi - PI) / TAU + phase_offset, 0.0, 1.0)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = MOON_LIGHT
	moon.light_energy = 0.0
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = SHADOW_DISTANCE
	moon.rotation = Vector3(0.0, PI + deg_to_rad(25.0), 0.0)
	add_child(moon)


func _warp_speed(e: float, ratio: float) -> float:
	return lerpf(1.0, ratio, 1.0 - smoothstep(WARP_FROM, WARP_TO, e))


func _night_share(ratio: float) -> float:
	var lo := acos(night_start_elevation)
	var hi := TAU - acos(dawn_elevation)
	var step := TAU / float(WARP_STEPS)
	var night := 0.0
	var total := 0.0
	for i in WARP_STEPS:
		var psi := (float(i) + 0.5) * step
		var t := step / _warp_speed(cos(psi), ratio)
		total += t
		if psi > lo and psi < hi:
			night += t
	return night / total


func _calibrate_warp() -> void:
	var lo := 1.0
	var hi := 400.0
	for i in 40:
		var mid := sqrt(lo * hi)
		if _night_share(mid) > night_fraction:
			lo = mid
		else:
			hi = mid
	warp_ratio = sqrt(lo * hi)
	var step := TAU / float(WARP_STEPS)
	var total := 0.0
	for i in WARP_STEPS:
		total += step / _warp_speed(cos((float(i) + 0.5) * step), warp_ratio)
	warp_base = total / day_length_seconds
	time_multiplier = TAU / day_length_seconds


func _process(delta):
	var rate := warp_base * _warp_speed(global_transform.basis.z.y, warp_ratio)
	rotate_x(rate * delta)
	day_phase = wrapf(day_phase + rate * delta / TAU, 0.0, 1.0)

	var e = global_transform.basis.z.y
	elevation = e
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
	env.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, day_amt)

	light_color = DUSK_LIGHT.lerp(DAY_LIGHT, day_amt)
	light_energy = sun_energy * smoothstep(0.0, 0.2, e)
	shadow_enabled = light_energy > 0.01
	shadow_opacity = lerpf(1.0, shadow_softness, smoothstep(0.0, 0.35, e))

	var moon_amt = smoothstep(-0.05, 0.15, -e)
	moon.light_energy = moon_energy * moon_amt
	moon.shadow_enabled = moon_amt > 0.05
