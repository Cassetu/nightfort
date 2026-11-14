extends CanvasLayer

const STRIP_WIDTH := 600.0
const TIC_X := 150.0

@onready var sun = $"../Sun"
@onready var strip_a = $TimeBar/Timeline
@onready var strip_b = $TimeBar/Timeline2
@onready var counts = $Counts
@onready var crosshair: ColorRect = $Crosshair

const CROSSHAIR_IDLE := Color(1.0, 1.0, 1.0, 0.75)
const CROSSHAIR_ALERT := Color(1.0, 0.15, 0.15, 0.95)
const SCAN_INTERVAL := 0.1
const SCAN_WIDTH := 1.0
const BOW_RANGE := 24.0
const ENEMY_GROUPS := ["enemy", "wild_gloom", "gloom_bird", "boss"]

var scan_timer: float = 0.0
var player_node = null


func _ready():
	Inventory.changed.connect(_on_inventory_changed)
	_refresh_counts()


func _process(delta):
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_INTERVAL
		crosshair.color = CROSSHAIR_ALERT if _enemy_in_range() else CROSSHAIR_IDLE
	var base = fposmod(TIC_X - sun.day_phase * STRIP_WIDTH, STRIP_WIDTH) - STRIP_WIDTH
	strip_a.position.x = base
	strip_b.position.x = base + STRIP_WIDTH


func _on_inventory_changed():
	_refresh_counts()


func _refresh_counts():
	var lines = ["Wood: %d" % Inventory.get_count("wood"), "Stone: %d" % Inventory.get_count("stone")]
	for item in ["dirt", "sand", "snow", "coal", "iron"]:
		var have = Inventory.get_count(item)
		if have > 0:
			lines.append("%s: %d" % [item.capitalize(), have])
	counts.text = "\n".join(lines)



func _enemy_in_range() -> bool:
	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
		if player_node == null:
			return false
	var cam: Camera3D = player_node.camera
	if cam == null:
		return false
	var reach: float = 2.6
	var weapon: Dictionary = Inventory.held_weapon()
	var held_slot: Dictionary = Inventory.slots[Inventory.selected]
	if weapon.has("reach"):
		reach = float(weapon["reach"])
	elif not held_slot.is_empty() and held_slot["id"] == "bow":
		reach = BOW_RANGE
	var origin: Vector3 = cam.global_position
	var forward: Vector3 = -cam.global_transform.basis.z
	for group: String in ENEMY_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if not (node is Node3D) or not is_instance_valid(node):
				continue
			var to: Vector3 = (node as Node3D).global_position + Vector3(0.0, 0.9, 0.0) - origin
			var along: float = to.dot(forward)
			if along < 0.0 or along > reach:
				continue
			if (to - forward * along).length() <= SCAN_WIDTH:
				return true
	return false
