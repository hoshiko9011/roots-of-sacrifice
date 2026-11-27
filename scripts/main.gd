# Main scene controller for menus, gameplay UI, modals, tutorials, and app lifecycle.
extends Control

const UI = preload("res://scripts/ui_factory.gd")
const CONTENT = preload("res://scripts/data/game_content.gd")
const WORLD = preload("res://scripts/world.gd")
const JOYSTICK = preload("res://scripts/touch_joystick.gd")
const MAX_NOTIFICATION_QUEUE := 12

var world: WorldController
var screen: Control
# The persistent overlay stays above screens so toasts and modals survive scene changes.
var overlay: Control
var modal: Control
var _modal_body: VBoxContainer
var _modal_footer: HBoxContainer
var _hud: HBoxContainer
var _hud_chips: Array[TextureRect] = []
var _quest_button: TextureButton
var _map_button: TextureButton
var _quest_label: Label
var _clock_label: Label
var _bottom_bar: HBoxContainer
var _toast_label: Label
var _toast_timer: Timer
var _joystick: Control
var _action_button: TouchActionButton
var _water_action_button: TouchActionButton
var _tutorial_layer: Control
var _tutorial_card: PanelContainer
var _tutorial_highlight: PanelContainer
var _tutorial_arrow: Line2D
var _tutorial_title_label: Label
var _tutorial_text_label: Label
var _tutorial_step_label: Label
var _tutorial_continue: Button
# Tutorial navigation and action completion are separate so gated steps cannot be skipped.
var _tutorial_id := ""
var _tutorial_steps: Array = []
var _tutorial_index := 0
var _tutorial_action_done := false
var _tutorial_origin := Vector2.ZERO
var _tutorial_baseline: Dictionary = {}
var _in_game := false
var _intro_index := 0
var _story_index := 0
var _quiz_index := -1
var _quiz_options: Array[Button] = []
var _quiz_feedback: Label
# Notifications are serialized because only one toast can be visible at a time.
var _notification_queue: Array[String] = []
var _cinematic_material: ShaderMaterial
var _cinematic_time := 0.0
# Modal pause state is captured on open and restored on close.
var _modal_restore_pause := false
var _modal_restore_audio_pause := false
var _modal_return_to_pause := false
# Focus changes pause audio without overwriting a pause that was already active.
var _audio_paused_by_focus := false
var _audio_was_paused_before_focus := false

# Wires global state signals and builds the persistent overlay before showing the menu.
func _ready() -> void:
	# Menus and quit confirmations must remain interactive while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	GameState.changed.connect(_refresh_hud)
	GameState.notification.connect(_toast)
	GameState.chapter_finished.connect(_chapter_finished)
	GameState.achievement_unlocked.connect(_achievement)
	GameState.time_changed.connect(_refresh_clock)
	GameState.day_started.connect(_on_day_started)
	overlay = _layer()
	# Keep tutorial and modal layers above contextual world controls such as the water shortcut.
	overlay.z_index = 100
	add_child(overlay)
	_toast_label = UI.text("", 20, UI.CREAM, true)
	_toast_label.position = Vector2(310, 78)
	_toast_label.size = Vector2(660, 56)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast_label.add_theme_stylebox_override("normal", UI.style(Color("153f30")))
	_toast_label.visible = false
	overlay.add_child(_toast_label)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 3.6
	_toast_timer.timeout.connect(_next_toast)
	add_child(_toast_timer)
	_show_menu()

# Advances cinematic motion and completes tutorial steps from live gameplay actions.
func _process(delta: float) -> void:
	if is_instance_valid(_cinematic_material):
		var reduced_motion := bool(GameState.settings.get("reduced_motion", false))
		_cinematic_material.set_shader_parameter("motion_enabled", not reduced_motion)
		if not reduced_motion and not get_tree().paused:
			_cinematic_time += delta
		_cinematic_material.set_shader_parameter("motion_time", _cinematic_time)
	if not _tutorial_active():
		return
	var step: Dictionary = _tutorial_steps[_tutorial_index]
	var action := String(step.get("complete_on", ""))
	var done := _tutorial_action_done
	if action == "move" and is_instance_valid(world):
		done = world.player_position().distance_to(_tutorial_origin) > 45.0
	elif action == "plant":
		done = int(GameState.data.stats.planted) > int(_tutorial_baseline.get("planted", 0))
	elif action == "water":
		done = int(GameState.data.stats.watered) > int(_tutorial_baseline.get("watered", 0))
	elif action == "compost":
		done = int(GameState.data.stats.compost_built) > int(_tutorial_baseline.get("compost_built", 0))
	if done != _tutorial_action_done:
		_tutorial_action_done = done
		_refresh_tutorial_continue()

# Creates a fixed-size, input-transparent layer for screens and overlays.
func _layer() -> Control:
	var layer := Control.new()
	layer.size = Vector2(1280, 720)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer

# Tears down the current scene and restores a clean, unpaused screen stack.
func _clear_screen() -> void:
	_close_tutorial(false)
	_close_modal(false)
	# The simulation runs only while a live gameplay screen owns the world.
	GameState.time_paused = not _in_game
	get_tree().paused = false
	AudioManager.set_paused(false)
	_audio_paused_by_focus = false
	# Drop scene-bound references before freeing their owners.
	_quest_button = null
	_map_button = null
	_quest_label = null
	_clock_label = null
	_hud = null
	_hud_chips.clear()
	_bottom_bar = null
	if is_instance_valid(screen):
		screen.free()
	if is_instance_valid(world):
		world.free()
	world = null
	_joystick = null
	_action_button = null
	_water_action_button = null
	_cinematic_material = null
	_cinematic_time = 0.0
	screen = _layer()
	add_child(screen)
	# Keep the persistent overlay above the newly created screen.
	move_child(overlay, get_child_count() - 1)

# Adds a full-screen background and optionally applies the cinematic garden shader.
func _background(file: String, cinematic: bool = false) -> void:
	var image := UI.image(GameAtlas.texture(file), Vector2(1280, 720))
	image.size = Vector2(1280, 720)
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if cinematic:
		var shader := load("res://assets/art/cinematic_garden.gdshader") as Shader
		_cinematic_material = ShaderMaterial.new()
		_cinematic_material.shader = shader
		_cinematic_material.set_shader_parameter("scene_texture", GameAtlas.texture(file))
		_cinematic_material.set_shader_parameter("image_aspect", GameAtlas.texture(file).get_size().x / GameAtlas.texture(file).get_size().y)
		_cinematic_material.set_shader_parameter("view_aspect", 1280.0 / 720.0)
		_cinematic_material.set_shader_parameter("motion_time", 0.0)
		_cinematic_material.set_shader_parameter("motion_enabled", not bool(GameState.settings.get("reduced_motion", false)))
		image.material = _cinematic_material
		image.stretch_mode = TextureRect.STRETCH_SCALE
	screen.add_child(image)

# Adds a non-interactive darkening layer above a background.
func _shade(parent: Node, color: Color = Color(0.03, 0.1, 0.06, 0.4)) -> ColorRect:
	var shade := ColorRect.new()
	shade.color = color
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	return shade

# Builds the title screen and starts menu music.
func _show_menu() -> void:
	_in_game = false
	_clear_screen()
	_background("cinematic_garden.png", true)
	_shade(screen, Color(0.03, 0.1, 0.06, 0.12))
	var plaque := UI.image(GameAtlas.texture("title_panel.svg"), Vector2(840, 184))
	plaque.name = "TitleBanner"
	plaque.position = Vector2(220, 30)
	plaque.size = Vector2(840, 184)
	plaque.stretch_mode = TextureRect.STRETCH_SCALE
	plaque.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.add_child(plaque)
	var title_column := UI.column(plaque, 4)
	title_column.position = Vector2(208, 24)
	title_column.size = Vector2(596, 136)
	title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UI.text("ریشه‌های ایثار", 60, UI.CREAM, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_color_override("font_shadow_color", Color(0.03, 0.1, 0.06, 0.55))
	title_column.add_child(title)
	var subtitle := UI.text("کاشت نهال امید؛ پیوند ایثار با پاسداشت محیط زیست", 19, Color("d9e4bd"), true)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_column.add_child(subtitle)
	var settings_button := _title_button("تنظیمات", _settings, "settings", "button_settings")
	settings_button.position = Vector2(1080, 24)
	settings_button.size = Vector2(160, 58)
	var settings_label := settings_button.get_child(1) as Label
	settings_label.add_theme_font_size_override("font_size", 18)
	screen.add_child(settings_button)
	var start_button := _title_button("شروع بازی", _request_new, "play", "button_start")
	start_button.position = Vector2(858, 252)
	start_button.size = Vector2(360, 84)
	var start_label := start_button.get_child(1) as Label
	start_label.add_theme_font_size_override("font_size", 27)
	screen.add_child(start_button)
	var continue_button := _title_button("ادامهٔ بازی", _continue_game, "sprout", "button_wood")
	continue_button.position = Vector2(858, 352)
	continue_button.size = Vector2(360, 74)
	continue_button.disabled = not GameState.save_available
	if continue_button.disabled:
		continue_button.modulate = Color(0.68, 0.68, 0.68, 0.78)
	screen.add_child(continue_button)
	var guide_button := _title_button("راهنما", _controls, "info", "button_wood")
	guide_button.position = Vector2(858, 442)
	guide_button.size = Vector2(360, 74)
	screen.add_child(guide_button)
	var exit_button := _title_button("خروج", _request_quit, "close", "button_wood_dark")
	exit_button.position = Vector2(858, 532)
	exit_button.size = Vector2(360, 74)
	screen.add_child(exit_button)
	for point in [Vector2(828, 258), Vector2(828, 358), Vector2(828, 448), Vector2(828, 538), Vector2(1208, 282), Vector2(1208, 552)]:
		var leaf := UI.image(GameAtlas.icon("leaf"), Vector2(28, 28))
		leaf.position = point
		screen.add_child(leaf)
	var about_button := _title_button("درباره ما", _about, "team", "button_about")
	about_button.position = Vector2(40, 606)
	about_button.size = Vector2(230, 64)
	var about_label := about_button.get_child(1) as Label
	about_label.add_theme_font_size_override("font_size", 18)
	screen.add_child(about_button)
	var tagline_panel := UI.panel(screen, Vector2(270, 652), Vector2(740, 46), Color(0.06, 0.16, 0.11, 0.42))
	var tagline := UI.text("هر نهال، فرصتی برای ساختن آینده‌ای مهربان‌تر", 21, UI.CREAM, true)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tagline_panel.add_child(tagline)
	if not bool(GameState.settings.get("reduced_motion", false)):
		var pulse := create_tween()
		pulse.tween_property(start_button, "modulate", Color(1.08, 1.08, 1.08, 1.0), 0.9)
		pulse.tween_property(start_button, "modulate", Color.WHITE, 0.9)
	AudioManager.set_paused(false)
	AudioManager.play_music("title")

# Builds a shared textured button with RTL text, icon, and click feedback.
func _title_button(title: String, action: Callable, icon_name: String, asset_name: String, minimum_height: float = 72.0) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = load("res://assets/art/" + asset_name + ".svg") as Texture2D
	button.texture_hover = load("res://assets/art/" + asset_name + "_hover.svg") as Texture2D
	button.texture_pressed = load("res://assets/art/" + asset_name + "_pressed.svg") as Texture2D
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.ignore_texture_size = true
	button.custom_minimum_size.y = minimum_height
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("focus", UI.style(Color.TRANSPARENT, UI.ACCENT, 30, 3))
	var compact := asset_name in ["button_settings", "button_about", "button_hud", "button_compact"]
	var quest := asset_name == "button_quest"
	var icon_size := 22.0 if compact else 28.0
	if not icon_name.is_empty():
		var icon := UI.image(GameAtlas.icon(icon_name), Vector2(icon_size, icon_size))
		icon.anchor_left = 1.0
		icon.anchor_right = 1.0
		icon.anchor_top = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -46.0 if quest else (-42.0 if compact else -48.0)
		icon.offset_right = -20.0
		icon.offset_top = -icon_size * 0.5
		icon.offset_bottom = icon_size * 0.5
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon)
	var label := UI.text(title, 22, UI.CREAM, true)
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 48.0 if quest else (38.0 if compact else 60.0)
	label.offset_right = -52.0 if quest else (-48.0 if compact else -60.0)
	label.offset_top = 8.0
	label.offset_bottom = -8.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(label)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled and not bool(GameState.settings.get("reduced_motion", false)):
			button.create_tween().tween_property(button, "modulate", Color(1.06, 1.06, 1.06, 1.0), 0.12)
	)
	button.mouse_exited.connect(func() -> void:
		if not button.disabled and not bool(GameState.settings.get("reduced_motion", false)):
			button.create_tween().tween_property(button, "modulate", Color.WHITE, 0.12)
	)
	button.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		action.call_deferred()
	)
	return button

# Confirms replacing an existing save before starting a new game.
func _request_new() -> void:
	if GameState.save_available:
		_open_modal("شروع دوباره", Vector2(620, 330))
		_modal_body.add_child(UI.text("بازی تازه جای پیشرفت قبلی را میگیرد. ادامه میدهی؟", 23))
		_modal_footer.add_child(UI.button("بازی تازه", _new_game, "play", "accent"))
	else:
		_new_game()

# Starts a fresh save, rolls back failed initialization, then opens the first chapter.
func _new_game() -> void:
	var previous_data := GameState.data.duplicate(true)
	var previous_save_available := GameState.save_available
	if not GameState.new_game():
		GameState.data = previous_data
		GameState.save_available = previous_save_available
		_toast(GameState.save_error)
		return
	_show_game()
	_intro_index = 0
	_show_intro()

# Saves the current player position before persisting progress for exit.
func _save_progress_for_exit() -> bool:
	if GameState.data.is_empty():
		return true
	_remember_position()
	return GameState.save_game()

# Loads a save and resumes the ending, chapter flow, or appropriate tutorial.
func _continue_game() -> void:
	if not GameState.load_game():
		_show_menu()
		_toast(GameState.save_error)
		return
	if GameState.data.finished:
		_show_ending()
	else:
		_show_game()
		if int(GameState.data.chapter) in GameState.data.completed:
			_chapter_finished(int(GameState.data.chapter))
		elif _should_start_first_run():
			_start_tutorial("first_run")
		else:
			_maybe_start_chapter_tutorial()

# Creates the world and all HUD, navigation, and touch controls for gameplay.
func _show_game() -> void:
	_in_game = true
	_clear_screen()
	world = WORLD.new()
	screen.add_child(world)
	world.interaction.connect(_interaction)
	var hud_panel := TextureRect.new()
	hud_panel.texture = GameAtlas.texture("hud_panel.svg")
	hud_panel.position = Vector2(18, 10)
	hud_panel.size = Vector2(850, 64)
	hud_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hud_panel.stretch_mode = TextureRect.STRETCH_SCALE
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(hud_panel)
	_hud = UI.row(hud_panel, 5)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.offset_left = 14
	_hud.offset_right = -14
	_hud.offset_top = 8
	_hud.offset_bottom = -8
	var buttons := UI.row(screen, 7)
	buttons.position = Vector2(1002, 12)
	buttons.size = Vector2(260, 58)
	for entry in [["نقشه", "map", _map], ["توقف", "pause", _pause]]:
		var btn := _title_button(entry[0], entry[2], entry[1], "button_hud", 58)
		btn.custom_minimum_size = Vector2(126, 58)
		btn.size = Vector2(126, 58)
		var label := btn.get_child(1) as Label
		label.add_theme_font_size_override("font_size", 17)
		buttons.add_child(btn)
		if entry[1] == "map":
			_map_button = btn
	_quest_button = _title_button("مأموریت", _missions, "quest", "button_quest", 62)
	_quest_button.position = Vector2(906, 85)
	_quest_button.size = Vector2(350, 62)
	_quest_label = _quest_button.get_child(1) as Label
	_quest_label.add_theme_font_size_override("font_size", 17)
	screen.add_child(_quest_button)
	var bottom := UI.row(screen, 8)
	bottom.position = Vector2(380, 646)
	bottom.size = Vector2(520, 64)
	_bottom_bar = bottom
	for entry in [["یادبود", "memorial", _memorials], ["نهال‌ها", "sprout", _plants], ["دستاورد", "trophy", _achievements]]:
		var btn := _title_button(entry[0], entry[2], entry[1], "button_compact", 64)
		btn.custom_minimum_size = Vector2(168, 64)
		btn.size = Vector2(168, 64)
		var label := btn.get_child(1) as Label
		label.add_theme_font_size_override("font_size", 17)
		bottom.add_child(btn)
	_joystick = JOYSTICK.new()
	_joystick.position = Vector2(22, 552)
	_joystick.visible = bool(GameState.settings.touch)
	# Modal validity gates touch movement so input cannot leak through dialogs.
	_joystick.direction_changed.connect(func(direction: Vector2) -> void:
		if is_instance_valid(world) and world.enabled and not is_instance_valid(modal):
			world.touch_direction = direction
	)
	screen.add_child(_joystick)
	for entry in [
		["عمل", "action", UI.GREEN, "primary", Vector2(984, 616), func() -> void: world.interact(), "تعامل با هدف نزدیک"],
		["آب", "water", UI.WATER, "water", Vector2(1120, 616), func() -> void: world.water_nearest(), "آبیاری نزدیک‌ترین نهال"],
	]:
		var button := UI.touch_button(entry[0], entry[5], entry[1], entry[3])
		button.position = entry[4]
		button.custom_minimum_size = Vector2(120, 88)
		button.size = Vector2(120, 88)
		button.tooltip_text = entry[6]
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_constant_override("icon_max_width", 30)
		button.add_theme_constant_override("h_separation", 4)
		var fill: Color = entry[2]
		button.add_theme_stylebox_override("normal", UI.style(fill, UI.ACCENT, 44, 3))
		button.add_theme_stylebox_override("hover", UI.style(fill.lightened(0.1), UI.ACCENT, 44, 3))
		button.add_theme_stylebox_override("pressed", UI.style(fill.darkened(0.12), UI.ACCENT, 44, 3))
		button.add_theme_stylebox_override("focus", UI.style(Color.TRANSPARENT, UI.ACCENT, 44, 3))
		screen.add_child(button)
		if entry[1] == "action":
			_action_button = button
		else:
			_water_action_button = button
	_refresh_touch_controls()
	_refresh_hud()
	AudioManager.set_paused(false)
	AudioManager.play_music(_music_for_current_scene())

# Shows touch controls only when enabled and no modal is blocking input.
func _refresh_touch_controls() -> void:
	var visible := bool(GameState.settings.get("touch", true)) and not is_instance_valid(modal)
	if is_instance_valid(_joystick):
		_joystick.visible = visible
	if is_instance_valid(_action_button):
		_action_button.visible = visible
	if is_instance_valid(_water_action_button):
		_water_action_button.visible = visible

# Builds a reusable icon-and-value chip for the HUD.
func _hud_chip(icon_name: String, value_text: String, width: float, font_size: int = 20, caption: String = "") -> TextureRect:
	var chip := TextureRect.new()
	chip.texture = GameAtlas.texture("hud_chip.svg")
	chip.custom_minimum_size = Vector2(width, 40)
	chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chip.stretch_mode = TextureRect.STRETCH_SCALE
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UI.column(chip, 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 5
	column.offset_right = -5
	column.offset_top = 2
	column.offset_bottom = -2
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.row(column, 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UI.image(GameAtlas.icon(icon_name), Vector2(15, 15)))
	var label := UI.text(value_text, font_size, UI.CREAM, true)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# HUD values stay centered even though most game text is right-aligned.
	label.set_meta("hud_text", true)
	chip.set_meta("value_label", label)
	row.add_child(label)
	if not caption.is_empty():
		var caption_label := UI.text(caption, 10, UI.CREAM)
		caption_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption_label.set_meta("hud_text", true)
		column.add_child(caption_label)
	return chip

# Updates HUD values in place and rebuilds chips only when a new gameplay screen is created.
func _refresh_hud() -> void:
	if not _in_game or not is_instance_valid(_hud) or not is_instance_valid(_quest_label):
		return
	var items: Array = [["star", GameState.data.scores.stars, "ستاره"], ["leaf", GameState.data.scores.eco, "سبزی"], ["heart", GameState.data.scores.social, "همکاری"], ["book", GameState.data.scores.culture, "دانش"], ["water", GameState.data.resources.water, "آب"], ["seed", GameState.data.resources.seeds, "بذر"], ["soil", GameState.data.resources.compost, "کمپوست"]]
	if _hud_chips.size() != items.size():
		for child in _hud.get_children():
			child.free()
		_hud_chips.clear()
		for item in items:
			var chip: TextureRect = _hud_chip(item[0], UI.number(int(item[1])), 72, 17, item[2])
			_hud.add_child(chip)
			_hud_chips.append(chip)
	if not is_instance_valid(_clock_label):
		var clock_chip: TextureRect = _hud_chip("sun", "", 260, 16, "زمان")
		_clock_label = clock_chip.get_child(0).get_child(0).get_child(1) as Label
		_hud.add_child(clock_chip)
	for index in range(items.size()):
		var value_label: Label = _hud_chips[index].get_meta("value_label")
		value_label.text = UI.number(int(items[index][1]))
	_refresh_clock()
	var chapter := GameState.current_chapter()
	var completed_tasks := 0
	for task in chapter.tasks:
		if GameState.task_count(task.id) >= int(task.target):
			completed_tasks += 1
	if GameState.chapter_ready():
		_quest_label.text = "مأموریت · پایان فصل آماده است"
	else:
		_quest_label.text = "مأموریت · " + UI.number(completed_tasks) + " از " + UI.number(chapter.tasks.size())

# Updates the clock readout and switches music when weather or time changes.
func _refresh_clock() -> void:
	if not is_instance_valid(_clock_label) or GameState.data.is_empty():
		return
	var period := "شب" if GameState.is_night() else "روز"
	_clock_label.text = "روز " + UI.number(int(GameState.data.day)) + " · " + UI.number(GameState.clock_text()) + " · " + period + " · " + GameState.weather()
	if _in_game:
		AudioManager.play_music(_music_for_current_scene())

# Chooses music from weather, time of day, and the active zone.
func _music_for_current_scene() -> String:
	if GameState.weather() == "بارانی" or GameState.is_night():
		return "rain"
	if String(GameState.data.get("zone", "garden")) in ["school", "park"]:
		return "path"
	return "garden"

# Plays the new-day cue and refreshes scene music.
func _on_day_started(_day: int) -> void:
	if not _in_game:
		return
	AudioManager.play_sfx("grow", 0.85)
	AudioManager.play_music(_music_for_current_scene())

# Copies the live player position into save data before persistence.
func _remember_position() -> void:
	if _in_game and is_instance_valid(world):
		var pos: Vector2 = world.player_position()
		GameState.data.player = [pos.x, pos.y]

# Suspends world input, captures pause state, and builds a modal above the toast.
func _open_modal(title: String, modal_size: Vector2 = Vector2(800, 576)) -> PanelContainer:
	# Capture prior state before replacing an existing modal.
	var restore_pause := get_tree().paused
	var restore_audio_pause := restore_pause or _tutorial_active()
	_close_modal(false)
	_modal_restore_pause = restore_pause
	_modal_restore_audio_pause = restore_audio_pause
	_modal_return_to_pause = false
	if restore_pause:
		get_tree().paused = true
	if restore_audio_pause:
		AudioManager.set_paused(true)
	_remember_position()
	if is_instance_valid(world):
		world.enabled = false
		world.touch_direction = Vector2.ZERO
	if is_instance_valid(_joystick):
		_joystick.reset()
		_joystick.hide()
	if is_instance_valid(_action_button):
		_action_button.disabled = true
	if is_instance_valid(_water_action_button):
		_water_action_button.disabled = true
	modal = _layer()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(modal)
	_shade(modal, Color(0.03, 0.1, 0.06, 0.65)).mouse_filter = Control.MOUSE_FILTER_STOP
	var container := UI.panel(modal, (Vector2(1280, 720) - modal_size) * 0.5, modal_size)
	if not bool(GameState.settings.get("reduced_motion", false)):
		container.pivot_offset = modal_size * 0.5
		container.modulate = Color(1, 1, 1, 0)
		container.scale = Vector2(0.97, 0.97)
		var appear := create_tween().set_parallel(true)
		appear.tween_property(container, "modulate", Color.WHITE, 0.18)
		appear.tween_property(container, "scale", Vector2.ONE, 0.18)
	var column := UI.column(container, 12)
	var header := UI.row(column, 8)
	var heading := UI.text(title, 30, UI.INK, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := UI.button("بستن", _close_modal, "close")
	close.add_theme_font_size_override("font_size", 17)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_modal_body = UI.column(scroll, 10)
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_footer = UI.row(column, 10)
	if is_instance_valid(_toast_label):
		_toast_label.position = Vector2(310, 8)
		overlay.move_child(_toast_label, overlay.get_child_count() - 1)
	return container

# Makes a closing modal input-transparent before its dismissal animation finishes.
func _set_input_transparent(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_input_transparent(child)

# Animates dismissal, restores prior pause and audio state, and re-enables gameplay input.
func _close_modal(allow_return: bool = true) -> void:
	# Snapshot restoration flags before clearing the active modal reference.
	var closing := modal
	var restore_pause := _modal_restore_pause
	var restore_audio_pause := _modal_restore_audio_pause
	var return_to_pause := _modal_return_to_pause
	modal = null
	_modal_restore_pause = false
	_modal_restore_audio_pause = false
	_modal_return_to_pause = false
	if is_instance_valid(_toast_label):
		_toast_label.position = Vector2(310, 78)
	if is_instance_valid(closing):
		_set_input_transparent(closing)
		if bool(GameState.settings.get("reduced_motion", false)):
			closing.queue_free()
		else:
			var disappear := create_tween().set_parallel(true)
			disappear.tween_property(closing, "modulate", Color(1, 1, 1, 0), 0.12)
			disappear.tween_property(closing, "scale", Vector2(0.98, 0.98), 0.12)
			disappear.chain().tween_callback(closing.queue_free)
	if allow_return and return_to_pause:
		_pause()
		return
	get_tree().paused = restore_pause
	AudioManager.set_paused(restore_audio_pause or _audio_paused_by_focus)
	if is_instance_valid(world):
		world.enabled = _in_game
	if is_instance_valid(_action_button):
		_action_button.disabled = not _in_game
	if is_instance_valid(_water_action_button):
		_water_action_button.disabled = not _in_game
	_refresh_touch_controls()

# Displays the current chapter introduction line and speaker portrait.
func _show_intro() -> void:
	var chapter := GameState.current_chapter()
	_open_modal("فصل " + UI.number(int(chapter.id)) + " · " + String(chapter.title), Vector2(830, 370))
	var line: Dictionary = chapter.intro[_intro_index]
	var row := UI.row(_modal_body, 18)
	row.add_child(UI.image(GameAtlas.cell("player.svg", 0, 0) if line.speaker == "آرمان" else GameAtlas.cell("npcs.svg", 2, 0), Vector2(130, 150)))
	var stack := UI.column(row, 12)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(UI.text(line.speaker, 24, Color("7b542e"), true))
	stack.add_child(UI.text(line.text, 24))
	_modal_footer.add_child(UI.button("ادامه" if _intro_index < chapter.intro.size() - 1 else "ورود به باغ", _next_intro, "play", "accent"))

# Advances dialogue or closes the introduction and starts the next tutorial.
func _next_intro() -> void:
	_intro_index += 1
	if _intro_index >= GameState.current_chapter().intro.size():
		_close_modal()
		if _should_start_first_run():
			_start_tutorial("first_run")
		else:
			_maybe_start_chapter_tutorial()
	else:
		_show_intro()

# Completes matching tutorial actions and routes world interactions to their menus.
func _interaction(kind: String, index: int) -> void:
	if _tutorial_active():
		var step: Dictionary = _tutorial_steps[_tutorial_index]
		# Compost completes only after construction changes stats, not when its panel merely opens.
		if String(step.get("complete_on", "")) == kind and kind != "compost":
			_tutorial_action_done = true
			_refresh_tutorial_continue()
	match kind:
		"plot": _plot_menu(index)
		"npc": _npc(index)
		"compost": _compost()

# Shows preparation, planting, care, or memorial options for the selected plot.
func _plot_menu(index: int) -> void:
	var plot: Dictionary = GameState.plots()[index]
	var near := _plot_is_near(index)
	_open_modal("اطلاعات بستر " + UI.number(index + 1), Vector2(960, 650))
	if not plot.prepared:
		var row := UI.row(_modal_body, 20)
		row.add_child(UI.image(GameAtlas.cell("props.svg", 1, 0), Vector2(150, 160)))
		var details := UI.column(row, 8)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_child(UI.text("خاک آمادهٔ کاشت نیست", 26, UI.INK, true))
		details.add_child(UI.text("نور بستر: " + UI.number(int(plot.sun)) + " از ۳ · کیفیت اولیهٔ خاک: " + UI.number(int(plot.soil)) + "٪", 21))
		details.add_child(UI.text("آماده‌کردن خاک ریشه‌ها را برای نشستن آماده می‌کند و نقطهٔ شروع مراقبت است.", 21))
		if not near:
			details.add_child(UI.text("برای انجام کار، نزدیک این بستر شو.", 20, Color("8b4e33"), true))
		else:
			_modal_footer.add_child(UI.button("آماده‌کردن خاک", func() -> void:
				if GameState.prepare_plot(index):
					AudioManager.play_sfx("prepare")
					if is_instance_valid(world):
						world.play_action("plant")
				_plot_menu(index)
			, "soil", "accent"))
	elif String(plot.species).is_empty():
		_modal_body.add_child(UI.text("یکی از شش درخت بومی ایران را متناسب با آب و نور بستر انتخاب کن. نور این بستر: " + UI.number(int(plot.sun)) + " از ۳", 22))
		if not near:
			_modal_body.add_child(UI.text("برای کاشت، ابتدا به بستر نزدیک شو.", 20, Color("8b4e33"), true))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		_modal_body.add_child(grid)
		for species in CONTENT.SPECIES:
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UI.style(Color("e4d5a9")))
			card.custom_minimum_size = Vector2(245, 205)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)
			var stack := UI.column(card, 5)
			stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var species_row := UI.row(stack, 6)
			species_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			species_row.add_child(UI.image(GameAtlas.plant(species.id, 4), Vector2(64, 70)))
			var information := UI.column(species_row, 2)
			information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var name_label := UI.text(species.name, 20, UI.INK, true)
			name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			information.add_child(name_label)
			var needs_label := UI.text("آب " + UI.number(int(species.water_need)) + " · نور " + UI.number(int(species.sun_need)) + " · رشد " + UI.number(int(species.growth_days)) + " روز", 15)
			needs_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			needs_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			information.add_child(needs_label)
			var use_label := UI.text(String(species.use), 16, UI.GREEN)
			use_label.custom_minimum_size = Vector2(0, 38)
			stack.add_child(use_label)
			# Capture the species ID so each button keeps its own selection after the loop.
			var species_id: String = species.id
			var plant_button := UI.button("کاشت " + String(species.name), func() -> void:
				if GameState.plant_tree(index, species_id):
					AudioManager.play_sfx("plant")
					if is_instance_valid(world):
						world.play_action("plant")
					_close_modal()
					if GameState.tutorial_seen("first_run"):
						_start_species_tutorial(species_id)
			, "sprout", "accent")
			plant_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plant_button.add_theme_font_size_override("font_size", 16)
			plant_button.autowrap_mode = TextServer.AUTOWRAP_OFF
			plant_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			plant_button.tooltip_text = "کاشت " + String(species.name)
			plant_button.disabled = not near
			stack.add_child(plant_button)
	else:
		var species := CONTENT.species_by_id(plot.species)
		var dead := bool(plot.get("dead", false))
		var plant_row := UI.row(_modal_body, 20)
		var portrait := UI.image(GameAtlas.plant(plot.species, int(plot.stage)), Vector2(190, 190))
		if dead:
			portrait.modulate = Color(0.48, 0.34, 0.22, 0.72)
		plant_row.add_child(portrait)
		var details := UI.column(plant_row, 6)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stage_name := "خراب شده" if dead else String(species.stage_names[int(plot.stage)])
		details.add_child(UI.text(species.name + " · " + stage_name, 26, UI.INK, true))
		details.add_child(UI.text(species.description, 20))
		details.add_child(UI.text("نوع: " + String(species.latin_common) + " · کاشت: روز " + UI.number(int(plot.planted_day)), 19))
		details.add_child(UI.text("نیاز آب: " + UI.number(int(species.water_need)) + " · نیاز نور: " + UI.number(int(species.sun_need)) + " · رشد کامل: " + UI.number(int(species.growth_days)) + " روز", 19))
		for item in [["رطوبت خاک", plot.moisture], ["کیفیت خاک", plot.soil], ["سلامت گیاه", plot.health]]:
			details.add_child(UI.text(item[0] + " " + UI.number(int(item[1])) + "٪", 19))
			details.add_child(UI.progress(float(item[1])))
		var fertilizer := "هنوز کمپوست نگرفته"
		if int(plot.compost_day) == int(GameState.data.day):
			fertilizer = "امروز کمپوست گرفته است"
		elif int(plot.compost_day) >= 0:
			fertilizer = "آخرین کمپوست: روز " + UI.number(int(plot.compost_day))
		details.add_child(UI.text("وضعیت کود: " + fertilizer, 19))
		if dead:
			details.add_child(UI.text("این نهال پس از بی‌توجهی طولانی خراب شد. بستر را پاک کن و گونهٔ تازه‌ای بکار.", 20, Color("a13f35"), true))
		else:
			var care := "حال خوب و رشد پیوسته"
			if int(plot.neglect_days) > 0:
				care = "نیازمند توجه · " + UI.number(int(plot.neglect_days)) + " روز بی‌توجهی"
			elif int(plot.health) < 60:
				care = "در حال بازیابی سلامت"
			details.add_child(UI.text("وضعیت مراقبت: " + care, 20, UI.GREEN if int(plot.health) >= 60 else Color("8b4e33"), true))
			var days_left := GameState.growth_days_left(plot)
			details.add_child(UI.text("رشد کامل: " + ("رسیده" if days_left <= 0 else UI.number(days_left) + " روز مراقبت سالم باقی مانده"), 19))
			_modal_body.add_child(UI.text("آب، خاک و نور هر صبح بررسی می‌شوند. مراقبت درست سلامت را بازیابی می‌کند؛ سه روز نادیده‌گرفتن نیازهای ضروری نهال را خراب می‌کند.", 18))
		if not near:
			_modal_body.add_child(UI.text("برای رسیدگی، نزدیک گیاه شو.", 20, Color("8b4e33"), true))
		elif dead:
			_modal_footer.add_child(UI.button("پاک‌سازی و بازکاشت", func() -> void:
				if GameState.clear_dead_plot(index):
					AudioManager.play_sfx("prepare")
					if is_instance_valid(world):
						world.play_action("collect")
				_plot_menu(index)
			, "sprout", "accent"))
		else:
			if GameState.plant_needs_water(plot):
				_modal_footer.add_child(UI.button("آبیاری", func() -> void:
					if GameState.water_plot(index):
						AudioManager.play_sfx("water")
						if is_instance_valid(world):
							world.play_action("water")
					_plot_menu(index)
				, "water", "water"))
			else:
				_modal_body.add_child(UI.text("خاک رطوبت کافی دارد و آبیاری بیشتر لازم نیست.", 19, UI.WATER, true))
			var compost_button := UI.button("کمپوست", func() -> void:
				if GameState.apply_compost(index):
					AudioManager.play_sfx("prepare", 0.8)
					if is_instance_valid(world):
						world.play_action("compost")
				_plot_menu(index)
			, "soil", "primary")
			compost_button.disabled = int(GameState.data.resources.compost) < 1 or int(plot.compost_day) == int(GameState.data.day)
			_modal_footer.add_child(compost_button)
			if String(plot.name).is_empty():
				_modal_footer.add_child(UI.button("پلاک یادبود", func() -> void: _write_memorial(String(GameState.data.zone), index), "memorial", "secondary"))

# Gates plot actions on the player's interaction distance.
func _plot_is_near(index: int) -> bool:
	return is_instance_valid(world) and world.player_position().distance_to(world.plot_position(index)) <= world.INTERACTION_DISTANCE

# Opens NPC dialogue with cycling conversation, story, and cooperation actions.
func _npc(index: int) -> void:
	GameState.talk_npc(index)
	var names := ["استاد رهنما · راهنمای باغ", "خانم نگار · مربی فرهنگی", "رها · داوطلب مدرسه", "سامان · همیار محله"]
	var conversations := [
		[String(GameState.current_chapter().mentor_line), "کارهای کوچک وقتی ماندگار می‌شوند که با دقت، صبر و مسئولیت انجام شوند."],
		["ایثار میتواند فرصتی برای خدمت بی‌چشمداشت باشد؛ اینجا با همکاری و مراقبت از نهال، سهمی در آینده داریم.", "هر روایت واقعی را با احترام و توجه به منبعش می‌خوانیم."],
		["یک گروه کوچک با تقسیم کار میتواند حیاط مدرسه را زنده کند. نقش هر داوطلب باید روشن و انتخابش آزادانه باشد.", "همکاری خوب یعنی هیچ‌کس تنها نمی‌ماند و همه فرصت مشارکت دارند."],
		["من برای رسیدگی به فضای مشترک محله آماده‌ام. به کمک کوچک اما پیوستهٔ همه نیاز دارم.", "گاهی یک گفت‌وگوی صمیمانه و یک تصمیم مشترک، راه را برای یک تغییر بزرگ باز می‌کند."]
	]
	_open_modal(names[index], Vector2(810, 440))
	var row := UI.row(_modal_body, 20)
	row.add_child(UI.image(GameAtlas.cell("npcs.svg", 2, index), Vector2(150, 175)))
	var stack := UI.column(row, 10)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dialogue_step := 0
	var dialogue_label := UI.text(conversations[index][dialogue_step], 25)
	stack.add_child(dialogue_label)
	stack.add_child(UI.text("همکاری داوطلبانه: تقسیم کار، کمک به مراقبت و فراهم‌کردن ابزار باغ", 18, Color("7b542e")))
	_modal_footer.add_child(UI.button("گفتگو", func() -> void:
		dialogue_step = (dialogue_step + 1) % conversations[index].size()
		dialogue_label.text = conversations[index][dialogue_step]
	, "book", "secondary"))
	var story_button := UI.button("داستان", func() -> void: _open_story(index, int(GameState.data.chapter)), "memorial", "primary")
	story_button.tooltip_text = "نمایش روایت تخیلی این فصل دربارهٔ پدر رها" if index == 2 else "نمایش روایت واقعی این فصل و منبع آن"
	_modal_footer.add_child(story_button)
	_modal_footer.add_child(UI.button("همکاری داوطلبانه", func() -> void:
		GameState.help_npc(index)
		_close_modal()
	, "heart", "accent"))

# Displays a sourced or fictional NPC story and tracks reading progress.
func _open_story(npc_index: int, chapter_id: int) -> void:
	var story := CONTENT.npc_story(npc_index, chapter_id)
	if story.is_empty():
		return
	var fictional := bool(story.get("fictional", false))
	var names := ["استاد رهنما · راهنمای باغ", "خانم نگار · مربی فرهنگی", "رها · داوطلب مدرسه", "سامان · همیار محله"]
	var first_read := GameState.read_npc_story(npc_index, chapter_id)
	_open_modal(names[npc_index] + " · " + ("روایت تخیلی" if fictional else "روایت واقعی"), Vector2(850, 560))
	var row := UI.row(_modal_body, 16)
	row.add_child(UI.image(GameAtlas.cell("npcs.svg", 2, npc_index), Vector2(130, 150)))
	var stack := UI.column(row, 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(UI.text(String(story.get("martyr_title", "شهید")) + " " + String(story.martyr), 30, Color("7b542e"), true))
	var perspective := String(story.get("perspective", ""))
	if not perspective.is_empty():
		stack.add_child(UI.text(perspective, 18, UI.GREEN, true))
	stack.add_child(UI.text(String(story.text), 24))
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UI.style(UI.SURFACE_MUTED, UI.BORDER, 12, 1))
	var info_column := UI.column(info_panel, 3)
	if fictional:
		info_column.add_child(UI.text("این روایت تخیلی است و به هیچ شخص یا واقعیت تاریخی نسبت داده نمی‌شود.", 16, UI.INK, true))
	else:
		info_column.add_child(UI.text("منبع: " + String(story.source_title), 16, UI.INK, true))
		var source_address := String(story.source_url)
		var source_host := source_address.split("/")[2] if source_address.split("/").size() > 2 else source_address
		var source_url := UI.text(source_host, 13, UI.TEXT_MUTED)
		source_url.text_direction = Control.TEXT_DIRECTION_LTR
		source_url.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		source_url.tooltip_text = source_address
		info_column.add_child(source_url)
	stack.add_child(info_panel)
	var listened := GameState.npc_story_seen(npc_index, chapter_id)
	var progress_text := "این روایت تازه خوانده شد." if first_read else ("این روایت را قبلاً خوانده‌ای." if listened else "روایت در حال نمایش است.")
	stack.add_child(UI.text(progress_text + " · فصل " + UI.number(chapter_id) + " از " + UI.number(CONTENT.CHAPTERS.size()) + " · " + UI.number(GameState.npc_story_count()) + " از " + UI.number(CONTENT.npc_story_total()) + " روایت", 17, UI.GREEN, true))
	var next_chapter := chapter_id % CONTENT.CHAPTERS.size() + 1
	var next_button := UI.button("روایت بعدی", func() -> void: _open_story(npc_index, next_chapter), "book", "accent")
	next_button.tooltip_text = "نمایش روایت فصل بعد از همین همراه"
	_modal_footer.add_child(next_button)
	_modal_footer.add_child(UI.button("بازگشت", _close_modal, "back", "quiet"))

# Shows compost construction, batch progress, collection, and production actions.
func _compost() -> void:
	var station: Dictionary = GameState.data.compost_station
	var built := bool(station.built)
	var construction_done := bool(station.construction_done)
	var batch_active := bool(station.batch_active)
	var ready := int(station.ready_compost)
	var remaining := GameState.compost_days_remaining()
	var raw_compost := int(GameState.data.resources.compost)
	_open_modal("ایستگاه کمپوست", Vector2(940, 620))
	var hero := UI.row(_modal_body, 14)
	hero.add_child(UI.image(GameAtlas.icon("recycle"), Vector2(64, 64)))
	var hero_copy := UI.column(hero, 3)
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hero_title := UI.text("کمپوست، ریشهٔ زندگی تازه", 28, UI.INK, true)
	hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hero_copy.add_child(hero_title)
	var hero_status := "آمادهٔ ساخت · به ۴ واحد مادهٔ خام نیاز داری"
	if built and not construction_done:
		hero_status = "ساخت در حال انجام · ادامه پس از سپیدهٔ دم"
	elif built and batch_active:
		hero_status = "آماده‌سازی دسته · " + UI.number(remaining) + " روز تا آماده‌شدن"
	elif construction_done:
		hero_status = "کارگاه آماده است · کمپوست تازه تولید کن"
	var status_label := UI.text(hero_status, 19, UI.GREEN, true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hero_copy.add_child(status_label)
	var summary := UI.row(_modal_body, 10)
	var time_value := "شروع نشد"
	if built and (not construction_done or batch_active):
		time_value = UI.number(remaining) + " روز"
	elif construction_done:
		time_value = "آماده"
	for item in [["soil", "مادهٔ خام", UI.number(raw_compost)], ["leaf", "کمپوست آماده", UI.number(ready)], ["sun", "زمان باقی", time_value]]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 78)
		card.add_theme_stylebox_override("panel", UI.style(UI.SURFACE_MUTED, UI.BORDER, 14, 1))
		var row := UI.row(card, 10)
		row.add_child(UI.image(GameAtlas.icon(item[0]), Vector2(30, 30)))
		var stack := UI.column(row, 2)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var caption := UI.text(item[1], 16, UI.TEXT_MUTED, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack.add_child(caption)
		var value := UI.text(item[2], 23, UI.INK, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack.add_child(value)
		summary.add_child(card)
	var stages := UI.row(_modal_body, 10)
	var stage_data := [
		["۱ · ساخت", "soil", built, construction_done, "ساخته شد" if construction_done else ("۱ روز باقی مانده" if built else "در انتظار")],
		["۲ · آماده‌سازی", "recycle", construction_done and (batch_active or ready == 0), construction_done and ready > 0 and not batch_active, UI.number(remaining) + " روز باقی مانده" if batch_active else ("آمادهٔ دریافت" if ready > 0 else ("آمادهٔ آغاز" if construction_done else "قفل است"))],
		["۳ · دریافت", "leaf", ready > 0, false, UI.number(ready) + " واحد آماده" if ready > 0 else "فعلاً خالی"],
	]
	for i in range(stage_data.size()):
		var current: bool = stage_data[i][2]
		var done: bool = stage_data[i][3]
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 126)
		var fill := Color("dbe7c9") if done else (Color("f1dda9") if current else Color("e5ddc7"))
		var edge := UI.GREEN if done else (UI.ACCENT if current else Color("b7ad8d"))
		card.add_theme_stylebox_override("panel", UI.style(fill, edge, 16, 2))
		var column := UI.column(card, 4)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(UI.image(GameAtlas.icon(stage_data[i][1]), Vector2(38, 38)))
		var title := UI.text(stage_data[i][0], 19, UI.INK, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		column.add_child(title)
		var status := UI.text(stage_data[i][4], 16, UI.GREEN if done or current else UI.TEXT_MUTED, true)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		column.add_child(status)
		stages.add_child(card)
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", UI.style(Color("eee0bd"), UI.BORDER, 14, 1))
	var detail_column := UI.column(detail, 5)
	if not built:
		detail_column.add_child(UI.text("برای شروع به ۴ واحد مادهٔ خام نیاز داری.", 21, UI.INK, true))
		detail_column.add_child(UI.text("مواد آلی جدا‌شده را جمع کن؛ پس از ساخت، هر دستهٔ تازه یک روز زمان می‌برد و ۲ واحد کمپوست آماده می‌دهد.", 18))
	elif not construction_done:
		detail_column.add_child(UI.text("پیشرفت ساخت · " + UI.number(int(clampf(100.0 * (1.0 - float(remaining)), 0.0, 100.0))) + "٪", 18, UI.INK, true))
		detail_column.add_child(UI.progress(clampf(100.0 * (1.0 - float(remaining)), 0.0, 100.0), UI.GOLD))
		detail_column.add_child(UI.text("کارگاه در حال ساخت است. با گذشت خودکار روز، آمادهٔ مرحلهٔ بعد می‌شود.", 18))
	elif batch_active:
		detail_column.add_child(UI.text("پیشرفت آماده‌سازی · " + UI.number(int(clampf(100.0 * (1.0 - float(remaining)), 0.0, 100.0))) + "٪", 18, UI.INK, true))
		detail_column.add_child(UI.progress(clampf(100.0 * (1.0 - float(remaining)), 0.0, 100.0), UI.GOLD))
		detail_column.add_child(UI.text("دستهٔ کمپوست در حال آماده‌سازی است؛ پس از یک روز، ۲ واحد آماده خواهد بود.", 18))
	else:
		detail_column.add_child(UI.text("کارگاه آمادهٔ کار است", 21, UI.INK, true))
		detail_column.add_child(UI.text("یک دستهٔ تازه با ۱ واحد مادهٔ خام شروع می‌شود و پس از یک روز ۲ واحد کمپوست آماده می‌دهد. کمپوست آماده را دریافت کن و به خاک نهال‌ها بده.", 18))
	_modal_body.add_child(detail)
	if not built:
		var build_button := UI.button("ساخت کارگاه کمپوست", func() -> void:
			if GameState.build_compost_station():
				AudioManager.play_sfx("prepare")
				if is_instance_valid(world):
					world.play_action("compost")
			_compost()
		, "soil", "accent")
		build_button.disabled = raw_compost < 4
		_modal_footer.add_child(build_button)
	elif not construction_done or batch_active:
		_modal_footer.add_child(UI.button("بازگشت به باغ", _close_modal, "back", "quiet"))
	else:
		var collect_button := UI.button("دریافت کمپوست آماده", func() -> void:
			if GameState.collect_compost() > 0:
				AudioManager.play_sfx("harvest")
				if is_instance_valid(world):
					world.play_action("collect")
			_compost()
		, "leaf", "accent")
		collect_button.disabled = ready <= 0 or raw_compost >= 12
		_modal_footer.add_child(collect_button)
		var batch_button := UI.button("آماده‌سازی دستهٔ تازه", func() -> void:
			if GameState.start_compost_batch():
				AudioManager.play_sfx("prepare", 0.8)
				if is_instance_valid(world):
					world.play_action("compost")
			_compost()
		, "recycle", "primary")
		batch_button.disabled = raw_compost < 1 or ready > 4
		_modal_footer.add_child(batch_button)

# Lists current chapter tasks with progress and context-specific actions.
func _missions() -> void:
	_open_modal("مأموریت‌های فصل", Vector2(850, 590))
	var chapter := GameState.current_chapter()
	_modal_body.add_child(UI.text(chapter.subtitle, 25, UI.INK, true))
	var instructions := {
		"clean_trash": "به بسته‌های پسماند نزدیک شو و تعامل کن.",
		"talk_guide": "با راهنماها و داوطلبان متفاوت گفت‌وگو کن.",
		"prepare_soil": "با بسترها تعامل کن؛ خاک خالی را آماده یا بستر قبلی را با کمپوست بهتر کن.",
		"plant_tree": "بستر آماده را انتخاب و یکی از گونه‌ها را بکار.",
		"water_tree": "وقتی دکمهٔ آب کنار نهال ظاهر شد، خاک را بر اساس نیاز آبیاری کن.",
		"collect_recycle": "مواد آلی و پسماندهای مشخص‌شده را جدا کن؛ مادهٔ خام کمپوست به دست می‌آید.",
		"plant_school": "از نقشه به مدرسه برو و در بسترهای آن نهال بکار.",
		"plant_native": "در شهر یکی از درختان بومی ایران مثل سرو، بلوط، انار، ارغوان، ممرز یا بید بکار.",
		"answer_quiz": "پرسش‌های این فصل را از دکمهٔ پایین همین پنجره پاسخ بده.",
		"final_quiz": "سه پرسش پایانی را با بازخورد آموزشی پاسخ بده.",
		"read_story": "روایت‌های متفاوت را از باغ یادبود یا دکمهٔ پایین همین پنجره بخوان.",
		"write_memorial": "برای یک نهال واقعیِ بازی نام و پیام یادبود بنویس.",
		"add_memorial": "ثبت همان پلاک، آن را به باغ یادبود اضافه میکند.",
		"help_people": "به داوطلبان متفاوت نزدیک شو و همکاری داوطلبانه را انتخاب کن.",
		"mature_tree": "حداقل دو نهال سالم را با آب، کمپوست و گذر روزها به مرحلهٔ درخت جوان برسان.",
		"celebrate_city": "پس از تکمیل بقیهٔ کارها، جشن پایانی را همینجا برگزار کن."
	}
	var needs_quiz := false
	var needs_stories := false
	for task in chapter.tasks:
		var count := GameState.task_count(task.id)
		_modal_body.add_child(UI.text(String(task.label) + "  " + UI.number(count) + "/" + UI.number(int(task.target)), 22, UI.INK, true))
		_modal_body.add_child(UI.progress(100.0 * count / int(task.target)))
		_modal_body.add_child(UI.text(instructions.get(task.id, ""), 19))
		if String(task.id) in ["answer_quiz", "final_quiz"]:
			needs_quiz = true
		if String(task.id) == "read_story":
			needs_stories = true
	if needs_quiz:
		_modal_footer.add_child(UI.button("پرسش‌های فصل", _quiz, "book"))
	if needs_stories:
		_modal_footer.add_child(UI.button("روایت‌های فصل", _stories, "book"))
	if int(GameState.data.chapter) == 8:
		_modal_footer.add_child(UI.button("برگزاری جشن شهر سبز", func() -> void:
			if GameState.celebrate():
				_missions()
		, "trophy", "accent"))
	if GameState.chapter_ready():
		_modal_footer.add_child(UI.button("پایان فصل", _finish_chapter, "check", "accent"))

# Completes the active chapter or advances one already marked complete.
func _finish_chapter() -> void:
	var chapter_id := int(GameState.data.chapter)
	if chapter_id in GameState.data.completed:
		_advance_after_chapter(chapter_id)
	elif GameState.complete_chapter():
		_chapter_finished(chapter_id)

# Moves to the next chapter introduction or shows the ending after chapter eight.
func _advance_after_chapter(chapter_id: int) -> void:
	if chapter_id < 8:
		GameState.next_chapter()
		_resume_live_world()
		_intro_index = 0
		_show_intro()
	else:
		_show_ending()

# Celebrates chapter completion and offers the reward transition.
func _chapter_finished(chapter_id: int) -> void:
	AudioManager.play_sfx("unlock")
	if is_instance_valid(world) and is_instance_valid(world._player):
		world._player.react()
	var chapter := CONTENT.chapter_by_id(chapter_id)
	_open_modal("آفرین! فصل کامل شد", Vector2(830, 475))
	_modal_body.add_child(UI.text(chapter.title, 33, Color("7b542e"), true))
	_modal_body.add_child(UI.text(chapter.completion, 25))
	var reward: Dictionary = chapter.reward
	_modal_body.add_child(UI.text("محیط زیست +" + UI.number(int(reward.eco)) + "  ·  مسئولیت +" + UI.number(int(reward.social)) + "  ·  آگاهی +" + UI.number(int(reward.culture)), 21))
	_modal_footer.add_child(UI.button("رفتن به فصل بعد" if chapter_id < 8 else "پایان داستان", func() -> void: _advance_after_chapter(chapter_id), "play", "accent"))

# Resumes the existing world after a modal instead of rebuilding the full gameplay screen.
func _resume_live_world() -> void:
	_close_modal()
	_close_tutorial(false)
	if not _in_game or not is_instance_valid(world):
		_show_game()
		return
	world.enabled = true
	_refresh_hud()
	_refresh_touch_controls()
	AudioManager.set_paused(false)
	AudioManager.play_music(_music_for_current_scene())

# Visits an unlocked zone while allowing GameState.changed to refresh actors exactly once.
func _visit_zone(zone: String) -> void:
	if not GameState.zone_unlocked(zone):
		return
	if String(GameState.data.get("zone", "")) != zone:
		if not GameState.set_zone(zone):
			return
	elif is_instance_valid(world):
		world.refresh()
	_resume_live_world()
	_maybe_start_zone_tutorial(zone)

# Shows unlocked zones and completed chapters for navigation.
func _map() -> void:
	_open_modal("نقشهٔ شهر و انتخاب فصل", Vector2(900, 610))
	var zones := [["garden", "باغ و بسترهای کاشت"], ["school", "حیاط مدرسه"], ["park", "پارک محله"], ["city", "شهر و باغ بومی"]]
	var locations_row := UI.row(_modal_body, 10)
	for entry in zones:
		# Capture loop values so each navigation button targets its own destination.
		var zone_id: String = entry[0]
		var btn := UI.button(entry[1], func() -> void:
			_visit_zone(zone_id)
		, "map")
		btn.disabled = not GameState.zone_unlocked(zone_id)
		btn.add_theme_font_size_override("font_size", 18)
		locations_row.add_child(btn)
	_modal_body.add_child(UI.text("فصل‌های قبلی برای بازدید آزادند؛ هدف‌های فعال مربوط به فصل فعلی است.", 19))
	for chapter in CONTENT.CHAPTERS:
		var id := int(chapter.id)
		var status := "کامل" if id in GameState.data.completed else ("فعال" if id == int(GameState.data.chapter) else "قفل")
		var btn := UI.button(UI.number(id) + " · " + String(chapter.title) + "  —  " + status, func() -> void:
			_visit_zone(String(chapter.location))
		, "check" if id in GameState.data.completed else ("play" if id == int(GameState.data.chapter) else "lock"))
		btn.disabled = id > int(GameState.data.chapter)
		_modal_body.add_child(btn)

# Summarizes planted trees across zones and offers direct visits.
func _plants() -> void:
	_open_modal("مدیریت نهال‌ها و تنوع زیستی", Vector2(900, 602))
	_modal_body.add_child(UI.text("درختان سالم در شهر: " + UI.number(GameState.biodiversity()) + " از ۶  ·  تنوع درختان بومی، باغ را زنده‌تر میکند.", 22))
	var found := false
	for zone in GameState.LOCATIONS:
		for index in range(6):
			var plot: Dictionary = GameState.plots(zone)[index]
			if String(plot.species).is_empty():
				continue
			found = true
			var row := UI.row(_modal_body, 10)
			row.add_child(UI.image(GameAtlas.plant(plot.species, int(plot.stage)), Vector2(64, 64)))
			var condition := "خراب" if bool(plot.get("dead", false)) else "سلامت " + UI.number(int(plot.health)) + "٪"
			var detail := UI.text(CONTENT.species_by_id(plot.species).name + " · " + _zone_name(zone) + " · " + condition + " · رطوبت " + UI.number(int(plot.moisture)) + "٪", 21)
			detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(detail)
			# Capture the plot location before creating the deferred visit action.
			var target_zone: String = zone
			var target_index := index
			row.add_child(UI.button("بازدید", func() -> void:
				_visit_zone(target_zone)
				if is_instance_valid(world):
					world.set_player_position(world.plot_position(target_index) + Vector2(65, 40))
			, "map"))
	if not found:
		_modal_body.add_child(UI.text("هنوز نهالی نکاشته‌ای؛ با یکی از بسترهای باغ تعامل کن.", 26))

# Lists valid memorial plaques and links to story and creation flows.
func _memorials() -> void:
	_open_modal("باغ یادبود · هر نهال یک پیام", Vector2(900, 610))
	_modal_body.add_child(UI.text("روایت‌های همراهان باغ از منابع معتبر انتخاب شده‌اند؛ پیام‌های یادبود تو فقط روی همین دستگاه ذخیره می‌شود.", 20, Color("7b542e")))
	if GameState.data.memorials.is_empty():
		_modal_body.add_child(UI.text("برای یک نهال کاشته‌شده پلاک یادبود ثبت کن.", 25))
	for entry in GameState.data.memorials:
		if not entry is Dictionary:
			continue
		var memorial_zone := String(entry.get("zone", ""))
		var memorial_index := int(entry.get("plot", -1))
		if not GameState.LOCATIONS.has(memorial_zone) or memorial_index < 0 or memorial_index >= GameState.plots(memorial_zone).size():
			continue
		var species_id := String(entry.get("species", ""))
		var species: Dictionary = CONTENT.species_by_id(species_id)
		if species.is_empty():
			continue
		var plot: Dictionary = GameState.plots(memorial_zone)[memorial_index]
		var stage := clampi(int(plot.stage), 0, 5)
		var row := UI.row(_modal_body, 10)
		row.add_child(UI.image(GameAtlas.plant(species_id, stage), Vector2(65, 75)))
		var stack := UI.column(row, 6)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(UI.text(String(entry.name) + " · " + String(species.name) + " · روز " + UI.number(int(entry.day)), 24, UI.INK, true))
		stack.add_child(UI.text(String(entry.message), 21))
		stack.add_child(UI.text(_zone_name(memorial_zone) + " · بستر " + UI.number(memorial_index + 1) + " · " + String(species.stage_names[stage]) + " · سلامت " + UI.number(int(plot.health)) + "٪", 18, UI.GREEN))
	_modal_footer.add_child(UI.button("ثبت پلاک تازه", _select_memorial_plant, "memorial", "accent"))
	_modal_footer.add_child(UI.button("روایت‌ها", _stories, "book"))

# Lists planted trees that do not already have a memorial plaque.
func _select_memorial_plant() -> void:
	_open_modal("انتخاب نهال امید", Vector2(790, 555))
	var found := false
	for zone in GameState.LOCATIONS:
		for index in range(6):
			var plot: Dictionary = GameState.plots(zone)[index]
			if String(plot.species).is_empty() or not String(plot.name).is_empty() or GameState.has_memorial(zone, index):
				continue
			found = true
			# Keep each selection bound to its originating plot after the loops advance.
			var target_zone: String = zone
			var target_index := index
			_modal_body.add_child(UI.button(CONTENT.species_by_id(plot.species).name + " · " + _zone_name(zone) + " · بستر " + UI.number(index + 1), func() -> void:
				_write_memorial(target_zone, target_index)
			, "sprout"))
	if not found:
		_modal_body.add_child(UI.text("نهال بدون پلاک پیدا نشد؛ در باغ نهال تازه بکار.", 25))

# Collects and validates a memorial name and message before saving it.
func _write_memorial(zone: String, index: int) -> void:
	_open_modal("نام و پیام نهال امید", Vector2(780, 570))
	if GameState.has_memorial(zone, index):
		_modal_body.add_child(UI.text("این بستر قبلاً پلاک یادبود دارد و ویرایش یا حذف پلاک در این نسخه ممکن نیست.", 23))
		return
	var plot: Dictionary = GameState.plots(zone)[index]
	if not String(plot.name).is_empty():
		_modal_body.add_child(UI.text("این نهال قبلاً پلاک دارد: " + String(plot.name), 24))
		return
	_modal_body.add_child(UI.text("یک پیام محترمانه دربارهٔ ایثار، امید و مراقبت بنویس. تاریخ و خاطرهٔ واقعی بدون منبع معتبر وارد نکن.", 21))
	_modal_body.add_child(UI.text("نام نهال · حداکثر ۴۰ حرف", 20, UI.INK, true))
	var name_field := LineEdit.new()
	name_field.placeholder_text = "مثلاً سرو امید"
	name_field.max_length = 40
	name_field.text_direction = Control.TEXT_DIRECTION_RTL
	name_field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_field.add_theme_font_override("font", UI.FONT)
	name_field.add_theme_font_size_override("font_size", 23)
	name_field.custom_minimum_size.y = 52
	_modal_body.add_child(name_field)
	_modal_body.add_child(UI.text("پیام یادبود · حداکثر ۲۴۰ حرف", 20, UI.INK, true))
	var message_field := TextEdit.new()
	message_field.text = "این نهال برای یاد همهٔ کسانی است که با مهربانی به آیندهٔ ما کمک کردند."
	message_field.text_direction = Control.TEXT_DIRECTION_RTL
	message_field.add_theme_font_override("font", UI.FONT)
	message_field.add_theme_font_size_override("font_size", 21)
	message_field.custom_minimum_size.y = 140
	_modal_body.add_child(message_field)
	var error := UI.text("", 18, Color("a13f35"))
	_modal_body.add_child(error)
	_modal_footer.add_child(UI.button("ثبت در باغ یادبود", func() -> void:
		if name_field.text.strip_edges().is_empty() or message_field.text.strip_edges().is_empty():
			error.text = "نام و پیام هر دو لازم هستند."
		elif message_field.text.length() > 240:
			error.text = "پیام باید کوتاه‌تر از ۲۴۱ حرف باشد."
		elif GameState.has_memorial(zone, index):
			error.text = "این بستر قبلاً پلاک یادبود دارد."
		elif GameState.save_memorial(zone, index, name_field.text, message_field.text):
			AudioManager.play_sfx("harvest")
			_memorials()
		else:
			error.text = "ثبت پلاک انجام نشد؛ نهال و اطلاعات واردشده را بررسی کن."
	, "check", "accent"))

# Opens the next unread NPC story, cycling through all stories afterward.
func _stories() -> void:
	var npc_ids := CONTENT.npc_story_npcs()
	var chapter_id := int(GameState.data.chapter)
	for offset in range(npc_ids.size()):
		var candidate := (_story_index + offset) % npc_ids.size()
		var npc_index := int(npc_ids[candidate])
		if not GameState.npc_story_seen(npc_index, chapter_id):
			_story_index = (candidate + 1) % npc_ids.size()
			_open_story(npc_index, chapter_id)
			return
	var npc_index := int(npc_ids[_story_index % npc_ids.size()])
	_story_index = (_story_index + 1) % npc_ids.size()
	_open_story(npc_index, chapter_id)

# Opens the first unanswered question or a completion message.
func _quiz() -> void:
	var indices := GameState.quiz_indices()
	_quiz_index = -1
	for index in indices:
		if index not in GameState.data.quiz_solved:
			_quiz_index = index
			break
	_open_modal("پرسش و پاسخ · یادگیری با تصمیم", Vector2(890, 555))
	if _quiz_index == -1:
		_modal_body.add_child(UI.text("همهٔ پرسش‌های این فصل پاسخ داده شدند. آفرین!", 28, UI.GREEN, true))
		return
	var question: Dictionary = CONTENT.QUESTIONS[_quiz_index]
	var heading_row := UI.row(_modal_body, 12)
	heading_row.add_child(UI.image(GameAtlas.cell("npcs.svg", 2, 1), Vector2(80, 94)))
	var question_label := UI.text(question.question, 25, UI.INK, true)
	question_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(question_label)
	_quiz_options = []
	for i in range(4):
		var answer_index := i
		var option := UI.button(question.options[i], func() -> void: _answer_quiz(answer_index), "")
		option.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		option.add_theme_font_size_override("font_size", 19)
		_modal_body.add_child(option)
		_quiz_options.append(option)
	_quiz_feedback = UI.text("برای پاسخ اشتباه امتیازی از دست نمیدهی؛ بازخورد را بخوان و دوباره تلاش کن.", 18, Color("7b542e"))
	_modal_body.add_child(_quiz_feedback)

# Records an answer, gives feedback, and unlocks the next question on success.
func _answer_quiz(option: int) -> void:
	var success := GameState.answer_question(_quiz_index, option)
	AudioManager.play_sfx("quiz_correct" if success else "quiz_wrong")
	_quiz_feedback.text = ("آفرین! " if success else "یکبار دیگر فکر کن. ") + String(CONTENT.QUESTIONS[_quiz_index].feedback)
	_quiz_feedback.add_theme_color_override("font_color", UI.GREEN if success else Color("8b4e33"))
	if success:
		for btn in _quiz_options:
			btn.disabled = true
		_modal_footer.add_child(UI.button("پرسش بعدی", _quiz, "play", "accent"))

# Displays all achievements with locked and unlocked states.
func _achievements() -> void:
	_open_modal("دستاوردهای باغ", Vector2(830, 610))
	_modal_body.add_child(UI.text("امتیازها برای فعالیت‌های باغ‌اند؛ نه ارزش‌گذاری انسان‌ها یا خاطره‌های آنان.", 21))
	for achievement in CONTENT.ACHIEVEMENTS:
		var unlocked: bool = achievement.id in GameState.data.achievements
		var row := UI.row(_modal_body, 12)
		row.add_child(UI.image(GameAtlas.icon("trophy" if unlocked else "lock"), Vector2(38, 42)))
		var stack := UI.column(row, 3)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(UI.text(achievement.title + (" · دریافت شد" if unlocked else " · در انتظار"), 23, UI.GREEN if unlocked else UI.INK, true))
		stack.add_child(UI.text(achievement.description, 18))

# Opens the pause menu without interrupting an active tutorial.
func _pause() -> void:
	if _tutorial_active():
		return
	_audio_paused_by_focus = false
	_open_modal("بازی متوقف است", Vector2(600, 460))
	# Closing the pause menu resumes play rather than restoring the paused tree.
	_modal_restore_pause = false
	_modal_restore_audio_pause = false
	get_tree().paused = true
	AudioManager.set_paused(true)
	_modal_body.add_child(UI.button("ادامهٔ بازی", _close_modal, "play", "accent"))
	_modal_body.add_child(UI.button("ذخیرهٔ پیشرفت", _manual_save, "check"))
	_modal_body.add_child(UI.button("تنظیمات", _settings, "settings"))
	_modal_body.add_child(UI.button("منوی اصلی", func() -> void:
		if _save_progress_for_exit():
			_show_menu()
		else:
			_toast(GameState.save_error)
	, "home"))

# Persist the current position and progress with audible confirmation or a visible error.
func _manual_save() -> void:
	_remember_position()
	var saved := GameState.save_game()
	_toast("پیشرفت ذخیره شد." if saved else GameState.save_error)
	if saved:
		AudioManager.play_sfx("save", 0.8)

# Build live settings and briefly preview audio even when the dialog opens from Pause.
func _settings(message: String = "") -> void:
	var preview_audio := get_tree().paused and not _tutorial_active()
	_open_modal("تنظیمات", Vector2(900, 650))
	_modal_return_to_pause = preview_audio
	if preview_audio:
		AudioManager.set_paused(false)
	var summary := UI.text(message if not message.is_empty() else "صدا، زمان روز و کنترل‌ها را تنظیم کن؛ برای شنیدن تغییر، اسلایدر صدا را حرکت بده.", 18, UI.GREEN if not message.is_empty() else UI.TEXT_MUTED)
	_modal_body.add_child(summary)
	var sound_card := _settings_section("صدا و موسیقی", "sound")
	var sound_row := UI.row(sound_card, 18)
	_settings_slider(sound_row, "music", "موسیقی", 0.0, 1.0, 0.05, func(value: float) -> String: return UI.number(int(value * 100.0)) + "٪")
	_settings_slider(sound_row, "sound", "صداهای بازی", 0.0, 1.0, 0.05, func(value: float) -> String: return UI.number(int(value * 100.0)) + "٪")
	var access_card := _settings_section("زمان و دسترسی", "sun")
	_settings_slider(access_card, "day_length", "مدت یک روز کامل", 120.0, 480.0, 60.0, func(value: float) -> String: return UI.number(int(value / 60.0)) + " دقیقه")
	var toggle_row := UI.row(access_card, 14)
	_settings_toggle(toggle_row, "touch", "کنترل‌های لمسی", "جوی‌استیک و دکمه‌های عمل و آب را در بازی نمایش می‌دهد.")
	_settings_toggle(toggle_row, "reduced_motion", "کاهش حرکت", "افکت‌ها و حرکت محلی را کم می‌کند؛ زمان و مأموریت‌ها تغییر نمی‌کنند.")
	var saved := UI.text("تغییرها بلافاصله و آفلاین ذخیره می‌شوند.", 16, UI.TEXT_MUTED)
	saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_footer.add_child(saved)
	_modal_footer.add_child(UI.button("بازنشانی تنظیمات", func() -> void:
		GameState.reset_settings()
		AudioManager.apply_settings()
		_refresh_touch_controls()
		_settings("تنظیمات به حالت اولیه بازگشت.")
	, "settings", "wood"))
	_modal_footer.add_child(UI.button("راهنمای کنترل‌ها", _controls, "info"))

# Add a titled icon card that groups related controls inside Settings.
func _settings_section(title: String, icon_name: String) -> VBoxContainer:
	var panel := UI.panel(_modal_body, Vector2.ZERO, Vector2.ZERO, Color("fbf0d4"))
	var column := UI.column(panel, 8)
	var heading := UI.row(column, 8)
	heading.add_child(UI.image(GameAtlas.icon(icon_name), Vector2(25, 25)))
	var label := UI.text(title, 23, UI.INK, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	return column

# Bind a range slider to a validated setting and apply its immediate audio or touch effect.
func _settings_slider(parent: Node, key: String, title: String, minimum: float, maximum: float, step: float, format_value: Callable) -> void:
	var column := UI.column(parent, 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := UI.row(column, 8)
	var label := UI.text(title, 20, UI.INK, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var value_label := UI.text("", 20, UI.GREEN, true)
	value_label.name = "value_" + key
	value_label.custom_minimum_size.x = 80
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.add_child(value_label)
	var slider := HSlider.new()
	slider.name = "setting_" + key
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(GameState.settings[key])
	slider.custom_minimum_size = Vector2(0, 44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.text = String(format_value.call(slider.value))
	slider.value_changed.connect(func(value: float) -> void:
		if GameState.set_setting(key, value):
			value_label.text = String(format_value.call(value))
			if key in ["music", "sound"]:
				AudioManager.apply_settings()
			elif key == "touch":
				_refresh_touch_controls()
	)
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed and float(GameState.settings.sound) > 0.0:
			AudioManager.play_sfx("click", 0.7)
	)
	column.add_child(slider)

# Build an RTL boolean setting card and refresh touch controls when its value changes.
func _settings_toggle(parent: Node, key: String, title: String, description: String) -> void:
	var panel := UI.panel(parent, Vector2.ZERO, Vector2.ZERO, Color("fff7e2"))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UI.column(panel, 2)
	var check := CheckButton.new()
	check.name = "setting_" + key
	check.text = title
	check.button_pressed = bool(GameState.settings[key])
	check.text_direction = Control.TEXT_DIRECTION_RTL
	check.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	check.add_theme_font_override("font", UI.BOLD)
	check.add_theme_font_size_override("font_size", 21)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		check.add_theme_color_override(color_name, UI.INK)
	check.custom_minimum_size = Vector2(0, 44)
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check.toggled.connect(func(value: bool) -> void:
		if GameState.set_setting(key, value) and key == "touch":
			_refresh_touch_controls()
	)
	column.add_child(check)
	column.add_child(UI.text(description, 17, UI.TEXT_MUTED))

# Show the numbered gameplay guide and entry points for replaying supported tutorials.
func _controls() -> void:
	var return_to_pause := get_tree().paused and not _tutorial_active()
	_open_modal("راهنمای بازی", Vector2(900, 650))
	_modal_return_to_pause = return_to_pause
	_modal_body.add_child(UI.text("مراحل این راهنما به‌ترتیب شماره‌گذاری شده‌اند؛ از مرحلهٔ ۱ شروع کن و تا مرحلهٔ آخر ادامه بده.", 18, UI.TEXT_MUTED))
	var steps := [
		{"icon": "leaf", "title": "حرکت کردن", "text": "روی گوشی جوی‌استیک پایین چپ را بکش. روی رایانه از کلیدهای جهت‌دار یا W A S D استفاده کن."},
		{"icon": "team", "title": "اطلاعات و گفت‌وگو", "text": "به NPC نزدیک شو و دکمهٔ «عمل» را بزن. گفت‌وگو، داستان و همکاری از همین پنجره باز می‌شود."},
		{"icon": "water", "title": "آبیاری نهال", "text": "نزدیک نهال برو و دکمهٔ «آب» پایین راست را بزن. روی رایانه کلید Q هم کار می‌کند."},
		{"icon": "seed", "title": "آماده‌کردن خاک و کاشت", "text": "نزدیک بستر خالی برو و دکمهٔ «عمل» را بزن؛ «آماده‌کردن خاک» را انتخاب کن و سپس درختی با نیازهای نور و آب متناسب برگزین."},
		{"icon": "recycle", "title": "جمع‌آوری و کمپوست", "text": "پسماند و مواد آلی را جمع کن. در ایستگاه باغ کارگاه کمپوست را بساز، تا آماده‌شدن صبر کن و کمپوست را به بستر بده."},
		{"icon": "sun", "title": "گذر زمان و مراقبت", "text": "روز و شب خودکار می‌گذرد. هر صبح رطوبت، خاک و سلامت بررسی می‌شود؛ سه روز بی‌مراقبت نهال را از بین می‌برد."},
		{"icon": "quest", "title": "مأموریت‌ها و فصل بعد", "text": "پس از آموزش گزینهٔ «مأموریت» را انتخاب کن و حتماً توضیحات زیر هر مأموریت را بخوان. پس از تکمیل همهٔ مأموریت‌ها، «پایان فصل» و سپس «رفتن به فصل بعد» را انتخاب کن."},
		{"icon": "map", "title": "نقشه و فصل‌های قبلی", "text": "برای دیدن نقشه‌ها و فصل‌های قبلی گزینهٔ «نقشه» را انتخاب کن. هر نقشه‌ای که باز شده باشد را انتخاب کن تا به همان مکان بروی."},
		{"icon": "memorial", "title": "یادبود و روایت‌ها", "text": "برای نهال کاشته‌شده از «یادبود» نام و پیام ثبت کن. با NPCها گفت‌وگو کن تا روایت‌های واقعی و تخیلی رها را بشنوی."},
		{"icon": "check", "title": "ذخیره خودکار و ادامه", "text": "بازی به‌صورت خودکار ذخیره می‌شود. برای اطمینان، در صفحهٔ بازی گزینه‌های «توقف» و «ذخیرهٔ پیشرفت» را انتخاب کن. هر وقت خواستی، در صفحهٔ اول گزینهٔ «ادامه بازی» را انتخاب کن."},
		{"icon": "pause", "title": "توقف و تنظیمات", "text": "برای استراحت از گزینهٔ «توقف» یا کلید Escape استفاده کن. صدا، کنترل‌ها، مدت روز و کاهش حرکت را در تنظیمات تغییر بده."},
	]
	for index in range(steps.size()):
		var step: Dictionary = steps[index]
		_guide_step(index + 1, String(step.icon), String(step.title), String(step.text))
	var replay_first := UI.button("آموزش اولیه", func() -> void: _start_tutorial("first_run", true), "play", "accent")
	var replay_chapter := UI.button("آموزش فصل جاری", func() -> void: _start_tutorial(_chapter_tutorial_id(), true), "book", "secondary")
	replay_first.disabled = GameState.data.is_empty()
	replay_chapter.disabled = GameState.data.is_empty() or _chapter_tutorial_id().is_empty()
	_modal_footer.add_child(replay_first)
	_modal_footer.add_child(replay_chapter)
	_modal_footer.add_child(UI.button("تنظیمات", _settings, "settings", "wood"))

# Render one numbered guide card with its icon, heading, and full instruction text.
func _guide_step(number: int, icon_name: String, title: String, description: String) -> void:
	var panel := UI.panel(_modal_body, Vector2.ZERO, Vector2.ZERO, Color("fff7e2"))
	var row := UI.row(panel, 12)
	var badge := UI.panel(row, Vector2.ZERO, Vector2(46, 46), UI.GREEN)
	badge.custom_minimum_size = Vector2(46, 46)
	var number_label := UI.text(UI.number(number), 22, UI.CREAM, true)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.set_meta("center_aligned", true)
	badge.add_child(number_label)
	var column := UI.column(row, 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := UI.row(column, 6)
	heading.add_child(UI.image(GameAtlas.icon(icon_name), Vector2(24, 24)))
	var title_label := UI.text(title, 22, UI.INK, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_label)
	column.add_child(UI.text(description, 19, UI.INK))

# Present NewTech credits, project identity, motto, and event inside the wooden team frame.
func _about() -> void:
	var container := _open_modal("درباره ما", Vector2(900, 680))
	var frame := StyleBoxTexture.new()
	frame.texture = load("res://assets/art/about_panel.svg") as Texture2D
	frame.texture_margin_left = 26.0
	frame.texture_margin_top = 26.0
	frame.texture_margin_right = 26.0
	frame.texture_margin_bottom = 26.0
	frame.content_margin_left = 74.0
	frame.content_margin_top = 82.0
	frame.content_margin_right = 74.0
	frame.content_margin_bottom = 58.0
	container.add_theme_stylebox_override("panel", frame)
	for node in modal.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == "بستن":
			button.text = "×"
			button.icon = null
			button.tooltip_text = "بستن"
			button.custom_minimum_size = Vector2(64, 64)
			button.add_theme_font_size_override("font_size", 30)
	var hero := UI.row(_modal_body, 14)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(UI.image(GameAtlas.icon("team"), Vector2(76, 76)))
	var hero_text := UI.column(hero, 2)
	hero_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_text.alignment = BoxContainer.ALIGNMENT_CENTER
	var group_name := UI.text("نیوتک (NewTech)", 38, UI.DEEP, true)
	group_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hero_text.add_child(group_name)
	var team_subtitle := UI.text("سازندگان بازی ریشه‌های ایثار", 22, UI.GREEN, true)
	team_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hero_text.add_child(team_subtitle)
	var members_heading := UI.text("اعضای گروه", 20, Color("7b542e"), true)
	members_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_modal_body.add_child(members_heading)
	var members := UI.row(_modal_body, 16)
	members.alignment = BoxContainer.ALIGNMENT_CENTER
	for member_name in ["یاسمین رضایی", "یاسمن بخشی‌زاده"]:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(320, 92)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UI.style(Color("f4e4bd"), UI.BORDER, 18, 2))
		members.add_child(card)
		var member_column := UI.column(card, 3)
		var name_label := UI.text(member_name, 25, UI.INK, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		member_column.add_child(name_label)
		var role_label := UI.text("عضو گروه", 17, UI.TEXT_MUTED)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		member_column.add_child(role_label)
	var project_label := UI.text("نام پروژه: بازی ریشه‌های ایثار", 23, UI.INK, true)
	project_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_modal_body.add_child(project_label)
	var motto_panel := UI.panel(_modal_body, Vector2.ZERO, Vector2(0, 94), UI.DEEP)
	motto_panel.custom_minimum_size = Vector2(0, 94)
	motto_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var motto := UI.text("«هر نهال، فرصتی برای ساختن آینده‌ای سبزتر است.»", 25, UI.CREAM, true)
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	motto_panel.add_child(motto)
	var event_label := UI.text("چهارمین رویداد تولید محتوای دیجیتال بسیج منطقه ۵ تهران بزرگ", 21, Color("7b542e"), true)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_modal_body.add_child(event_label)

# Replace gameplay with the final scorecard and routes back to the garden or title screen.
func _show_ending() -> void:
	_in_game = false
	_clear_screen()
	_background("cinematic_garden.png", true)
	_shade(screen, Color(0.03, 0.1, 0.06, 0.3))
	var card := UI.panel(screen, Vector2(640, 88), Vector2(600, 560))
	card.add_theme_stylebox_override("panel", UI.style(UI.CREAM, UI.WOOD_LIGHT, 30, 4))
	var column := UI.column(card, 10)
	var hero := UI.row(column, 12)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(UI.image(GameAtlas.icon("sprout"), Vector2(56, 56)))
	var heading := UI.column(hero, 2)
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UI.text("ریشه‌های ماندگار", 40, Color("7b542e"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.add_child(title)
	var subtitle := UI.text("پایان ماجراجویی، آغاز یک باغ ماندگار", 18, UI.GREEN, true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.add_child(subtitle)
	var message := UI.text("تبریک! شهر با همکاری شما سبزتر شد. باغ یادبود پایان راه نیست؛ آغاز مراقبت مشترک از آینده است.", 22)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(message)
	var scores := UI.row(column, 10)
	for item in [["leaf", "محیط زیست", GameState.data.scores.eco], ["heart", "مسئولیت اجتماعی", GameState.data.scores.social], ["book", "آگاهی فرهنگی", GameState.data.scores.culture]]:
		var score_card := PanelContainer.new()
		score_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		score_card.custom_minimum_size = Vector2(0, 90)
		score_card.add_theme_stylebox_override("panel", UI.style(UI.SURFACE_MUTED, UI.BORDER, 16, 2))
		var score_column := UI.column(score_card, 2)
		score_column.alignment = BoxContainer.ALIGNMENT_CENTER
		var value_row := UI.row(score_column, 6)
		value_row.alignment = BoxContainer.ALIGNMENT_CENTER
		value_row.add_child(UI.image(GameAtlas.icon(item[0]), Vector2(26, 26)))
		var value := UI.text(UI.number(int(item[2])), 29, UI.GREEN, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_row.add_child(value)
		var caption := UI.text(item[1], 16, UI.TEXT_MUTED, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_column.add_child(caption)
		scores.add_child(score_card)
	var biodiversity := PanelContainer.new()
	biodiversity.add_theme_stylebox_override("panel", UI.style(UI.DEEP, UI.ACCENT, 14, 2))
	var biodiversity_row := UI.row(biodiversity, 8)
	biodiversity_row.alignment = BoxContainer.ALIGNMENT_CENTER
	biodiversity_row.add_child(UI.image(GameAtlas.icon("leaf"), Vector2(24, 24)))
	var biodiversity_label := UI.text("درختان سالم شهر: " + UI.number(GameState.biodiversity()), 21, UI.CREAM, true)
	biodiversity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	biodiversity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	biodiversity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	biodiversity_row.add_child(biodiversity_label)
	column.add_child(biodiversity)
	var garden_button := _title_button("بازدید دوباره از باغ", _show_game, "sprout", "button_start", 64)
	garden_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(garden_button)
	var menu_button := _title_button("منوی اصلی", _show_menu, "home", "button_wood", 60)
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(menu_button)
	if not bool(GameState.settings.get("reduced_motion", false)):
		card.pivot_offset = Vector2(300, 280)
		card.modulate = Color(1, 1, 1, 0)
		card.scale = Vector2(0.97, 0.97)
		var appear := create_tween().set_parallel(true)
		appear.tween_property(card, "modulate", Color.WHITE, 0.22)
		appear.tween_property(card, "scale", Vector2.ONE, 0.22)
	AudioManager.play_music("title")

# Return the Persian location label, including the chapter-five memorial garden name.
func _zone_name(zone: String) -> String:
	if zone == "garden":
		return "باغ یادبود" if int(GameState.data.get("chapter", 1)) == 5 and String(GameState.data.get("zone", "garden")) == "garden" else "باغ نهال‌ها"
	return {"school": "مدرسه", "park": "پارک محله", "city": "شهر سبز"}.get(zone, "باغ")

# Trigger the player's reaction and announce the title of a newly unlocked achievement.
func _achievement(id: String) -> void:
	if is_instance_valid(world) and is_instance_valid(world._player):
		world._player.react()
	for achievement in CONTENT.ACHIEVEMENTS:
		if achievement.id == id:
			_toast("دستاورد تازه: " + String(achievement.title))
			break

# Queue a transient notification so simultaneous events cannot overwrite each other.
func _toast(message: String) -> void:
	if not is_instance_valid(_toast_label):
		return
	# Collapse consecutive duplicates and cap backlog so repeated actions cannot stall notifications.
	if (not _notification_queue.is_empty() and _notification_queue.back() == message) or (_toast_label.visible and _toast_label.text == message):
		return
	if _notification_queue.size() >= MAX_NOTIFICATION_QUEUE:
		_notification_queue.pop_front()
	_notification_queue.append(message)
	if _toast_timer.is_stopped():
		_next_toast()

# Display the next queued notification, animate it when allowed, and restart its timer.
func _next_toast() -> void:
	if _notification_queue.is_empty():
		_toast_label.visible = false
		return
	_toast_label.text = _notification_queue.pop_front()
	_toast_label.visible = true
	if not bool(GameState.settings.get("reduced_motion", false)):
		_toast_label.modulate = Color(1, 1, 1, 0)
		_toast_label.create_tween().tween_property(_toast_label, "modulate", Color.WHITE, 0.18)
	_toast_timer.start()

# Report whether the interactive tutorial overlay currently exists.
func _tutorial_active() -> bool:
	return is_instance_valid(_tutorial_layer)

# Initialize a guided overlay while freezing the game clock and audio but keeping world input available.
func _start_tutorial(id: String, force: bool = false, custom_steps: Array = []) -> void:
	if GameState.data.is_empty() or (not force and GameState.tutorial_seen(id)):
		return
	var steps: Array = custom_steps.duplicate(true) if not custom_steps.is_empty() else CONTENT.TUTORIALS.get(id, []).duplicate(true)
	if steps.is_empty():
		return
	_close_tutorial(false)
	_close_modal()
	_tutorial_id = id
	_tutorial_steps = steps
	_tutorial_index = 0
	_tutorial_action_done = false
	_tutorial_origin = world.player_position() if is_instance_valid(world) else Vector2.ZERO
	_tutorial_baseline = GameState.data.stats.duplicate(true)
	GameState.time_paused = true
	AudioManager.set_paused(true)
	if is_instance_valid(world):
		world.enabled = true
	_tutorial_layer = _layer()
	_tutorial_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_tutorial_layer)
	var shade := _shade(_tutorial_layer, Color(0.02, 0.06, 0.04, 0.38))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_highlight = PanelContainer.new()
	_tutorial_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_highlight.add_theme_stylebox_override("panel", UI.style(Color.TRANSPARENT, Color("ffe3a0"), 20, 4))
	_tutorial_layer.add_child(_tutorial_highlight)
	_tutorial_arrow = Line2D.new()
	_tutorial_arrow.default_color = Color("ffe3a0")
	_tutorial_arrow.width = 3.0
	_tutorial_layer.add_child(_tutorial_arrow)
	_tutorial_card = UI.panel(_tutorial_layer, Vector2(696, 280), Vector2(520, 300), UI.CREAM)
	var column := UI.column(_tutorial_card, 6)
	_tutorial_step_label = UI.text("", 16, UI.TEXT_MUTED, true)
	column.add_child(_tutorial_step_label)
	_tutorial_title_label = UI.text("", 27, UI.INK, true)
	column.add_child(_tutorial_title_label)
	_tutorial_text_label = UI.text("", 20, UI.INK)
	_tutorial_text_label.custom_minimum_size.y = 150
	column.add_child(_tutorial_text_label)
	_tutorial_continue = UI.button("ادامه", _next_tutorial, "play", "accent")
	column.add_child(_tutorial_continue)
	if not bool(GameState.settings.get("reduced_motion", false)):
		var highlight_pulse := create_tween()
		highlight_pulse.tween_property(_tutorial_highlight, "modulate", Color(1, 1, 1, 0.55), 0.65)
		highlight_pulse.tween_property(_tutorial_highlight, "modulate", Color.WHITE, 0.65)
		var arrow_pulse := create_tween()
		arrow_pulse.tween_property(_tutorial_arrow, "width", 5.0, 0.55)
		arrow_pulse.tween_property(_tutorial_arrow, "width", 2.5, 0.55)
	_update_tutorial_step()

# Populate the current tutorial card and place its highlight and arrow clear of touch controls.
func _update_tutorial_step() -> void:
	if not _tutorial_active():
		return
	var step: Dictionary = _tutorial_steps[_tutorial_index]
	_tutorial_step_label.text = "آموزش " + UI.number(_tutorial_index + 1) + " از " + UI.number(_tutorial_steps.size())
	_tutorial_title_label.text = String(step.title)
	_tutorial_text_label.text = String(step.text)
	var target := _tutorial_target_rect(String(step.get("target", "world")))
	_tutorial_highlight.position = target.position
	_tutorial_highlight.size = target.size
	_tutorial_card.position = Vector2(64.0 if target.position.x > 600.0 else 696.0, 280.0)
	var start := _tutorial_card.position + Vector2(0.0 if target.get_center().x < _tutorial_card.position.x else _tutorial_card.size.x, 92.0)
	_tutorial_arrow.points = PackedVector2Array([start, target.get_center()])
	var action := String(step.get("complete_on", ""))
	_tutorial_action_done = action.is_empty()
	_refresh_tutorial_continue()

# Keep Continue disabled until the current step's required world action is complete.
func _refresh_tutorial_continue() -> void:
	if is_instance_valid(_tutorial_continue):
		_tutorial_continue.disabled = not _tutorial_action_done

# Advance after the required action, or close the final step and mark the tutorial seen.
func _next_tutorial() -> void:
	if not _tutorial_active() or not _tutorial_action_done:
		return
	_tutorial_index += 1
	if _tutorial_index >= _tutorial_steps.size():
		_close_tutorial(true)
	else:
		_tutorial_action_done = false
		_update_tutorial_step()

# Destroy the tutorial overlay and restore time, audio, and world input to their prior modal state.
func _close_tutorial(mark_seen: bool) -> void:
	var closing_id := _tutorial_id
	if is_instance_valid(_tutorial_layer):
		_tutorial_layer.queue_free()
	_tutorial_layer = null
	_tutorial_card = null
	_tutorial_highlight = null
	_tutorial_arrow = null
	_tutorial_title_label = null
	_tutorial_text_label = null
	_tutorial_step_label = null
	_tutorial_continue = null
	_tutorial_id = ""
	_tutorial_steps = []
	GameState.time_paused = not _in_game or is_instance_valid(modal) or get_tree().paused
	AudioManager.set_paused(GameState.time_paused or _audio_paused_by_focus)
	if is_instance_valid(world):
		world.enabled = true
	if mark_seen and not closing_id.is_empty():
		GameState.mark_tutorial_seen(closing_id)

# Resolve a tutorial highlight rectangle with stable fallbacks before controls are created.
func _tutorial_target_rect(target: String) -> Rect2:
	match target:
		"joystick":
			if is_instance_valid(_joystick):
				return _joystick.get_global_rect().grow(10.0)
			return Rect2(22, 542, 170, 170)
		"guide":
			return Rect2(WORLD.NPC_POSITIONS[0] - Vector2(46, 100), Vector2(92, 132))
		"plot":
			if is_instance_valid(world):
				return Rect2(world.plot_position(0) - Vector2(58, 98), Vector2(116, 122))
			return Rect2(187, 202, 116, 122)
		"water":
			if is_instance_valid(world) and is_instance_valid(world._water_button) and world._water_button.visible:
				return world._water_button.get_global_rect().grow(10.0)
			return _tutorial_target_rect("plot")
		"compost":
			return Rect2(WORLD.COMPOST_POSITION - Vector2(54, 94), Vector2(108, 122))
		"clock":
			if is_instance_valid(_clock_label):
				return _clock_label.get_global_rect().grow(8.0)
			return Rect2(610, 12, 220, 56)
		"quest":
			if is_instance_valid(_quest_button):
				return _quest_button.get_global_rect().grow(8.0)
			return Rect2(906, 85, 350, 62)
		"map":
			if is_instance_valid(_map_button):
				return _map_button.get_global_rect().grow(8.0)
			return Rect2(1002, 12, 126, 58)
		"bottom":
			if is_instance_valid(_bottom_bar):
				return _bottom_bar.get_global_rect().grow(8.0)
	return Rect2(360, 220, 560, 300)

# Map chapters two through eight to the tutorial for each newly introduced feature.
func _chapter_tutorial_id() -> String:
	match int(GameState.data.get("chapter", 1)):
		2: return "planting"
		3: return "compost"
		4: return "school"
		5: return "memorial"
		6: return "park"
		7: return "city"
		8: return "stewardship"
	return ""

# Restrict automatic first-run guidance to an untouched chapter-one garden.
func _should_start_first_run() -> bool:
	return not GameState.tutorial_seen("first_run") and int(GameState.data.chapter) == 1 and int(GameState.data.stats.planted) == 0

# Start a chapter tutorial only when its new feature has not already been used.
func _maybe_start_chapter_tutorial() -> void:
	var id := _chapter_tutorial_id()
	if id == "compost":
		if bool(GameState.data.compost_station.built):
			return
	elif id == "memorial":
		if not GameState.data.memorials.is_empty():
			return
	elif id != "":
		return
	if not id.is_empty():
		_start_tutorial(id)

# Introduce memorial planting when chapter five opens and no memorial exists yet.
func _maybe_start_zone_tutorial(zone: String) -> void:
	if zone == "garden" and int(GameState.data.chapter) == 5 and GameState.data.memorials.is_empty():
		_start_tutorial("memorial")

# Show a one-time needs guide the first time a chapter-one species is planted.
func _start_species_tutorial(species_id: String) -> void:
	if int(GameState.data.chapter) != 1:
		return
	var id := "species_" + species_id
	if GameState.tutorial_seen(id):
		return
	var species := CONTENT.species_by_id(species_id)
	var steps := [
		{"title": "درخت تازه: " + String(species.name), "text": "این درخت به آب " + UI.number(int(species.water_need)) + "، نور " + UI.number(int(species.sun_need)) + " و " + UI.number(int(species.growth_days)) + " روز مراقبت سالم برای رشد کامل نیاز دارد.", "target": "plot"},
		{"title": "نیازهای " + String(species.name), "text": "پنل گیاه، روز کاشت، مرحلهٔ رشد، سلامت، رطوبت و وضعیت کمپوست را نشان می‌دهد. هر صبح این وضعیت بررسی می‌شود.", "target": "water"},
	]
	_start_tutorial(id, false, steps)

# Confirm exit and autosave progress before shutting down audio and the application.
func _request_quit() -> void:
	_open_modal("خروج از بازی", Vector2(600, 300))
	_modal_body.add_child(UI.text("پیشرفت ذخیره میشود. از بازی خارج میشوی؟", 25))
	_modal_footer.add_child(UI.button("خروج", func() -> void:
		if not _save_progress_for_exit():
			_toast(GameState.save_error)
			return
		AudioManager.shutdown()
		get_tree().quit()
	, "close", "accent"))

# Route Back through modal close, tutorial quit confirmation, gameplay pause, or title quit.
func _handle_back_action() -> void:
	if is_instance_valid(modal):
		_close_modal()
	elif _tutorial_active():
		_request_quit()
	elif _in_game:
		_pause()
	else:
		_request_quit()

# Map Escape to the same Back behavior used by Android and consume the key event.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_handle_back_action()
		get_viewport().set_input_as_handled()

# Handle close, Back, pause, and focus lifecycle events with autosave and safe audio restoration.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_action()
		get_viewport().set_input_as_handled()
	elif what == NOTIFICATION_APPLICATION_PAUSED and _in_game:
		_audio_paused_by_focus = false
		_remember_position()
		GameState.save_game()
		# Preserve an open modal or tutorial instead of replacing it with Pause on backgrounding.
		if not is_instance_valid(modal) and not _tutorial_active():
			_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _audio_paused_by_focus:
			_audio_was_paused_before_focus = AudioManager.is_paused()
			_audio_paused_by_focus = true
		AudioManager.set_paused(true)
		if is_instance_valid(_joystick):
			_joystick.reset()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _audio_paused_by_focus:
			AudioManager.set_paused(_audio_was_paused_before_focus)
			_audio_paused_by_focus = false
