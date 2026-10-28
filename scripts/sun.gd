extends DirectionalLight3D

@export var day_length_seconds: float = 60.0
@export_range(0.0, 1.0) var phase_offset: float = 0.0

var time_multiplier: float
var day_phase: float = 0.0

@onready var env = $"../WorldEnvironment".environment

func _ready():
	time_multiplier = TAU / day_length_seconds
	var dir = -global_transform.basis.z
	var psi = atan2(dir.z, dir.y)
	day_phase = wrapf((psi - PI) / TAU + phase_offset, 0.0, 1.0)

func _process(delta):
	rotate_x(time_multiplier * delta)
	day_phase = wrapf(day_phase + delta / day_length_seconds, 0.0, 1.0)

	var sun_height = -global_transform.basis.z.y
	var energy = clamp(-sun_height, 0.02, 1.0)

	env.background_energy_multiplier = energy
	env.ambient_light_energy = energy
