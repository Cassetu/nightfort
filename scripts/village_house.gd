extends RefCounted

const TORCH_SCENE := "res://scenes/torch.tscn"
const WALL_H := 3


static func _put(world, type: String, x: int, y: int, z: int, yaw: float = 0.0) -> void:
	world.restore_block(type, Vector3(x + 0.5, y + 0.5, z + 0.5), yaw)


static func _ascent_yaw(dx: int, dz: int) -> float:
	return atan2(-float(dx), -float(dz))


static func build_blocks(world, cx: int, cz: int, floor_y: int, w: int, d: int, door_dir: Vector2i) -> void:
	var hw := (w - 1) >> 1
	var hd := (d - 1) >> 1
	var door_cell := Vector2i(door_dir.x * hw, door_dir.y * hd)
	for i in range(-hw, hw + 1):
		for j in range(-hd, hd + 1):
			var edge_x := absi(i) == hw
			var edge_z := absi(j) == hd
			var cell := Vector2i(i, j)
			_put(world, "stone_brick", cx + i, floor_y, cz + j)
			if not (edge_x or edge_z):
				continue
			var corner := edge_x and edge_z
			for k in WALL_H:
				var y := floor_y + 1 + k
				if cell == door_cell:
					if k == 0:
						var yaw := 0.0 if door_dir.x == 0 else PI * 0.5
						_put(world, "door", cx + i, y, cz + j, yaw)
					elif k == 2:
						_put(world, "plank", cx + i, y, cz + j)
					continue
				_put(world, "wood" if corner else "plank", cx + i, y, cz + j)
	var out := door_cell + door_dir
	_put(world, "stone_stairs", cx + out.x, floor_y, cz + out.y, _ascent_yaw(-door_dir.x, -door_dir.y))
	var bed := Vector2i.ZERO
	if door_dir.y != 0:
		bed = Vector2i(-(hw - 1), -door_dir.y * (hd - 1))
	else:
		bed = Vector2i(-door_dir.x * (hw - 1), -(hd - 1))
	_put(world, "bed", cx + bed.x, floor_y + 1, cz + bed.y, 0.0)
	var back := Vector2i(-door_dir.x * hw, -door_dir.y * hd)
	var torch = load(TORCH_SCENE).instantiate()
	torch.fixture = false
	torch.wall_normal = Vector3(door_dir.x, 0.0, door_dir.y)
	world.add_child(torch)
	torch.global_position = Vector3(cx + back.x + door_dir.x + 0.5, floor_y + 2.5, cz + back.y + door_dir.y + 0.5)
	_roof(world, cx, cz, floor_y, hw, hd)


static func _roof(world, cx: int, cz: int, floor_y: int, hw: int, hd: int) -> void:
	var along_x := hw >= hd
	var half_along := hw if along_x else hd
	var half_across := hd if along_x else hw
	var base_y := floor_y + 1 + WALL_H
	for a in range(-half_along, half_along + 1):
		var end := absi(a) == half_along
		for t in range(-half_across, half_across + 1):
			var k := half_across - absi(t)
			var x := cx + (a if along_x else t)
			var z := cz + (t if along_x else a)
			if t == 0:
				_put(world, "plank", x, base_y + k, z)
			else:
				var s := signi(-t)
				var dx := 0 if along_x else s
				var dz := s if along_x else 0
				_put(world, "roof", x, base_y + k, z, _ascent_yaw(dx, dz))
		if end:
			for k in range(0, half_across):
				for t in range(-(half_across - k) + 1, half_across - k):
					var x := cx + (a if along_x else t)
					var z := cz + (t if along_x else a)
					_put(world, "plank", x, base_y + k, z)
