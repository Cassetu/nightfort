extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")
const WALL_H := 3.0
const THICK := 0.5
const DOOR := 2.0


static func _wall_material(tile: String, tint: Color, w: float, h: float) -> StandardMaterial3D:
	var base := TileArt.uv_material(tile, tint, Vector3.ONE)
	var m := base.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(maxf(w, 1.0), maxf(h, 1.0), 1.0)
	m.albedo_color = tint
	return m


static func _box(parent: Node3D, body: StaticBody3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = TileArt.box_mesh(size, mat)
	mi.position = pos
	parent.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


static func build(parent: Node3D, pos: Vector3, yaw: float, w: int, d: int, door_side: int, tint: Color, roof_tint: Color) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = yaw
	parent.add_child(node)
	var body := StaticBody3D.new()
	node.add_child(body)
	var fw := float(w)
	var fd := float(d)
	var plank_a := _wall_material("plank", tint, fw, WALL_H)
	var plank_b := _wall_material("plank", tint, fd, WALL_H)
	var stone := _wall_material("stone_brick", Color(0.7, 0.7, 0.72), fw, 1.0)
	_box(node, body, Vector3(0.0, 0.5, 0.0), Vector3(fw + 0.4, 1.0, fd + 0.4), stone)
	for side in 4:
		var along_x := side < 2
		var length := fw if along_x else fd
		var mat := plank_a if along_x else plank_b
		var sign_v := -1.0 if side % 2 == 0 else 1.0
		var offset := (fd if along_x else fw) * 0.5 - THICK * 0.5
		var wpos := Vector3(0.0, 1.0 + (WALL_H - 1.0) * 0.5, 0.0)
		if along_x:
			wpos.z = sign_v * offset
		else:
			wpos.x = sign_v * offset
		var size := Vector3(length, WALL_H - 1.0, THICK) if along_x else Vector3(THICK, WALL_H - 1.0, length)
		if side != door_side:
			_box(node, body, wpos, size, mat)
			continue
		var seg := (length - DOOR) * 0.5
		for half in [-1.0, 1.0]:
			var seg_pos := wpos
			var seg_size := size
			if along_x:
				seg_pos.x = half * (DOOR * 0.5 + seg * 0.5)
				seg_size.x = seg
			else:
				seg_pos.z = half * (DOOR * 0.5 + seg * 0.5)
				seg_size.z = seg
			_box(node, body, seg_pos, seg_size, mat)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = roof_tint
	roof_mat.roughness = 1.0
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.material = roof_mat
	if w > d:
		prism.size = Vector3(fd + 1.2, 1.8, fw + 1.2)
		roof.rotation.y = PI * 0.5
	else:
		prism.size = Vector3(fw + 1.2, 1.8, fd + 1.2)
	roof.mesh = prism
	roof.position = Vector3(0.0, WALL_H + 0.9, 0.0)
	node.add_child(roof)
	var cap := CollisionShape3D.new()
	var cap_shape := BoxShape3D.new()
	cap_shape.size = Vector3(fw + 1.0, 1.2, fd + 1.0)
	cap.shape = cap_shape
	cap.position = Vector3(0.0, WALL_H + 0.6, 0.0)
	body.add_child(cap)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 0.7
	light.omni_range = 6.0
	light.position = Vector3(0.0, 1.8, 0.0)
	node.add_child(light)
	return node
