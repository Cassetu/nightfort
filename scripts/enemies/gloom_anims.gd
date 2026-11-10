extends RefCounted

const REST := {
	"Body/ArmL:rotation:x": 0.06,
	"Body/ArmL:rotation:z": -0.1,
	"Body/ArmR:rotation:x": 0.06,
	"Body/ArmR:rotation:z": 0.1,
	"Body/LegL:rotation:x": 0.0,
	"Body/LegR:rotation:x": 0.0,
	"Body/Head:rotation:x": 0.42,
	"Body/Head:rotation:z": 0.2,
	"Body/Head:position:y": 0.7,
	"Body/Head:position:z": -0.22,
	"Body:position:y": 0.0,
	"Body:rotation:x": 0.0,
}

const ATTACKS := ["swipe_r", "swipe_l", "slam", "bite"]
const BREAKS := ["bite", "bite", "slam", "swipe_r"]
const ONE_SHOTS := ["swipe_r", "swipe_l", "slam", "bite"]

static var library_cache: AnimationLibrary


static func library() -> AnimationLibrary:
	if library_cache != null:
		return library_cache
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make(2.6, true, {
		"Body/ArmL:rotation:x": [[0.0, 0.05], [1.3, 0.1], [2.6, 0.05]],
		"Body/ArmR:rotation:x": [[0.0, 0.08], [1.3, 0.04], [2.6, 0.08]],
		"Body/ArmL:rotation:z": [[0.0, -0.1], [1.3, -0.15], [2.6, -0.1]],
		"Body/ArmR:rotation:z": [[0.0, 0.1], [1.3, 0.14], [2.6, 0.1]],
		"Body:position:y": [[0.0, 0.0], [1.3, -0.025], [2.6, 0.0]],
		"Body/Head:rotation:z": [[0.0, 0.2], [0.9, 0.27], [1.8, 0.14], [2.6, 0.2]],
		"Body/Head:rotation:x": [[0.0, 0.42], [1.3, 0.5], [2.6, 0.42]],
	}))
	lib.add_animation("walk", _make(0.8, true, {
		"Body/LegL:rotation:x": [[0.0, 0.0], [0.2, 0.7], [0.4, 0.0], [0.6, -0.7], [0.8, 0.0]],
		"Body/LegR:rotation:x": [[0.0, 0.0], [0.2, -0.7], [0.4, 0.0], [0.6, 0.7], [0.8, 0.0]],
		"Body/ArmL:rotation:x": [[0.0, 0.06], [0.2, -0.3], [0.4, 0.06], [0.6, 0.4], [0.8, 0.06]],
		"Body/ArmR:rotation:x": [[0.0, 0.06], [0.2, 0.4], [0.4, 0.06], [0.6, -0.3], [0.8, 0.06]],
		"Body:position:y": [[0.0, 0.0], [0.1, 0.05], [0.2, 0.0], [0.3, 0.05], [0.4, 0.0], [0.5, 0.05], [0.6, 0.0], [0.7, 0.05], [0.8, 0.0]],
		"Body/Head:rotation:z": [[0.0, 0.2], [0.2, 0.27], [0.4, 0.2], [0.6, 0.13], [0.8, 0.2]],
		"Body/Head:rotation:x": [[0.0, 0.42], [0.2, 0.48], [0.4, 0.42], [0.6, 0.48], [0.8, 0.42]],
	}))
	lib.add_animation("swipe_r", _make(0.5, false, {
		"Body/ArmR:rotation:x": [[0.0, 0.06], [0.14, -1.0], [0.26, 1.7], [0.5, 0.06]],
		"Body/ArmR:rotation:z": [[0.0, 0.1], [0.14, 0.5], [0.26, -0.3], [0.5, 0.1]],
		"Body/ArmL:rotation:x": [[0.0, 0.06], [0.26, 0.5], [0.5, 0.06]],
		"Body:rotation:x": [[0.0, 0.0], [0.14, 0.12], [0.26, -0.22], [0.5, 0.0]],
		"Body/Head:rotation:x": [[0.0, 0.42], [0.26, 0.75], [0.5, 0.42]],
	}))
	lib.add_animation("swipe_l", _make(0.5, false, {
		"Body/ArmL:rotation:x": [[0.0, 0.06], [0.14, -1.0], [0.26, 1.7], [0.5, 0.06]],
		"Body/ArmL:rotation:z": [[0.0, -0.1], [0.14, -0.5], [0.26, 0.3], [0.5, -0.1]],
		"Body/ArmR:rotation:x": [[0.0, 0.06], [0.26, 0.5], [0.5, 0.06]],
		"Body:rotation:x": [[0.0, 0.0], [0.14, 0.12], [0.26, -0.22], [0.5, 0.0]],
		"Body/Head:rotation:x": [[0.0, 0.42], [0.26, 0.75], [0.5, 0.42]],
	}))
	lib.add_animation("slam", _make(0.65, false, {
		"Body/ArmL:rotation:x": [[0.0, 0.06], [0.2, -1.5], [0.33, 1.6], [0.65, 0.06]],
		"Body/ArmR:rotation:x": [[0.0, 0.06], [0.2, -1.5], [0.33, 1.6], [0.65, 0.06]],
		"Body:rotation:x": [[0.0, 0.0], [0.2, 0.2], [0.33, -0.3], [0.65, 0.0]],
		"Body/Head:rotation:x": [[0.0, 0.42], [0.33, 0.8], [0.65, 0.42]],
	}))
	lib.add_animation("bite", _make(0.55, false, {
		"Body/Head:position:z": [[0.0, -0.22], [0.12, -0.12], [0.22, -0.58], [0.3, -0.5], [0.38, -0.62], [0.55, -0.22]],
		"Body/Head:position:y": [[0.0, 0.7], [0.22, 0.62], [0.55, 0.7]],
		"Body/Head:rotation:x": [[0.0, 0.42], [0.12, 0.1], [0.22, 0.95], [0.3, 0.6], [0.38, 0.95], [0.55, 0.42]],
		"Body:rotation:x": [[0.0, 0.0], [0.12, 0.15], [0.22, -0.35], [0.38, -0.3], [0.55, 0.0]],
		"Body/ArmL:rotation:z": [[0.0, -0.1], [0.22, -0.4], [0.55, -0.1]],
		"Body/ArmR:rotation:z": [[0.0, 0.1], [0.22, 0.4], [0.55, 0.1]],
	}))
	library_cache = lib
	return lib


static func _make(length: float, loop: bool, tracks: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for path: String in REST:
		var keys: Array = tracks.get(path, [[0.0, REST[path]], [length, REST[path]]])
		var i := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(i, NodePath(path))
		a.track_set_interpolation_type(i, Animation.INTERPOLATION_CUBIC if loop else Animation.INTERPOLATION_LINEAR)
		a.track_set_interpolation_loop_wrap(i, loop)
		for k: Array in keys:
			a.track_insert_key(i, float(k[0]), float(k[1]))
	return a
