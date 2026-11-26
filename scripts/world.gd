# Builds playable zones and owns nearby interactions, prompts, and ambient effects.
class_name WorldController
extends Node2D

signal interaction(kind: String, index: int)
signal hint_changed(text: String)

const UI = preload("res://scripts/ui_factory.gd")
const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const PLOT_SCRIPT = preload("res://scripts/plot.gd")
const VIRTUAL_SIZE: Vector2 = Vector2(1280.0, 720.0)
const INTERACTION_DISTANCE: float = 115.0
const PLOT_POSITIONS: Array[Vector2] = [
	Vector2(245, 300), Vector2(420, 300), Vector2(245, 420),
	Vector2(420, 420), Vector2(245, 540), Vector2(420, 540)
]
const NPC_POSITIONS: Array[Vector2] = [
	Vector2(610, 400), Vector2(785, 390), Vector2(870, 515), Vector2(665, 550)
]
const LITTER_POSITIONS: Array[Vector2] = [
	Vector2(540, 520), Vector2(600, 300), Vector2(790, 580), Vector2(540, 430),
	Vector2(935, 400), Vector2(760, 260), Vector2(610, 610), Vector2(540, 355)
]
const WATER_POSITION: Vector2 = Vector2(1035, 490)
const COMPOST_POSITION: Vector2 = Vector2(900, 300)
const WATER_OBSTACLE: Rect2 = Rect2(970, 465, 170, 150)
const SHED_OBSTACLE: Rect2 = Rect2(950, 170, 280, 175)
const MONUMENT_OBSTACLE: Rect2 = Rect2(587, 214, 110, 164)
const CHAPTER_SCENES: Dictionary = {
	1: "garden_overgrown", 2: "garden_saplings", 3: "garden_soil_water",
	4: "school_courtyard", 5: "memorial_garden", 6: "neighborhood_park",
	7: "green_city", 8: "city_stewardship"
}
const DEFAULT_SCENES: Dictionary = {
	"garden": "garden_saplings", "school": "school_courtyard",
	"park": "neighborhood_park", "city": "green_city"
}
const SCENE_OBSTACLES: Dictionary = {
	"garden_overgrown": [SHED_OBSTACLE, WATER_OBSTACLE],
	"garden_saplings": [SHED_OBSTACLE, WATER_OBSTACLE],
	"garden_soil_water": [SHED_OBSTACLE, WATER_OBSTACLE],
	"school_courtyard": [WATER_OBSTACLE],
	"memorial_garden": [MONUMENT_OBSTACLE, WATER_OBSTACLE],
	"neighborhood_park": [WATER_OBSTACLE, Rect2(566, 244, 52, 32), Rect2(982, 266, 52, 32), Rect2(882, 572, 52, 32)],
	"green_city": [WATER_OBSTACLE, Rect2(0, 200, 118, 520), Rect2(1162, 200, 118, 520), Rect2(112, 222, 32, 32), Rect2(1002, 210, 32, 32), Rect2(1144, 244, 32, 32), Rect2(570, 574, 52, 32), Rect2(720, 244, 52, 32)],
	"city_stewardship": [WATER_OBSTACLE, Rect2(0, 200, 118, 520), Rect2(1162, 200, 118, 520), Rect2(110, 210, 32, 32), Rect2(1000, 198, 32, 32), Rect2(1144, 228, 32, 32), Rect2(566, 574, 52, 32), Rect2(718, 244, 52, 32), Rect2(724, 500, 176, 70)]
}
const ZONE_PROP_OBSTACLES: Dictionary = {
	"garden": [Rect2(872, 282, 56, 32)],
	"school": [Rect2(680, 184, 60, 30), Rect2(872, 282, 56, 32)],
	"park": [Rect2(700, 247, 60, 32), Rect2(818, 287, 44, 28), Rect2(875, 592, 50, 32)],
	"city": [Rect2(533, 274, 24, 24), Rect2(813, 589, 24, 24), Rect2(810, 252, 60, 32)]
}

# Clamp virtual joystick input before forwarding it to the player.
var touch_direction: Vector2 = Vector2.ZERO:
	set(value):
		touch_direction = value.limit_length(1.0)
		if is_instance_valid(_player):
			_player.set_external_direction(touch_direction)
# Disable player movement and interaction focus together with world input.
var enabled: bool = true:
	set(value):
		enabled = value
		if is_instance_valid(_player):
			_player.enabled = enabled
		if is_instance_valid(_prompt):
			_update_focus()

var _layer: Node2D
var _player: PlayerController
var _plots: Array[GardenPlot] = []
var _npcs: Array[Sprite2D] = []
var _litter: Array[Sprite2D] = []
var _npc_frames: Array[Texture2D] = []
var _props: Dictionary = {}
var _icons: Dictionary = {}
var _backgrounds: Dictionary = {}
var _background: Texture2D
var _atmosphere: Atmosphere
var _prompt: PanelContainer
var _prompt_icon: TextureRect
var _prompt_label: Label
var _water_button: Button
var _compost_sprite: Sprite2D
var _bursts: Array[Node2D] = []
var _zone: String = ""
var _chapter: int = 0
var _scene: String = ""
var _memorial: bool = false
var _weather: String = ""
var _biodiversity: int = 0
var _reduced_motion: bool = false
var _clock: float = 0.0
var _redraw_time: float = 0.0
var _npc_frame: int = -1
var _reloading: bool = false
var _target: Dictionary = {}
var _last_hint: String = ""
var _hint_override: String = ""
var _hint_time: float = 0.0
var _last_pointer_ms: int = -1000
var _pending_position: Vector2 = Vector2(660, 460)
var _has_pending_position: bool = false

# Cache art, connect state updates, and build the initial zone when ready.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cache_art()
	_atmosphere = Atmosphere.new()
	_atmosphere.world = self
	_atmosphere.z_index = 0
	add_child(_atmosphere)
	_build_prompt()
	_build_water_button()
	GameState.changed.connect(refresh)
	GameState.time_changed.connect(_on_time_changed)
	reload_zone()

# Load chapter backdrops, NPC frames, icons, and props once per controller.
func _cache_art() -> void:
	for scene_value in CHAPTER_SCENES.values():
		var scene := String(scene_value)
		_backgrounds[scene] = GameAtlas.texture("scene_" + scene + ".svg")
	for row in range(4):
		for column in range(2):
			_npc_frames.append(GameAtlas.cell("npcs.svg", column, row))
	for key in ["soil", "seed", "leaf", "water", "book", "trash", "recycle"]:
		_icons[key] = GameAtlas.icon(key)
	_props["litter"] = GameAtlas.cell("props.svg", 6, 0)
	_props["recycle"] = GameAtlas.cell("props.svg", 7, 1)
	_props["board"] = GameAtlas.cell("props.svg", 5, 0)
	_props["bench"] = GameAtlas.cell("props.svg", 0, 2)
	_props["lamp"] = GameAtlas.cell("props.svg", 1, 2)
	_props["birdbath"] = GameAtlas.cell("props.svg", 2, 2)
	_props["compost"] = GameAtlas.cell("props.svg", 6, 2)

# Build a right-to-left prompt that never intercepts pointer input.
func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.z_index = 80
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.18, 0.15, 0.94)
	style.border_color = Color(0.88, 0.82, 0.52, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_prompt.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_prompt_icon = TextureRect.new()
	_prompt_icon.custom_minimum_size = Vector2(26, 26)
	_prompt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_prompt_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_prompt_icon)
	_prompt_label = Label.new()
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.text_direction = Control.TEXT_DIRECTION_RTL
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_label.add_theme_font_size_override("font_size", 16)
	_prompt_label.add_theme_color_override("font_color", Color("fff2cf"))
	row.add_child(_prompt_label)
	_prompt.add_child(row)
	add_child(_prompt)
	_prompt.hide()

# Provide a thumb-sized contextual button for a nearby thirsty plant.
func _build_water_button() -> void:
	_water_button = UIFactory.button("آب", func() -> void: water_nearest(), "", "water")
	_water_button.custom_minimum_size = Vector2(78, 78)
	_water_button.size = Vector2(78, 78)
	_water_button.z_index = 90
	_water_button.add_theme_font_size_override("font_size", 18)
	_water_button.add_theme_stylebox_override("normal", UIFactory.style(UI.WATER, UI.ACCENT, 39, 3))
	_water_button.add_theme_stylebox_override("hover", UIFactory.style(UI.WATER.lightened(0.12), UI.ACCENT, 39, 3))
	_water_button.add_theme_stylebox_override("pressed", UIFactory.style(UI.WATER.darkened(0.12), UI.ACCENT, 39, 3))
	_water_button.add_theme_stylebox_override("focus", UIFactory.style(Color.TRANSPARENT, UI.ACCENT, 39, 3))
	add_child(_water_button)
	_water_button.hide()

# Redraw atmospheric lighting and weather when the game clock changes.
func _on_time_changed() -> void:
	if is_instance_valid(_atmosphere):
		_atmosphere.queue_redraw()

# Rebuild zone actors while preserving the saved or explicitly requested spawn.
func reload_zone() -> void:
	if not is_node_ready() or _reloading:
		return
	_reloading = true
	# Detach before freeing: no stale render, physics or target nodes survive.
	var old_layer := _layer
	_layer = null
	_player = null
	_plots.clear()
	_npcs.clear()
	_litter.clear()
	_compost_sprite = null
	for burst in _bursts:
		if is_instance_valid(burst):
			burst.free()
	_bursts.clear()
	_target = {}
	if is_instance_valid(old_layer):
		remove_child(old_layer)
		old_layer.free()
	_zone = String(GameState.data.get("zone", "garden"))
	_chapter = int(GameState.data.get("chapter", 1))
	_scene = _scene_for_current_location()
	_memorial = _scene == "memorial_garden"
	AudioManager.set_zone("memorial" if _memorial else _zone)
	_background = _backgrounds[_scene]
	_layer = Node2D.new()
	_layer.name = "Actors"
	_layer.y_sort_enabled = true
	add_child(_layer)
	_hint_override = ""
	_hint_time = 0.0
	_npc_frame = -1
	if not GameState.data.is_empty():
		var states: Array = GameState.plots()
		for i in range(mini(6, states.size())):
			var plot: GardenPlot = PLOT_SCRIPT.new()
			plot.index = i
			plot.position = PLOT_POSITIONS[i]
			plot.plot_data = states[i]
			_layer.add_child(plot)
			_plots.append(plot)
		for i in range(NPC_POSITIONS.size()):
			_npcs.append(_add_sprite(NPC_POSITIONS[i], _npc_frames[i * 2], 1.35))
		for i in range(LITTER_POSITIONS.size()):
			var sprite := _add_sprite(LITTER_POSITIONS[i], _props["litter" if i % 2 == 0 else "recycle"], 0.65)
			sprite.visible = not GameState.trash_collected(i)
			_litter.append(sprite)
		_build_zone_props()
		_player = PLAYER_SCRIPT.new()
		_player.name = "Player"
		_player.blocked_rects.assign(_blocked_rects())
		_player.blocked_points.assign(NPC_POSITIONS)
		var saved: Array = GameState.data.get("player", [660.0, 460.0])
		# A requested spawn applies once; later reloads return to the saved coordinate.
		_player.position = _pending_position if _has_pending_position else Vector2(float(saved[0]), float(saved[1]))
		_has_pending_position = false
		_player.enabled = enabled
		_player.set_external_direction(touch_direction)
		_layer.add_child(_player)
		_store_player_position()
	_reloading = false
	_refresh_compost_visual()
	_refresh_environment()
	_update_focus()
	queue_redraw()

# Combine scene, prop, and plot-bed footprints into the player's collision set.
func _blocked_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	rects.assign(SCENE_OBSTACLES.get(_scene, []))
	rects.append_array(ZONE_PROP_OBSTACLES.get(_zone, []))
	for plot_position in PLOT_POSITIONS:
		rects.append(Rect2(plot_position + GardenPlot.BED_RECT.position, GardenPlot.BED_RECT.size))
	return rects

# Use chapter artwork only at its matching location to avoid memorial ambience elsewhere.
func _scene_for_current_location() -> String:
	if GameState.data.is_empty():
		return String(DEFAULT_SCENES.get(_zone, "garden_overgrown"))
	var chapter: Dictionary = GameState.current_chapter()
	if String(chapter.get("location", "")) == _zone:
		return String(CHAPTER_SCENES.get(int(chapter.get("id", 1)), DEFAULT_SCENES.get(_zone, "garden_overgrown")))
	return String(DEFAULT_SCENES.get(_zone, "garden_overgrown"))

# Anchor tall artwork at its ground point so sorting and hit areas stay aligned.
func _add_sprite(point: Vector2, texture: Texture2D, art_scale: float) -> Sprite2D:
	var anchor := Node2D.new()
	anchor.position = point
	_layer.add_child(anchor)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = Vector2(0, -26.0 * art_scale)
	sprite.scale = Vector2.ONE * art_scale
	anchor.add_child(sprite)
	return sprite

# Add only the landmarks and collision-matched props for the current zone.
func _build_zone_props() -> void:
	if _zone in ["garden", "school"]:
		_compost_sprite = _add_sprite(COMPOST_POSITION, _props["compost"], 1.25)
	match _zone:
		"school":
			_add_sprite(Vector2(710, 202), _props["board"], 2.1)
		"park":
			_add_sprite(Vector2(730, 265), _props["bench"], 1.6)
			_add_sprite(Vector2(840, 305), _props["birdbath"], 1.2)
			_add_sprite(Vector2(900, 610), _props["bench"], 1.5)
		"city":
			_add_sprite(Vector2(545, 290), _props["lamp"], 1.5)
			_add_sprite(Vector2(825, 605), _props["lamp"], 1.5)
			_add_sprite(Vector2(840, 270), _props["bench"], 1.4)

# Update state in place, rebuilding only after location changes or lost actors.
func refresh() -> void:
	if not is_node_ready() or _reloading:
		return
	var zone := String(GameState.data.get("zone", "garden"))
	var chapter := int(GameState.data.get("chapter", 1))
	if zone != _zone or chapter != _chapter or (not GameState.data.is_empty() and not is_instance_valid(_player)):
		reload_zone()
		return
	if not GameState.data.is_empty():
		var states: Array = GameState.plots()
		for plot in _plots:
			if plot.index < states.size():
				plot.refresh(states[plot.index])
		for i in range(_litter.size()):
			_litter[i].visible = not GameState.trash_collected(i)
	_refresh_compost_visual()
	_refresh_environment()
	_update_focus()
	queue_redraw()

# Tint the compost station to show unbuilt, active, and ready-to-collect states.
func _refresh_compost_visual() -> void:
	if not is_instance_valid(_compost_sprite):
		return
	var station: Dictionary = GameState.data.get("compost_station", {})
	_compost_sprite.modulate = Color.WHITE
	if not bool(station.get("built", false)):
		_compost_sprite.modulate = Color(0.82, 0.78, 0.66, 0.9)
	elif bool(station.get("batch_active", false)):
		_compost_sprite.modulate = Color(1.0, 0.86, 0.58, 1.0)
	elif int(station.get("ready_compost", 0)) > 0:
		_compost_sprite.modulate = Color(0.78, 1.0, 0.66, 1.0)

# Cache weather, biodiversity, and motion preferences for atmosphere rendering.
func _refresh_environment() -> void:
	_weather = GameState.weather()
	_biodiversity = GameState.biodiversity() if not GameState.data.is_empty() else 0
	_reduced_motion = bool(GameState.settings.get("reduced_motion", false))
	if is_instance_valid(_atmosphere):
		_atmosphere.queue_redraw()

# Resolve blocked coordinates, cancel movement, and persist explicit placement.
func set_player_position(pos: Vector2) -> void:
	if not is_instance_valid(_player):
		_pending_position = pos
		_has_pending_position = true
		return
	_player.position = _player.safe_position(pos)
	_player.motion = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_store_player_position()
	_update_focus()

# Return the pending spawn until the live player actor exists.
func player_position() -> Vector2:
	return _player.position if is_instance_valid(_player) else _pending_position

# Clamp external plot indexes to the shared six-bed layout.
func plot_position(index: int) -> Vector2:
	return PLOT_POSITIONS[clampi(index, 0, PLOT_POSITIONS.size() - 1)]

# Expose the shared station location for UI placement and interaction routing.
func compost_position() -> Vector2:
	return COMPOST_POSITION

# Persist live movement only after a game exists, never for the empty title state.
func _store_player_position() -> void:
	if is_instance_valid(_player) and not GameState.data.is_empty():
		GameState.data["player"] = [_player.position.x, _player.position.y]

# Clean effects, persist movement, throttle redraws, and refresh interaction focus.
func _process(delta: float) -> void:
	for index in range(_bursts.size() - 1, -1, -1):
		if not is_instance_valid(_bursts[index]):
			_bursts.remove_at(index)
	var reduced := bool(GameState.settings.get("reduced_motion", false))
	if reduced != _reduced_motion:
		_reduced_motion = reduced
		_atmosphere.queue_redraw()
	if enabled:
		_hint_time = maxf(0.0, _hint_time - delta)
		if _hint_time <= 0.0:
			_hint_override = ""
		_store_player_position()
		# Reduced motion freezes ambient time and caps atmosphere redraws.
		if not _reduced_motion:
			_clock = fmod(_clock + delta, 3600.0)
			_redraw_time += delta
			if _redraw_time >= 1.0 / 30.0:
				_redraw_time = 0.0
				_atmosphere.queue_redraw()
	# Alternate NPC frames without animating for reduced-motion users.
	var frame := 0 if _reduced_motion else int(_clock / 0.7) % 2
	if frame != _npc_frame:
		_npc_frame = frame
		for i in range(_npcs.size()):
			_npcs[i].texture = _npc_frames[i * 2 + frame]
	_update_focus()

# Choose the nearest visible interactable target in the current zone.
func closest_target() -> Dictionary:
	if not is_instance_valid(_player) or GameState.data.is_empty():
		return {}
	var nearest: Dictionary = {}
	for plot in _plots:
		nearest = _consider(nearest, "plot", plot.index, plot.position)
	for i in range(_npcs.size()):
		nearest = _consider(nearest, "npc", i, NPC_POSITIONS[i])
	for i in range(_litter.size()):
		if _litter[i].visible:
			nearest = _consider(nearest, "trash", i, LITTER_POSITIONS[i])
	if _zone in ["garden", "school"]:
		nearest = _consider(nearest, "compost", 0, COMPOST_POSITION)
	return _consider(nearest, "water", 0, WATER_POSITION)

# Keep distant candidates so guidance can lead the player instead of hiding targets.
func _consider(nearest: Dictionary, kind: String, index: int, point: Vector2) -> Dictionary:
	var distance := player_position().distance_to(point)
	if nearest.is_empty() or distance < float(nearest["distance"]):
		return {"kind": kind, "index": index, "distance": distance}
	return nearest

# Resolve a target descriptor to its world-space interaction anchor.
func _target_position(target: Dictionary) -> Vector2:
	var index := int(target.get("index", 0))
	match String(target.get("kind", "")):
		"plot":
			if index >= 0 and index < _plots.size():
				return _plots[index].position
		"npc":
			return NPC_POSITIONS[index]
		"trash":
			return LITTER_POSITIONS[index]
		"water":
			return WATER_POSITION
		"compost":
			return COMPOST_POSITION
	return player_position()

# Interact only while unpaused; distant targets produce a walking hint, not teleportation.
func interact() -> void:
	if not enabled or get_tree().paused:
		return
	var target := closest_target()
	if target.is_empty():
		return
	if float(target["distance"]) > INTERACTION_DISTANCE:
		_show_hint(_walk_hint(target))
		return
	_interact_target(target)

# Route nearby interactions to state APIs or the main scene's modal flows.
func _interact_target(target: Dictionary) -> void:
	var kind := String(target["kind"])
	var index := int(target["index"])
	match kind:
		"plot", "npc":
			# Only main owns planting, care, stories and conversation modals.
			if kind == "plot":
				play_action("plant")
			interaction.emit(kind, index)
		"trash":
			if GameState.collect_trash(index):
				play_action("collect")
				_spawn_burst(LITTER_POSITIONS[index], "compost")
				AudioManager.play_sfx("harvest")
				GameState.notification.emit("مواد آلی جدا شد؛ یک واحد مادهٔ خام برای کمپوست به دست آوردی.")
				interaction.emit(kind, index)
		"compost":
			interaction.emit(kind, index)
		"water":
			var water_before := int(GameState.data["resources"]["water"])
			GameState.refill_water()
			AudioManager.play_sfx("water" if water_before < 8 else "click")
			interaction.emit(kind, index)
	_update_focus()

# Animate the action and place matching feedback at the affected world position.
func play_action(action: String) -> void:
	if is_instance_valid(_player):
		_player.play_action(action)
	if action == "water":
		var target := _nearest_water_target()
		var point := _target_position(target) if not target.is_empty() else player_position()
		_spawn_burst(point, "water")
	elif action in ["plant", "compost", "collect"]:
		_spawn_burst(player_position(), action)

# Limit the water shortcut to living plots that actually need moisture.
func _nearest_water_target() -> Dictionary:
	var nearest: Dictionary = {}
	for plot in _plots:
		if GameState.plant_needs_water(plot.plot_data):
			nearest = _consider(nearest, "plot", plot.index, plot.position)
	return nearest

# Water the closest thirsty plot only within normal interaction range.
func water_nearest() -> void:
	if not enabled or get_tree().paused or not is_instance_valid(_player):
		return
	var nearest := _nearest_water_target()
	if nearest.is_empty():
		_show_hint("نهال نزدیکی به آب نیاز ندارد یا هنوز نهالی نکارته‌ای.")
		return
	if float(nearest["distance"]) > INTERACTION_DISTANCE:
		_show_hint("برای آبیاری، با جوی‌استیک به نهال نزدیک شو و دکمهٔ «آب» را بزن.")
		return
	var watered := GameState.water_plot(int(nearest["index"]))
	if watered:
		play_action("water")
	AudioManager.play_sfx("water" if watered else "click")

# Skip decorative particles entirely when reduced motion is enabled.
func _spawn_burst(point: Vector2, kind: String) -> void:
	if bool(GameState.settings.get("reduced_motion", false)):
		return
	var burst := ActionBurst.new()
	burst.kind = kind
	burst.position = point
	add_child(burst)
	_bursts.append(burst)

# Map keyboard, mouse, and touch to the same range-checked interaction routes.
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or get_tree().paused or not is_instance_valid(_player):
		return
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return
		var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_E or key == KEY_SPACE:
			get_viewport().set_input_as_handled()
			interact()
		elif key == KEY_Q:
			get_viewport().set_input_as_handled()
			water_nearest()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_click_target(get_global_transform_with_canvas().affine_inverse() * event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_click_target(get_global_transform_with_canvas().affine_inverse() * event.position)

# Route pointer taps by hit area without moving the player or bypassing range checks.
func _click_target(point: Vector2) -> void:
	var now := Time.get_ticks_msec()
	# Ignore rapid repeat taps so one pointer gesture cannot trigger a target twice.
	if now - _last_pointer_ms < 180:
		return
	for plot in _plots:
		if not plot.contains_point(point):
			continue
		get_viewport().set_input_as_handled()
		_last_pointer_ms = now
		if player_position().distance_to(plot.position) <= INTERACTION_DISTANCE:
			play_action("plant")
		interaction.emit("plot", plot.index)
		return
	for i in range(_npcs.size()):
		if not Rect2(NPC_POSITIONS[i] - Vector2(42, 96), Vector2(84, 120)).has_point(point):
			continue
		get_viewport().set_input_as_handled()
		_last_pointer_ms = now
		interaction.emit("npc", i)
		return
	if _zone in ["garden", "school"] and point.distance_to(COMPOST_POSITION) <= 62.0:
		get_viewport().set_input_as_handled()
		_last_pointer_ms = now
		interaction.emit("compost", 0)
		return
	for i in range(_litter.size()):
		if not _litter[i].visible or point.distance_to(LITTER_POSITIONS[i]) > 34.0:
			continue
		get_viewport().set_input_as_handled()
		_last_pointer_ms = now
		var distance := player_position().distance_to(LITTER_POSITIONS[i])
		if distance <= INTERACTION_DISTANCE:
			_interact_target({"kind": "trash", "index": i, "distance": distance})
		else:
			_show_hint("برای جمع‌آوری مواد آلی، نزدیک آن‌ها برو.")
		return
	if point.distance_to(WATER_POSITION) <= 86.0:
		get_viewport().set_input_as_handled()
		_last_pointer_ms = now
		var distance := player_position().distance_to(WATER_POSITION)
		if distance <= INTERACTION_DISTANCE:
			_interact_target({"kind": "water", "index": 0, "distance": distance})
		else:
			_show_hint("برای پر کردن آب‌پاش، به حوض نزدیک شو.")

# Synchronize selection, prompts, water shortcut, and guidance with the nearest target.
func _update_focus() -> void:
	var nearest := closest_target()
	var near := enabled and not nearest.is_empty() and float(nearest.get("distance", INF)) <= INTERACTION_DISTANCE
	var water_target := _nearest_water_target()
	var show_water := enabled and not water_target.is_empty() and float(water_target.get("distance", INF)) <= INTERACTION_DISTANCE
	if is_instance_valid(_water_button):
		_water_button.visible = show_water
		if show_water:
			var water_point := _target_position(water_target) + Vector2(66, -74)
			_water_button.position = Vector2(
				clampf(water_point.x - _water_button.size.x * 0.5, 12.0, VIRTUAL_SIZE.x - _water_button.size.x - 12.0),
				clampf(water_point.y - _water_button.size.y * 0.5, 190.0, 560.0)
			)
	for plot in _plots:
		plot.selected = near and nearest.get("kind", "") == "plot" and int(nearest.get("index", -1)) == plot.index
	if _target != nearest:
		_target = nearest
		if is_instance_valid(_atmosphere):
			_atmosphere.queue_redraw()
	if is_instance_valid(_prompt):
		_prompt.visible = near
		if near:
			_prompt_label.text = _action_text(nearest)
			_prompt_icon.texture = _icons[_target_icon(nearest)]
			_prompt.reset_size()
			var point := _target_position(nearest)
			var lift := 116.0 if nearest["kind"] == "npc" else 94.0
			_prompt.position = Vector2(
				clampf(point.x - _prompt.size.x * 0.5, 12.0, VIRTUAL_SIZE.x - _prompt.size.x - 12.0),
				clampf(point.y - lift, 205.0, 620.0)
			)
	var hint := ""
	if enabled and not nearest.is_empty():
		hint = _action_text(nearest) + " · فاصله: " + UIFactory.number(int(ceil(float(nearest["distance"])))) if near else _walk_hint(nearest)
	if enabled and not _hint_override.is_empty():
		hint = _hint_override
	_set_hint(hint)

# Choose the Persian action label from the target's current gameplay state.
func _action_text(target: Dictionary) -> String:
	match String(target.get("kind", "")):
		"plot":
			var state: Dictionary = _plots[int(target["index"])].plot_data
			if not bool(state.get("prepared", false)):
				return "دکمهٔ عمل · آماده‌سازی خاک"
			if String(state.get("species", "")).is_empty():
				return "دکمهٔ عمل · کاشت نهال"
			if bool(state.get("dead", false)):
				return "دکمهٔ عمل · اطلاعات نهال خراب"
			return "دکمهٔ عمل · اطلاعات و رسیدگی"
		"npc":
			return "دکمهٔ عمل · گفت‌وگو"
		"trash":
			return "دکمهٔ عمل · جمع‌آوری مواد آلی"
		"water":
			return "دکمهٔ عمل · پر کردن آب‌پاش"
		"compost":
			var station: Dictionary = GameState.data.compost_station
			if not bool(station.built):
				return "دکمهٔ عمل · ساخت کارگاه کمپوست"
			if bool(station.batch_active):
				return "دکمهٔ عمل · وضعیت آماده‌سازی کمپوست"
			return "دکمهٔ عمل · مدیریت کمپوست"
	return ""

# Reflect plot preparation and planting state in the prompt icon.
func _target_icon(target: Dictionary) -> String:
	match String(target.get("kind", "")):
		"plot":
			var state: Dictionary = _plots[int(target["index"])].plot_data
			if not String(state.get("species", "")).is_empty():
				return "leaf"
			return "seed" if bool(state.get("prepared", false)) else "soil"
		"npc":
			return "book"
		"trash":
			return "recycle"
		"compost":
			return "soil"
	return "water"

# Give distant targets a consistent movement instruction.
func _walk_hint(target: Dictionary) -> String:
	var names := {"plot": "بستر خاک", "npc": "راهنما", "trash": "مواد آلی", "water": "حوض", "compost": "کارگاه کمپوست"}
	return "به " + String(names.get(target.get("kind", ""), "هدف")) + " نزدیک شو؛ با جوی‌استیک حرکت کن و برای تعامل دکمهٔ «عمل» را بزن."

# Temporarily override contextual guidance for range errors or unavailable actions.
func _show_hint(text: String) -> void:
	_hint_override = text
	_hint_time = 3.0
	_set_hint(text)

# Emit only when guidance changes to avoid redundant accessibility updates.
func _set_hint(text: String) -> void:
	if text != _last_hint:
		_last_hint = text
		hint_changed.emit(text)

# Draw the active chapter background beneath the live actor layer.
func _draw() -> void:
	if _background != null:
		draw_texture_rect(_background, Rect2(Vector2.ZERO, VIRTUAL_SIZE), false)

class ActionBurst:
	extends Node2D
	var kind := "plant"
	var life := 0.0
	var particles: Array[Dictionary] = []

	# Seed a short radial burst with randomized speed, gravity bias, and size.
	func _ready() -> void:
		life = 0.72
		for i in range(12):
			var angle := TAU * float(i) / 12.0 + randf_range(-0.2, 0.2)
			var speed := randf_range(28.0, 70.0)
			particles.append({"position": Vector2.ZERO, "velocity": Vector2(cos(angle), sin(angle)) * speed - Vector2(0, 35), "size": randf_range(2.0, 4.5)})

	# Move particles under gravity until the burst expires and frees itself.
	func _process(delta: float) -> void:
		life -= delta
		for particle in particles:
			particle.position += particle.velocity * delta
			particle.velocity.y += 95.0 * delta
		queue_redraw()
		if life <= 0.0:
			queue_free()

	# Fade action-colored particles out over the burst's remaining lifetime.
	func _draw() -> void:
		var alpha := clampf(life / 0.72, 0.0, 1.0)
		for particle in particles:
			var color := Color("8fc36a")
			if kind == "water":
				color = Color("78d4ea")
			elif kind == "compost":
				color = Color("b98a55")
			elif kind == "collect":
				color = Color("e6c477")
			color.a = alpha
			draw_circle(particle.position, float(particle.size), color)

class Atmosphere:
	extends Node2D
	var world: WorldController

	# Render weather, wildlife, night lighting, and target arrows over the world.
	func _draw() -> void:
		if not is_instance_valid(world):
			return
		var time := 0.0 if world._reduced_motion else world._clock
		for cloud in range(3):
			var x := fposmod(float(cloud * 470) + time * (5.0 + float(cloud)), 1500.0) - 110.0
			var y := 70.0 + float(cloud) * 42.0
			draw_circle(Vector2(x, y), 42.0, Color(0.96, 0.97, 0.88, 0.045))
			draw_circle(Vector2(x + 35.0, y + 8.0), 32.0, Color(0.96, 0.97, 0.88, 0.04))
			draw_circle(Vector2(x - 34.0, y + 10.0), 28.0, Color(0.96, 0.97, 0.88, 0.035))
		if world._weather != "بارانی":
			var warmth := 0.035 if world._weather == "نیمه‌ابری" else 0.065
			draw_colored_polygon(PackedVector2Array([Vector2(1030, 0), Vector2(1215, 0), Vector2(855, 610), Vector2(515, 610)]), Color(1.0, 0.91, 0.6, warmth))
			draw_circle(Vector2(1110, 65), 80.0, Color(1.0, 0.92, 0.65, 0.035))
		for i in range(18):
			var x := fposmod(float(i * 173 + 41) + time * (8.0 + float(i % 4)), 1280.0)
			var y := 205.0 + fposmod(float(i * 79) + time * (12.0 + float(i % 5)), 440.0)
			var point := Vector2(x + sin(time * 0.7 + float(i)) * 13.0, y)
			var leaf_color := Color(0.76, 0.77, 0.34, 0.56) if i % 3 == 0 else Color(0.55, 0.69, 0.36, 0.5)
			draw_set_transform(point, sin(time + float(i)) * 0.7)
			draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(0, -2), Vector2(4, 0), Vector2(0, 2)]), leaf_color)
			draw_line(Vector2(-3, 0), Vector2(3, 0), Color(0.29, 0.43, 0.2, 0.45), 1.0)
			draw_set_transform(Vector2.ZERO)
		if world._weather == "بارانی":
			draw_rect(Rect2(Vector2.ZERO, VIRTUAL_SIZE), Color(0.22, 0.36, 0.46, 0.075))
			var count := 16 if world._reduced_motion else 64
			for i in range(count):
				var point := Vector2(fposmod(float(i * 149 + 43) - time * 43.0, 1280.0), fposmod(float(i * 97 + 39) + time * 310.0, 720.0))
				draw_line(point, point + Vector2(-4, 13), Color(0.79, 0.91, 1.0, 0.37), 1.0)
		# Wildlife appears only after planting raises the zone's biodiversity.
		if world._biodiversity >= 2:
			for i in range(4):
				var point := Vector2(400.0 + float(i) * 135.0 + sin(time * 0.6 + float(i) * 2.0) * 35.0, 320.0 + float(i % 2) * 170.0 + cos(time * 0.7 + float(i)) * 18.0)
				var wing := 2.0 + absf(sin(time * 7.0 + float(i))) * 3.0
				var color := Color("efd790") if i % 2 == 0 else Color("a3d4d5")
				draw_set_transform(point, sin(time * 0.5 + float(i)) * 0.4)
				draw_circle(Vector2(-wing * 0.6, -1), wing, color)
				draw_circle(Vector2(wing * 0.6, -1), wing, color)
				draw_line(Vector2(0, -3), Vector2(0, 4), Color("4c5140"), 1.5)
				draw_set_transform(Vector2.ZERO)
			for i in range(3):
				var point := Vector2(fposmod(180.0 + float(i) * 330.0 + time * 25.0, 1280.0), 65.0 + float(i) * 28.0 + sin(time + float(i)) * 6.0)
				var wing_y := -3.0 + sin(time * 4.0 + float(i)) * 2.0
				draw_polyline(PackedVector2Array([point + Vector2(-6, wing_y), point, point + Vector2(6, wing_y)]), Color(0.15, 0.25, 0.24, 0.68), 1.5)
		# Apply night lighting after the daytime scenery and weather layers.
		var night := GameState.night_amount()
		if night > 0.0:
			draw_rect(Rect2(Vector2.ZERO, VIRTUAL_SIZE), Color(0.05, 0.1, 0.24, 0.7 * night))
			draw_circle(Vector2(1120, 82), 54.0, Color(0.78, 0.86, 1.0, 0.07 * night))
			draw_circle(Vector2(1120, 82), 25.0, Color(0.9, 0.94, 1.0, 0.88 * night))
			draw_circle(Vector2(1131, 74), 23.0, Color(0.12, 0.2, 0.36, 0.9 * night))
			for star in range(22):
				var star_point := Vector2(fposmod(float(star * 149 + 63), 1220.0) + 30.0, 28.0 + fposmod(float(star * 47), 170.0))
				var twinkle := 0.45 + 0.35 * sin(time * 1.5 + float(star))
				draw_circle(star_point, 1.4 if star % 4 else 2.2, Color(0.92, 0.95, 1.0, twinkle * night))
			# Light only lamps that exist in the current zone's scenery.
			if world._zone in ["city", "park"]:
				for lamp in [Vector2(545, 290), Vector2(825, 605)]:
					draw_circle(lamp, 54.0, Color(1.0, 0.77, 0.38, 0.08 * night))
					draw_circle(lamp, 26.0, Color(1.0, 0.86, 0.52, 0.12 * night))
		# A short arrow makes distant targets discoverable, never click-to-teleport.
		if world.enabled and not world._target.is_empty() and float(world._target.get("distance", 0.0)) > INTERACTION_DISTANCE:
			var origin := world.player_position()
			var direction := origin.direction_to(world._target_position(world._target))
			var tip := origin + direction * 42.0
			var normal := Vector2(-direction.y, direction.x)
			draw_line(origin + direction * 25.0, tip, Color(1.0, 0.93, 0.68, 0.64), 2.0)
			draw_polyline(PackedVector2Array([tip - direction * 6.0 + normal * 5.0, tip, tip - direction * 6.0 - normal * 5.0]), Color(1.0, 0.93, 0.68, 0.75), 2.0)
