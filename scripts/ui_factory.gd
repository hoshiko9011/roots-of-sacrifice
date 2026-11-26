class_name UIFactory
extends RefCounted

const CREAM := Color("f6e6bf")
const INK := Color("2b4030")
const GREEN := Color("41683d")
const DEEP := Color("173f32")
const DEEP_DARK := Color("0f2d25")
const ACCENT := Color("d7ad62")
const GOLD := ACCENT
const WATER := Color("2f7f95")
const DANGER := Color("a95445")
const WOOD := Color("815234")
const WOOD_DARK := Color("5d3926")
const WOOD_LIGHT := Color("a76c3e")
const SURFACE_MUTED := Color("e8d9b6")
const BORDER := Color("b9965e")
const TEXT_MUTED := Color("6f725c")
const FONT = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const BOLD = preload("res://assets/fonts/Vazirmatn-Bold.ttf")

# Converts Latin digits in a value to Persian digits for display.
static func number(value: Variant) -> String:
	var result := str(value)
	for i in range(10):
		result = result.replace(str(i), "۰۱۲۳۴۵۶۷۸۹"[i])
	return result

# Creates a right-aligned, word-wrapped RTL label using the project fonts.
static func text(content: String, font_size: int = 20, color: Color = INK, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = content
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.add_theme_font_override("font", BOLD if bold else FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# Builds the shared padded panel style with rounded corners and a soft shadow.
static func style(fill: Color, edge: Color = BORDER, radius: int = 14, border: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 11
	box.content_margin_bottom = 11
	box.shadow_color = Color(0.03, 0.08, 0.05, 0.28)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 4)
	return box

# Adds a positioned, fixed-size styled panel to the requested parent.
static func panel(parent: Node, position: Vector2, size: Vector2, color: Color = CREAM) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", style(color, BORDER, 18, 2))
	parent.add_child(result)
	result.position = position
	result.size = size
	return result

# Adds a vertically arranged RTL container with the requested spacing.
static func column(parent: Node, spacing: int = 8) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", spacing)
	result.layout_direction = Control.LAYOUT_DIRECTION_RTL
	parent.add_child(result)
	return result

# Adds a horizontally arranged RTL container with the requested spacing.
static func row(parent: Node, spacing: int = 8) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", spacing)
	result.layout_direction = Control.LAYOUT_DIRECTION_RTL
	parent.add_child(result)
	return result

# Expands a nine-slice button texture around its text and optional icon.
static func _button_texture_style(asset_name: String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = GameAtlas.texture(asset_name + ".svg")
	box.texture_margin_left = 44
	box.texture_margin_right = 44
	box.texture_margin_top = 12
	box.texture_margin_bottom = 12
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

# Creates a themed RTL button whose click sound precedes a deferred gameplay action.
static func button(title: String, action: Callable, icon_name: String = "", variant: String = "primary") -> Button:
	var result := Button.new()
	result.text = title
	result.text_direction = Control.TEXT_DIRECTION_RTL
	result.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	result.custom_minimum_size = Vector2(0, 56)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_override("font", BOLD)
	result.add_theme_font_size_override("font_size", 20)
	# Unknown variants safely fall back to the primary button artwork.
	var assets := {
		"primary": "button_start",
		"accent": "button_start",
		"secondary": "button_wood_dark",
		"water": "button_water",
		"danger": "button_danger",
		"quiet": "button_wood",
		"wood": "button_wood",
		"wood_dark": "button_wood_dark",
		"start": "button_start",
	}
	var asset_name: String = assets.get(variant, "button_start")
	result.add_theme_color_override("font_color", CREAM)
	result.add_theme_color_override("font_hover_color", Color.WHITE)
	result.add_theme_color_override("font_focus_color", Color.WHITE)
	result.add_theme_color_override("font_pressed_color", CREAM)
	result.add_theme_stylebox_override("normal", _button_texture_style(asset_name))
	result.add_theme_stylebox_override("hover", _button_texture_style(asset_name + "_hover"))
	result.add_theme_stylebox_override("pressed", _button_texture_style(asset_name + "_pressed"))
	result.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), ACCENT, 14, 3))
	result.add_theme_stylebox_override("disabled", _button_texture_style(asset_name + "_pressed"))
	result.add_theme_color_override("font_disabled_color", Color("e7e0cb"))
	if not icon_name.is_empty():
		result.icon = GameAtlas.icon(icon_name)
		result.expand_icon = true
		result.add_theme_constant_override("icon_max_width", 28)
		result.add_theme_constant_override("h_separation", 10)
	# Hover feedback is skipped when the player enables reduced motion.
	result.mouse_entered.connect(func() -> void:
		if bool(GameState.settings.get("reduced_motion", false)):
			return
		result.create_tween().tween_property(result, "modulate", Color(1.06, 1.06, 1.06, 1.0), 0.12)
	)
	# Restores normal modulation after the pointer leaves.
	result.mouse_exited.connect(func() -> void:
		if bool(GameState.settings.get("reduced_motion", false)):
			return
		result.create_tween().tween_property(result, "modulate", Color.WHITE, 0.12)
	)
	# Press feedback dims the button without delaying its input signal.
	result.button_down.connect(func() -> void:
		if not bool(GameState.settings.get("reduced_motion", false)):
			result.create_tween().tween_property(result, "modulate", Color(0.94, 0.94, 0.94, 1.0), 0.08)
	)
	# Release feedback reflects whether the pointer still hovers over the button.
	result.button_up.connect(func() -> void:
		if not bool(GameState.settings.get("reduced_motion", false)):
			result.create_tween().tween_property(result, "modulate", Color(1.04, 1.04, 1.04, 1.0) if result.is_hovered() else Color.WHITE, 0.1)
	)
	# Deferring the callable lets button signal cleanup finish before game state changes.
	result.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		action.call_deferred()
	)
	return result

# Creates a non-interactive image that preserves aspect ratio within its minimum size.
static func image(texture: Texture2D, size: Vector2) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.custom_minimum_size = size
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

# Creates a percentage-free zero-to-one-hundred condition bar with themed colors.
static func progress(value: float, color: Color = GREEN) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", style(Color("d0c8a8"), Color.TRANSPARENT, 6, 0))
	bar.add_theme_stylebox_override("fill", style(color, Color.TRANSPARENT, 6, 0))
	return bar
