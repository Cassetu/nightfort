extends CanvasLayer

const ARROWS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
const MARGIN := Vector2(90.0, 70.0)
const MARKER_LIFT := 6.0

@onready var labels: Array = [%A, %B]

var spawner
var core
var terrain


func setup(s, c, t) -> void:
	spawner = s
	core = c
	terrain = t


func _process(_delta: float) -> void:
	var dirs: Array = spawner.attack_dirs if spawner != null else []
	var cam := get_viewport().get_camera_3d()
	for i in labels.size():
		var label: Label = labels[i]
		if i >= dirs.size() or cam == null or not is_instance_valid(core):
			label.visible = false
			continue
		_place(label, cam, float(dirs[i]))


func _place(label: Label, cam: Camera3D, angle: float) -> void:
	var c: Vector3 = core.global_position
	var radius: float = spawner.spawn_radius
	var p := Vector3(c.x + cos(angle) * radius, 0.0, c.z + sin(angle) * radius)
	p.y = terrain.height_at(p.x, p.z) + MARKER_LIFT
	var dist := cam.global_position.distance_to(p)
	var view := get_viewport().get_visible_rect().size
	var center := view * 0.5
	var behind := cam.is_position_behind(p)
	var sp := cam.unproject_position(p)
	if behind:
		sp = center - (sp - center)
	var on_screen := not behind and sp.x > MARGIN.x and sp.x < view.x - MARGIN.x and sp.y > MARGIN.y and sp.y < view.y - MARGIN.y
	var arrow := "▼"
	if not on_screen:
		var dir := sp - center
		if dir.length() < 1.0:
			dir = Vector2.UP
		var k := minf((center.x - MARGIN.x) / maxf(absf(dir.x), 0.001), (center.y - MARGIN.y) / maxf(absf(dir.y), 0.001))
		sp = center + dir * k
		var slot := int(roundf(dir.angle() / (TAU / 8.0)))
		arrow = ARROWS[posmod(slot, 8)]
	var text := "Gloom %du\n%s" % [roundi(dist), arrow]
	if text != label.text:
		label.text = text
		label.reset_size()
	label.visible = true
	if on_screen:
		label.position = sp - Vector2(label.size.x * 0.5, label.size.y)
	else:
		label.position = sp - label.size * 0.5
