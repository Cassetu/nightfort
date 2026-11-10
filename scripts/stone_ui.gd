extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")

const THEME_PATH := "res://resources/main-theme.tres"
const SIZE := 32
const BORDER := 3
const BODY_FONT := "res://resources/fonts/AlegreyaSans-Medium.ttf"
const AMBER := Color(1.0, 0.78, 0.25)

static var applied: bool = false


static func apply(theme: Theme) -> void:
	if applied or theme == null:
		return
	applied = true
	var body: Font = load(BODY_FONT)
	if body != null:
		theme.default_font = body
		ThemeDB.fallback_font = body
	var cool := Color(0.74, 0.74, 0.8)
	_style(theme, "Button", "normal", cool, false, Color(0, 0, 0, 0))
	_style(theme, "Button", "hover", Color(0.98, 0.9, 0.78), false, AMBER)
	_style(theme, "Button", "pressed", Color(0.5, 0.46, 0.4), true, AMBER)
	_style(theme, "Button", "disabled", Color(0.38, 0.38, 0.42), true, Color(0, 0, 0, 0))
	_style(theme, "PanelContainer", "panel", Color(0.46, 0.46, 0.52), false, Color(0, 0, 0, 0))
	_style(theme, "SlotPanel", "panel", Color(0.36, 0.36, 0.42), true, Color(0, 0, 0, 0))
	_style(theme, "SlotHover", "panel", Color(0.5, 0.5, 0.56), true, Color(0.85, 0.85, 0.9))
	_style(theme, "SlotSelected", "panel", Color(0.36, 0.36, 0.42), true, AMBER)
	_style(theme, "LineEdit", "normal", Color(0.3, 0.3, 0.35), true, Color(0, 0, 0, 0))
	_style(theme, "LineEdit", "focus", Color(0.34, 0.34, 0.4), true, AMBER)


static func _style(theme: Theme, type: String, style_name: String, tint: Color, inset: bool, accent: Color) -> void:
	var old: StyleBox = theme.get_stylebox(style_name, type) if theme.has_stylebox(style_name, type) else null
	theme.set_stylebox(style_name, type, _box(old, tint, inset, accent))


static func _box(old: StyleBox, tint: Color, inset: bool, accent: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(_image(tint, inset, accent))
	sb.texture_margin_left = BORDER + 1
	sb.texture_margin_right = BORDER + 1
	sb.texture_margin_top = BORDER + 1
	sb.texture_margin_bottom = BORDER + 1
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	if old != null:
		sb.content_margin_left = maxf(old.content_margin_left, 8.0)
		sb.content_margin_right = maxf(old.content_margin_right, 8.0)
		sb.content_margin_top = maxf(old.content_margin_top, 6.0)
		sb.content_margin_bottom = maxf(old.content_margin_bottom, 6.0)
	return sb


static func _image(tint: Color, inset: bool, accent: Color) -> Image:
	var src := TileArt.tile_image("stone", Color(0.5, 0.5, 0.55))
	var sw := src.get_width()
	var sh := src.get_height()
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var lit := 0.3
	var shade := 0.5
	for y in SIZE:
		for x in SIZE:
			var base := src.get_pixel((x * sw / SIZE) % sw, (y * sh / SIZE) % sh)
			var c := Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, 1.0)
			var edge := mini(mini(x, y), mini(SIZE - 1 - x, SIZE - 1 - y))
			if edge == 0:
				c = Color(c.r * 0.25, c.g * 0.25, c.b * 0.28, 1.0)
			elif edge <= BORDER:
				var top_left := (x <= y and x < SIZE - 1 - y and x == edge) or (y < x and y == edge and y < SIZE - 1 - x)
				var bright := top_left != inset
				if bright:
					c = c.lerp(Color.WHITE, lit)
				else:
					c = c.lerp(Color.BLACK, shade)
				if accent.a > 0.0 and edge == 1:
					c = c.lerp(accent, 0.8)
			img.set_pixel(x, y, c)
	return img
