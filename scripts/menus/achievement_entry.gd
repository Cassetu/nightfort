extends PanelContainer

@onready var icon: TextureRect = %Icon
@onready var title: Label = %Name
@onready var req: Label = %Req
@onready var bar: ProgressBar = %Bar
@onready var count: Label = %Count
@onready var message: Label = %Message


func setup(def: Dictionary) -> void:
	var mgr = Game.achievements
	var earned: bool = mgr.is_done(def["id"])
	var veiled: bool = bool(def["hidden"]) and not earned
	icon.texture = mgr.icon_for(def, veiled)
	title.text = "???" if veiled else String(def["name"])
	req.text = "" if veiled else String(def["req"])
	bar.max_value = float(def["goal"])
	bar.value = 0.0 if veiled else float(mgr.value_of(def))
	bar.visible = not veiled
	count.text = "" if veiled else "%d / %d" % [mgr.value_of(def), int(def["goal"])]
	message.text = "" if veiled else String(def["msg"])
	modulate = Color(1, 1, 1, 1) if earned else Color(0.74, 0.74, 0.8, 1)
