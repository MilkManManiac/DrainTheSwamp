class_name PixelUI
extends RefCounted
# Pixel UI skin helpers shared by hud / shop / menu / ticker / touch controls.
# Everything visual comes from assets/art/ui/* (drawn by tools/bake/ui_kit.py)
# and assets/ui_theme.tres; this file only hands out tinted copies so the panels
# can keep their per-category colour cues without building StyleBoxFlats.
#
# UI grid: viewport 640x360 stretched x2, so 1 UI px = 1 art px = 2 screen px.
# Silkscreen sizes are 8 (captions / body) and 16 (headers / hero numbers) only.

const THEME: Theme = preload("res://assets/ui_theme.tres")
const TEX_INSET: Texture2D = preload("res://assets/art/ui/panel_inset.png")
const TEX_PARCH: Texture2D = preload("res://assets/art/ui/panel_parchment.png")
const TEX_WOOD: Texture2D = preload("res://assets/art/ui/panel_wood.png")
const TEX_FRAME: Texture2D = preload("res://assets/art/ui/panel_frame.png")
const TEX_CONTENT: Texture2D = preload("res://assets/art/ui/panel_content.png")
const TEX_ROW: Texture2D = preload("res://assets/art/ui/row_card.png")
const TEX_ROW_ACTIVE: Texture2D = preload("res://assets/art/ui/row_card_active.png")
const TEX_ROW_LOCKED: Texture2D = preload("res://assets/art/ui/row_card_locked.png")
const TEX_BAR_FILL: Texture2D = preload("res://assets/art/ui/bar_fill.png")
const FONT_BODY: FontFile = preload("res://assets/fonts/VT323-Regular.ttf")
const FONT_SILK: FontFile = preload("res://assets/fonts/Silkscreen-Regular.ttf")

const ICONS: Dictionary = {
	"coin": preload("res://assets/art/ui/icon_coin.png"),
	"bag": preload("res://assets/art/ui/icon_bag.png"),
	"sun": preload("res://assets/art/ui/icon_sun.png"),
	"moon": preload("res://assets/art/ui/icon_moon.png"),
	"drop": preload("res://assets/art/ui/icon_drop.png"),
	"bolt": preload("res://assets/art/ui/icon_bolt.png"),
	"air": preload("res://assets/art/ui/icon_air.png"),
}

const TOOL_ICONS: Dictionary = {
	"hands": preload("res://assets/art/ui/icon_tool_hands.png"),
	"spoon": preload("res://assets/art/ui/icon_tool_spoon.png"),
	"cup": preload("res://assets/art/ui/icon_tool_cup.png"),
	"bucket": preload("res://assets/art/ui/icon_tool_bucket.png"),
	"shovel": preload("res://assets/art/ui/icon_tool_shovel.png"),
	"wheelbarrow": preload("res://assets/art/ui/icon_tool_wheelbarrow.png"),
	"barrel": preload("res://assets/art/ui/icon_tool_barrel.png"),
	"water_wagon": preload("res://assets/art/ui/icon_tool_water_wagon.png"),
	"hose": preload("res://assets/art/ui/icon_tool_hose.png"),
}

const CREAM := Color(0.94, 0.88, 0.72)
const CREAM_DIM := Color(0.72, 0.66, 0.52)
const GOLD := Color(1.0, 0.86, 0.32)
const GREEN := Color(0.45, 0.9, 0.5)
const RED := Color(0.95, 0.4, 0.35)
const INK := Color(0.2, 0.14, 0.08)

const SIZE_CAPTION: int = 8
const SIZE_HEADER: int = 16


static func icon(name: String, min_size: int = 9) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = ICONS[name]
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(min_size, min_size)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func tool_icon(tool_id: String, min_size: int = 14) -> TextureRect:
	## Per-tool pixel icon baked from the player track's in-hand sprites
	## (assets/art/drainsville/tool_*.png) — see tools/bake/ui_kit.py::tool_icon.
	var tr := TextureRect.new()
	tr.texture = TOOL_ICONS.get(tool_id, TOOL_ICONS["hands"])
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(min_size, min_size)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func frame(pad_x: int = 10, pad_y: int = 8) -> StyleBoxTexture:
	## Outermost surface: darker wood, thicker border, brass corner rivets.
	## Use for the outside of dialogs/panels — never for content or rows, so
	## the three surfaces (frame > content > row) stay visually distinct.
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_FRAME
	sb.texture_margin_left = 7
	sb.texture_margin_top = 7
	sb.texture_margin_right = 7
	sb.texture_margin_bottom = 7
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func content(pad_x: int = 6, pad_y: int = 6) -> StyleBoxTexture:
	## Middle surface: lighter than the frame, darker than a row card. The
	## backdrop content sits on — a shop's scroll area, a popup's body.
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_CONTENT
	sb.texture_margin_left = 4
	sb.texture_margin_top = 4
	sb.texture_margin_right = 4
	sb.texture_margin_bottom = 4
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func row(pad_x: int = 6, pad_y: int = 4, state: String = "normal") -> StyleBoxTexture:
	## Lightest surface: one row/list item as its own raised chip.
	## state: "normal" | "active" (equipped/selected, green edge) | "locked"
	## (desaturated, recedes). Replaces the old single dark `inset()` used for
	## every row regardless of state — that's what read as "empty inset row".
	var sb := StyleBoxTexture.new()
	match state:
		"active":
			sb.texture = TEX_ROW_ACTIVE
		"locked":
			sb.texture = TEX_ROW_LOCKED
		_:
			sb.texture = TEX_ROW
	sb.texture_margin_left = 3
	sb.texture_margin_top = 3
	sb.texture_margin_right = 3
	sb.texture_margin_bottom = 3
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func inset(tint: Color = Color.WHITE, pad_x: int = 6, pad_y: int = 4) -> StyleBoxTexture:
	## Dark wood slot (shop rows, sections). `tint` is blended in lightly so the
	## old category colours still read without turning the wood into plastic.
	## Low blend amount: a saturated-but-dark tint (e.g. a dim blue-grey category
	## colour) multiplies the texture DARKER, not lighter — the baked inset
	## texture is already lightened for contrast, so the tint only needs to be
	## a faint hue wash, not the main source of value.
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_INSET
	sb.texture_margin_left = 3
	sb.texture_margin_top = 3
	sb.texture_margin_right = 3
	sb.texture_margin_bottom = 3
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.modulate_color = _tint_mod(tint, 0.15)
	return sb


static func _tint_mod(tint: Color, amount: float) -> Color:
	## The old panels passed near-black category colours; lift them to full
	## value so only the hue survives as a light wash over the wood.
	if tint == Color.WHITE:
		return Color.WHITE
	var t := Color.from_hsv(tint.h, minf(tint.s * 0.7, 0.5), 1.0)
	return Color.WHITE.lerp(t, amount)


static func wood(pad_x: int = 8, pad_y: int = 6) -> StyleBoxTexture:
	## Same wood plank panel as the HUD/shop/menu chrome, for dialogs built in
	## code (no shared Theme resource) — e.g. scene_manager.gd popups.
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_WOOD
	sb.texture_margin_left = 6
	sb.texture_margin_top = 6
	sb.texture_margin_right = 6
	sb.texture_margin_bottom = 6
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func parchment(pad_x: int = 6, pad_y: int = 4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_PARCH
	sb.texture_margin_left = 3
	sb.texture_margin_top = 3
	sb.texture_margin_right = 3
	sb.texture_margin_bottom = 3
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func bar_fill(color: Color) -> StyleBoxTexture:
	## Segmented pixel fill; recolour by setting `modulate_color` later.
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_BAR_FILL
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.modulate_color = color
	return sb


static func button(btn: Button, tint: Color = Color.WHITE) -> void:
	## Wood button from the theme with an optional light tint (kept subtle so
	## every button on a screen is the same wood).
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.add_theme_font_size_override("font_size", SIZE_CAPTION)
	if tint == Color.WHITE:
		return
	var mod: Color = _tint_mod(tint, 0.3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxTexture = THEME.get_stylebox(state, "Button").duplicate()
		if state != "disabled":
			sb.modulate_color = mod
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_stylebox_override("hover_pressed", btn.get_theme_stylebox("pressed"))


static func caption(text: String, color: Color = CREAM, centered: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", SIZE_CAPTION)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func header(text: String, color: Color = GOLD) -> Label:
	var l := caption(text, color, true)
	l.add_theme_font_size_override("font_size", SIZE_HEADER)
	return l


static func section_label(text: String, color: Color) -> Label:
	## "-- Core Stats --" style dividers: caption size, centred, category colour.
	return caption(text, color, true)


static func prompt(text: String, color: Color = Color(1.0, 0.92, 0.6)) -> Label:
	## In-world floating prompt ("[SPACE]", "PRESS SPACE TO ENTER") — a bare
	## Label dropped directly on a world node (not under PixelUI.THEME), so it
	## needs its own Silkscreen font override, not just a size override.
	## Used by lore_wall.gd, loot_node.gd, dead_drop.gd, cave_base.gd; leaves
	## position/z_index/visibility to the caller.
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_SILK)
	l.add_theme_font_size_override("font_size", SIZE_CAPTION)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.02, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
