extends Node

const TICK := 0.5
const GROUPS := ["enemy", "wild_gloom", "player", "troop"]
const HALF := 0.45
const RADIUS := 0.4
const HEIGHT := 1.7
const BOX_LOW := 0.05
const BOX_HIGH := 0.95

static var cells: Dictionary = {}
static var instance: Node

var timer: float = 0.0


static func register(barricade: Node3D) -> void:
	if not barricade.is_inside_tree():
		return
	if instance == null or not is_instance_valid(instance):
		cells.clear()
		instance = Node.new()
		instance.set_script(load("res://scripts/allies/barricade_hub.gd"))
		barricade.get_tree().current_scene.add_child(instance)
	var p := barricade.global_position
	var key := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	cells[key] = barricade
	barricade.set_meta("hub_cell", key)


static func unregister(barricade: Node) -> void:
	if not barricade.has_meta("hub_cell"):
		return
	var key: Vector3i = barricade.get_meta("hub_cell")
	if cells.get(key) == barricade:
		cells.erase(key)
	barricade.remove_meta("hub_cell")


func _physics_process(delta: float) -> void:
	timer += delta
	if timer < TICK:
		return
	timer = 0.0
	if cells.is_empty():
		return
	var reach := HALF + RADIUS
	for group in GROUPS:
		for body in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(body):
				continue
			var p: Vector3 = body.global_position
			var top := p.y + HEIGHT
			for y in range(floori(p.y) - 1, floori(top) + 1):
				for z in range(floori(p.z - reach), floori(p.z + reach) + 1):
					for x in range(floori(p.x - reach), floori(p.x + reach) + 1):
						var b = cells.get(Vector3i(x, y, z))
						if b == null or not is_instance_valid(b) or b.dying:
							continue
						if absf(p.x - (float(x) + 0.5)) >= reach or absf(p.z - (float(z) + 0.5)) >= reach:
							continue
						if p.y >= float(y) + BOX_HIGH or top <= float(y) + BOX_LOW:
							continue
						b.strike(body)
