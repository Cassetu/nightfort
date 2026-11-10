extends CanvasLayer

const Sfx = preload("res://scripts/core/sfx.gd")
const TerritoryScript = preload("res://scripts/territory.gd")

const ORBIT_RADIUS := 24.0
const ORBIT_HEIGHT := 17.0
const ORBIT_SPEED := 0.1
const BOB := 1.5
const BLEND_TIME := 0.9
const MIN_CLEARANCE := 6.0
const MAX_LEVEL := 5
const GEM_ITEM := "soul_gem"

@onready var root: Control = $Root
@onready var level_label: Label = %LevelLabel
@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var heal_label: Label = %HealLabel
@onready var upgrade_button: Button = %UpgradeButton
@onready var cost_label: Label = %CostLabel
@onready var close_button: Button = %CloseButton

var player
var core
var terrain
var inv_ui
var cam: Camera3D
var open: bool = false
var closing: bool = false
var blend: float = 0.0
var angle: float = 0.0
var from_xform := Transform3D.IDENTITY


func _ready() -> void:
	root.visible = false
	close_button.pressed.connect(close)
	upgrade_button.pressed.connect(_on_upgrade)
	Inventory.changed.connect(_on_inventory_changed)


func setup(p, c, t, inventory_ui) -> void:
	player = p
	core = c
	terrain = t
	inv_ui = inventory_ui
	core.health_changed.connect(_on_core_health)


func open_core(c) -> void:
	if open or closing or not inv_ui.can_open():
		return
	core = c
	open = true
	blend = 0.0
	from_xform = player.camera.global_transform
	angle = atan2(from_xform.origin.x - core.global_position.x, from_xform.origin.z - core.global_position.z)
	cam = Camera3D.new()
	cam.fov = player.camera.fov
	cam.far = player.camera.far
	cam.global_transform = from_xform
	add_child(cam)
	cam.make_current()
	player.frozen = true
	player.held.visible = false
	core.overview = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	root.visible = true
	_refresh()


func close() -> void:
	if not open:
		return
	open = false
	closing = true
	root.visible = false
	from_xform = player.camera.global_transform


func force_close() -> void:
	if not open and not closing:
		return
	open = false
	_finish_close()
	if player != null and player.dead:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _finish_close() -> void:
	closing = false
	root.visible = false
	if cam != null and is_instance_valid(cam):
		cam.queue_free()
	cam = null
	if player != null and is_instance_valid(player):
		player.camera.make_current()
		player.held.visible = true
		if not player.dead:
			player.frozen = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if core != null and is_instance_valid(core):
		core.overview = false


func _orbit_transform() -> Transform3D:
	var c: Vector3 = core.global_position
	var radius := maxf(ORBIT_RADIUS, float(TerritoryScript.HALF) * 1.45 + 6.0)
	var pos := c + Vector3(sin(angle) * radius, ORBIT_HEIGHT + sin(angle * 0.7) * BOB, cos(angle) * radius)
	var ground := float(terrain.surface_y(floori(pos.x), floori(pos.z)))
	pos.y = maxf(pos.y, ground + MIN_CLEARANCE)
	var xf := Transform3D(Basis.IDENTITY, pos)
	return xf.looking_at(c + Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	if open:
		angle += ORBIT_SPEED * delta
		blend = minf(blend + delta / BLEND_TIME, 1.0)
		cam.global_transform = _blend(from_xform, _orbit_transform(), _ease(blend))
	elif closing:
		blend = maxf(blend - delta / BLEND_TIME, 0.0)
		cam.global_transform = _blend(player.camera.global_transform, _orbit_transform(), _ease(blend))
		if blend <= 0.0:
			_finish_close()


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _blend(a: Transform3D, b: Transform3D, t: float) -> Transform3D:
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), t)
	return Transform3D(Basis(q), a.origin.lerp(b.origin, t))


func upgrade_cost() -> int:
	return core.level


func _on_upgrade() -> void:
	if not open or core.level >= MAX_LEVEL:
		return
	var cost := upgrade_cost()
	if not Inventory.take_item(GEM_ITEM, cost):
		return
	core.upgrade()
	Sfx.play(self, "core_upgrade")
	var troop = world_ref().spawn_troop({})
	if troop != null and player != null and player.has_signal("notice"):
		player.notice.emit(troop.display_name)
	_refresh()


func world_ref():
	return get_tree().current_scene


func _on_inventory_changed() -> void:
	if open:
		_refresh()


func _on_core_health(_current, _maximum) -> void:
	if open:
		_refresh()


func _refresh() -> void:
	level_label.text = "Level %d" % core.level
	health_label.text = "%d/%d" % [core.current_health, core.max_health]
	health_bar.max_value = core.max_health
	health_bar.value = core.current_health
	var amount = core.get("night_heal")
	if core.level >= MAX_LEVEL:
		cost_label.text = "-"
		upgrade_button.text = "Max Level"
		upgrade_button.disabled = true
	else:
		var have := Inventory.get_count(GEM_ITEM)
		var cost := upgrade_cost()
		cost_label.text = "%d/%d" % [have, cost]
		upgrade_button.text = "Upgrade"
		upgrade_button.disabled = have < cost
	heal_label.text = "+%d" % (int(amount) if amount != null else 5)


func _input(event: InputEvent) -> void:
	if open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
