extends Node3D

signal army_changed(count: int)

const BloodTerrain = preload("res://scripts/blood_terrain.gd")
const FleshBlock = preload("res://scripts/flesh_block.gd")
const PitGloom = preload("res://scripts/pit_gloom.gd")
const PitSpitter = preload("res://scripts/pit_spitter.gd")
const WALL_CLAIM_COST := 9.0
const BoneBarricade = preload("res://scripts/enemies/bone_barricade.gd")
const PitFlora = preload("res://scripts/pit_flora.gd")
const MerlonMesh = preload("res://scripts/blocks/merlon_mesh.gd")
const Ally = preload("res://scripts/ally.gd")
const BileSack = preload("res://scripts/enemies/bile_sack.gd")
const GloomScene = preload("res://scenes/gloom.tscn")
const TileArt = preload("res://scripts/tile_art.gd")
const SkyShader = preload("res://resources/blood_sky.gdshader")

const BLOCK := 1.0
const LAYERS := 6
const GATE_LAYERS := 2
const WALL_TILE := "gloom_flesh"
const SPITTER_EVERY := 14
const GLOOM_COUNTS := [60, 48, 36]
const PACK_SIZE := 6
const PACK_SPREAD := 2.6
const PACK_DEPTH_MIN := 7.0
const PACK_DEPTH_MAX := 14.0
const PACK_INNER_LIMIT := 4.8
const WALL_ROWS := 3
const ACTIVATE_R2 := 2.2
const BONE_BAND_MIN := 1.5
const BONE_BAND_MAX := 3.5
const BONE_CHANCE := 0.4
const BONE_BUCKET := 4.0
const BONE_DAMAGE := 3
const BONE_TICK := 0.5
const BONE_RADIUS := 0.85
const BONE_AVOID := 1.3
const BONE_COLOR := Color(0.78, 0.74, 0.62)
const INNER_GLOOM := 14
const SOLDIERS := 32
const ARCHERS := 10
const DOOM_MARGIN := 8.0
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
const HEARTBEAT_PATH := "res://audio/sfx/heartbeat.mp3"
const HEARTBEAT_NEAR := 6.0
const HEARTBEAT_FAR := 180.0
const HEARTBEAT_QUIET_DB := -26.0
const HEARTBEAT_CURVE := 0.8
const HEARTBEAT_SMOOTH := 6.0

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
var heartbeat: AudioStreamPlayer
var columns: Array = [{}, {}, {}]
var pending: Array = []
var wall_shape: BoxShape3D
var wall_meshes: Array = []
var bones: Dictionary = {}
var bone_tick: float = 0.0
var doomed: bool = false
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


var wall_claims: Dictionary = {}
var gloom_frame: int = -1
var gloom_nodes: Array = []
var gloom_pos := PackedVector3Array()
var gloom_band := PackedInt32Array()


func build(host: Node, who: Node3D, at: Vector3) -> void:
	PitSpitter.released = false
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
	_build_heartbeat()
	_build_walls()
	_build_barricades()
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
	heart_mat.albedo_color = Color(0.85, 0.7, 0.7)
	heart_mat.albedo_texture = TileArt.mip_texture("blood", Color(0.5, 0.05, 0.1))
	heart_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	heart_mat.uv1_scale = Vector3(5.0, 4.0, 1.0)
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


func _build_heartbeat() -> void:
	var stream := load(HEARTBEAT_PATH) as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	heartbeat = AudioStreamPlayer.new()
	heartbeat.stream = stream
	heartbeat.bus = "SFX"
	heartbeat.volume_db = HEARTBEAT_QUIET_DB
	add_child(heartbeat)
	heartbeat.play()


func _update_heartbeat(delta: float) -> void:
	if heartbeat == null or not is_instance_valid(player):
		return
	var d: float = distance_from_heart(player.global_position)
	var t: float = clampf(1.0 - (d - HEARTBEAT_NEAR) / (HEARTBEAT_FAR - HEARTBEAT_NEAR), 0.0, 1.0)
	var target: float = lerpf(HEARTBEAT_QUIET_DB, 0.0, pow(t, HEARTBEAT_CURVE))
	heartbeat.volume_db = lerpf(heartbeat.volume_db, target, minf(HEARTBEAT_SMOOTH * delta, 1.0))


func _block_mesh() -> ArrayMesh:
	var material := TileArt.uv_material(WALL_TILE, FLESH, Vector3.ONE, true)
	return TileArt.box_mesh(Vector3.ONE * BLOCK, material)


func _ring_cells(r: float, lo: float, hi: float) -> Array:
	var cells: Array = []
	var reach := int(ceil(r + hi)) + 1
	for ix in range(-reach, reach + 1):
		for iz in range(-reach, reach + 1):
			var d := Vector2(float(ix) + 0.5, float(iz) + 0.5).length()
			if d >= r + lo and d < r + hi:
				cells.append(Vector2i(ix, iz))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return atan2(float(a.y) + 0.5, float(a.x) + 0.5) < atan2(float(b.y) + 0.5, float(b.x) + 0.5))
	return cells


func _spawn_wall_block(ring: int, column_index: int, layer: int, depth: int, slot: int, pos: Vector3, batch: MultiMesh = null):
	var block = FleshBlock.new()
	block.setup(wall_shape, batch if batch != null else wall_meshes[ring], slot, ring, column_index, layer)
	block.depth = depth
	block.on_break = _on_wall_break
	add_child(block)
	block.position = pos
	return block


func _on_wall_break(broken) -> void:
	if broken.layer >= LAYERS:
		return
	var list: Array = pending[broken.ring][broken.layer]
	for desc: Dictionary in list:
		if desc["depth"] != broken.depth + 1:
			continue
		if (desc["pos"] as Vector3).distance_squared_to(broken.position) > ACTIVATE_R2:
			continue
		if desc["block"] == null:
			desc["block"] = _spawn_wall_block(broken.ring, desc["column"], broken.layer, desc["depth"], desc["slot"], desc["pos"])
			if desc.has("rider"):
				desc["block"].rider = desc["rider"]
		if broken.next_block == null and is_instance_valid(desc["block"]) and not desc["block"].dead:
			broken.next_block = desc["block"]


func _build_walls() -> void:
	var mesh := _block_mesh()
	var merlon_mesh := MerlonMesh.build(TileArt.uv_material(WALL_TILE, FLESH, Vector3.ONE, true))
	wall_shape = BoxShape3D.new()
	wall_shape.size = Vector3.ONE * BLOCK
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var floor_y: float = BloodTerrain.PAD_H
	for ring in BloodTerrain.RINGS.size():
		var r: float = BloodTerrain.RINGS[ring]
		var cells: Array = _ring_cells(r, -0.5, 0.5)
		var inner: Array = _ring_cells(r, -0.5 - float(WALL_ROWS - 1), -0.5)
		var count := cells.size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = (count + inner.size()) * LAYERS
		wall_meshes.append(mm)
		var layer_lists: Array = []
		for layer in LAYERS:
			layer_lists.append([])
		pending.append(layer_lists)
		var holder := MultiMeshInstance3D.new()
		holder.multimesh = mm
		add_child(holder)
		var merlon_mm := MultiMesh.new()
		merlon_mm.transform_format = MultiMesh.TRANSFORM_3D
		merlon_mm.use_colors = true
		merlon_mm.mesh = merlon_mesh
		merlon_mm.instance_count = (count + 1) / 2
		var merlon_holder := MultiMeshInstance3D.new()
		merlon_holder.multimesh = merlon_mm
		add_child(merlon_holder)
		for i in count:
			var cell: Vector2i = cells[i]
			var column: Array = []
			for layer in LAYERS:
				var slot := i * LAYERS + layer
				var pos := Vector3(float(cell.x) + 0.5, floor_y + BLOCK * (float(layer) + 0.5), float(cell.y) + 0.5)
				mm.set_instance_transform(slot, Transform3D(Basis.IDENTITY, pos))
				var tone := rng.randf_range(0.8, 1.15)
				mm.set_instance_color(slot, Color(tone, tone * rng.randf_range(0.85, 1.05), tone))
				column.append(_spawn_wall_block(ring, i, layer, 0, slot, pos))
			if i % 2 == 0:
				var mslot := i / 2
				var mpos := Vector3(float(cell.x) + 0.5, floor_y + BLOCK * (float(LAYERS) + 0.5), float(cell.y) + 0.5)
				merlon_mm.set_instance_transform(mslot, Transform3D(Basis.IDENTITY, mpos))
				var mtone := rng.randf_range(0.85, 1.1)
				merlon_mm.set_instance_color(mslot, Color(mtone, mtone * rng.randf_range(0.85, 1.05), mtone))
				column.append(_spawn_wall_block(ring, i, LAYERS, 0, mslot, mpos, merlon_mm))
			columns[ring][cell] = column
		for j in inner.size():
			var icell: Vector2i = inner[j]
			var d := Vector2(float(icell.x) + 0.5, float(icell.y) + 0.5).length()
			var depth := clampi(int(floor(r + 0.5 - d)), 1, WALL_ROWS - 1)
			for layer in LAYERS:
				var slot2 := (count + j) * LAYERS + layer
				var pos2 := Vector3(float(icell.x) + 0.5, floor_y + BLOCK * (float(layer) + 0.5), float(icell.y) + 0.5)
				mm.set_instance_transform(slot2, Transform3D(Basis.IDENTITY, pos2))
				var tone2 := rng.randf_range(0.7, 1.0)
				mm.set_instance_color(slot2, Color(tone2, tone2 * rng.randf_range(0.85, 1.05), tone2))
				pending[ring][layer].append({"pos": pos2, "depth": depth, "slot": slot2, "column": j, "block": null})
		for i in range(0, count, SPITTER_EVERY):
			var ocell: Vector2i = cells[i]
			var ocenter := Vector2(float(ocell.x) + 0.5, float(ocell.y) + 0.5)
			var behind := ocenter - ocenter.normalized() * BLOCK
			var best_j := -1
			var best_d := INF
			for j in inner.size():
				var jc: Vector2i = inner[j]
				var jp := Vector2(float(jc.x) + 0.5, float(jc.y) + 0.5)
				var jd := Vector2(jp.length() - (r - 1.0), 0.0).length()
				if jd > 0.5:
					continue
				var dist := jp.distance_squared_to(behind)
				if dist < best_d:
					best_d = dist
					best_j = j
			if best_j < 0:
				continue
			var bc: Vector2i = inner[best_j]
			var spitter = PitSpitter.new()
			add_child(spitter)
			spitter.position = Vector3(float(bc.x) + 0.5, floor_y + BLOCK * float(LAYERS), float(bc.y) + 0.5)
			spitter.covered = true
			for desc: Dictionary in pending[ring][LAYERS - 1]:
				if desc["column"] == best_j:
					desc["rider"] = spitter


func _bone_mesh(count: int) -> ArrayMesh:
	var material := TileArt.block_material("bone", BONE_COLOR)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.09
	spike.height = 0.95
	spike.radial_segments = 5
	spike.rings = 1
	var arrays := spike.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 7:
		var a := TAU * float(k) / 7.0 + rng.randf_range(-0.3, 0.3)
		var spot := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.38)
		spot.y = 0.25
		var tilt := Vector3(rng.randf_range(-0.7, 0.7), rng.randf() * TAU, rng.randf_range(-0.7, 0.7))
		if k >= count:
			continue
		var xf := Transform3D(Basis.from_euler(tilt), spot)
		for idx in order:
			st.set_normal(xf.basis * norms[idx])
			st.add_vertex(xf * verts[idx])
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh


func _bucket(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / BONE_BUCKET), floori(p.z / BONE_BUCKET))


func _build_barricades() -> void:
	var stage_meshes: Array = []
	for count: int in BoneBarricade.STAGE_SPIKES:
		stage_meshes.append(_bone_mesh(count))
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for ring in BloodTerrain.RINGS.size():
		var r: float = BloodTerrain.RINGS[ring]
		var spots: Array = []
		for cell: Vector2i in _ring_cells(r, BONE_BAND_MIN, BONE_BAND_MAX):
			if rng.randf() < BONE_CHANCE:
				spots.append(cell)
		var batches: Array = []
		for stage_mesh: ArrayMesh in stage_meshes:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = stage_mesh
			mm.instance_count = spots.size()
			for z_i in spots.size():
				mm.set_instance_transform(z_i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
			var holder := MultiMeshInstance3D.new()
			holder.multimesh = mm
			add_child(holder)
			batches.append(mm)
		for i in spots.size():
			var cell: Vector2i = spots[i]
			var x := float(cell.x) + 0.5
			var z := float(cell.y) + 0.5
			var pos := Vector3(x, gen.height(x, z), z)
			var yaw := rng.randf() * TAU
			var size := rng.randf_range(0.9, 1.25)
			var bone := BoneBarricade.new()
			add_child(bone)
			bone.position = pos
			bone.setup(batches, i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), pos))
			var key := _bucket(bone.global_position)
			if not bones.has(key):
				bones[key] = []
			bones[key].append(bone)


func nearest_barricade(pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius * radius
	var reach := int(ceil(radius / BONE_BUCKET))
	var center := _bucket(pos)
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var key := center + Vector2i(dx, dz)
			if not bones.has(key):
				continue
			for b in bones[key]:
				if not is_instance_valid(b) or b.dead:
					continue
				var d := Vector2(pos.x - b.global_position.x, pos.z - b.global_position.z).length_squared()
				if d < best_d:
					best_d = d
					best = b
	return best


func bone_push(pos: Vector3) -> Vector3:
	var push := Vector3.ZERO
	var center := _bucket(pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := center + Vector2i(dx, dz)
			if not bones.has(key):
				continue
			for b in bones[key]:
				if not is_instance_valid(b) or b.dead:
					continue
				var away := Vector3(pos.x - b.global_position.x, 0.0, pos.z - b.global_position.z)
				var d := away.length()
				if d < BONE_AVOID and d > 0.001:
					push += away / d * (1.0 - d / BONE_AVOID)
	return push


func _bone_under(pos: Vector3) -> Node3D:
	var center := _bucket(pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := center + Vector2i(dx, dz)
			if not bones.has(key):
				continue
			for b in bones[key]:
				if not is_instance_valid(b) or b.dead:
					continue
				if Vector2(pos.x - b.global_position.x, pos.z - b.global_position.z).length() < BONE_RADIUS:
					return b
	return null


func _bone_tick() -> void:
	for a in get_tree().get_nodes_in_group("ally_unit"):
		if not is_instance_valid(a):
			continue
		var b := _bone_under(a.global_position)
		if b != null:
			a.take_damage(BONE_DAMAGE, b.global_position)
	if is_instance_valid(player) and not player.dead:
		var pb := _bone_under(player.global_position)
		if pb != null:
			player.take_damage(BONE_DAMAGE, pb.global_position)


func _spawn_gloom(local: Vector3) -> void:
	var g: CharacterBody3D = GloomScene.instantiate()
	g.set_script(PitGloom)
	add_child(g)
	g.position = local
	g.rotation.y = randf() * TAU


func _build_gloom() -> void:
	for ring in BloodTerrain.RINGS.size():
		var r: float = BloodTerrain.RINGS[ring]
		var packs: int = maxi(GLOOM_COUNTS[ring] / PACK_SIZE, 1)
		for i in packs:
			var a := TAU * (float(i) + randf_range(-0.3, 0.3)) / float(packs)
			var depth := randf_range(PACK_DEPTH_MIN, PACK_DEPTH_MAX)
			var center := Vector2(cos(a), sin(a)) * (r - depth)
			for j in PACK_SIZE:
				var jitter := Vector2.from_angle(randf() * TAU) * randf_range(0.0, PACK_SPREAD)
				var spot := center + jitter
				var radius := clampf(spot.length(), r - 16.0, r - PACK_INNER_LIMIT)
				spot = spot.normalized() * radius
				_spawn_gloom(Vector3(spot.x, BloodTerrain.PAD_H + 1.0, spot.y))
	for i in INNER_GLOOM:
		var a2 := TAU * float(i) / float(INNER_GLOOM)
		_spawn_gloom(Vector3(cos(a2) * 16.0, BloodTerrain.PAD_H + 1.0, sin(a2) * 16.0))


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
	return BloodTerrain.to_mesh(v, n, c, idx, BloodTerrain.detail_material("bone"))


func _mound_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	BloodTerrain.append_box(v, n, c, idx, Vector3(0.0, 0.3, 0.0), Vector3(1.6, 0.5, 1.4), Basis.IDENTITY, Color(0.6, 0.14, 0.18))
	BloodTerrain.append_box(v, n, c, idx, Vector3(0.2, 0.8, 0.1), Vector3(0.9, 0.4, 0.8), Basis.from_euler(Vector3(0.0, 0.5, 0.0)), Color(0.74, 0.26, 0.3))
	return BloodTerrain.to_mesh(v, n, c, idx, BloodTerrain.detail_material("blood"))


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
	PitFlora.scatter(self, gen)


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
	var rows := 4
	var per_row := int(ceil(float(SOLDIERS) / float(rows)))
	for i in SOLDIERS:
		var row := i / per_row
		var col := i % per_row
		var x := (float(col) - float(per_row - 1) * 0.5) * 3.2
		soldiers.append(_spawn_ally("soldier", x, z0 - float(row) * 3.2, PI))
	for i in ARCHERS:
		var row2 := i / 5
		var col2 := i % 5
		var x2 := (float(col2) - 2.0) * 4.0
		archers.append(_spawn_ally("archer", x2, z0 - 13.0 - float(row2) * 3.0, PI))
	odrick = _spawn_ally("commander", 2.8, LANDING_Z + 4.5, 0.0)


func _on_fell(unit: Node3D) -> void:
	if unit == odrick:
		Game.achievements.put_progress("highway", 1)
	army_changed.emit(alive_count())


func alive_count() -> int:
	return get_tree().get_nodes_in_group("ally_unit").size()


func command() -> void:
	PitSpitter.released = true
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


func nearest_wall(ring: int, pos: Vector3, unit = null) -> Node3D:
	var cols: Dictionary = columns[ring]
	var rel := pos - origin
	var flat := Vector2(rel.x, rel.z)
	var spot := flat
	if flat.length() > 0.01:
		spot = flat.normalized() * BloodTerrain.RINGS[ring]
	var center := Vector2i(floori(spot.x), floori(spot.y))
	var best: Array = []
	var best_key = null
	var best_cost := INF
	for dx in range(-5, 6):
		for dz in range(-5, 6):
			var key := center + Vector2i(dx, dz)
			if not cols.has(key):
				continue
			var column: Array = cols[key]
			var id: int = column[0].get_instance_id()
			var cost := pos.distance_squared_to(column[0].global_position)
			var claims: int = int(wall_claims.get(id, 0))
			if unit != null and unit.claim_key == id:
				claims -= 1
			cost += float(maxi(claims, 0)) * WALL_CLAIM_COST
			if cost < best_cost:
				best_cost = cost
				best = column
				best_key = id
	if best.is_empty():
		return null
	if unit != null:
		release_wall(unit)
		unit.claim_key = best_key
		wall_claims[best_key] = int(wall_claims.get(best_key, 0)) + 1
	for layer in GATE_LAYERS:
		var block = _front(best[layer])
		if not block.dead:
			return block
	return _front(best[0])


func release_wall(unit) -> void:
	if unit.claim_key == null:
		return
	var left: int = int(wall_claims.get(unit.claim_key, 0)) - 1
	if left > 0:
		wall_claims[unit.claim_key] = left
	else:
		wall_claims.erase(unit.claim_key)
	unit.claim_key = null


func _front(block):
	var cur = block
	while cur.dead and cur.next_block != null and is_instance_valid(cur.next_block):
		cur = cur.next_block
	return cur


func hold_point(pos: Vector3) -> Vector3:
	var out := pos - heart_position
	out.y = 0.0
	out = out.normalized()
	return heart_position + out * (BloodTerrain.RINGS[2] + 14.0)


func doom_reached(pos: Vector3) -> bool:
	return distance_from_heart(pos) < BloodTerrain.RINGS[1] + DOOM_MARGIN


func army_breached() -> bool:
	for s in soldiers:
		if is_instance_valid(s) and not s.dead and distance_from_heart(s.global_position) < BloodTerrain.RINGS[1] - 2.0:
			return true
	return false


func wipe_army() -> void:
	for a in get_tree().get_nodes_in_group("ally_unit"):
		var t := get_tree().create_timer(randf_range(0.2, 1.8))
		t.timeout.connect(func() -> void:
			if is_instance_valid(a):
				a.take_damage(9999))


func _gloom_snapshot() -> void:
	var frame := Engine.get_physics_frames()
	if frame == gloom_frame:
		return
	gloom_frame = frame
	gloom_nodes.clear()
	gloom_pos.clear()
	gloom_band.clear()
	for g in get_tree().get_nodes_in_group("pit_gloom"):
		if not is_instance_valid(g) or g.dying:
			continue
		gloom_nodes.append(g)
		gloom_pos.append(g.global_position)
		gloom_band.append(BloodTerrain.band(g.global_position))


func nearest_gloom(pos: Vector3, radius: float) -> Node3D:
	_gloom_snapshot()
	var best: Node3D = null
	var best_d := radius * radius
	var band: int = BloodTerrain.band(pos)
	for i in gloom_nodes.size():
		var d := pos.distance_squared_to(gloom_pos[i])
		if d >= best_d or gloom_band[i] != band:
			continue
		best_d = d
		best = gloom_nodes[i]
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
	if gen != null and is_instance_valid(player):
		gen.update(player.global_position - origin)
		if rain != null:
			rain.global_position = player.global_position + Vector3(0.0, 18.0, 0.0)
	_update_heartbeat(delta)
	bone_tick -= delta
	if bone_tick <= 0.0:
		bone_tick = BONE_TICK
		_bone_tick()
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
