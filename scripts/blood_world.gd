extends Node3D

signal army_changed(count: int)

const BloodTerrain = preload("res://scripts/blood_terrain.gd")
const FleshWall = preload("res://scripts/flesh_wall.gd")
const PitGloom = preload("res://scripts/pit_gloom.gd")
const PitSpitter = preload("res://scripts/pit_spitter.gd")
const Ally = preload("res://scripts/ally.gd")
const BileSack = preload("res://scripts/enemies/bile_sack.gd")
const GloomScene = preload("res://scenes/gloom.tscn")
const SkyShader = preload("res://resources/blood_sky.gdshader")

const WALL_SIZE := Vector3(9.4, 10.0, 3.0)
const SEGMENT := 9.0
const SPITTER_EVERY := 6
const GLOOM_COUNTS := [8, 10, 14]
const INNER_GLOOM := 6
const SOLDIERS := 13
const ARCHERS := 5
const LANDING_Z := -165.0
const FLASH_MIN := 5.0
const FLASH_MAX := 11.0
const PRESSURE_START := 80.0
const PRESSURE_RAMP := 120.0
const DRAIN_START := 150.0
const DRAIN_AMOUNT := 3
const RAIN_AMOUNT := 1600
const TREE_COUNT := 220
const SPIKE_COUNT := 140
const MOUND_COUNT := 90
const FLESH := Color(0.55, 0.16, 0.2)

var origin: Vector3 = Vector3.ZERO
var gen
var ground: StaticBody3D
var player: Node3D
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var heart: Node3D
var heart_light: OmniLight3D
var heart_mat: StandardMaterial3D
var rain: GPUParticles3D
var walls: Array = [[], [], []]
var soldiers: Array = []
var archers: Array = []
var odrick
var heart_position: Vector3 = Vector3.ZERO
var landing: Vector3 = Vector3.ZERO
var commanded: bool = false
var command_time: float = 0.0
var flash_timer: float = 6.0
var flash_tween: Tween
var drain_timer: float = 0.0
var last_count: int = -1


func build(host: Node, who: Node3D, at: Vector3) -> void:
	player = who
	origin = at
	BloodTerrain.origin = at
	host.add_child(self)
	global_position = at
	gen = BloodTerrain.new()
	ground = gen.build(self)
	heart_position = at + Vector3(0.0, BloodTerrain.PAD_H, 0.0)
	var landing_y: float = gen.height(0.0, LANDING_Z)
	landing = at + Vector3(0.0, landing_y + 0.3, LANDING_Z)
	_make_environment()
	_make_light()
	_make_rain()
	_build_heart()
	_build_walls()
	_build_gloom()
	_scatter()
	_build_army()
	_schedule_flash()


func _make_environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.2, 0.32)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.05, 0.12)
	env.fog_density = 0.005
	env.fog_sky_affect = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.6


func _make_light() -> void:
	sun = DirectionalLight3D.new()
	sun.light_color = Color(0.9, 0.3, 0.4)
	sun.light_energy = 0.55
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-48.0, 30.0, 0.0)
	add_child(sun)


func _make_rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = RAIN_AMOUNT
	rain.lifetime = 1.2
	rain.preprocess = 1.2
	rain.visibility_aabb = AABB(Vector3(-40.0, -30.0, -40.0), Vector3(80.0, 40.0, 80.0))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30.0, 0.5, 30.0)
	pm.direction = Vector3(0.12, -1.0, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 26.0
	pm.initial_velocity_max = 32.0
	pm.gravity = Vector3(0.0, -6.0, 0.0)
	rain.process_material = pm
	var streak := BoxMesh.new()
	streak.size = Vector3(0.02, 0.75, 0.02)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.08, 0.1, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.material = mat
	rain.draw_pass_1 = streak
	add_child(rain)


func _build_heart() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = Vector3(0.0, BloodTerrain.PAD_H + 5.5, 0.0)
	add_child(body)
	heart = body
	heart_mat = StandardMaterial3D.new()
	heart_mat.albedo_color = Color(0.5, 0.05, 0.1)
	heart_mat.roughness = 0.3
	heart_mat.emission_enabled = true
	heart_mat.emission = Color(0.6, 0.05, 0.1)
	heart_mat.emission_energy_multiplier = 1.2
	var core := SphereMesh.new()
	core.radius = 5.0
	core.height = 9.0
	core.material = heart_mat
	var core_node := MeshInstance3D.new()
	core_node.mesh = core
	body.add_child(core_node)
	for i in 5:
		var lobe := SphereMesh.new()
		lobe.radius = randf_range(1.6, 2.6)
		lobe.height = lobe.radius * 1.8
		lobe.material = heart_mat
		var lobe_node := MeshInstance3D.new()
		lobe_node.mesh = lobe
		var a := TAU * float(i) / 5.0
		lobe_node.position = Vector3(cos(a) * 3.8, randf_range(0.5, 3.5), sin(a) * 3.8)
		body.add_child(lobe_node)
	var vein_mat := StandardMaterial3D.new()
	vein_mat.albedo_color = Color(0.3, 0.08, 0.4)
	vein_mat.emission_enabled = true
	vein_mat.emission = Color(0.36, 0.2, 0.46)
	vein_mat.emission_energy_multiplier = 1.5
	for i in 8:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.6
		cyl.height = 14.0
		cyl.material = vein_mat
		var vn := MeshInstance3D.new()
		vn.mesh = cyl
		var a2 := TAU * float(i) / 8.0 + 0.2
		vn.position = Vector3(cos(a2) * 7.0, -2.0, sin(a2) * 7.0)
		vn.rotation = Vector3(sin(a2) * 0.9, 0.0, -cos(a2) * 0.9)
		body.add_child(vn)
	var cs := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 5.4
	cs.shape = ball
	body.add_child(cs)
	heart_light = OmniLight3D.new()
	heart_light.light_color = Color(1.0, 0.15, 0.22)
	heart_light.light_energy = 3.0
	heart_light.omni_range = 70.0
	body.add_child(heart_light)
	var beat := create_tween().set_loops()
	beat.tween_property(body, "scale", Vector3.ONE * 1.09, 0.16)
	beat.tween_property(body, "scale", Vector3.ONE, 0.22)
	beat.tween_property(body, "scale", Vector3.ONE * 1.05, 0.12)
	beat.tween_property(body, "scale", Vector3.ONE, 0.2)
	beat.tween_interval(0.7)


func _wall_mesh(seed_value: int, material: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var tone: float = rng.randf_range(0.85, 1.1)
	BloodTerrain.append_box(v, n, c, idx, Vector3.ZERO, WALL_SIZE * 0.5, Basis.IDENTITY, FLESH * tone)
	BloodTerrain.append_box(v, n, c, idx, Vector3(0.0, -3.0, 0.0), Vector3(4.8, 2.0, 2.0), Basis.IDENTITY, Color(0.32, 0.09, 0.13))
	for i in 4:
		var side: float = 1.0 if rng.randf() < 0.5 else -1.0
		var half := Vector3(rng.randf_range(0.7, 1.4), rng.randf_range(0.7, 1.5), 0.7)
		var pos := Vector3(rng.randf_range(-3.5, 3.5), rng.randf_range(-3.0, 3.5), side * 1.6)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.6, 0.6)))
		BloodTerrain.append_box(v, n, c, idx, pos, half, basis, Color(0.72, 0.3, 0.34))
	for i in 3:
		var side2: float = 1.0 if i % 2 == 0 else -1.0
		var x: float = rng.randf_range(-3.8, 3.8)
		BloodTerrain.append_box(v, n, c, idx, Vector3(x, 0.5, side2 * 1.55), Vector3(0.13, rng.randf_range(2.5, 4.2), 0.06), Basis.IDENTITY, Color(0.4, 0.14, 0.5))
	for i in 3:
		var x2: float = -3.5 + float(i) * 3.5 + rng.randf_range(-0.5, 0.5)
		BloodTerrain.append_box(v, n, c, idx, Vector3(x2, 5.4, 0.0), Vector3(0.3, rng.randf_range(0.6, 1.2), 0.3), Basis.from_euler(Vector3(0.0, 0.0, rng.randf_range(-0.3, 0.3))), Color(0.9, 0.86, 0.78))
	return BloodTerrain.to_mesh(v, n, c, idx, material)


func _build_walls() -> void:
	var material := BloodTerrain.detail_material("gloom_flesh")
	var variants: Array = []
	for i in 4:
		variants.append(_wall_mesh(100 + i, material))
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var base_y: float = BloodTerrain.PAD_H + 4.0
	for ring in BloodTerrain.RINGS.size():
		var r: float = BloodTerrain.RINGS[ring]
		var count := roundi(TAU * r / SEGMENT)
		for i in count:
			var a := TAU * float(i) / float(count)
			var wall = FleshWall.new()
			wall.setup(ring, variants[rng.randi() % variants.size()], WALL_SIZE)
			add_child(wall)
			wall.position = Vector3(cos(a) * r, base_y, sin(a) * r)
			wall.rotation.y = atan2(-cos(a), -sin(a))
			walls[ring].append(wall)
			if i % SPITTER_EVERY == 0:
				var spitter = PitSpitter.new()
				add_child(spitter)
				spitter.position = Vector3(cos(a) * r, BloodTerrain.PAD_H + 9.0, sin(a) * r)
				wall.rider = spitter


func _spawn_gloom(local: Vector3) -> void:
	var g: CharacterBody3D = GloomScene.instantiate()
	g.set_script(PitGloom)
	add_child(g)
	g.position = local
	g.rotation.y = randf() * TAU


func _build_gloom() -> void:
	for ring in BloodTerrain.RINGS.size():
		var r: float = BloodTerrain.RINGS[ring]
		var count: int = GLOOM_COUNTS[ring]
		for i in count:
			var a := TAU * (float(i) + randf_range(-0.3, 0.3)) / float(count)
			var rr := r - randf_range(3.5, 8.0)
			_spawn_gloom(Vector3(cos(a) * rr, BloodTerrain.PAD_H + 1.0, sin(a) * rr))
	for i in INNER_GLOOM:
		var a2 := TAU * float(i) / float(INNER_GLOOM)
		_spawn_gloom(Vector3(cos(a2) * 15.0, BloodTerrain.PAD_H + 1.0, sin(a2) * 15.0))


func _tree_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var bark := Color(0.2, 0.14, 0.15)
	BloodTerrain.append_box(v, n, c, idx, Vector3(0.0, 3.2, 0.0), Vector3(0.28, 3.2, 0.28), Basis.from_euler(Vector3(0.05, 0.0, 0.08)), bark)
	for i in 6:
		var y: float = 3.0 + float(i) * 0.7
		var yaw: float = float(i) * 1.7
		var tilt: float = rng.randf_range(0.7, 1.2)
		var len: float = rng.randf_range(0.9, 1.9) - float(i) * 0.1
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)) * Basis.from_euler(Vector3(0.0, 0.0, tilt))
		var center := Vector3(0.0, y, 0.0) + basis * Vector3(len, 0.0, 0.0)
		BloodTerrain.append_box(v, n, c, idx, center, Vector3(len, 0.08, 0.08), basis, bark)
	return BloodTerrain.to_mesh(v, n, c, idx, BloodTerrain.detail_material("stone"))


func _spike_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	BloodTerrain.append_box(v, n, c, idx, Vector3(0.0, 1.8, 0.0), Vector3(0.22, 1.8, 0.22), Basis.from_euler(Vector3(0.12, 0.0, 0.1)), Color(0.88, 0.84, 0.74))
	BloodTerrain.append_box(v, n, c, idx, Vector3(0.0, 3.4, 0.0), Vector3(0.1, 0.9, 0.1), Basis.from_euler(Vector3(0.12, 0.0, 0.2)), Color(0.92, 0.88, 0.78))
	return BloodTerrain.to_mesh(v, n, c, idx, BloodTerrain.detail_material("stone"))


func _mound_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	BloodTerrain.append_box(v, n, c, idx, Vector3(0.0, 0.3, 0.0), Vector3(1.6, 0.5, 1.4), Basis.IDENTITY, Color(0.6, 0.14, 0.18))
	BloodTerrain.append_box(v, n, c, idx, Vector3(0.2, 0.8, 0.1), Vector3(0.9, 0.4, 0.8), Basis.from_euler(Vector3(0.0, 0.5, 0.0)), Color(0.74, 0.26, 0.3))
	return BloodTerrain.to_mesh(v, n, c, idx, BloodTerrain.detail_material("gloom_flesh"))


func _spot(rng: RandomNumberGenerator, min_heart: float) -> Vector3:
	for attempt in 30:
		var x: float = rng.randf_range(-235.0, 235.0)
		var z: float = rng.randf_range(-235.0, 235.0)
		var p := Vector2(x, z)
		if p.length() < min_heart or p.distance_to(BloodTerrain.ARMY) < 48.0:
			continue
		var h: float = gen.height(x, z)
		if h < BloodTerrain.POOL_LEVEL + 0.8:
			continue
		var slope: float = absf(gen.height(x + 2.0, z) - gen.height(x - 2.0, z)) / 4.0
		if slope > 0.7:
			continue
		return Vector3(x, h, z)
	return Vector3(INF, INF, INF)


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	var trees := MultiMesh.new()
	trees.transform_format = MultiMesh.TRANSFORM_3D
	trees.mesh = _tree_mesh()
	var placed: Array = []
	for i in TREE_COUNT:
		var p := _spot(rng, 150.0)
		if not p.is_finite():
			continue
		placed.append([p, rng.randf_range(0.8, 1.6), rng.randf() * TAU])
	trees.instance_count = placed.size()
	var bodies := StaticBody3D.new()
	bodies.collision_layer = 1
	add_child(bodies)
	for i in placed.size():
		var entry: Array = placed[i]
		var p2: Vector3 = entry[0]
		var s: float = entry[1]
		var t := Transform3D(Basis(Vector3.UP, entry[2]).scaled(Vector3.ONE * s), p2 - Vector3(0.0, 0.3, 0.0))
		trees.set_instance_transform(i, t)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.5 * s
		cyl.height = 6.0 * s
		cs.shape = cyl
		cs.position = p2 + Vector3(0.0, 3.0 * s, 0.0)
		bodies.add_child(cs)
	var tree_node := MultiMeshInstance3D.new()
	tree_node.multimesh = trees
	add_child(tree_node)
	_scatter_decor(_spike_mesh(), SPIKE_COUNT, 60.0, 0.8, 1.7, rng)
	_scatter_decor(_mound_mesh(), MOUND_COUNT, 30.0, 0.7, 1.6, rng)


func _scatter_decor(mesh: Mesh, count: int, min_heart: float, smin: float, smax: float, rng: RandomNumberGenerator) -> void:
	var spots: Array = []
	for i in count:
		var p := _spot(rng, min_heart)
		if p.is_finite() and not (Vector2(p.x, p.z).length() < 140.0 and Vector2(p.x, p.z).length() > 40.0):
			spots.append(p)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = spots.size()
	for i in spots.size():
		var s := rng.randf_range(smin, smax)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(basis, spots[i] - Vector3(0.0, 0.2, 0.0)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	add_child(node)


func _spawn_ally(role: String, local_x: float, local_z: float, yaw: float):
	var a = Ally.new()
	add_child(a)
	a.setup(role, self)
	a.position = Vector3(local_x, gen.height(local_x, local_z) + 0.4, local_z)
	a.rotation.y = yaw
	a.fell.connect(_on_fell)
	return a


func _build_army() -> void:
	var z0: float = LANDING_Z - 5.0
	for i in SOLDIERS:
		var row := 0 if i < 7 else 1
		var col := i if i < 7 else i - 7
		var count := 7 if row == 0 else 6
		var x := (float(col) - float(count - 1) * 0.5) * 4.0
		soldiers.append(_spawn_ally("soldier", x, z0 - row * 3.5, PI))
	for i in ARCHERS:
		var x2 := (float(i) - 2.0) * 4.5
		archers.append(_spawn_ally("archer", x2, z0 - 9.0, PI))
	odrick = _spawn_ally("commander", 2.8, LANDING_Z + 4.5, 0.0)


func _on_fell(_unit: Node3D) -> void:
	army_changed.emit(alive_count())


func alive_count() -> int:
	return get_tree().get_nodes_in_group("ally_unit").size()


func command() -> void:
	commanded = true
	command_time = 0.0
	for a in get_tree().get_nodes_in_group("ally_unit"):
		a.command()
	army_changed.emit(alive_count())


func odrick_rejoin() -> void:
	if not is_instance_valid(odrick):
		return
	odrick.goto_point = to_global(Vector3(3.5, 0.0, LANDING_Z - 8.0))
	odrick.has_goto = true


func odrick_walking() -> bool:
	return is_instance_valid(odrick) and odrick.has_goto


func distance_from_heart(pos: Vector3) -> float:
	return Vector2(pos.x - origin.x, pos.z - origin.z).length()


func ring_for(pos: Vector3) -> int:
	var b: int = BloodTerrain.band(pos)
	return b if b < BloodTerrain.RINGS.size() else -1


func nearest_wall(ring: int, pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for w in walls[ring]:
		var d: float = pos.distance_squared_to(w.global_position)
		if d < best_d:
			best_d = d
			best = w
	return best


func nearest_gloom(pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius * radius
	var band: int = BloodTerrain.band(pos)
	for g in get_tree().get_nodes_in_group("pit_gloom"):
		if not is_instance_valid(g) or BloodTerrain.band(g.global_position) != band:
			continue
		var d := pos.distance_squared_to(g.global_position)
		if d < best_d:
			best_d = d
			best = g
	return best


func nearest_spitter(pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius * radius
	for s in get_tree().get_nodes_in_group("pit_spitter"):
		if not is_instance_valid(s):
			continue
		var d := pos.distance_squared_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func support_point(pos: Vector3, gap: float) -> Vector3:
	var front: Node3D = null
	var best := INF
	for s in soldiers:
		if not is_instance_valid(s) or s.dead:
			continue
		var d := distance_from_heart(s.global_position)
		if d < best:
			best = d
			front = s
	if front == null:
		return pos
	var out := front.global_position - heart_position
	out.y = 0.0
	out = out.normalized()
	var side := Vector3(-out.z, 0.0, out.x)
	var lane := float(posmod(int(pos.x), 7)) - 3.0
	return front.global_position + out * gap + side * lane * 1.2


func _schedule_flash() -> void:
	flash_timer = randf_range(FLASH_MIN, FLASH_MAX)


func _flash() -> void:
	if flash_tween != null:
		flash_tween.kill()
	flash_tween = create_tween()
	for i in 2:
		flash_tween.tween_method(_set_flash, 0.0, 1.0, 0.05)
		flash_tween.tween_method(_set_flash, 1.0, 0.15, 0.1)
	flash_tween.tween_method(_set_flash, 0.5, 0.0, 0.5)


func _set_flash(value: float) -> void:
	sky_mat.set_shader_parameter("flash", value)
	sun.light_energy = 0.55 + value * 1.6


func pressure() -> float:
	if not commanded:
		return 0.0
	return clampf((command_time - PRESSURE_START) / PRESSURE_RAMP, 0.0, 1.0)


func pulse_heart(strength: float) -> void:
	var tween := create_tween()
	tween.tween_property(heart_light, "light_energy", 3.0 + strength, 0.2)
	tween.tween_property(heart_light, "light_energy", 3.0, 1.2)


func _process(delta: float) -> void:
	if is_instance_valid(player) and rain != null:
		rain.global_position = player.global_position + Vector3(0.0, 18.0, 0.0)
	flash_timer -= delta
	if flash_timer <= 0.0:
		_schedule_flash()
		_flash()
	if commanded:
		command_time += delta
		var p := pressure()
		PitGloom.pressure = p
		PitSpitter.pressure = p
		BileSack.unit_scale = 1.0 + p * 0.5
		if command_time > DRAIN_START:
			drain_timer += delta
			if drain_timer >= 1.0:
				drain_timer = 0.0
				for a in get_tree().get_nodes_in_group("ally_unit"):
					a.take_damage(DRAIN_AMOUNT)
	var count := alive_count()
	if count != last_count:
		last_count = count
		army_changed.emit(count)


func _exit_tree() -> void:
	PitGloom.pressure = 0.0
	PitSpitter.pressure = 0.0
	BileSack.unit_scale = 1.0
