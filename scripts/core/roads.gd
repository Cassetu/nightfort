extends RefCounted

const BloodTerrain = preload("res://scripts/blood_terrain.gd")

const BOOST := 1.15
const PIT_REACH := 250.0
const CACHE_LIMIT := 6000

static var terrain
static var cache: Dictionary = {}


static func factor(pos: Vector3) -> float:
	if BloodTerrain.origin != Vector3.ZERO:
		var local := Vector2(pos.x - BloodTerrain.origin.x, pos.z - BloodTerrain.origin.z)
		if absf(local.x) < PIT_REACH and absf(local.y) < PIT_REACH and absf(pos.y - BloodTerrain.origin.y) < 120.0:
			return BOOST if BloodTerrain.road_lateral(local.x, local.y) < 0.0 else 1.0
	if terrain == null or not is_instance_valid(terrain):
		return 1.0
	var cell := Vector2i(floori(pos.x), floori(pos.z))
	if cache.has(cell):
		var cached: float = cache[cell]
		return cached
	if cache.size() > CACHE_LIMIT:
		cache.clear()
	var value: float = BOOST if terrain.is_road(cell.x, cell.y) else 1.0
	cache[cell] = value
	return value


static func register(node: Node) -> void:
	terrain = node
	cache.clear()


static func unregister(node: Node) -> void:
	if terrain == node:
		terrain = null
		cache.clear()
