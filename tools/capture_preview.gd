# Captures deterministic gameplay and asset-sheet previews for runtime verification.

extends SceneTree

# Keep generated previews in a git-ignored directory.
const OUTPUT := "res://tools/ignored"
# Use the game's chapter data to drive the ordered scene sweep.
const CONTENT = preload("res://scripts/data/game_content.gd")

# Defer the capture run until the scene tree is ready.
func _initialize() -> void:
	call_deferred("_run")

# Walk a fixed gameplay sequence so every preview captures a known state.
func _run() -> void:
	var game_state = root.get_node("GameState")
	# Isolate preview saves from normal player data.
	game_state.save_path = "user://roots-preview-save.json"
	game_state.backup_path = "user://roots-preview-backup.json"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await _assert_music("title")
	await _capture("runtime-menu.png")
	main._about()
	await process_frame
	await process_frame
	await _capture("runtime-about.png")
	main._close_modal()
	main._new_game()
	await process_frame
	await process_frame
	await _assert_music("garden")
	await _capture("runtime-intro.png")
	# Bound scripted intro advancement so a stalled modal cannot hang capture.
	var intro_guard := 0
	while is_instance_valid(main.modal) and intro_guard < 12:
		main._next_intro()
		intro_guard += 1
		await process_frame
	await _capture("runtime-tutorial.png")
	# Bound tutorial advancement for the same hang-free capture guarantee.
	var tutorial_guard := 0
	while main._tutorial_active() and tutorial_guard < 12:
		main._tutorial_action_done = true
		main._next_tutorial()
		tutorial_guard += 1
		await process_frame
	main.world.set_player_position(Vector2(320, 300))
	await physics_frame
	await _capture("runtime-garden.png")
	main._settings()
	await create_timer(0.25).timeout
	await _capture("runtime-settings.png")
	main._close_modal()
	main._controls()
	await create_timer(0.25).timeout
	await _capture("runtime-controls.png")
	main._close_modal()
	main._toast_label.visible = false
	main._toast_timer.stop()
	main._notification_queue.clear()
	main._npc(0)
	await process_frame
	await _capture("runtime-npc.png")
	main._open_story(0, int(game_state.data.chapter))
	await process_frame
	await process_frame
	await _capture("runtime-npc-story.png")
	main._close_modal()
	main._open_story(2, int(game_state.data.chapter))
	await process_frame
	await process_frame
	await _capture("runtime-npc-raha-story.png")
	main._close_modal()
	# Force the rainy night state and verify its music before capture.
	game_state.data.time_of_day = 14.0
	main._refresh_clock()
	main.world._on_time_changed()
	await physics_frame
	await _assert_music("rain")
	await _capture("runtime-night.png")
	game_state.data.time_of_day = 2.0
	main.world._on_time_changed()
	# Capture every chapter at midnight with all planting plots matured.
	for chapter in CONTENT.CHAPTERS:
		var chapter_id := int(chapter.id)
		game_state.data.chapter = chapter_id
		game_state.data.zone = String(chapter.location)
		game_state.data.time_of_day = 1.0
		main._refresh_clock()
		main.world.reload_zone()
		main._refresh_hud()
		_mature_current_plots(game_state, main.world)
		main.world.set_player_position(Vector2(650, 470))
		await physics_frame
		await _capture("runtime-chapter-%02d.png" % chapter_id)
	game_state.new_game()
	main.world.reload_zone()
	main.world.set_player_position(Vector2(320, 300))
	await physics_frame
	main._plot_menu(0)
	await process_frame
	await _capture("runtime-plot.png")
	main._close_modal()
	game_state.build_compost_station()
	main._toast_label.visible = false
	main._toast_timer.stop()
	main._notification_queue.clear()
	main._compost()
	await process_frame
	await _capture("runtime-compost.png")
	main._close_modal()
	game_state.prepare_plot(0)
	main._plot_menu(0)
	await process_frame
	await process_frame
	await _capture("runtime-species.png")
	main._close_modal()
	game_state.plant_tree(0, "cypress")
	main._write_memorial("garden", 0)
	await process_frame
	await process_frame
	await _capture("runtime-memorial-form.png")
	main._close_modal()
	game_state.save_memorial("garden", 0, "سرو امید", "این نهال برای آیندهٔ محله و یاد همکاری است.")
	main._memorials()
	await process_frame
	await _capture("runtime-memorial.png")
	main._close_modal()
	_mature_current_plots(game_state, main.world)
	game_state.plots("garden")[0].moisture = 20
	main.world.refresh()
	main.world.set_player_position(main.world.plot_position(0) + Vector2(50, 30))
	await physics_frame
	await _capture("runtime-plants.png")
	main._plot_menu(0)
	await process_frame
	await _capture("runtime-plant-info.png")
	main._close_modal()
	main.world.play_action("water")
	await physics_frame
	await _capture("runtime-action-water.png")
	main.world.play_action("plant")
	await physics_frame
	await _capture("runtime-action-plant.png")
	game_state.data.chapter = 5
	main.world.reload_zone()
	main.world.set_player_position(Vector2(650, 500))
	await physics_frame
	await _capture("runtime-memorial-world.png")
	game_state.data.chapter = 1
	main.world.reload_zone()
	main._quiz()
	await process_frame
	await _capture("runtime-quiz.png")
	main._close_modal()
	game_state.data.finished = true
	main._toast_label.visible = false
	main._toast_timer.stop()
	main._notification_queue.clear()
	main._show_ending()
	await process_frame
	await _capture("runtime-ending.png")
	# Release gameplay nodes before rendering standalone asset sheets.
	main.free()
	await _capture_asset_sheet("PLANT ATLAS - SIX SPECIES x SIX STAGES", "runtime-plant-atlas.png", [
		{"path": "res://assets/art/plants.svg", "position": Vector2(256, 96), "size": Vector2(768, 576)},
	])
	await _capture_asset_sheet("PLAYER ATLAS - WALK, WATER AND PLANT", "runtime-player-atlas.png", [
		{"path": "res://assets/art/player.svg", "position": Vector2(448, 90), "size": Vector2(384, 576)},
	])
	await _capture_asset_sheet("GAME ICON ATLAS - 32 PIXEL CELLS", "runtime-icon-atlas.png", [
		{"path": "res://assets/art/icons.svg", "position": Vector2(128, 220), "size": Vector2(1024, 256)},
	])
	await _capture_asset_sheet("LAUNCHER ICON VARIANTS", "runtime-icon-variants.png", [
		{"path": "res://assets/art/android_icon.svg", "position": Vector2(64, 190), "size": Vector2(240, 240), "label": "Legacy"},
		{"path": "res://assets/art/android_icon_background.svg", "position": Vector2(368, 190), "size": Vector2(240, 240), "label": "Background"},
		{"path": "res://assets/art/android_icon_foreground.svg", "position": Vector2(672, 190), "size": Vector2(240, 240), "label": "Foreground"},
		{"path": "res://assets/art/android_icon_monochrome.svg", "position": Vector2(976, 190), "size": Vector2(240, 240), "label": "Monochrome"},
	])
	await _capture_button_sheet()
	await _capture_hud_sheet()
	# Stop audio cleanly before exiting so preview runs do not linger.
	root.get_node("AudioManager").shutdown()
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	quit()

# Populate all six plots with mature species for repeatable chapter previews.
func _mature_current_plots(game_state, world) -> void:
	var species_ids := ["cypress", "native_oak", "pomegranate", "arghavan", "olive", "willow"]
	for i in range(species_ids.size()):
		var plot: Dictionary = game_state.plots()[i]
		plot.prepared = true
		plot.species = species_ids[i]
		plot.stage = 5
		plot.moisture = 72
		plot.soil = 82
		plot.health = 100
		plot.dead = false
		plot.healthy_days = int(plot.stage) * 2
	world.refresh()

# Validate that the expected track is an active looping MP3.
func _assert_music(expected: String) -> void:
	await create_timer(0.2).timeout
	var manager := root.get_node("AudioManager") as Node
	var players: Array = manager._music_players
	var valid: bool = int(manager._active_music) >= 0
	var actual := String(manager._track)
	var playing := false
	var looped := false
	if valid:
		var player := players[int(manager._active_music)] as AudioStreamPlayer
		playing = player.playing
		valid = playing and player.stream is AudioStreamMP3
		if valid:
			var stream := player.stream as AudioStreamMP3
			looped = stream.loop
			valid = looped and actual == expected
	if not valid:
		push_error("Runtime music validation failed: expected %s, actual %s, playing %s, looped %s" % [expected, actual, playing, looped])

# Render a titled, nearest-filtered sheet of supplied asset entries.
func _capture_asset_sheet(title: String, file_name: String, entries: Array) -> void:
	var layer := Control.new()
	layer.size = Vector2(1280, 720)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("f4e4bd")
	background.size = Vector2(1280, 720)
	layer.add_child(background)
	var heading := Label.new()
	heading.text = title
	heading.position = Vector2(40, 28)
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("20352e"))
	layer.add_child(heading)
	for entry in entries:
		var rect := TextureRect.new()
		rect.texture = load(String(entry.path))
		rect.position = entry.position
		rect.size = entry.size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.add_child(rect)
		if entry.has("label"):
			var caption := Label.new()
			caption.text = String(entry.label)
			caption.text_direction = Control.TEXT_DIRECTION_RTL
			caption.position = entry.position + Vector2(0, 250)
			caption.size = Vector2(240, 32)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			caption.add_theme_font_size_override("font_size", 22)
			caption.add_theme_color_override("font_color", Color("20352e"))
			layer.add_child(caption)
	await _capture(file_name)
	layer.queue_free()
	await process_frame

# Capture every title-button state in a stable grid.
func _capture_button_sheet() -> void:
	var layer := Control.new()
	layer.size = Vector2(1280, 720)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("173f32")
	background.size = Vector2(1280, 720)
	layer.add_child(background)
	var heading := Label.new()
	heading.text = "TITLE BUTTON IMAGES - NORMAL / HOVER / PRESSED"
	heading.position = Vector2(40, 28)
	heading.size = Vector2(1200, 44)
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("f4e4bd"))
	layer.add_child(heading)
	var button_names := ["button_start", "button_wood", "button_wood_dark", "button_settings", "button_about"]
	var states := ["", "_hover", "_pressed"]
	for row in range(states.size()):
		for column in range(button_names.size()):
			var rect := TextureRect.new()
			rect.texture = load("res://assets/art/" + button_names[column] + states[row] + ".svg")
			rect.position = Vector2(40 + column * 246, 116 + row * 176)
			rect.size = Vector2(216, 86)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			layer.add_child(rect)
			var caption := Label.new()
			caption.text = button_names[column] + states[row]
			caption.position = rect.position + Vector2(0, 92)
			caption.size = Vector2(216, 30)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_size_override("font_size", 15)
			caption.add_theme_color_override("font_color", Color("d7ad62"))
			layer.add_child(caption)
	await _capture("runtime-button-images.png")
	layer.queue_free()
	await process_frame

# Capture HUD button states plus the shared panel and chip assets.
func _capture_hud_sheet() -> void:
	var layer := Control.new()
	layer.size = Vector2(1280, 720)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("173f32")
	background.size = Vector2(1280, 720)
	layer.add_child(background)
	var heading := Label.new()
	heading.text = "IN-GAME BUTTONS AND HUD - NORMAL / HOVER / PRESSED"
	heading.position = Vector2(40, 28)
	heading.size = Vector2(1200, 44)
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("f4e4bd"))
	layer.add_child(heading)
	var button_names := ["button_hud", "button_quest", "button_compact"]
	var states := ["", "_hover", "_pressed"]
	for row in range(states.size()):
		for column in range(button_names.size()):
			var rect := TextureRect.new()
			rect.texture = load("res://assets/art/" + button_names[column] + states[row] + ".svg")
			rect.position = Vector2(40 + column * 250, 112 + row * 160)
			rect.size = Vector2(224, 96)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			layer.add_child(rect)
			var caption := Label.new()
			caption.text = button_names[column] + states[row]
			caption.position = rect.position + Vector2(0, 102)
			caption.size = Vector2(224, 30)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_size_override("font_size", 15)
			caption.add_theme_color_override("font_color", Color("d7ad62"))
			layer.add_child(caption)
	var panel := TextureRect.new()
	panel.texture = load("res://assets/art/hud_panel.svg")
	panel.position = Vector2(820, 130)
	panel.size = Vector2(400, 64)
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(panel)
	var panel_caption := Label.new()
	panel_caption.text = "hud_panel.svg"
	panel_caption.position = Vector2(820, 202)
	panel_caption.size = Vector2(400, 30)
	panel_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_caption.add_theme_font_size_override("font_size", 18)
	panel_caption.add_theme_color_override("font_color", Color("d7ad62"))
	layer.add_child(panel_caption)
	for index in range(8):
		var chip := TextureRect.new()
		chip.texture = load("res://assets/art/hud_chip.svg")
		chip.position = Vector2(820 + (index % 4) * 100, 270 + (index / 4) * 82)
		chip.size = Vector2(92, 44)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_SCALE
		chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.add_child(chip)
	var chip_caption := Label.new()
	chip_caption.text = "hud_chip.svg"
	chip_caption.position = Vector2(820, 440)
	chip_caption.size = Vector2(400, 30)
	chip_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_caption.add_theme_font_size_override("font_size", 18)
	chip_caption.add_theme_color_override("font_color", Color("d7ad62"))
	layer.add_child(chip_caption)
	await _capture("runtime-hud-images.png")
	layer.queue_free()
	await process_frame

# Wait for rendering to settle, then save the viewport as a PNG.
func _capture(file_name: String) -> void:
	await create_timer(0.25).timeout
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var result := image.save_png(OUTPUT + "/" + file_name)
	if result != OK:
		push_error("Could not save " + file_name)
