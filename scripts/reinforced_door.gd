extends "res://scripts/door.gd"

const FRAME_TILE := "stone_brick"
const FRAME_COLOR := Color(0.55, 0.55, 0.6)
const POST_W := 0.14
const FRAME_D := 0.34


func _build() -> void:
	super()
	var mat := TileArt.uv_material(FRAME_TILE, FRAME_COLOR, Vector3.ONE)
	var post_mesh := TileArt.box_mesh(Vector3(POST_W, 2.0, FRAME_D), mat)
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.position = Vector3(sx * (0.5 - POST_W * 0.5), 0.5, 0.0)
		visual.add_child(post)
	var lintel := MeshInstance3D.new()
	lintel.mesh = TileArt.box_mesh(Vector3(1.0, POST_W, FRAME_D), mat)
	lintel.position = Vector3(0.0, 1.5 - POST_W * 0.5, 0.0)
	visual.add_child(lintel)


func _half(tile: String, y: float) -> MeshInstance3D:
	var mi := super(tile, y)
	mi.mesh = TileArt.box_mesh(Vector3(1.0 - POST_W, 1.0, 0.2), TileArt.uv_material(tile, Color(0.5, 0.5, 0.55), Vector3.ONE))
	return mi
