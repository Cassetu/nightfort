extends DirectionalLight3D

@export var day_length_seconds: float = 60.0 
var time_multiplier: float

@onready var env = $"../WorldEnvironment".environment

func _ready():
	time_multiplier = TAU / day_length_seconds

func _process(delta):
	rotate_x(time_multiplier * delta)
	
	var sun_height = -global_transform.basis.z.y 
	var energy = clamp(-sun_height, 0.02, 1.0)
	
	env.background_energy_multiplier = energy
	env.ambient_light_energy = energy
