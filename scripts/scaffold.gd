extends "res://scripts/block.gd"

const DECK := 0.125
const POST := 0.125
const POLL := 0.3

var deck: MeshInstance3D
var deck_col: CollisionShape3D
var posts: Array = []
var short_mesh: ArrayMesh
var full_mesh: ArrayMesh
var poll_timer: float = 0.0
var deck_on: bool = true


func _build() -> void:
	var deck_mat := TileArt.uv_material("plank", Color(0.72, 0.55, 0.32), Vector3.ONE)
	var post_mat := TileArt.uv_material("wood", Color(0.58, 0.40, 0.22), Vector3.ONE)

	deck = MeshInstance3D.new()
	deck.mesh = TileArt.box_mesh(Vector3(1.0, DECK, 1.0), deck_mat)
	deck.position = Vector3(0.0, 0.5 - DECK * 0.5, 0.0)
	visual.add_child(deck)

	short_mesh = TileArt.box_mesh(Vector3(POST, 1.0 - DECK, POST), post_mat)
	full_mesh = TileArt.box_mesh(Vector3(POST, 1.0, POST), post_mat)
	var offset := 0.5 - POST * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			post.mesh = short_mesh
			post.position = Vector3(sx * offset, -DECK * 0.5, sz * offset)
			visual.add_child(post)
			posts.append(post)

	deck_col = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, DECK, 1.0)
	deck_col.shape = box
	deck_col.position = Vector3(0.0, 0.5 - DECK * 0.5, 0.0)
	add_child(deck_col)

	_refresh_deck()


func _process(delta: float) -> void:
	if dying:
		return
	poll_timer += delta
	if poll_timer < POLL:
		return
	poll_timer = 0.0
	_refresh_deck()


func _refresh_deck() -> void:
	var open := true
	var stability := get_tree().get_first_node_in_group("stability")
	if stability != null:
		var above = stability.cell_map.get(cells()[0] + Vector3i.UP)
		if above != null and above != self and not above.dying and above.block_type == "scaffold":
			open = false
	if open == deck_on and deck_col != null and deck.visible == open:
		return
	deck_on = open
	deck.visible = open
	deck_col.set_deferred("disabled", not open)
	for post in posts:
		post.mesh = short_mesh if open else full_mesh
		post.position.y = -DECK * 0.5 if open else 0.0
