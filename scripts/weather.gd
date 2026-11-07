extends Node

enum State { CLEAR, CLOUDY, RAIN, FOG, STORM }

const CloudShader = preload("res://resources/cloud.gdshader")
const BlockScript = preload("res://scripts/block.gd")

const TARGETS := {
	State.CLEAR: {"cover": 0.3, "rain": 0.0, "fog": 0.0, "dark": 0.0, "wind": 1.0},
	State.CLOUDY: {"cover": 1.0, "rain": 0.0, "fog": 0.2, "dark": 0.55, "wind": 1.6},
	State.RAIN: {"cover": 0.85, "rain": 0.6, "fog": 0.3, "dark": 0.45, "wind": 2.0},
	State.FOG: {"cover": 0.55, "rain": 0.0, "fog": 1.0, "dark": 0.2, "wind": 0.6},
	State.STORM: {"cover": 1.0, "rain": 1.0, "fog": 0.45, "dark": 0.8, "wind": 3.0},
}
const WEIGHTS := {State.CLEAR: 5.0, State.CLOUDY: 2.0, State.RAIN: 3.0, State.FOG: 1.5, State.STORM: 1.5}

const CLOUD_HEIGHT := 95.0
const CLOUD_SIZE := 1600.0
const BASE_FOG := 0.022
const FOG_BOOST := 3.0
const BLEND_RATE := 0.03
const WIND_DIR := Vector2(0.8, 0.35)
const NIGHT_TINT := Color(0.05, 0.06, 0.11)
const RAIN_AMOUNT := 2600
const RAIN_HEIGHT := 14.0
const BOLT_MIN := 5.0
const BOLT_MAX := 14.0

var sun
var env: Environment
var sky_material: ProceduralSkyMaterial
var player
var terrain

var state: int = State.CLEAR
var state_left: float = 90.0
var cover: float = 0.3
var rain: float = 0.0
var fog: float = 0.0
var dark: float = 0.0
var wind: float = 1.0
var wind_offset: Vector2 = Vector2.ZERO
var rain_shown: float = 0.0
var wet: float = 0.0

var clouds: MeshInstance3D
var cloud_material: ShaderMaterial
var rain_particles: GPUParticles3D
var roof_field: GPUParticlesCollisionHeightField3D
var bolt: MeshInstance3D
var bolt_material: StandardMaterial3D
var bolt_left: float = 8.0
var bolt_age: float = 99.0
var flash: float = 0.0


func _ready() -> void:
	process_priority = 100
	randomize()


func setup(sun_node, environment: Environment, player_node, terrain_node) -> void:
	sun = sun_node
	env = environment
	sky_material = env.sky.sky_material
	player = player_node
	terrain = terrain_node
	_build_clouds()
	_build_rain()
	_build_bolt()


func _build_clouds() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(CLOUD_SIZE, CLOUD_SIZE)
	cloud_material = ShaderMaterial.new()
	cloud_material.shader = CloudShader
	clouds = MeshInstance3D.new()
	clouds.name = "Clouds"
	clouds.mesh = plane
	clouds.material_override = cloud_material
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clouds.extra_cull_margin = 4000.0
	clouds.top_level = true
	add_child(clouds)


func _build_rain() -> void:
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "Rain"
	rain_particles.amount = RAIN_AMOUNT
	rain_particles.lifetime = 0.8
	rain_particles.local_coords = false
	rain_particles.emitting = true
	rain_particles.amount_ratio = 0.0
	rain_particles.visibility_aabb = AABB(Vector3(-24, -26, -24), Vector3(48, 40, 48))
	rain_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(16.0, 0.5, 16.0)
	mat.direction = Vector3(0.12, -1.0, 0.04)
	mat.spread = 2.0
	mat.initial_velocity_min = 24.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3.ZERO
	mat.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	rain_particles.process_material = mat
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.5, 0.012)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.72, 0.8, 0.9, 0.45)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_mat
	rain_particles.draw_pass_1 = drop
	rain_particles.top_level = true
	add_child(rain_particles)

	roof_field = GPUParticlesCollisionHeightField3D.new()
	roof_field.name = "RoofField"
	roof_field.size = Vector3(36.0, 44.0, 36.0)
	roof_field.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	roof_field.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS
	roof_field.heightfield_mask = 1
	roof_field.top_level = true
	add_child(roof_field)


func _build_bolt() -> void:
	bolt = MeshInstance3D.new()
	bolt.name = "Bolt"
	bolt.visible = false
	bolt.top_level = true
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.extra_cull_margin = 400.0
	bolt_material = StandardMaterial3D.new()
	bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bolt_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_material.albedo_color = Color(0.85, 0.9, 1.0, 1.0)
	bolt.material_override = bolt_material
	add_child(bolt)


func _pick_state() -> void:
	var total := 0.0
	for s in WEIGHTS:
		if s != state:
			total += WEIGHTS[s]
	var roll := randf() * total
	for s in WEIGHTS:
		if s == state:
			continue
		roll -= WEIGHTS[s]
		if roll <= 0.0:
			state = s
			break
	if state == State.CLEAR:
		state_left = randf_range(150.0, 360.0)
	else:
		state_left = randf_range(100.0, 240.0)


func _process(delta: float) -> void:
	if player == null or sun == null:
		return
	state_left -= delta
	if state_left <= 0.0:
		_pick_state()

	var target: Dictionary = TARGETS[state]
	var step := BLEND_RATE * delta
	cover = move_toward(cover, target["cover"], step)
	rain = move_toward(rain, target["rain"], step * 1.5)
	fog = move_toward(fog, target["fog"], step)
	dark = move_toward(dark, target["dark"], step)
	wind = move_toward(wind, target["wind"], step * 2.0)

	var ppos: Vector3 = player.global_position
	wind_offset += WIND_DIR * wind * 4.0 * delta

	_update_lightning(delta, ppos)
	_apply_clouds(ppos)
	_apply_rain(delta, ppos)
	_apply_wetness(delta)
	_apply_environment()


func _apply_wetness(delta: float) -> void:
	if rain > 0.05:
		wet = move_toward(wet, 1.0, rain * 0.25 * delta)
	else:
		wet = move_toward(wet, 0.0, 0.012 * delta)
	BlockScript.apply_wetness(wet)
	if terrain != null and terrain.material != null:
		terrain.material.set_shader_parameter("wetness", wet)


func _apply_clouds(ppos: Vector3) -> void:
	clouds.global_position = Vector3(ppos.x, CLOUD_HEIGHT, ppos.z)
	var vis := smoothstep(-0.15, 0.15, sun.elevation)
	var tint: Color = NIGHT_TINT.lerp(sun.light_color, vis)
	tint = tint.lerp(Color(0.9, 0.92, 1.0), flash * 0.8)
	cloud_material.set_shader_parameter("offset", wind_offset)
	cloud_material.set_shader_parameter("cover", cover)
	cloud_material.set_shader_parameter("darkness", dark)
	cloud_material.set_shader_parameter("tint", tint)


func _apply_rain(delta: float, ppos: Vector3) -> void:
	var outside := 1.0
	if terrain != null:
		var ground: int = terrain.surface_y(floori(ppos.x), floori(ppos.z))
		if ppos.y < ground - 3.0:
			outside = 0.0
	rain_shown = move_toward(rain_shown, rain * outside, delta * 0.8)
	rain_particles.amount_ratio = clampf(rain_shown, 0.0, 1.0)
	rain_particles.emitting = rain_shown > 0.01
	rain_particles.global_position = ppos + Vector3(0.0, RAIN_HEIGHT, 0.0)
	roof_field.global_position = ppos + Vector3(0.0, 6.0, 0.0)
	var mat := rain_particles.process_material as ParticleProcessMaterial
	mat.direction = Vector3(0.05 + 0.08 * wind, -1.0, 0.03 * wind)


func _apply_environment() -> void:
	var gray_mix := minf(cover * 0.8, 0.9)
	var shade := 1.0 - dark * 0.55
	sky_material.sky_top_color = _grade(sky_material.sky_top_color, gray_mix, shade)
	sky_material.sky_horizon_color = _grade(sky_material.sky_horizon_color, gray_mix, shade)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = sky_material.sky_top_color.darkened(0.5)
	env.fog_light_color = _grade(env.fog_light_color, minf(gray_mix + fog * 0.3, 0.95), shade)
	env.fog_density = BASE_FOG * (1.0 + fog * FOG_BOOST + rain * 0.5)
	env.ambient_light_energy *= 1.0 - dark * 0.25
	sun.light_energy *= 1.0 - dark * 0.85
	if flash > 0.01:
		sky_material.sky_top_color = sky_material.sky_top_color.lerp(Color(0.75, 0.8, 0.95), flash * 0.6)
		sky_material.sky_horizon_color = sky_material.sky_horizon_color.lerp(Color(0.8, 0.85, 1.0), flash * 0.6)
		env.ambient_light_energy += flash * 3.0
		sun.moon.light_energy += flash * 0.8


func _grade(c: Color, gray_mix: float, shade: float) -> Color:
	var l := c.get_luminance()
	var g := c.lerp(Color(l, l, l), gray_mix)
	return Color(g.r * shade, g.g * shade, g.b * shade, 1.0)


func _update_lightning(delta: float, ppos: Vector3) -> void:
	if flash > 0.0 or bolt_age < 0.6:
		bolt_age += delta
		flash = exp(-bolt_age * 7.0) * (0.75 + 0.25 * sin(bolt_age * 70.0))
		bolt_material.albedo_color.a = clampf(flash * 1.4, 0.0, 1.0)
		if bolt_age >= 0.6:
			flash = 0.0
			bolt.visible = false
	if state != State.STORM or rain < 0.7:
		return
	bolt_left -= delta
	if bolt_left > 0.0:
		return
	bolt_left = randf_range(BOLT_MIN, BOLT_MAX)
	_strike(ppos)


func _strike(ppos: Vector3) -> void:
	var angle := randf() * TAU
	var dist := randf_range(45.0, 130.0)
	var x := ppos.x + cos(angle) * dist
	var z := ppos.z + sin(angle) * dist
	var ground := 0.0
	if terrain != null:
		ground = terrain.height_at(x, z)
	var top := Vector3(x, CLOUD_HEIGHT, z)
	var bottom := Vector3(x, ground, z)
	bolt.mesh = _bolt_mesh(top, bottom)
	bolt.global_transform = Transform3D.IDENTITY
	bolt.visible = true
	bolt_age = 0.0
	flash = 1.0


func _bolt_mesh(top: Vector3, bottom: Vector3) -> ArrayMesh:
	var segments := 14
	var points: Array = []
	for i in segments + 1:
		var t := float(i) / float(segments)
		var p := top.lerp(bottom, t)
		if i > 0 and i < segments:
			p += Vector3(randf_range(-7.0, 7.0), 0.0, randf_range(-7.0, 7.0))
		points.append(p)
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var half := 0.4
	for i in segments:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
			var base := verts.size()
			verts.push_back(a - axis * half)
			verts.push_back(a + axis * half)
			verts.push_back(b + axis * half)
			verts.push_back(b - axis * half)
			for offset: int in [0, 1, 2, 0, 2, 3]:
				indices.push_back(base + offset)
	var data: Array = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = verts
	data[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	return mesh
