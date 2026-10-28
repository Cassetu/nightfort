extends CanvasLayer

const STRIP_WIDTH := 600.0
const TIC_X := 150.0

@onready var sun = $"../Sun"
@onready var strip_a = $TimeBar/Timeline
@onready var strip_b = $TimeBar/Timeline2

func _process(_delta):
	var base = fposmod(TIC_X - sun.day_phase * STRIP_WIDTH, STRIP_WIDTH) - STRIP_WIDTH
	strip_a.position.x = base
	strip_b.position.x = base + STRIP_WIDTH
