extends CanvasLayer

@onready var sun = $"../Sun" 
@onready var timeline = $TimeBar/Timeline

func _process(_delta):
	var cycle = wrapf(sun.rotation.x / TAU, 0.0, 1.0)
	timeline.position.x = 150 - (cycle * 600.0)
