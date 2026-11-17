extends "res://scripts/enemies/gloom.gd"

const BileSack = preload("res://scripts/enemies/bile_sack.gd")
const BlockIndex = preload("res://scripts/block_index.gd")
const TileArt = preload("res://scripts/tile_art.gd")

const LOB_RANGE := 30.0
const STAND_OFF := 22.0
const LOB_COOLDOWN := 4.5
const WINDUP := 0.35
const RETARGET := 1.2
const MIN_FLIGHT := 0.9
const MAX_FLIGHT := 2.1
const FLIGHT_PER_UNIT := 0.07
const LOB_GRAVITY := 22.0
const CORE_PREFERENCE := 0.25
const PICK_POOL := 3
const SPITTER_HEALTH := 0.75
const SPITTER_SPEED := 0.9
const MELEE_DAMAGE := 6
const SAC_COLOR := Color(0.36, 0.2, 0.46)
const SAC_GLOW := Color(0.6, 0.3, 0.8)

var lob_timer: float = 0.0
var retarget_timer: float = 0.0
var target_pos := Vector3.INF
var sac: MeshInstance3D
var swell: Tween


func _ready() -> void:
	super()
	add_to_group("spitter")
	lob_timer = randf_range(1.0, LOB_COOLDOWN)
	_build_sac()


func setup(f, c, p, night: int) -> void:
	super(f, c, p, night)
	health *= SPITTER_HEALTH
	speed_mult *= SPITTER_SPEED


func _build_sac() -> void:
	var mat: StandardMaterial3D = TileArt.block_material("bile", SAC_COLOR).duplicate()
	mat.emission_enabled = true
	mat.emission_texture = mat.albedo_texture
	mat.emission = SAC_GLOW
	mat.emission_energy_multiplier = 1.6
	var ball := SphereMesh.new()
	ball.radius = 0.32
	ball.height = 0.64
	ball.radial_segments = 8
	ball.rings = 4
	ball.material = mat
	sac = MeshInstance3D.new()
	sac.mesh = ball
	sac.position = Vector3(0.0, 1.55, 0.3)
	sac.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sac.add_to_group(GloomBake.KEEP_GROUP)
	body.add_child(sac)


func _hunt_ai() -> Array:
	var desired := Vector3.ZERO
	var facing := Vector3.ZERO

	if is_instance_valid(player) and not player.dead:
		var to_player: Vector3 = player.global_position - global_position
		var flat_player := Vector3(to_player.x, 0.0, to_player.z)
		if flat_player.length() < PLAYER_REACH and absf(to_player.y) < 2.2:
			facing = flat_player
			if attack_timer <= 0.0:
				player.take_damage(MELEE_DAMAGE, global_position)
				attack_timer = ATTACK_INTERVAL
				_lunge()
			return [desired, facing]

	retarget_timer -= get_physics_process_delta_time()
	if retarget_timer <= 0.0 or not target_pos.is_finite():
		retarget_timer = RETARGET
		target_pos = _pick_target()

	if target_pos.is_finite():
		var to_target := target_pos - global_position
		var flat := Vector3(to_target.x, 0.0, to_target.z)
		facing = flat
		if flat.length() > STAND_OFF:
			desired = _advance()
			facing = desired
		else:
			lob_timer -= get_physics_process_delta_time() * float(_stride())
			if lob_timer <= 0.0 and stun <= 0.0:
				lob_timer = LOB_COOLDOWN
				_wind_up(target_pos)
	else:
		desired = _advance()
		facing = desired
	return [desired, facing]


func _advance() -> Vector3:
	if flow != null:
		return flow.direction_at(global_position)
	return Vector3.ZERO


func _pick_target() -> Vector3:
	var from := global_position
	var limit := LOB_RANGE * LOB_RANGE
	var territory := get_tree().get_first_node_in_group("territory")
	var pool: Array = []
	for b in BlockIndex.list:
		if not is_instance_valid(b) or b.dying or not b.structural or b.is_in_group("torch"):
			continue
		var d2 := from.distance_squared_to(b.global_position)
		if d2 > limit:
			continue
		if territory != null and not territory.contains(b.global_position):
			continue
		pool.append([d2, b.global_position])
	if is_instance_valid(core) and from.distance_squared_to(core.global_position) <= limit:
		if pool.is_empty() or randf() < CORE_PREFERENCE:
			return core.global_position
	if pool.is_empty():
		return Vector3.INF
	pool.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var pick: Array = pool[randi() % mini(PICK_POOL, pool.size())]
	return pick[1]


func _wind_up(point: Vector3) -> void:
	anim.speed_scale = 1.0
	anim.play("slam", 0.05)
	if swell != null:
		swell.kill()
	sac.scale = Vector3.ONE
	swell = create_tween()
	swell.tween_property(sac, "scale", Vector3.ONE * 1.8, WINDUP)
	swell.tween_property(sac, "scale", Vector3.ONE, 0.25)
	get_tree().create_timer(WINDUP).timeout.connect(_release.bind(point))


func _release(point: Vector3) -> void:
	if dying or not is_inside_tree():
		return
	var origin := sac.global_position + Vector3(0.0, 0.3, 0.0)
	var aim := point + Vector3(0.0, 0.5, 0.0)
	var offset := aim - origin
	var flat := Vector2(offset.x, offset.z).length()
	var flight := clampf(MIN_FLIGHT + flat * FLIGHT_PER_UNIT, MIN_FLIGHT, MAX_FLIGHT)
	var v := Vector3(offset.x / flight, offset.y / flight + 0.5 * LOB_GRAVITY * flight, offset.z / flight)
	BileSack.drop(self, origin, v, true)
