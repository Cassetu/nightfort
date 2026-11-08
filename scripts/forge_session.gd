extends CanvasLayer

signal finished(result: String)

const Sfx = preload("res://scripts/sfx.gd")
const HeldItem = preload("res://scripts/held_item.gd")
const TileArt = preload("res://scripts/tile_art.gd")

const START_METER := 0.25
const FLY_TIME := 0.7
const RETURN_TIME := 0.5
const END_HOLD := 0.9
const MIN_RADIUS := 1.2
const POP_TIME := 0.4
const HIT_PAD := 16.0
const LOSS_RATIO := 0.6
const COL_FILL := Color(1.0, 0.5, 0.12, 0.3)
const COL_RING := Color(1.0, 0.6, 0.16, 1.0)
const COL_POP := Color(1.0, 0.9, 0.5, 1.0)

@onready var root: Control = $Root
@onready var field: Control = %Field
@onready var meter: ProgressBar = %Meter
@onready var title: Label = %Title
@onready var result_label: Label = %Result

var player
var forge
var recipe: Dictionary = {}
var camera: Camera3D
var active: bool = false
var running: bool = false
var ended: bool = false
var tween: Tween
var mask: PackedByteArray = PackedByteArray()
var img_w: int = 1
var img_h: int = 1
var circles: Array = []
var spawn_left: float = 0.0
var elapsed: float = 0.0
var meter_value: float = START_METER
var gain: float = 0.1
var life: float = 2.4
var interval: float = 0.9
var size_scale: float = 1.0


func _ready() -> void:
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)


func begin(p, f, r: Dictionary) -> void:
	player = p
	forge = f
	recipe = r
	active = true
	running = false
	ended = false
	circles.clear()
	meter_value = START_METER
	meter.value = START_METER
	var speed: float = float(r["speed"])
	gain = 0.75 / float(r["strikes"])
	life = 2.6 / speed
	interval = 0.85 / speed
	size_scale = clampf(float(r["zone"]) / 0.2, 0.7, 1.3)
	spawn_left = 0.4
	elapsed = 0.0
	title.text = Inventory.item_name(r["id"])
	result_label.text = ""
	_load_mask(r["id"])
	forge.show_item(r["id"])
	forge.set_active(true)
	player.frozen = true
	player.held.set_suppressed(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	root.modulate = Color(1, 1, 1, 0)
	root.visible = true

	camera = Camera3D.new()
	forge.add_child(camera)
	camera.fov = player.camera.fov
	camera.global_transform = player.camera.global_transform
	camera.current = true
	var from: Transform3D = camera.global_transform
	var to: Transform3D = forge.global_transform * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), forge.CAM_POS)
	_kill_tween()
	tween = create_tween()
	tween.tween_method(_fly.bind(from, to), 0.0, 1.0, FLY_TIME)
	tween.tween_callback(_arrived)


func _fly(t: float, from: Transform3D, to: Transform3D) -> void:
	camera.global_transform = from.interpolate_with(to, smoothstep(0.0, 1.0, t))


func _arrived() -> void:
	running = true
	var fade := create_tween()
	fade.tween_property(root, "modulate", Color(1, 1, 1, 1), 0.25)


func _kill_tween() -> void:
	if tween:
		tween.kill()
		tween = null


func _load_mask(id: String) -> void:
	var tex: Texture2D = TileArt.icon(id, "")
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img_w = img.get_width()
	img_h = img.get_height()
	mask = PackedByteArray()
	mask.resize(img_w * img_h)
	for y in img_h:
		for x in img_w:
			mask[y * img_w + x] = 1 if img.get_pixel(x, y).a >= 0.5 else 0


func _solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img_w or y >= img_h:
		return false
	return mask[y * img_w + x] == 1


func _disc_solid(cx: int, cy: int, r: float) -> bool:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			if dx * dx + dy * dy <= r * r and not _solid(cx + dx, cy + dy):
				return false
	return true


func _spawn() -> void:
	var r := clampf(randf_range(5.0, 9.0) * size_scale, 2.0, 10.0)
	for attempt in 80:
		var x := randi() % img_w
		var y := randi() % img_h
		if not _solid(x, y) or not _disc_solid(x, y, r):
			if attempt % 8 == 7:
				r = maxf(r - 0.6, MIN_RADIUS + 0.5)
			continue
		var pos := Vector2(x + 0.5, y + 0.5)
		var clear := true
		for c: Dictionary in circles:
			if c["pop"] < 0.0 and pos.distance_to(c["pos"]) < (r + float(c["r0"])) * 0.9:
				clear = false
				break
		if not clear:
			continue
		circles.append({"pos": pos, "r0": r, "age": 0.0, "life": life * randf_range(0.9, 1.15), "pop": -1.0, "r_hit": r})
		return


func _radius_now(c: Dictionary) -> float:
	return lerpf(float(c["r0"]), MIN_RADIUS, clampf(float(c["age"]) / float(c["life"]), 0.0, 1.0))


func _screen_point(pos: Vector2) -> Vector2:
	var pix := HeldItem.ITEM_SIZE / float(maxi(img_w, img_h))
	var local := Vector3((pos.x - img_w * 0.5) * pix, (img_h * 0.5 - pos.y) * pix, HeldItem.THICKNESS * 0.5)
	return camera.unproject_position(forge.item_node.to_global(local))


func _screen_radius(pos: Vector2, r: float) -> float:
	var pix := HeldItem.ITEM_SIZE / float(maxi(img_w, img_h))
	var local := Vector3((pos.x - img_w * 0.5) * pix, (img_h * 0.5 - pos.y) * pix, HeldItem.THICKNESS * 0.5)
	var world_point: Vector3 = forge.item_node.to_global(local)
	var right: Vector3 = camera.global_transform.basis.x
	var edge := camera.unproject_position(world_point + right * r * pix * forge.ITEM_SCALE)
	return edge.distance_to(camera.unproject_position(world_point))


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	meter.value = move_toward(meter.value, meter_value, delta * 1.4)
	if running and not ended:
		spawn_left -= delta
		if spawn_left <= 0.0:
			spawn_left = interval * randf_range(0.8, 1.2)
			_spawn()
	var i := 0
	while i < circles.size():
		var c: Dictionary = circles[i]
		if c["pop"] >= 0.0:
			c["pop"] += delta / POP_TIME
			if c["pop"] >= 1.0:
				circles.remove_at(i)
				continue
		elif running and not ended:
			c["age"] += delta
			if c["age"] >= c["life"]:
				circles.remove_at(i)
				_miss()
				continue
		i += 1
	field.queue_redraw()


func _draw_field() -> void:
	if not active or camera == null or forge == null or forge.item_node == null:
		return
	for c: Dictionary in circles:
		var pos: Vector2 = c["pos"]
		var sp := _screen_point(pos)
		if c["pop"] < 0.0:
			var rp := _screen_radius(pos, _radius_now(c))
			field.draw_circle(sp, rp, COL_FILL)
			field.draw_arc(sp, rp, 0.0, TAU, 48, COL_RING, 3.0, true)
		else:
			var p: float = c["pop"]
			var rp := _screen_radius(pos, float(c["r_hit"])) * (1.0 + 1.4 * p)
			var shimmer := 0.65 + 0.35 * sin(elapsed * 40.0)
			var alpha := (1.0 - p) * shimmer
			field.draw_circle(sp, rp, Color(COL_POP.r, COL_POP.g, COL_POP.b, alpha * 0.3))
			field.draw_arc(sp, rp, 0.0, TAU, 48, Color(COL_POP.r, COL_POP.g, COL_POP.b, alpha), 3.0, true)
			for k in 8:
				var ang := TAU * float(k) / 8.0 + elapsed * 3.0
				var spark := 0.5 + 0.5 * sin(elapsed * 30.0 + float(k) * 1.7)
				field.draw_circle(sp + Vector2(cos(ang), sin(ang)) * rp, 1.0 + 3.0 * spark * (1.0 - p), Color(1.0, 0.95, 0.7, (1.0 - p) * spark))


func _on_field_input(event: InputEvent) -> void:
	if not running or ended:
		return
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in range(circles.size() - 1, -1, -1):
		var c: Dictionary = circles[i]
		if c["pop"] >= 0.0:
			continue
		var pos: Vector2 = c["pos"]
		var r_now := _radius_now(c)
		var sp := _screen_point(pos)
		if sp.distance_to(event.position) <= maxf(_screen_radius(pos, r_now), HIT_PAD):
			c["pop"] = 0.0
			c["r_hit"] = r_now
			Sfx.play(self, "anvil_hit", Vector3.INF, -3.0)
			meter_value = minf(meter_value + gain, 1.0)
			if meter_value >= 1.0:
				_end("won")
			return
	for c: Dictionary in circles:
		if c["pop"] < 0.0 or c["pop"] > 0.5:
			continue
		var pos: Vector2 = c["pop_pos"] if c.has("pop_pos") else c["pos"]
		var sp := _screen_point(pos)
		if sp.distance_to(event.position) <= _screen_radius(pos, float(c["r_hit"])) * 1.5 + HIT_PAD:
			return
	_miss()


func _miss() -> void:
	meter_value = maxf(meter_value - gain * LOSS_RATIO, 0.0)
	var flash := create_tween()
	meter.modulate = Color(1.0, 0.45, 0.45, 1.0)
	flash.tween_property(meter, "modulate", Color(1, 1, 1, 1), 0.3)
	if meter_value <= 0.0:
		_end("cracked")


func _end(result: String) -> void:
	if ended:
		return
	ended = true
	running = false
	for c: Dictionary in circles:
		if c["pop"] < 0.0:
			c["pop"] = 0.0
	result_label.text = "Forged" if result == "won" else "Cracked"
	get_tree().create_timer(END_HOLD).timeout.connect(_leave.bind(result))


func _input(event: InputEvent) -> void:
	if active and not ended and event.is_action_pressed("ui_cancel"):
		ended = true
		running = false
		_leave("cancel")
		get_viewport().set_input_as_handled()


func _leave(result: String) -> void:
	if not active:
		return
	_kill_tween()
	var from: Transform3D = camera.global_transform
	var to: Transform3D = player.camera.global_transform
	root.visible = false
	tween = create_tween()
	tween.tween_method(_fly.bind(from, to), 0.0, 1.0, RETURN_TIME)
	tween.tween_callback(_restore.bind(result))


func _restore(result: String) -> void:
	_teardown()
	finished.emit(result)


func abort() -> void:
	if not active:
		return
	_kill_tween()
	_teardown()
	finished.emit("cancel")


func _teardown() -> void:
	active = false
	running = false
	ended = true
	circles.clear()
	if camera != null:
		camera.queue_free()
		camera = null
	player.camera.make_current()
	player.frozen = false
	player.held.set_suppressed(false)
	root.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if is_instance_valid(forge):
		forge.set_active(false)
		forge.show_item("")
