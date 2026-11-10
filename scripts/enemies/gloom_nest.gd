extends Node3D

const RISE_TIME := 7.0
const SINK_TIME := 4.0
const BURIED := -3.2

const FLESH := Color(0.15, 0.07, 0.17)
const FLESH_DARK := Color(0.09, 0.04, 0.11)
const BILE := Color(0.32, 0.18, 0.4)

static var flesh_material: StandardMaterial3D
static var dark_material: StandardMaterial3D
static var bile_material: StandardMaterial3D

var tween: Tween
var sinking: bool = false


static func _ensure_materials() -> void:
	if flesh_material != null:
		return
	flesh_material = StandardMaterial3D.new()
	flesh_material.albedo_color = FLESH
	flesh_material.roughness = 0.55
	dark_material = StandardMaterial3D.new()
	dark_material.albedo_color = FLESH_DARK
	dark_material.roughness = 0.8
	bile_material = StandardMaterial3D.new()
	bile_material.albedo_color = Color(0.1, 0.05, 0.14)
	bile_material.emission_enabled = true
	bile_material.emission = BILE
	bile_material.emission_energy_multiplier = 0.8
	bile_material.roughness = 0.2


func _ready() -> void:
	_ensure_materials()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(get_meta("seed", 5))

	var pool := CylinderMesh.new()
	pool.top_radius = 2.3
	pool.bottom_radius = 2.5
	pool.height = 0.12
	pool.material = bile_material
	_add(pool, Vector3(0.0, 0.06, 0.0), Vector3.ZERO)

	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.0
	core_mesh.height = 1.7
	core_mesh.material = flesh_material
	_add(core_mesh, Vector3(0.0, 0.6, 0.0), Vector3.ZERO, Vector3(1.5, 1.0, 1.5))

	for i in 7:
		var a := TAU * float(i) / 7.0 + rng.randf() * 0.4
		var r := rng.randf_range(1.5, 2.0)
		var lump := SphereMesh.new()
		lump.radius = 0.7
		lump.height = 1.1
		lump.material = flesh_material if i % 2 == 0 else dark_material
		var s := rng.randf_range(0.8, 1.3)
		_add(lump, Vector3(cos(a) * r, 0.25, sin(a) * r), Vector3.ZERO, Vector3(s, rng.randf_range(0.6, 1.0), s))

	for i in 8:
		var a := TAU * float(i) / 8.0 + rng.randf() * 0.5
		var r := rng.randf_range(0.5, 1.7)
		var h := rng.randf_range(1.2, 3.0)
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = rng.randf_range(0.14, 0.3)
		spike.height = h
		spike.radial_segments = 6
		spike.rings = 1
		spike.material = dark_material
		var tilt := rng.randf_range(0.15, 0.5)
		var rot := Vector3(sin(a) * tilt, 0.0, -cos(a) * tilt)
		_add(spike, Vector3(cos(a) * r, h * 0.5 + 0.5, sin(a) * r), rot)

	var drip := CPUParticles3D.new()
	var bead := SphereMesh.new()
	bead.radius = 0.07
	bead.height = 0.14
	bead.radial_segments = 6
	bead.rings = 3
	bead.material = bile_material
	drip.mesh = bead
	drip.amount = 10
	drip.lifetime = 3.0
	drip.direction = Vector3.UP
	drip.spread = 25.0
	drip.gravity = Vector3(0.0, 0.4, 0.0)
	drip.initial_velocity_min = 0.2
	drip.initial_velocity_max = 0.6
	drip.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drip.emission_sphere_radius = 1.6
	drip.position = Vector3(0.0, 0.8, 0.0)
	add_child(drip)

	var glow := OmniLight3D.new()
	glow.light_color = Color(0.55, 0.25, 0.75)
	glow.light_energy = 0.7
	glow.omni_range = 7.0
	glow.shadow_enabled = false
	glow.position = Vector3(0.0, 1.0, 0.0)
	add_child(glow)

	position.y = _ground_y() + BURIED
	rise()


func _add(mesh: Mesh, pos: Vector3, rot: Vector3, mesh_scale: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = mesh_scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func rise() -> void:
	if tween != null:
		tween.kill()
	sinking = false
	var target := _ground_y()
	tween = create_tween()
	tween.tween_property(self, "position:y", target, RISE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func sink() -> void:
	if sinking:
		return
	sinking = true
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "position:y", _ground_y() + BURIED, SINK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _ground_y() -> float:
	return get_meta("ground_y", 0.0)
