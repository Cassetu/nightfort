extends Node

const SFX_DIR := "res://audio/sfx/"
const RAIN_PATH := "res://audio/rain.mp3"
const SFX_BUS := "SFX"
const RAIN_BUS := "Rain"
const POOL_2D := 8
const POOL_3D := 16
const SOUNDS := {
	"ui_click": ["ui_click"],
	"pickup": ["pickup_1", "pickup_2"],
	"pickup_gem": ["pickup_gem"],
	"core_upgrade": ["core_upgrade"],
	"equip_armor": ["equip_armor_1", "equip_armor_2"],
	"land": ["item_drop"],
	"sword_swing": ["sword_swing_1", "sword_swing_2"],
	"gloom_attack": ["gloom_attack_1", "gloom_attack_2"],
	"arrow_release": ["arrow_release"],
	"chop": ["chop"],
	"ambient_creak": ["ambient_creak"],
	"door_open": ["door_open"],
	"door_close": ["door_close"],
	"block_place": ["block_place"],
	"footstep_stone": ["footstep_stone"],
	"footstep_soil": ["footstep_soil"],
	"footstep_wood": ["footstep_wood"],
	"footstep_organic": ["footstep_organic"],
}
const WOOD_RESOURCES := ["wood", "plank", "scaffold", "door", "ladder", "chest", "workbench", "barricade", "banner"]
const SOIL_BLOCKS := [1, 2, 5, 6]
const CREAK_MIN := 18.0
const CREAK_MAX := 40.0
const RAIN_BASE_DB := -24.0
const RAIN_RANGE_DB := 18.0
const SHELTER_FADE := 10.0
const RING_NEAR := 3.0
const RING_FAR := 7.0
const RAIN_UPDATE := 0.15

var player
var terrain
var weather
var roof
var sun
var cache: Dictionary = {}
var pool_2d: Array = []
var pool_3d: Array = []
var next_3d: int = 0
var next_2d: int = 0
var creak_timer: float = 20.0
var rain_a: AudioStreamPlayer
var rain_b: AudioStreamPlayer
var rain_filter: AudioEffectLowPassFilter
var rain_stream: AudioStream
var rain_clock: float = 0.0
var rain_timer: float = 0.0
var shelter: float = 1.0
var shelter_target: float = 1.0
var rain_on: bool = false


func setup(p, t, w, r, s) -> void:
	player = p
	terrain = t
	weather = w
	roof = r
	sun = s
	add_to_group("audio_manager")
	_ensure_bus(SFX_BUS)
	_ensure_bus(RAIN_BUS)
	var rain_index := AudioServer.get_bus_index(RAIN_BUS)
	if AudioServer.get_bus_effect_count(rain_index) == 0:
		rain_filter = AudioEffectLowPassFilter.new()
		rain_filter.cutoff_hz = 16000.0
		AudioServer.add_bus_effect(rain_index, rain_filter)
	else:
		rain_filter = AudioServer.get_bus_effect(rain_index, 0) as AudioEffectLowPassFilter
	for i in POOL_2D:
		var a := AudioStreamPlayer.new()
		a.bus = SFX_BUS
		add_child(a)
		pool_2d.append(a)
	for i in POOL_3D:
		var a3 := AudioStreamPlayer3D.new()
		a3.bus = SFX_BUS
		a3.unit_size = 6.0
		a3.max_distance = 70.0
		a3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(a3)
		pool_3d.append(a3)
	_build_rain()
	creak_timer = randf_range(CREAK_MIN, CREAK_MAX)
	get_tree().node_added.connect(_on_node_added)
	_scan_buttons.call_deferred()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _scan_buttons() -> void:
	for n in get_tree().root.find_children("*", "BaseButton", true, false):
		_hook_button(n)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node)


func _hook_button(btn: BaseButton) -> void:
	if not btn.pressed.is_connected(_on_button):
		btn.pressed.connect(_on_button)


func _on_button() -> void:
	play("ui_click")


func _load(file_name: String) -> AudioStream:
	if cache.has(file_name):
		return cache[file_name]
	var path := SFX_DIR + file_name + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	cache[file_name] = stream
	return stream


func play(key: String, pos: Vector3 = Vector3.INF, vol_db: float = 0.0, pitch_var: float = 0.06) -> void:
	if not SOUNDS.has(key):
		return
	var variants: Array = SOUNDS[key]
	var stream := _load(variants[randi() % variants.size()])
	if stream == null:
		return
	var pitch := 1.0 + randf_range(-pitch_var, pitch_var)
	if pos.is_finite():
		var a3: AudioStreamPlayer3D = pool_3d[next_3d]
		for i in pool_3d.size():
			var cand: AudioStreamPlayer3D = pool_3d[(next_3d + i) % pool_3d.size()]
			if not cand.playing:
				a3 = cand
				break
		next_3d = (next_3d + 1) % pool_3d.size()
		a3.stream = stream
		a3.global_position = pos
		a3.volume_db = vol_db
		a3.pitch_scale = pitch
		a3.play()
	else:
		var a: AudioStreamPlayer = pool_2d[next_2d]
		for i in pool_2d.size():
			var cand2: AudioStreamPlayer = pool_2d[(next_2d + i) % pool_2d.size()]
			if not cand2.playing:
				a = cand2
				break
		next_2d = (next_2d + 1) % pool_2d.size()
		a.stream = stream
		a.volume_db = vol_db
		a.pitch_scale = pitch
		a.play()


func surface_at(pos: Vector3) -> String:
	var cell := Vector3i(floori(pos.x), floori(pos.y - 0.15), floori(pos.z))
	var stability = get_tree().get_first_node_in_group("stability")
	if stability != null:
		var n = stability.cell_map.get(cell)
		if n != null and is_instance_valid(n):
			var info: Dictionary = Inventory.BLOCK_TYPES.get(n.block_type, {})
			if WOOD_RESOURCES.has(info.get("resource", "")):
				return "wood"
			return "stone"
	var id: int = terrain.block_at(cell.x, cell.y, cell.z)
	if SOIL_BLOCKS.has(id):
		return "soil"
	return "stone"


func footstep(pos: Vector3) -> void:
	play("footstep_" + surface_at(pos), pos, -4.0, 0.08)


func _build_rain() -> void:
	if not ResourceLoader.exists(RAIN_PATH):
		return
	rain_stream = load(RAIN_PATH)
	if rain_stream is AudioStreamMP3:
		(rain_stream as AudioStreamMP3).loop = true
	rain_a = AudioStreamPlayer.new()
	rain_a.bus = RAIN_BUS
	rain_a.stream = rain_stream
	rain_a.volume_db = -80.0
	add_child(rain_a)
	rain_b = AudioStreamPlayer.new()
	rain_b.bus = RAIN_BUS
	rain_b.stream = rain_stream
	rain_b.volume_db = -80.0
	add_child(rain_b)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_creak(delta)
	_rain(delta)


func _creak(delta: float) -> void:
	creak_timer -= delta
	if creak_timer > 0.0:
		return
	creak_timer = randf_range(CREAK_MIN, CREAK_MAX)
	if sun == null or sun.elevation > -0.05:
		return
	var angle := randf() * TAU
	var spot: Vector3 = player.global_position + Vector3(cos(angle) * randf_range(10.0, 18.0), 1.0, sin(angle) * randf_range(10.0, 18.0))
	play("ambient_creak", spot, -10.0, 0.12)


func _rain(delta: float) -> void:
	if rain_a == null or weather == null:
		return
	var level: float = clampf(weather.rain_shown, 0.0, 1.0)
	if level < 0.01:
		if rain_on:
			rain_on = false
			rain_a.stop()
			rain_b.stop()
		return
	if not rain_on:
		rain_on = true
		rain_a.play(randf() * 4.0)
		rain_b.play(10.7 + randf() * 4.0)
	rain_clock += delta
	rain_timer -= delta
	if rain_timer <= 0.0:
		rain_timer = RAIN_UPDATE
		shelter_target = _shelter()
	shelter = lerpf(shelter, shelter_target, clampf(delta * 3.0, 0.0, 1.0))
	var base := RAIN_BASE_DB + RAIN_RANGE_DB * sqrt(level) - 3.0
	var shelter_db := linear_to_db(clampf(shelter, 0.005, 1.0))
	var wobble_a := sin(rain_clock * 0.23) * 1.6 + sin(rain_clock * 0.61 + 1.3) * 0.8
	var wobble_b := sin(rain_clock * 0.19 + 2.1) * 1.6 + sin(rain_clock * 0.53 + 4.0) * 0.8
	rain_a.volume_db = base + shelter_db + wobble_a
	rain_b.volume_db = base + shelter_db + wobble_b
	rain_a.pitch_scale = 1.0 + 0.012 * sin(rain_clock * 0.17)
	rain_b.pitch_scale = 1.0 + 0.012 * sin(rain_clock * 0.14 + 2.0)
	if rain_filter != null:
		rain_filter.cutoff_hz = lerpf(700.0, 16000.0, pow(clampf(shelter, 0.0, 1.0), 0.6))


func _shelter() -> float:
	if roof == null or not roof.ready_flag:
		return 1.0
	var p: Vector3 = player.global_position
	var head := p.y + 1.6
	var h: float = roof.height_at(p.x, p.z)
	if h <= roof.UNKNOWN + 1.0:
		return 1.0
	var above := maxf(h - head, 0.0)
	if above <= 0.3:
		return 1.0
	var outside := 0.0
	var total := 0.0
	for ring in [RING_NEAR, RING_FAR]:
		for k in 8:
			var a := TAU * float(k) / 8.0
			var rh: float = roof.height_at(p.x + cos(a) * ring, p.z + sin(a) * ring)
			total += 1.0
			if rh > roof.UNKNOWN + 1.0 and rh <= p.y + 1.2:
				outside += 1.0
	var open_frac := outside / maxf(total, 1.0)
	return exp(-above / SHELTER_FADE) * (0.25 + 0.75 * open_frac) * 0.55
