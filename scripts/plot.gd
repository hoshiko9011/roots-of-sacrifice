class_name GardenPlot
extends Node2D

# Render and interact with one planting bed, including growth, moisture, selection, and actions.
const SOIL_RECT: Rect2 = Rect2(-49.0, -23.0, 98.0, 46.0)
const BED_RECT: Rect2 = Rect2(-55.0, -29.0, 110.0, 60.0)
const HIT_RECT: Rect2 = Rect2(-56.0, -96.0, 112.0, 120.0)
# Static caches share plant and action-icon textures across every plot instance.
static var _plant_textures: Dictionary = {}
static var _icons: Dictionary = {}

var index: int = 0
var plot_data: Dictionary = {}
var selected: bool = false:
	# Redraw only when selection changes to avoid unnecessary outline work.
	set(value):
		if selected != value:
			selected = value
			queue_redraw()

var _plant: Texture2D
var _action_icon: Texture2D
var _outline: StyleBoxFlat
var _plant_scale: float = 1.0
var _last_stage: int = -1
var _wind_time: float = 0.0
var _redraw_time: float = 0.0

# Builds the selection outline and renders the plot's initial state.
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outline = StyleBoxFlat.new()
	_outline.bg_color = Color(0.9, 1.0, 0.73, 0.05)
	_outline.border_color = Color(0.98, 0.91, 0.55, 0.95)
	_outline.set_border_width_all(2)
	_outline.set_corner_radius_all(9)
	refresh(plot_data)

# Updates cached visuals and animates growth only when reduced motion is disabled.
func refresh(state: Dictionary) -> void:
	plot_data = state
	var species := String(plot_data.get("species", ""))
	_plant = null
	if not species.is_empty():
		var stage := clampi(int(plot_data.get("stage", 0)), 0, 5)
		if _last_stage >= 0 and stage != _last_stage and not bool(GameState.settings.get("reduced_motion", false)):
			_plant_scale = 0.78
			create_tween().tween_property(self, "_plant_scale", 1.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_last_stage = stage
		var key := species + ":" + str(stage)
		if not _plant_textures.has(key):
			_plant_textures[key] = GameAtlas.plant(species, stage)
		_plant = _plant_textures[key]
	# Empty beds advertise the next valid action: seed when prepared, otherwise soil.
	var action := "leaf" if not species.is_empty() else ("seed" if bool(plot_data.get("prepared", false)) else "soil")
	if not _icons.has(action):
		_icons[action] = GameAtlas.icon(action)
	_action_icon = _icons[action]
	queue_redraw()

# Tests interaction input against the plot's enlarged local hit area.
func contains_point(world_point: Vector2) -> bool:
	return HIT_RECT.has_point(to_local(world_point))

# Advances wind for living plants and caps redraws at fifteen frames per second.
func _process(delta: float) -> void:
	if _plant == null or bool(GameState.settings.get("reduced_motion", false)):
		return
	_wind_time += delta
	_redraw_time += delta
	if _redraw_time >= 1.0 / 15.0:
		_redraw_time = 0.0
		queue_redraw()

# Draws the bed, plant condition, memorial marker, and contextual selection prompt.
func _draw() -> void:
	var prepared := bool(plot_data.get("prepared", false))
	draw_rect(BED_RECT, Color(0.08, 0.14, 0.10, 0.82))
	draw_rect(Rect2(-51.0, -25.0, 102.0, 52.0), Color(0.78, 0.63, 0.36, 0.92))
	var shade := Color(0.25, 0.16, 0.10, 0.43) if prepared else Color(0.56, 0.42, 0.27, 0.14)
	draw_rect(SOIL_RECT, shade)
	# Prepared soil gets furrows; untouched soil gets deterministic scattered pebbles.
	if prepared:
		for row in range(4):
			var y := -15.0 + float(row) * 10.0
			draw_line(Vector2(-40.0, y), Vector2(40.0, y - 1.0), Color(0.18, 0.12, 0.07, 0.3), 2.0)
	else:
		for i in range(9):
			var pebble := Vector2(float((i * 31 + index * 13) % 83) - 41.0, float((i * 17) % 35) - 17.0)
			draw_circle(pebble, 1.5, Color(0.75, 0.64, 0.42, 0.45))
	if selected and _outline != null:
		draw_style_box(_outline, BED_RECT)
	if _plant != null:
		var dead := bool(plot_data.get("dead", false))
		var plant_size := 96.0 * _plant_scale
		var sway := sin(_wind_time * 1.7 + float(index)) * 0.012 if not dead else 0.0
		draw_set_transform(Vector2(sway * 18.0, 0.0), sway)
		draw_texture_rect(_plant, Rect2(-plant_size * 0.5, 9.0 - plant_size, plant_size, plant_size), false, Color(0.48, 0.34, 0.22, 0.72) if dead else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		if not dead:
			_draw_bar(Vector2(-24.0, 24.0), float(plot_data.get("moisture", 0)) / 100.0, Color("5bc8e4"))
			var health := float(plot_data.get("health", 100)) / 100.0
			_draw_bar(Vector2(-24.0, 32.0), health, Color("9bc769") if health >= 0.6 else Color("ed9870"))
		if not String(plot_data.get("name", "")).is_empty():
			draw_rect(Rect2(28.0, 2.0, 13.0, 9.0), Color("f1dfae"))
			draw_line(Vector2(34.0, 11.0), Vector2(34.0, 17.0), Color("66482c"), 2.0)
	if selected and _action_icon != null and _plant == null:
		draw_circle(Vector2(0.0, -43.0), 15.0, Color(0.09, 0.22, 0.18, 0.85))
		draw_texture_rect(_action_icon, Rect2(-12.0, -55.0, 24.0, 24.0), false)

# Draws a clamped condition bar over its dark background and track.
func _draw_bar(origin: Vector2, amount: float, color: Color) -> void:
	draw_rect(Rect2(origin - Vector2.ONE, Vector2(50.0, 6.0)), Color(0.08, 0.17, 0.13, 0.78))
	draw_rect(Rect2(origin, Vector2(48.0, 4.0)), Color(0.24, 0.28, 0.22, 0.8))
	draw_rect(Rect2(origin, Vector2(48.0 * clampf(amount, 0.0, 1.0), 4.0)), color)
