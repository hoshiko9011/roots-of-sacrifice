# Exercises progression, persistence, assets, and live UI flows through gameplay APIs.
extends Node

const STATE_SCRIPT = preload("res://scripts/game_state.gd")
const CONTENT = preload("res://scripts/data/game_content.gd")
const SAVE_FILE := "user://roots-test-save.json"
const BACKUP_FILE := "user://roots-test-backup.json"

var state
var failures: Array[String] = []
var checks := 0

# Defer execution until the scene tree and autoloads are ready.
func _ready() -> void:
	call_deferred("_run")

# Run every regression group, clean isolated saves, and fail the process on any error.
func _run() -> void:
	# Isolated save paths keep tests from overwriting a player's normal saves.
	for path in [SAVE_FILE, BACKUP_FILE, SAVE_FILE + ".tmp", BACKUP_FILE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	state = STATE_SCRIPT.new()
	state.save_path = SAVE_FILE
	state.backup_path = BACKUP_FILE
	add_child(state)
	await get_tree().process_frame
	state.new_game()
	_check(not state.data.is_empty() and int(state.data.chapter) == 1, "new game creates a valid initial state")
	_check(state.data.zones.size() == 4, "four locations are initialized")
	_check(state.plots("garden").size() == 6, "each location has six garden plots")
	for chapter_id in range(1, 9):
		_check(int(state.data.chapter) == chapter_id, "chapter %d is active" % chapter_id)
		_complete_chapter(chapter_id)
		_check(state.chapter_ready(), "chapter %d can be completed through public gameplay APIs" % chapter_id)
		_check(state.complete_chapter(), "chapter %d completion succeeds once" % chapter_id)
		_check(not state.complete_chapter(), "chapter %d cannot reward completion twice" % chapter_id)
		if chapter_id < 8:
			state.next_chapter()
	_check(bool(state.data.finished), "finishing chapter eight reaches the ending")
	_check(state.data.completed.size() == 8, "all eight chapters are recorded")
	_test_save_and_backup()
	_test_backup_failure()
	_test_save_availability()
	_test_settings_persistence()
	_test_validation()
	_test_time_and_care()
	_test_audit_regressions()
	_test_npc_stories()
	_test_mission_regressions()
	_test_polished_assets()
	_test_runtime_images()
	# Let live UI checks finish before their temporary files are removed.
	await _test_ui_smoke()
	for path in [SAVE_FILE, BACKUP_FILE, SAVE_FILE + ".tmp", BACKUP_FILE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("ROOTS_TESTS: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		push_error("ROOTS_TEST_FAILURE: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

# Drive chapter tasks through gameplay APIs instead of editing mission progress.
func _complete_chapter(chapter_id: int) -> void:
	var chapter: Dictionary = state.current_chapter()
	state.set_zone(String(chapter.location))
	for task_value in chapter.tasks:
		var task: Dictionary = task_value
		var task_id := String(task.id)
		var remaining: int = int(task.target) - state.task_count(task_id)
		match task_id:
			"clean_trash", "collect_recycle":
				for index in range(8):
					if state.task_count(task_id) >= int(task.target):
						break
					state.collect_trash(index)
			"talk_guide":
				for index in range(4):
					if state.task_count(task_id) >= int(task.target):
						break
					state.talk_npc(index)
			"prepare_soil":
				for index in range(6):
					if state.task_count(task_id) >= int(task.target):
						break
					var plot: Dictionary = state.plots()[index]
					if not bool(plot.prepared):
						state.prepare_plot(index)
					elif not String(plot.species).is_empty() and not bool(plot.get("dead", false)) and int(state.data.resources.compost) > 0:
						state.apply_compost(index)
			"plant_tree", "plant_school":
				_plant_needed(remaining, false)
			"plant_native":
				_plant_needed(remaining, true)
			"water_tree":
				_water_needed(remaining)
			"answer_quiz", "final_quiz":
				for index in state.quiz_indices():
					var question: Dictionary = CONTENT.QUESTIONS[index]
					state.answer_question(index, int(question.correct))
			"read_story":
				for index in range(remaining):
					state.read_story(index)
			"write_memorial", "add_memorial":
				_write_memorial()
			"help_people":
				for index in range(remaining):
					state.help_npc(index)
			"mature_tree":
				_mature_needed(remaining)
			"celebrate_city":
				state.celebrate()
		_check(state.task_count(task_id) >= int(task.target), "chapter %d task %s" % [chapter_id, task_id])
	if chapter_id == 1:
		var before: int = state.task_count("talk_guide")
		state.talk_npc(0)
		_check(state.task_count("talk_guide") == before, "duplicate dialogue does not advance a task")

# Plant only the remaining task count, replenishing seeds through guide dialogue.
func _plant_needed(amount: int, native_only: bool) -> void:
	var native := ["cypress", "native_oak", "pomegranate", "arghavan", "olive", "willow"]
	var all := ["cypress", "native_oak", "pomegranate", "arghavan", "olive", "willow"]
	var planted := 0
	for index in range(6):
		if planted >= amount:
			return
		var plot: Dictionary = state.plots()[index]
		if not bool(plot.prepared):
			state.prepare_plot(index)
		if String(plot.species).is_empty():
			var choices: Array = native if native_only else all
			var species: String = choices[planted % choices.size()]
			if int(state.data.resources.seeds) < 1:
				state.talk_npc(0)
			if state.plant_tree(index, species):
				planted += 1
	if planted < amount:
		state.refill_water()
		state.advance_day()

# Alternate watering and day advances so plants survive until the task is met.
func _water_needed(amount: int) -> void:
	var guard := 0
	while amount > 0 and guard < 20:
		guard += 1
		var changed := false
		for index in range(6):
			if amount <= 0:
				break
			var plot: Dictionary = state.plots()[index]
			if not String(plot.species).is_empty() and state.water_plot(index):
				amount -= 1
				changed = true
		if amount > 0:
			state.refill_water()
			if not changed:
				state.advance_day()
			elif guard % 3 == 0:
				state.advance_day()

# Reuse an unnamed planted plot so the memorial task has a valid target.
func _write_memorial() -> void:
	for index in range(6):
		var plot: Dictionary = state.plots()[index]
		if not String(plot.species).is_empty() and String(plot.name).is_empty():
			_check(state.save_memorial(String(state.data.zone), index, "نهال امید", "مراقبت مشترک از این نهال ادامه پیدا می‌کند."), "memorial writing succeeds")
			return
	_check(false, "an unlabelled planted plot is available for a memorial")

# Prove maturity is reachable through bounded daily care without debug edits.
func _mature_needed(amount: int) -> void:
	var guard := 0
	while amount > 0 and guard < 30:
		guard += 1
		for index in range(6):
			var plot: Dictionary = state.plots()[index]
			if not String(plot.species).is_empty():
				state.water_plot(index)
				if int(plot.soil) < 50 and int(state.data.resources.compost) > 0 and int(plot.compost_day) != int(state.data.day):
					state.apply_compost(index)
		state.refill_water()
		state.advance_day()
		amount = 2 - state.task_count("mature_tree")
	_check(guard < 30, "mature trees are reachable without debug state edits")

# Corrupt the primary save to verify fallback uses the previous valid backup.
func _test_save_and_backup() -> void:
	_check(state.save_game(), "manual save writes a valid envelope")
	var saved_day := int(state.data.day)
	state.data.day += 50
	_check(state.load_game(), "valid save loads")
	_check(int(state.data.day) == saved_day, "load restores the saved day")
	state.data.day += 1
	_check(state.save_game(), "second save creates a backup candidate")
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	_check(state.load_game(), "corrupt primary save falls back to backup")
	_check(int(state.data.day) == saved_day, "backup restores the last valid progression")
	_check(state._read_save(SAVE_FILE).is_empty(), "corrupt save is rejected")

# Force backup creation to fail and ensure the previous primary save is untouched.
func _test_backup_failure() -> void:
	var save_path := "user://roots-backup-failure-save.json"
	var backup_path := "user://roots-missing-backup-dir/backup.json"
	var backup_state = STATE_SCRIPT.new()
	backup_state.save_path = save_path
	backup_state.backup_path = backup_path
	add_child(backup_state)
	backup_state.new_game()
	var original := FileAccess.get_file_as_string(save_path)
	backup_state.data.day += 1
	Engine.set_print_error_messages(false)
	var saved: bool = backup_state.save_game()
	Engine.set_print_error_messages(true)
	_check(not saved and FileAccess.get_file_as_string(save_path) == original and not backup_state.save_error.is_empty() and not FileAccess.file_exists(backup_path + ".tmp"), "failed backup creation preserves the previous primary save and leaves no partial backup")
	for path in [save_path, save_path + ".tmp", backup_path, backup_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	backup_state.free()

# Confirm corrupt saves disable Continue instead of starting an empty game.
func _test_save_availability() -> void:
	var save_path := "user://roots-invalid-save.json"
	var backup_path := "user://roots-invalid-backup.json"
	for path in [save_path, backup_path]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("corrupt")
		file.close()
	var invalid_state = STATE_SCRIPT.new()
	invalid_state.save_path = save_path
	invalid_state.backup_path = backup_path
	add_child(invalid_state)
	_check(not invalid_state.has_valid_save(), "continue availability rejects two corrupt save files")
	_check(not invalid_state.load_game() and not invalid_state.save_available, "failed load disables continue until a valid save exists")
	invalid_state.free()
	for path in [save_path, backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

# Verify valid settings persist while unknown keys and invalid types are rejected.
func _test_settings_persistence() -> void:
	var settings_path := "user://roots-settings-test.cfg"
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)
	var writer = STATE_SCRIPT.new()
	writer.settings_path = settings_path
	add_child(writer)
	_check(writer.set_setting("music", 0.3) and writer.set_setting("sound", 0.4), "settings API stores valid volume levels")
	_check(writer.set_setting("day_length", 360.0) and writer.current_day_seconds() == 360.0, "settings API stores the selected day length")
	_check(writer.set_setting("touch", false) and writer.set_setting("reduced_motion", true), "settings API stores accessibility toggles")
	_check(not writer.set_setting("unknown", 1.0) and not writer.set_setting("music", "loud") and not writer.set_setting("touch", 1) and not writer.set_setting("day_length", NAN), "settings API rejects unknown keys and invalid value types")
	var reader = STATE_SCRIPT.new()
	reader.settings_path = settings_path
	add_child(reader)
	_check(is_equal_approx(float(reader.settings.music), 0.3) and is_equal_approx(float(reader.settings.sound), 0.4) and reader.current_day_seconds() == 360.0 and not bool(reader.settings.touch) and bool(reader.settings.reduced_motion), "saved settings restore after reload")
	reader.reset_settings()
	_check(reader.settings == reader.DEFAULT_SETTINGS, "settings reset restores every default value")
	var reloaded = STATE_SCRIPT.new()
	reloaded.settings_path = settings_path
	add_child(reloaded)
	_check(reloaded.settings == reloaded.DEFAULT_SETTINGS, "reset defaults persist after another reload")
	reloaded.free()
	reader.free()
	writer.free()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)

# Guard memorial identity, story credit, and saved mission progress against regression.
func _test_mission_regressions() -> void:
	var save_path := "user://roots-mission-regression-save.json"
	var backup_path := "user://roots-mission-regression-backup.json"
	var mission_state = STATE_SCRIPT.new()
	mission_state.save_path = save_path
	mission_state.backup_path = backup_path
	add_child(mission_state)
	mission_state.new_game()
	_check(mission_state.prepare_plot(0) and mission_state.plant_tree(0, "cypress"), "mission regression test plants a memorial tree")
	_check(mission_state.save_memorial("garden", 0, "سرو امید", "پیامی برای آیندهٔ محله."), "mission regression test creates an early memorial")
	# Replanting must preserve the plaque tied to this zone and plot index.
	mission_state.plots("garden")[0].dead = true
	mission_state.clear_dead_plot(0)
	mission_state.plant_tree(0, "cypress")
	_check(mission_state.has_memorial("garden", 0) and String(mission_state.plots("garden")[0].name) == "سرو امید", "clearing and replanting a memorial bed preserves its plaque record and visible name")
	_check(not mission_state.save_memorial("garden", 0, "سرو تازه", "پیام تازه"), "a replanted memorial bed cannot silently submit a duplicate plaque")
	# Existing memorials must count on entry instead of causing a chapter deadlock.
	mission_state.data.chapter = 4
	mission_state.next_chapter()
	_check(int(mission_state.data.chapter) == 5 and mission_state.task_count("write_memorial") >= 1 and mission_state.task_count("add_memorial") >= 1, "existing memorials prevent chapter-five mission deadlock")
	# Global reading history is independent of the active chapter's task credit.
	_check(mission_state.read_npc_story(0, 4) and mission_state.npc_story_count() == 1, "out-of-chapter stories still record global reading progress")
	_check(mission_state.task_count("read_story") == 0, "out-of-chapter stories do not advance the active reading mission")
	_check(mission_state.read_npc_story(0, 5) and mission_state.task_count("read_story") == 1, "current-chapter stories advance the active reading mission")
	mission_state.read_npc_story(1, 5)
	mission_state.read_npc_story(2, 5)
	_check(mission_state.task_count("read_story") == 3, "three distinct chapter-five stories complete the reading mission")
	# Chapter re-entry repairs task credit from previously recorded story history.
	mission_state.data.chapter = 4
	mission_state.data.progress = {}
	mission_state.next_chapter()
	_check(int(mission_state.data.chapter) == 5 and mission_state.task_count("read_story") == 3, "entering a chapter credits its previously read stories")
	mission_state.data.progress = {}
	_check(not mission_state.read_npc_story(0, 5) and mission_state.task_count("read_story") == 3, "replaying an already-read story repairs missing mission progress")
	# Loading must repair missing task credit just like live chapter entry.
	mission_state.data.progress = {}
	mission_state.save_game()
	mission_state.data = {}
	_check(mission_state.load_game() and mission_state.task_count("read_story") == 3, "loading an existing save repairs missing reading mission progress")
	for path in [save_path, backup_path, save_path + ".tmp", backup_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	mission_state.free()

# Reject invalid saves and lock quiz and species content to their intended sets.
func _test_validation() -> void:
	var invalid: Dictionary = state.data.duplicate(true)
	invalid.zone = "not-a-zone"
	_check(not state._valid_save(invalid), "unknown locations are rejected")
	invalid = state.data.duplicate(true)
	invalid.zones.garden.plots[0].stage = 99
	_check(not state._valid_save(invalid), "out-of-range growth stages are rejected")
	_check(CONTENT.QUESTIONS.size() == 17, "seventeen educational questions are available")
	var final_indices: Array[int] = state.quiz_indices()
	var final_questions_ready: bool = final_indices.size() == 3
	for index in final_indices:
		final_questions_ready = final_questions_ready and int(CONTENT.QUESTIONS[index].chapter) == 8
	_check(final_questions_ready, "chapter eight uses three questions from its own chapter")
	invalid = state.data.duplicate(true)
	invalid.player = ["invalid", 460.0]
	_check(not state._valid_save(invalid), "non-numeric player coordinates are rejected")
	invalid = state.data.duplicate(true)
	invalid.memorials = [{"key": "garden:0", "zone": "invalid", "plot": 0, "name": "نهال", "message": "پیام", "day": 1, "species": "cypress"}]
	_check(not state._valid_save(invalid), "invalid memorial locations are rejected")
	invalid.memorials[0].zone = "garden"
	invalid.memorials[0].key = "garden:9"
	invalid.memorials[0].plot = 9
	_check(not state._valid_save(invalid), "out-of-range memorial plot indexes are rejected")
	invalid.memorials[0].key = "garden:0"
	invalid.memorials[0].plot = 0
	invalid.memorials[0].species = "invalid"
	_check(not state._valid_save(invalid), "invalid memorial species are rejected")
	var tree_ids := ["cypress", "native_oak", "pomegranate", "arghavan", "olive", "willow"]
	var native_trees_ready := CONTENT.SPECIES.size() == 6
	for species in CONTENT.SPECIES:
		native_trees_ready = native_trees_ready and tree_ids.has(String(species.id))
	_check(native_trees_ready, "exactly six native Iranian tree species are available and flower species are removed")

# Cover daily growth, neglect, compost timing, and older save migrations.
func _test_time_and_care() -> void:
	var care_save := "user://roots-care-test-save.json"
	var care_backup := "user://roots-care-test-backup.json"
	var care = STATE_SCRIPT.new()
	care.save_path = care_save
	care.backup_path = care_backup
	add_child(care)
	care.new_game()
	care.settings.day_length = 240.0
	# Pausing time keeps the daily care assertions deterministic.
	care.time_paused = true
	_check(is_equal_approx(care.current_day_seconds(), 240.0), "day cycle defaults to four minutes")
	_check(care.prepare_plot(0), "care test prepares a plot")
	_check(care.plant_tree(0, "cypress"), "care test plants a cypress")
	var healthy: Dictionary = care.plots("garden")[0]
	healthy.sun = 3
	_check(care.water_plot(0), "care test waters the new plant")
	care.advance_day()
	_check(int(healthy.healthy_days) == 1 and int(healthy.health) >= 100, "correct daily care preserves health and records a growth day")
	healthy.health = 50
	care.water_plot(0)
	care.advance_day()
	_check(int(healthy.health) > 50, "timely care recovers plant health")
	_check(care.prepare_plot(1), "care test prepares a neglected plot")
	_check(care.plant_tree(1, "arghavan"), "care test plants a second native tree")
	var neglected: Dictionary = care.plots("garden")[1]
	neglected.moisture = 0
	neglected.health = 10
	neglected.neglect_days = 2
	care.data.day = 7
	care.advance_day()
	_check(bool(neglected.dead) and int(neglected.health) == 0, "continued neglect kills a plant")
	_check(care.clear_dead_plot(1), "dead plant can be cleared for replanting")
	_check(care.build_compost_station(), "compost station construction starts")
	_check(not bool(care.data.compost_station.construction_done), "compost station is not ready immediately")
	care.advance_day()
	_check(bool(care.data.compost_station.construction_done), "compost station finishes after one in-game day")
	_check(care.start_compost_batch(), "compost batch starts")
	care.advance_day()
	_check(int(care.data.compost_station.ready_compost) == 2, "finished compost waits at the station for collection")
	_check(care.collect_compost() == 2, "player collects ready compost")
	_check(int(care.data.compost_station.ready_compost) == 0, "collected compost is removed from station storage")
	var soil_before := int(healthy.soil)
	_check(care.apply_compost(0), "compost can be applied to a living plant")
	_check(int(healthy.soil) > soil_before, "compost improves soil quality")
	care.data.time_of_day = 14.0
	_check(care.is_night() and care.night_amount() > 0.9, "night state is visually distinct")
	care.data.time_of_day = 2.0
	_check(not care.is_night() and care.night_amount() == 0.0, "day state is restored after dawn")
	var day_before := int(care.data.day)
	care.data.time_of_day = 23.99
	# Crossing midnight must advance the day without a player button.
	care.time_paused = false
	care._process(0.2)
	_check(int(care.data.day) == day_before + 1, "automatic clock advances the day without a player button")
	var legacy: Dictionary = care.data.duplicate(true)
	legacy.version = 1
	legacy.erase("time_of_day")
	legacy.erase("tutorials")
	legacy.erase("compost_station")
	for zone in care.LOCATIONS:
		for plot in legacy.zones[zone].plots:
			plot.erase("healthy_days")
			plot.erase("dead")
			plot.erase("neglect_days")
	# Build a valid version-one envelope so migration runs through normal validation.
	var payload := JSON.stringify(legacy)
	var envelope := JSON.stringify({"payload": payload, "checksum": payload.sha256_text()})
	var file := FileAccess.open(care_save, FileAccess.WRITE)
	file.store_string(envelope)
	file.close()
	var migrated: Dictionary = care._read_save(care_save)
	_check(not migrated.is_empty() and int(migrated.version) == 3 and migrated.has("compost_station"), "legacy saves migrate to the timed native-tree care system")
	var old_species: Dictionary = care.data.duplicate(true)
	old_species.version = 2
	old_species.chapter = 2
	old_species.tutorials = []
	old_species.zones.garden.plots[0].species = "rose"
	old_species.zones.garden.plots[1].species = "lavender"
	old_species.memorials = [{"key": "garden:0", "zone": "garden", "plot": 0, "name": "نهال", "message": "روایت فرضی", "day": 1, "species": "rose"}]
	var tree_migrated: Dictionary = care._migrate_state(old_species)
	_check(String(tree_migrated.zones.garden.plots[0].species) == "arghavan" and String(tree_migrated.zones.garden.plots[1].species) == "olive" and String(tree_migrated.memorials[0].species) == "arghavan", "version-two saves replace removed flower species with native trees")
	# Species migration must not restart tutorial progress from older saves.
	_check(tree_migrated.tutorials.has("first_run"), "progressed saves do not restart the first-run planting tutorial")
	var malformed: Dictionary = care.data.duplicate(true)
	malformed.version = 1
	malformed.stats = {}
	malformed.zones = {}
	# Malformed legacy data must be rejected without crashing migration.
	var malformed_payload := JSON.stringify(malformed)
	var malformed_envelope := JSON.stringify({"payload": malformed_payload, "checksum": malformed_payload.sha256_text()})
	file = FileAccess.open(care_save, FileAccess.WRITE)
	file.store_string(malformed_envelope)
	file.close()
	_check(care._read_save(care_save).is_empty(), "malformed legacy saves are rejected without migration crashes")
	for path in [care_save, care_backup, care_save + ".tmp", care_backup + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	care.free()

# Cover audit regressions for save safety, clock persistence, compost capacity, and build gating.
func _test_audit_regressions() -> void:
	var audit_save := "user://roots-audit-save.json"
	var audit_backup := "user://roots-audit-backup.json"
	for path in [audit_save, audit_backup, audit_save + ".tmp", audit_backup + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var audit = STATE_SCRIPT.new()
	audit.save_path = audit_save
	audit.backup_path = audit_backup
	add_child(audit)
	_check(audit.new_game(), "audit state starts with a valid save")
	# Clock-only changes must not use the ten-second gameplay autosave cadence.
	audit.time_paused = false
	audit.data.time_of_day = 1.0
	audit._dirty = false
	audit._clock_dirty = false
	audit._clock_save_elapsed = 0.0
	var before_clock_save := FileAccess.get_file_as_string(audit_save)
	audit._process(0.1)
	audit._autosave()
	_check(audit._clock_dirty and not audit._dirty and FileAccess.get_file_as_string(audit_save) == before_clock_save, "idle clock ticks do not trigger the gameplay autosave timer")
	audit._clock_save_elapsed = audit.CLOCK_SAVE_INTERVAL
	audit._autosave()
	_check(not audit._clock_dirty and FileAccess.get_file_as_string(audit_save) != before_clock_save, "clock-only progress persists at its one-minute threshold")
	# Failed autosave must remain visible and must not replace the valid primary.
	var notices: Array[String] = []
	audit.notification.connect(func(message: String) -> void: notices.append(message))
	audit.backup_path = "user://roots-audit-missing-dir/backup.json"
	audit._last_save_error_notification_ms = -audit.SAVE_ERROR_NOTIFICATION_INTERVAL_MS
	var primary_before_failure := FileAccess.get_file_as_string(audit_save)
	audit.data.day += 1
	audit._dirty = true
	audit._autosave()
	_check(not notices.is_empty() and not audit.save_error.is_empty() and FileAccess.get_file_as_string(audit_save) == primary_before_failure and audit._dirty, "autosave failure notifies the player and preserves valid progress for retry")
	_check(not FileAccess.file_exists(audit.backup_path + ".tmp"), "failed backup rotation leaves no partial backup temporary file")
	# A station at five or six ready units cannot accept a batch whose output would be discarded.
	audit.data.compost_station.built = true
	audit.data.compost_station.construction_done = true
	audit.data.compost_station.batch_active = false
	audit.data.compost_station.ready_compost = 6
	audit.data.resources.compost = 1
	_check(not audit.start_compost_batch() and int(audit.data.resources.compost) == 1 and int(audit.data.compost_station.ready_compost) == 6, "full compost storage rejects a batch without consuming raw compost")
	# Missing species keys in old version-two records must not abort migration.
	var malformed_v2: Dictionary = audit.data.duplicate(true)
	malformed_v2.version = 2
	malformed_v2.zones.garden.plots[0].erase("species")
	malformed_v2.memorials = [{"key": "garden:0", "zone": "garden", "plot": 0, "name": "نهال", "message": "پیام", "day": 1}]
	var migrated_v2: Dictionary = audit._migrate_state(malformed_v2)
	_check(migrated_v2 is Dictionary and int(migrated_v2.version) == 3, "version-two migration tolerates missing species fields without script errors")
	# Reused wind ambience must update its location gain without restarting the stream.
	var old_audio_enabled := AudioManager._audio_enabled
	var old_track := AudioManager._track
	var old_zone := AudioManager._zone
	var old_active := AudioManager._active_ambience
	var old_name := AudioManager._ambience_name
	var old_scales := AudioManager._ambience_scales.duplicate()
	AudioManager._audio_enabled = true
	AudioManager._track = "garden"
	AudioManager._zone = "garden"
	AudioManager._active_ambience = 0
	AudioManager._ambience_name = "sfx_wind"
	AudioManager._ambience_scales[0] = 0.8
	var wind := AudioManager._stream("sfx_wind", true)
	AudioManager._ambience_players[0].stream = wind
	AudioManager._ambience_players[0].play()
	AudioManager.set_zone("school")
	_check(is_equal_approx(float(AudioManager._ambience_scales[0]), 0.68), "location changes update reused ambience gain without restarting the wind stream")
	AudioManager._ambience_players[0].stop()
	AudioManager._ambience_players[0].stream = null
	AudioManager._audio_enabled = old_audio_enabled
	AudioManager._track = old_track
	AudioManager._zone = old_zone
	AudioManager._active_ambience = old_active
	AudioManager._ambience_name = old_name
	AudioManager._ambience_scales = old_scales
	# Release packaging must stop before export when the regression suite fails.
	var build_source := FileAccess.get_file_as_string("res://tools/build_android.sh")
	var test_position := build_source.find("--scene res://tests/test_runner.tscn")
	var export_position := build_source.find("--export-debug")
	_check(test_position > 0 and export_position > test_position, "Android build script runs regression tests before exporting APKs")
	var world_source := FileAccess.get_file_as_string("res://scripts/world.gd")
	_check(world_source.contains("if world._zone == \"city\":") and not world_source.contains("if world._zone in [\"city\", \"park\"]:"), "night lamp glows are limited to the city where lamp props exist")
	audit.free()
	for path in [audit_save, audit_backup, audit_save + ".tmp", audit_backup + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

# Check story sourcing, fictional labels, narrator voices, and persisted progress.
func _test_npc_stories() -> void:
	var total := CONTENT.npc_story_total()
	var unique_texts := {}
	var sources_ready := true
	var fiction_ready := true
	var narrator_ready := true
	var chapter_counts_ready := true
	var expected_perspectives := ["به زبان خود استاد رهنما", "به زبان خود خانم نگار", "روایت تخیلی به زبان رها", "به زبان خود سامان"]
	var real_story_count := 0
	var fictional_story_count := 0
	for npc_index in CONTENT.npc_story_npcs():
		var count := 0
		for chapter_id in range(1, 9):
			var story: Dictionary = CONTENT.npc_story(npc_index, chapter_id)
			count += 1 if not story.is_empty() else 0
			unique_texts[String(story.get("text", ""))] = true
			narrator_ready = narrator_ready and "من " in String(story.get("text", "")) and String(story.get("perspective", "")) == expected_perspectives[npc_index]
			# Real martyr stories require citations; Raha's fiction must remain sourceless.
			if npc_index == 2:
				fictional_story_count += 1
				fiction_ready = fiction_ready and bool(story.get("fictional", false)) and String(story.get("source_title", "")).is_empty() and String(story.get("source_url", "")).is_empty() and "تخیلی" in String(story.get("perspective", "")) and "پدر" in String(story.get("text", ""))
			else:
				real_story_count += 1
				sources_ready = sources_ready and not String(story.get("martyr", "")).is_empty() and not String(story.get("source_title", "")).is_empty() and String(story.get("source_url", "")).begins_with("https://")
		chapter_counts_ready = chapter_counts_ready and count == 8
	_check(total == 32 and unique_texts.size() == 32 and chapter_counts_ready and real_story_count == 24 and fictional_story_count == 8, "four NPCs have eight distinct chapter stories each")
	_check(sources_ready, "all twenty-four real martyr stories retain a valid HTTPS source")
	_check(fiction_ready, "all eight Raha stories are clearly fictional, sourceless, and about their father")
	_check(narrator_ready, "all thirty-two stories use the first-person voice of their own NPC")
	for npc_index in CONTENT.npc_story_npcs():
		for chapter_id in range(1, 9):
			state.read_npc_story(npc_index, chapter_id)
	_check(state.npc_story_count() == total, "reading every chapter story records full progress")
	_check("martyr_voices" in state.data.achievements, "all thirty-two NPC stories unlock the collective achievement")
	_check(not state.read_npc_story(0, 1), "replaying a story does not duplicate progress or rewards")
	_check(state.save_game(), "NPC story progress is included in the save")
	state.data["npc_stories"] = []
	_check(state.load_game() and state.npc_story_count() == total, "NPC story progress survives save and load")

# Validate runtime imports and fixed asset formats that gameplay depends on.
func _test_polished_assets() -> void:
	var audio_files := [
		"sfx_prepare.wav", "sfx_plant.wav", "sfx_grow.wav", "sfx_water.wav", "sfx_harvest.wav",
		"sfx_save.wav", "sfx_click.wav", "sfx_quiz_correct.wav", "sfx_quiz_wrong.wav",
		"sfx_unlock.wav", "sfx_birds.wav", "sfx_wind.wav", "sfx_rain.wav",
		"sfx_water_loop.wav", "sfx_steps.wav",
	]
	var audio_ready := true
	for file_name in audio_files:
		var path: String = "res://assets/audio/" + file_name
		if not FileAccess.file_exists(path):
			audio_ready = false
			continue
		var stream := ResourceLoader.load(path, "AudioStreamWAV", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
		if stream == null or stream.mix_rate != 32000 or stream.stereo or stream.format != AudioStreamWAV.FORMAT_16_BITS:
			audio_ready = false
		stream = null
	_check(audio_ready, "all fifteen generated WAV effects exist as mono 32 kHz 16-bit PCM")
	var music_ready := true
	for file_name in ["music_title.mp3", "music_garden.mp3", "music_rain.mp3", "music_path.mp3"]:
		var stream := ResourceLoader.load("res://assets/audio/" + file_name, "AudioStreamMP3", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamMP3
		if stream == null or stream.get_length() <= 0.0:
			music_ready = false
		stream = null
	_check(music_ready, "all four user-supplied music tracks load as playable MP3 streams")
	# Test loop flags on duplicates without mutating cached source streams.
	var music_source := ResourceLoader.load("res://assets/audio/music_path.mp3", "AudioStreamMP3", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamMP3
	var looped_music := music_source.duplicate() as AudioStreamMP3
	looped_music.loop = true
	_check(looped_music != null and looped_music.loop, "supplied MP3 music supports runtime looping")
	looped_music = null
	music_source = null
	var title_buttons_ready := true
	for base_name in ["button_start", "button_wood", "button_wood_dark", "button_settings", "button_about"]:
		for state in ["", "_hover", "_pressed"]:
			title_buttons_ready = title_buttons_ready and ResourceLoader.load("res://assets/art/" + base_name + state + ".svg", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) != null
	_check(title_buttons_ready, "all fifteen separate title-button SVG textures load in normal, hover and pressed states")
	var in_game_button_states_ready := true
	for base_name in ["button_hud", "button_quest", "button_compact"]:
		for state in ["", "_hover", "_pressed"]:
			in_game_button_states_ready = in_game_button_states_ready and ResourceLoader.load("res://assets/art/" + base_name + state + ".svg", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) != null
	_check(in_game_button_states_ready, "all nine separate in-game button textures load in normal, hover and pressed states")
	var utility_button_states_ready := true
	for base_name in ["button_water", "button_danger"]:
		for state_name in ["", "_hover", "_pressed"]:
			utility_button_states_ready = utility_button_states_ready and ResourceLoader.load("res://assets/art/" + base_name + state_name + ".svg", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) != null
	_check(utility_button_states_ready, "blue water and red danger buttons provide all three leaf-framed states")
	var sample_button := UIFactory.button("آزمون", func() -> void: pass, "leaf", "primary")
	var sample_normal := sample_button.get_theme_stylebox("normal") as StyleBoxTexture
	var sample_hover := sample_button.get_theme_stylebox("hover") as StyleBoxTexture
	var sample_pressed := sample_button.get_theme_stylebox("pressed") as StyleBoxTexture
	_check(sample_normal != null and sample_hover != null and sample_pressed != null and sample_normal.texture != null and sample_hover.texture != null and sample_pressed.texture != null, "modal and touch buttons use the same three-state wooden artwork as title buttons")
	sample_button.free()
	var hud_panel_texture := ResourceLoader.load("res://assets/art/hud_panel.svg", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	var hud_chip_texture := ResourceLoader.load("res://assets/art/hud_chip.svg", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	_check(hud_panel_texture != null and hud_panel_texture.get_size() == Vector2(850, 64) and hud_chip_texture != null and hud_chip_texture.get_size() == Vector2(92, 44), "wooden HUD panel and green resource chips load at their source sizes")
	_check(ResourceLoader.load("res://assets/art/about_panel.svg", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) != null and GameAtlas.icon("team") != null, "dedicated about-team panel and group icon load")
	var title_panel_texture := ResourceLoader.load("res://assets/art/title_panel.svg", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	_check(title_panel_texture != null and title_panel_texture.get_size() == Vector2(840, 184), "dedicated forest-and-wood title banner loads at its source size")
	var icon_texture := ResourceLoader.load("res://assets/art/icons.svg", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	var icon_source := FileAccess.get_file_as_string("res://assets/art/icons.svg")
	var icon_keys_ready := true
	for key in GameAtlas.ICONS:
		icon_keys_ready = icon_keys_ready and GameAtlas.icon(String(key)) != null
	_check(icon_texture != null and icon_texture.get_size() == Vector2(512, 128) and not icon_source.contains("undefined") and icon_keys_ready, "redesigned game icon atlas loads every mapped icon without undefined cells")
	var scene_assets_ready := true
	var scene_keys := {}
	for chapter in CONTENT.CHAPTERS:
		var scene := String(WorldController.CHAPTER_SCENES[int(chapter.id)])
		scene_keys[scene] = true
		var scene_texture := ResourceLoader.load("res://assets/art/scene_" + scene + ".svg", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		scene_assets_ready = scene_assets_ready and scene_texture != null and scene_texture.get_size() == Vector2(1280, 720)
	_check(scene_assets_ready and scene_keys.size() == 8, "all eight unique chapter backgrounds load at 1280x720")
	# Shared bed geometry must preserve access and separation at mature stages.
	var plot_layout_ready := WorldController.PLOT_POSITIONS.size() == 6 and GardenPlot.HIT_RECT.size.y <= 120.0
	for i in range(WorldController.PLOT_POSITIONS.size()):
		plot_layout_ready = plot_layout_ready and PlayerController.WALK_BOUNDS.has_point(WorldController.PLOT_POSITIONS[i])
	for i in range(4):
		plot_layout_ready = plot_layout_ready and WorldController.PLOT_POSITIONS[i + 2].y - WorldController.PLOT_POSITIONS[i].y >= 120.0
	_check(plot_layout_ready, "shared planting grid keeps six reachable beds and mature plants separated")
	var plants_ready := true
	for species in CONTENT.SPECIES:
		for stage in range(6):
			plants_ready = plants_ready and GameAtlas.plant(String(species.id), stage) != null
	_check(plants_ready, "all six plant species expose six readable atlas stages")
	var icons_ready := true
	for file_name in ["sprout_icon.svg", "android_icon.svg", "android_icon_background.svg", "android_icon_foreground.svg", "android_icon_monochrome.svg"]:
		icons_ready = icons_ready and FileAccess.file_exists("res://assets/art/" + file_name)
	_check(icons_ready, "in-game, legacy, adaptive, foreground, background and monochrome icon sources exist")
	var primary_icon_source := ResourceLoader.load("res://assets/art/source/user_sprout_primary.png", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	var growth_icon_source := ResourceLoader.load("res://assets/art/source/user_sprout_growth.png", "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	var sprout_icon_texture := GameAtlas.icon("sprout")
	_check(primary_icon_source != null and primary_icon_source.get_size() == Vector2(256, 256) and growth_icon_source != null and growth_icon_source.get_size() == Vector2(64, 64) and sprout_icon_texture != null and sprout_icon_texture.resource_path.ends_with("sprout_icon.svg"), "user-created sprout sources are preserved and power the in-game and launcher icons")
	_check(AudioManager._music_players.size() == 2 and AudioManager._ambience_players.size() == 2, "audio manager provides crossfade players for music and ambience")
	_check(AudioManager._effects.size() == 6, "audio manager retains six round-robin effect players")
	var click_stream := AudioManager._stream("sfx_click") as AudioStreamWAV
	var wind_stream := AudioManager._stream("sfx_wind", true) as AudioStreamWAV
	var title_music_stream := AudioManager._stream("music_title", true) as AudioStreamMP3
	_check(click_stream != null and wind_stream != null and wind_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and title_music_stream != null and title_music_stream.loop, "audio lookup resolves imported WAV effects and supplied MP3 music with correct looping")
	_check(AudioManager._stream("sfx_missing") == null, "missing optional audio returns a null stream instead of reaching playback")
	# Headless checks must not depend on an audio device or ambience startup.
	AudioManager.set_zone("garden")
	var headless_ambience_silent := true
	for player in AudioManager._ambience_players:
		headless_ambience_silent = headless_ambience_silent and player.stream == null and not player.playing
	_check(headless_ambience_silent, "headless runs do not load or play ambience streams")

# Scan runtime art directly so unimported or zero-sized images fail the suite.
func _test_runtime_images() -> void:
	var directory := DirAccess.open("res://assets/art")
	var image_count := 0
	var runtime_images_ready := directory != null
	if directory != null:
		for file_name in directory.get_files():
			if file_name.get_extension().to_lower() not in ["svg", "png", "webp", "jpg", "jpeg"]:
				continue
			image_count += 1
			var texture := ResourceLoader.load("res://assets/art/" + file_name, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			runtime_images_ready = runtime_images_ready and texture != null and texture.get_width() > 0 and texture.get_height() > 0
	_check(image_count >= 60 and runtime_images_ready, "every runtime art image imports successfully with nonzero dimensions")

# Drive the real main scene through title, gameplay, settings, save, and ending flows.
func _test_ui_smoke() -> void:
	var ui_save := "user://roots-ui-test-save.json"
	var ui_backup := "user://roots-ui-test-backup.json"
	var ui_settings := "user://roots-ui-test-settings.cfg"
	# Snapshot singleton settings because their persistence path is temporarily redirected.
	var original_settings := GameState.settings.duplicate()
	var original_settings_path := GameState.settings_path
	GameState.save_path = ui_save
	GameState.backup_path = ui_backup
	GameState.settings_path = ui_settings
	GameState.settings.touch = true
	GameState.new_game()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var original_backup_path := GameState.backup_path
	var data_before_failed_save := GameState.data.duplicate(true)
	# A failed save must abort the title transition and restore the previous game.
	GameState.backup_path = "user://roots-ui-missing-backup/backup.json"
	Engine.set_print_error_messages(false)
	var exit_save_succeeded: bool = main._save_progress_for_exit()
	main._new_game()
	Engine.set_print_error_messages(true)
	GameState.backup_path = original_backup_path
	_check(not exit_save_succeeded, "menu and quit transitions report backup save failures instead of proceeding")
	_check(not main._in_game and GameState.data == data_before_failed_save, "failed new-game save restores the previous game and stays on the title screen")
	_check(is_instance_valid(main.screen) and not main._in_game, "title screen instantiates")
	var title_background := main.screen.get_child(0) as TextureRect
	var title_material := title_background.material as ShaderMaterial if title_background != null else null
	var title_cinematic_ready := title_background != null and title_background.texture != null and title_background.texture.resource_path.ends_with("cinematic_garden.png") and title_background.texture.get_size() == Vector2(1792, 1024) and title_material != null and title_material.shader != null and title_material.shader.resource_path.ends_with("cinematic_garden.gdshader") and is_equal_approx(float(title_material.get_shader_parameter("image_aspect")), 1.75)
	_check(title_cinematic_ready, "title screen uses the supplied cinematic garden with aspect-preserving pixel shader")
	var title_banner := main.screen.get_node_or_null("TitleBanner") as TextureRect
	var banner_title: Label = null
	var banner_subtitle: Label = null
	if title_banner != null:
		for node in title_banner.find_children("*", "Label", true, false):
			var label := node as Label
			if label.text == "ریشه‌های ایثار":
				banner_title = label
			elif label.text == "کاشت نهال امید؛ پیوند ایثار با پاسداشت محیط زیست":
				banner_subtitle = label
	var title_banner_ready: bool = title_banner != null and title_banner.texture != null and title_banner.texture.resource_path.ends_with("title_panel.svg") and banner_title != null and banner_subtitle != null and banner_title.get_line_count() == 1 and banner_subtitle.get_line_count() == 1 and title_banner.get_global_rect().encloses(banner_title.get_global_rect()) and title_banner.get_global_rect().encloses(banner_subtitle.get_global_rect())
	_check(title_banner_ready, "title and subtitle stay single-line and readable inside the new decorative banner")
	_check(_ui_rtl_ready(main.screen), "all title-screen text and buttons are right-aligned")
	var title_texture_buttons: Array[Node] = main.screen.find_children("*", "TextureButton", true, false)
	var title_texture_states_ready: bool = title_texture_buttons.size() == 6
	for node in title_texture_buttons:
		var texture_button := node as TextureButton
		title_texture_states_ready = title_texture_states_ready and texture_button != null and texture_button.texture_normal != null and texture_button.texture_hover != null and texture_button.texture_pressed != null
	_check(title_texture_states_ready, "all six title actions use independent normal, hover and pressed button images")
	var title_labels_ready := true
	var expected_titles := ["تنظیمات", "شروع بازی", "ادامهٔ بازی", "راهنما", "خروج", "درباره ما"]
	for node in title_texture_buttons:
		var labels: Array[Node] = node.find_children("*", "Label", true, false)
		if labels.size() != 1:
			title_labels_ready = false
			continue
		var title_label := labels[0] as Label
		title_labels_ready = title_labels_ready and title_label != null and expected_titles.has(title_label.text) and title_label.autowrap_mode == TextServer.AUTOWRAP_OFF
	_check(title_labels_ready, "title image buttons keep readable single-line Persian labels")
	# Preserve chapter state while exercising scene-specific music selection.
	var original_day := int(GameState.data.day)
	var original_zone := String(GameState.data.zone)
	var original_time := float(GameState.data.time_of_day)
	GameState.data.day = 1
	GameState.data.time_of_day = 1.0
	GameState.data.zone = "garden"
	_check(main._music_for_current_scene() == "garden", "daytime garden uses the supplied garden music")
	GameState.data.zone = "school"
	_check(main._music_for_current_scene() == "path", "school uses the supplied garden-path music")
	GameState.data.zone = "park"
	_check(main._music_for_current_scene() == "path", "neighborhood park uses the supplied garden-path music")
	GameState.data.zone = "city"
	_check(main._music_for_current_scene() == "garden", "city uses the supplied garden music")
	GameState.data.time_of_day = 14.0
	_check(main._music_for_current_scene() == "rain", "night scenes use the supplied night-garden music")
	GameState.data.time_of_day = 1.0
	GameState.data.day = 2
	_check(main._music_for_current_scene() == "rain", "rainy weather uses the supplied night-garden music")
	GameState.data.day = original_day
	GameState.data.zone = original_zone
	GameState.data.time_of_day = original_time
	var about_title_button: TextureButton
	for node in title_texture_buttons:
		var about_labels: Array[Node] = node.find_children("*", "Label", true, false)
		if about_labels.size() == 1 and (about_labels[0] as Label).text == "درباره ما":
			about_title_button = node as TextureButton
	_check(about_title_button != null, "title screen exposes the dedicated about-team action")
	about_title_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	_check(is_instance_valid(main.modal), "about-team screen opens")
	_check(_ui_contains_text(main._modal_body, "نیوتک (NewTech)"), "about-team screen shows the group name")
	_check(_ui_contains_text(main._modal_body, "یاسمین رضایی") and _ui_contains_text(main._modal_body, "یاسمن بخشی‌زاده"), "about-team screen lists both creators")
	_check(_ui_contains_text(main._modal_body, "بازی ریشه‌های ایثار"), "about-team screen shows the project name")
	_check(_ui_contains_text(main._modal_body, "«هر نهال، فرصتی برای ساختن آینده‌ای سبزتر است.»"), "about-team screen shows the group motto")
	_check(_ui_contains_text(main._modal_body, "چهارمین رویداد تولید محتوای دیجیتال بسیج منطقه ۵ تهران بزرگ"), "about-team screen shows the competition event")
	var about_group_label: Label
	var about_event_label: Label
	for node in main._modal_body.find_children("*", "Label", true, false):
		var about_label := node as Label
		if about_label.text == "نیوتک (NewTech)":
			about_group_label = about_label
		elif about_label.text == "چهارمین رویداد تولید محتوای دیجیتال بسیج منطقه ۵ تهران بزرگ":
			about_event_label = about_label
	var about_scroll := main._modal_body.get_parent() as ScrollContainer
	var about_layout_ready := about_group_label != null and about_event_label != null and about_scroll != null
	if about_layout_ready:
		about_layout_ready = about_group_label.size.x > 500.0 and about_group_label.get_line_count() == 1 and about_event_label.get_line_count() == 1 and about_scroll.get_global_rect().encloses(about_event_label.get_global_rect())
	_check(about_layout_ready, "about-team text stays horizontal and fits inside the modal viewport")
	var about_close_ready := false
	var about_close_button: Button
	for node in main.modal.find_children("*", "Button", true, false):
		var about_button := node as Button
		if about_button != null and about_button.text == "×":
			about_close_button = about_button
			about_close_ready = about_button.size.x >= 64.0 and about_button.size.y >= 64.0
	_check(about_close_ready and main.modal.mouse_filter == Control.MOUSE_FILTER_STOP, "about-team modal has a touch-sized close button and blocks the main menu")
	about_close_button.pressed.emit()
	await get_tree().process_frame
	_check(not is_instance_valid(main.modal), "about-team close returns to the main menu")
	_show_ui_modal(main, "_settings", "settings screen opens")
	main._controls()
	await get_tree().process_frame
	await get_tree().process_frame
	# Containers need a frame to apply sizes before guide layout is measured.
	var guide_titles := ["حرکت کردن", "اطلاعات و گفت‌وگو", "آبیاری نهال", "آماده‌کردن خاک و کاشت", "جمع‌آوری و کمپوست", "گذر زمان و مراقبت", "مأموریت‌ها و فصل بعد", "نقشه و فصل‌های قبلی", "یادبود و روایت‌ها", "ذخیره خودکار و ادامه", "توقف و تنظیمات"]
	var guide_steps_ready := is_instance_valid(main.modal)
	for title in guide_titles:
		guide_steps_ready = guide_steps_ready and _ui_contains_text(main._modal_body, title)
	_check(guide_steps_ready, "game guide presents nine ordered step-by-step instruction cards")
	_check(_ui_rtl_ready(main.modal), "step-by-step guide keeps Persian text readable and right-aligned")
	var guide_scroll := main._modal_body.get_parent() as ScrollContainer
	var final_guide_step := main._modal_body.get_child(main._modal_body.get_child_count() - 1) as Control
	guide_scroll.ensure_control_visible(final_guide_step)
	await get_tree().process_frame
	await get_tree().process_frame
	var guide_viewport := guide_scroll.get_global_rect()
	var final_guide_rect := final_guide_step.get_global_rect()
	var final_guide_visible := final_guide_rect.position.y >= guide_viewport.position.y - 1.0 and final_guide_rect.end.y <= guide_viewport.end.y + 1.0
	_check(final_guide_visible, "guide scrolling reaches the final instruction without hiding it behind the footer")
	main._close_modal()
	_show_ui_modal(main, "_request_quit", "quit confirmation opens without quitting")
	main._new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(main._in_game and is_instance_valid(main.world), "new game enters the live world")
	var intro_guard := 0
	while is_instance_valid(main.modal) and intro_guard < 12:
		main._next_intro()
		intro_guard += 1
		await get_tree().process_frame
	_check(not is_instance_valid(main.modal) and intro_guard > 0, "chapter intro advances to gameplay")
	_check(main._tutorial_active(), "first run starts the guided tutorial")
	var tutorial_step_before_layout: int = main._tutorial_index
	main._tutorial_index = 3
	main._update_tutorial_step()
	var tutorial_card_rect: Rect2 = main._tutorial_card.get_global_rect()
	var tutorial_controls_clear: bool = not tutorial_card_rect.intersects(main._action_button.get_global_rect()) and not tutorial_card_rect.intersects(main._water_action_button.get_global_rect())
	_check(tutorial_controls_clear, "tutorial message stays above the touch action and water buttons")
	main._tutorial_index = tutorial_step_before_layout
	main._update_tutorial_step()
	main._missions()
	_check(is_instance_valid(main.modal) and AudioManager._paused, "opening a modal during tutorial keeps audio paused")
	main._close_modal()
	_check(main._tutorial_active() and AudioManager._paused, "closing a tutorial submodal does not resume audio early")
	var welcome_step: Dictionary = CONTENT.TUTORIALS.first_run[0]
	_check(String(welcome_step.title) == "به باغ فراموش‌شده خوش آمدی!" and String(welcome_step.text) == "این باغ روزگاری سرسبز و پر از زندگی بود، اما حالا به کمک تو نیاز دارد. در این ماجراجویی همراه ما شو، با گیاهان آشنا شو، نهال بکار و از آن‌ها مراقبت کن. شاید با تلاش تو، دوباره باغ پر از رنگ و زندگی شود! 🌱", "welcome tutorial uses the approved title and text")
	var tutorial_flow_text := ""
	for step in CONTENT.TUTORIALS.first_run.slice(-2):
		tutorial_flow_text += String(step.text)
	var tutorial_flow_ready := CONTENT.TUTORIALS.first_run.size() >= 10 and "مأموریت" in tutorial_flow_text and "فصل بعد" in tutorial_flow_text and "نقشه" in tutorial_flow_text and "ذخیرهٔ پیشرفت" in tutorial_flow_text and "ادامه بازی" in tutorial_flow_text
	_check(tutorial_flow_ready, "first-run tutorial explains missions, next chapter, maps, saving and continue")
	var tutorial_guard := 0
	while main._tutorial_active() and tutorial_guard < 12:
		main._tutorial_action_done = true
		main._next_tutorial()
		tutorial_guard += 1
		await get_tree().process_frame
	_check(not main._tutorial_active() and GameState.tutorial_seen("first_run"), "guided tutorial completes and is remembered")
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	_check(get_tree().paused and is_instance_valid(main.modal), "Android Back opens pause during gameplay")
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	_check(not get_tree().paused and not is_instance_valid(main.modal), "Android Back closes the active modal before leaving gameplay")
	var tutorial_chapter := int(GameState.data.chapter)
	GameState.data.chapter = 2
	_check(not main._should_start_first_run(), "first-run tutorial never restarts in later chapters")
	main._maybe_start_chapter_tutorial()
	_check(not main._tutorial_active(), "chapter two does not auto-repeat planting training")
	GameState.data.chapter = 4
	main._maybe_start_zone_tutorial("school")
	_check(not main._tutorial_active(), "new regions do not auto-open redundant tutorials")
	GameState.data.chapter = 3
	main._maybe_start_chapter_tutorial()
	_check(main._tutorial_active(), "compost training appears only when the new station is not built")
	main._close_tutorial(true)
	GameState.data.compost_station.built = true
	main._maybe_start_chapter_tutorial()
	_check(not main._tutorial_active(), "compost training is skipped when the feature is already built")
	GameState.data.compost_station.built = false
	GameState.data.chapter = 5
	main._maybe_start_chapter_tutorial()
	_check(main._tutorial_active(), "memorial training appears only before the first memorial")
	main._close_tutorial(true)
	GameState.data.memorials.append({})
	main._maybe_start_chapter_tutorial()
	_check(not main._tutorial_active(), "memorial training is skipped after the feature is used")
	GameState.data.memorials.pop_back()
	GameState.data.chapter = 2
	main._start_species_tutorial("arghavan")
	_check(not main._tutorial_active(), "species tutorials do not interrupt later chapters")
	GameState.data.chapter = tutorial_chapter
	main.world.reload_zone()
	await _test_live_world(main)
	var data_before_finish := GameState.data.duplicate(true)
	var finish_chapter := int(GameState.data.chapter)
	for task in GameState.current_chapter().tasks:
		GameState.data.progress[task.id] = int(task.target)
	main._finish_chapter()
	_check(is_instance_valid(main.modal) and finish_chapter in GameState.data.completed, "finishing a ready chapter opens its completion popup")
	# Dismissing completion must leave chapter advancement available from Missions.
	main._close_modal()
	main._missions()
	var retry_finish_button := _ui_find_button(main._modal_footer, "پایان فصل")
	_check(retry_finish_button != null, "missions still offer chapter advancement after dismissing the completion popup")
	if retry_finish_button != null:
		retry_finish_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
	_check(int(GameState.data.chapter) == finish_chapter + 1 and is_instance_valid(main.modal), "finish action advances the chapter after the popup was dismissed")
	# Restore the exact pre-transition snapshot rather than replaying completion.
	GameState.data = data_before_finish
	main._show_game()
	await get_tree().process_frame
	await get_tree().process_frame
	main.world.set_player_position(main.world.plot_position(0) + Vector2(0, 65))
	main.world._update_focus()
	main._action_button.pressed.emit()
	await get_tree().process_frame
	_check(is_instance_valid(main.modal), "touch action button interacts with the nearest plot")
	_check(main._action_button.disabled and main._water_action_button.disabled, "touch action buttons are disabled while a modal blocks gameplay")
	main._close_modal()
	for entry in [
		["_missions", "mission screen opens"],
		["_map", "map screen opens"],
		["_plants", "plant management screen opens"],
		["_memorials", "memorial screen opens"],
		["_select_memorial_plant", "memorial plant picker opens"],
		["_stories", "sourced story screen opens"],
		["_quiz", "quiz screen opens"],
		["_achievements", "achievements screen opens"],
		["_compost", "compost station screen opens"],
		["_npc", "NPC dialogue opens"],
	]:
		if entry[0] == "_npc":
			main._npc(0)
			_check(is_instance_valid(main.modal), entry[1])
			_check(not main._joystick.visible, "touch joystick is hidden while a modal blocks gameplay")
			_check(_ui_rtl_ready(main.modal), "NPC dialogue text and actions are right-aligned")
			_check(_ui_contains_button(main._modal_footer, "گفتگو") and _ui_contains_button(main._modal_footer, "داستان"), "mentor NPC exposes conversation and sourced story actions")
			_check(not _ui_contains_button(main._modal_footer, "راهنمای کنترل"), "NPC dialogue no longer shows the controls button")
			main._close_modal()
			main._open_story(0, 1)
			await get_tree().process_frame
			_check(_ui_rtl_ready(main.modal), "story text is right-aligned while the Latin source URL remains LTR")
			_check(_ui_contains_text(main._modal_body, "شهید ") and _ui_contains_text(main._modal_body, "منبع:"), "sourced martyr story screen shows the martyr and reference")
			var mentor_next := _ui_find_button(main._modal_footer, "روایت بعدی")
			_check(mentor_next != null, "sourced story screen exposes the next-story action")
			if mentor_next != null:
				mentor_next.pressed.emit()
				await get_tree().process_frame
			_check(_ui_contains_text(main.modal, "استاد رهنما · راهنمای باغ · روایت واقعی") and _ui_contains_text(main._modal_body, String(CONTENT.npc_story(0, 2).martyr)) and not _ui_contains_text(main.modal, "خانم نگار"), "next story advances the same mentor to their next chapter")
			main._close_modal()
			main._npc(2)
			_check(_ui_contains_button(main._modal_footer, "گفتگو") and _ui_contains_button(main._modal_footer, "داستان"), "Raha exposes conversation and fictional story actions")
			main._close_modal()
			main._open_story(2, 1)
			await get_tree().process_frame
			_check(_ui_contains_text(main.modal, "رها · داوطلب مدرسه · روایت تخیلی") and _ui_contains_text(main._modal_body, "پدر شهید رها") and _ui_contains_text(main._modal_body, "این روایت تخیلی است") and not _ui_contains_text(main._modal_body, "منبع:"), "Raha story screen is clearly fictional and shows no fabricated source")
			var raha_next := _ui_find_button(main._modal_footer, "روایت بعدی")
			_check(raha_next != null, "Raha story screen exposes the next-story action")
			if raha_next != null:
				raha_next.pressed.emit()
				await get_tree().process_frame
			_check(_ui_contains_text(main.modal, "رها · داوطلب مدرسه · روایت تخیلی") and _ui_contains_text(main._modal_body, String(CONTENT.npc_story(2, 2).text)) and not _ui_contains_text(main.modal, "استاد رهنما"), "next Raha story stays with Raha and advances their chapter")
			main._close_modal()
			main._stories()
			var first_shortcut_index := int(main._story_index)
			main._close_modal()
			main._stories()
			var second_shortcut_index := int(main._story_index)
			_check(first_shortcut_index != second_shortcut_index, "chapter-story shortcut rotates through unread NPC stories")
			main._close_modal()
		else:
			_show_ui_modal(main, entry[0], entry[1])
	main._compost()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_ui_contains_text(main._modal_body, "کمپوست، ریشهٔ زندگی تازه") and _ui_contains_text(main._modal_body, "مادهٔ خام") and _ui_contains_text(main._modal_body, "۱ · ساخت"), "compost dashboard shows resource summary and all three process stages")
	_check(_ui_contains_button(main._modal_footer, "ساخت کارگاه کمپوست"), "compost dashboard exposes the contextual construction action")
	main._close_modal()
	main._plot_menu(0)
	_check(is_instance_valid(main.modal), "unprepared plot screen opens")
	main._close_modal()
	_check(GameState.prepare_plot(0), "UI flow prepares the first plot")
	main._plot_menu(0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_instance_valid(main.modal), "species selection opens for prepared soil")
	var species_labels: Array[Node] = main._modal_body.find_children("*", "Label", true, false)
	var species_labels_ready := true
	for species in CONTENT.SPECIES:
		var found := false
		for label_node in species_labels:
			var species_label := label_node as Label
			if species_label != null and species_label.text == String(species.name):
				found = true
				species_labels_ready = species_labels_ready and species_label.autowrap_mode == TextServer.AUTOWRAP_OFF and species_label.size.x >= 100.0
		species_labels_ready = species_labels_ready and found
	_check(species_labels_ready, "native tree cards keep readable horizontal Persian labels")
	var species_uses_ready := true
	for species in CONTENT.SPECIES:
		var found := false
		for label_node in species_labels:
			var species_label := label_node as Label
			if species_label != null and species_label.text == String(species.use):
				found = true
				species_uses_ready = species_uses_ready and species_label.size.x >= 150.0 and species_label.get_line_count() <= 2
		species_uses_ready = species_uses_ready and found
	_check(species_uses_ready, "every native tree card shows one short practical use sentence")
	main._close_modal()
	_check(GameState.plant_tree(0, "cypress"), "UI flow plants a cypress")
	if main._tutorial_active():
		main._close_tutorial(true)
	main.world.set_player_position(main.world.plot_position(0) + Vector2(50, 30))
	main.world._update_focus()
	_check(main.world._water_button.visible, "water button appears beside a nearby plant that needs water")
	var moisture_before := int(GameState.plots("garden")[0].moisture)
	main._water_action_button.pressed.emit()
	await get_tree().process_frame
	_check(int(GameState.plots("garden")[0].moisture) > moisture_before, "touch water button waters the nearest plant without a keyboard")
	main._plot_menu(0)
	_check(is_instance_valid(main.modal), "plant care screen opens")
	main._close_modal()
	main._write_memorial("garden", 0)
	var has_name_field := false
	var has_message_field := false
	if is_instance_valid(main.modal):
		for child in main._modal_body.get_children():
			has_name_field = has_name_field or child is LineEdit
			has_message_field = has_message_field or child is TextEdit
	_check(has_name_field and has_message_field, "memorial form exposes name and message inputs")
	_check(_ui_rtl_ready(main.modal), "memorial labels, name input and message editor use RTL alignment")
	main._close_modal()
	_check(GameState.save_memorial("garden", 0, "سرو امید", "پیامی برای آیندهٔ محله."), "UI flow saves a memorial record")
	# Inject malformed records to ensure memorial rendering remains defensive.
	GameState.data.memorials.append({"zone": "invalid", "plot": 99, "species": "invalid"})
	GameState.data.memorials.append("invalid")
	main._memorials()
	_check(is_instance_valid(main.modal) and _ui_contains_text(main._modal_body, "سرو امید"), "memorial screen skips malformed saved entries without crashing")
	GameState.data.memorials.pop_back()
	GameState.data.memorials.pop_back()
	var memorial_species: Dictionary = CONTENT.species_by_id("cypress")
	var memorial_plot: Dictionary = GameState.plots("garden")[0]
	var memorial_stage := String(memorial_species.stage_names[int(memorial_plot.stage)])
	_check(_ui_contains_text(main._modal_body, String(memorial_species.name)), "memorial list shows the plant species")
	_check(_ui_contains_text(main._modal_body, memorial_stage), "memorial list shows the current growth stage")
	main._close_modal()
	main._quiz()
	var question_index := int(main._quiz_index)
	_check(question_index >= 0, "quiz selects an unanswered question")
	if question_index >= 0:
		var question: Dictionary = CONTENT.QUESTIONS[question_index]
		var correct := int(question.correct)
		main._answer_quiz((correct + 1) % 4)
		_check(question_index not in GameState.data.quiz_solved, "wrong UI answer is not recorded as solved")
		_check(not main._quiz_feedback.text.is_empty(), "wrong UI answer displays feedback")
		main._answer_quiz(correct)
		_check(question_index in GameState.data.quiz_solved, "correct UI answer records progress")
	main._close_modal()
	GameState.settings.reduced_motion = true
	main._settings()
	await get_tree().process_frame
	await get_tree().process_frame
	var settings_viewport := main._modal_body.get_parent() as ScrollContainer
	var music_slider := main.modal.find_child("setting_music", true, false) as HSlider
	var sound_slider := main.modal.find_child("setting_sound", true, false) as HSlider
	var day_slider := main.modal.find_child("setting_day_length", true, false) as HSlider
	var touch_toggle := main.modal.find_child("setting_touch", true, false) as CheckButton
	var motion_toggle := main.modal.find_child("setting_reduced_motion", true, false) as CheckButton
	var settings_controls_ready := music_slider != null and sound_slider != null and day_slider != null and touch_toggle != null and motion_toggle != null
	if settings_controls_ready:
		for control in [music_slider, sound_slider, day_slider, touch_toggle, motion_toggle]:
			settings_controls_ready = settings_controls_ready and settings_viewport.get_global_rect().encloses(control.get_global_rect())
	_check(settings_controls_ready, "all five settings controls are visible without clipping")
	_check(_ui_rtl_ready(main.modal), "settings labels and toggles use readable right-aligned Persian text")
	music_slider.value = 0.3
	sound_slider.value = 0.4
	day_slider.value = 360.0
	_check(is_equal_approx(float(GameState.settings.music), 0.3) and is_equal_approx(float(GameState.settings.sound), 0.4) and GameState.current_day_seconds() == 360.0, "settings sliders update audio and day duration immediately")
	_check((main.modal.find_child("value_music", true, false) as Label).text == "۳۰٪" and (main.modal.find_child("value_sound", true, false) as Label).text == "۴۰٪" and (main.modal.find_child("value_day_length", true, false) as Label).text == "۶ دقیقه", "settings sliders show live formatted values")
	touch_toggle.button_pressed = false
	motion_toggle.button_pressed = true
	# Toggle signals settle on the physics frame before world settings are asserted.
	await get_tree().physics_frame
	_check(not bool(GameState.settings.touch) and bool(GameState.settings.reduced_motion) and main.world._reduced_motion, "settings toggles immediately update touch controls and reduced motion")
	main._close_modal()
	_check(not main._joystick.visible, "disabling touch controls hides the joystick after settings closes")
	main._settings()
	await get_tree().process_frame
	_check(not (main.modal.find_child("setting_touch", true, false) as CheckButton).button_pressed and (main.modal.find_child("setting_reduced_motion", true, false) as CheckButton).button_pressed, "reopening settings preserves the selected toggle states")
	var reset_button := _ui_find_button(main._modal_footer, "بازنشانی تنظیمات")
	_check(reset_button != null, "settings expose a reset action")
	if reset_button != null:
		reset_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
	_check(GameState.settings == GameState.DEFAULT_SETTINGS and (main.modal.find_child("setting_touch", true, false) as CheckButton).button_pressed and not (main.modal.find_child("setting_reduced_motion", true, false) as CheckButton).button_pressed, "reset action restores defaults and refreshes every control")
	var controls_button := _ui_find_button(main._modal_footer, "راهنمای کنترل‌ها")
	_check(controls_button != null, "settings link to the control guide")
	if controls_button != null:
		controls_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(_ui_contains_text(main.modal, "راهنمای بازی"), "control guide opens from settings")
		var back_to_settings := _ui_find_button(main._modal_footer, "تنظیمات")
		_check(back_to_settings != null, "control guide provides a return action to settings")
		if back_to_settings != null:
			back_to_settings.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			_check(_ui_contains_text(main.modal, "صدا و موسیقی"), "return action reopens the redesigned settings screen")
	main._close_modal()
	_check(main._joystick.visible, "restored touch defaults show the joystick again")
	main._pause()
	_check(get_tree().paused and AudioManager._paused, "pause screen stops both the game clock and all audio")
	main._settings()
	_check(get_tree().paused and is_instance_valid(main.modal), "opening settings from pause keeps the game clock paused")
	_check(not AudioManager._paused, "settings opened from pause enable audible volume preview")
	var preview_slider := main.modal.find_child("setting_sound", true, false) as HSlider
	preview_slider.value = 0.55
	_check(not AudioManager._paused and is_equal_approx(float(GameState.settings.sound), 0.55), "changing preview volume keeps settings audio audible and updates immediately")
	main._close_modal()
	_check(get_tree().paused and AudioManager._paused and _ui_contains_text(main.modal, "بازی متوقف است"), "closing settings opened from pause returns to the paused game without resuming the clock")
	main._settings()
	main._handle_back_action()
	_check(get_tree().paused and AudioManager._paused and _ui_contains_text(main.modal, "بازی متوقف است"), "Android Back from pause settings returns to pause instead of resuming gameplay")
	main._close_modal()
	_check(not get_tree().paused and not AudioManager._paused, "closing the pause screen resumes the tree and audio")
	main._settings()
	# Focus changes must preserve whether pause-preview audio was intentionally active.
	var audio_before_focus := AudioManager.is_paused()
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(AudioManager.is_paused(), "focus loss pauses audio on every Android vendor")
	main._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(AudioManager.is_paused() == audio_before_focus, "focus return restores the previous audio preview state")
	main._close_modal()
	main._manual_save()
	_check(GameState.save_available, "UI manual save succeeds")
	main._show_ending()
	await get_tree().process_frame
	_check(not main._in_game and is_instance_valid(main.screen), "ending screen replaces the world")
	var ending_background := main.screen.get_child(0) as TextureRect
	var ending_material := ending_background.material as ShaderMaterial if ending_background != null else null
	_check(ending_background != null and ending_background.texture != null and ending_background.texture.resource_path.ends_with("cinematic_garden.png") and ending_material != null and ending_material.shader != null and ending_material.shader.resource_path.ends_with("cinematic_garden.gdshader"), "ending screen uses the same animated cinematic garden background")
	_check(_ui_rtl_ready(main.screen), "all ending-screen text and actions are right-aligned")
	var ending_buttons: Array[Node] = main.screen.find_children("*", "TextureButton", true, false)
	var ending_buttons_ready := ending_buttons.size() == 2
	for node in ending_buttons:
		var texture_button := node as TextureButton
		ending_buttons_ready = ending_buttons_ready and texture_button != null and texture_button.texture_normal != null and texture_button.texture_hover != null and texture_button.texture_pressed != null
	_check(ending_buttons_ready, "ending actions use independent normal, hover and pressed button images")
	_check(_ui_contains_text(main.screen, "محیط زیست") and _ui_contains_text(main.screen, "مسئولیت اجتماعی") and _ui_contains_text(main.screen, "آگاهی فرهنگی"), "ending screen presents the three score categories as readable cards")
	var ending_title: Label
	for node in main.screen.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text == "ریشه‌های ماندگار":
			ending_title = label
	_check(ending_title != null and ending_title.size.x > 300.0 and ending_title.get_line_count() == 1, "ending title stays horizontal on a single line")
	var biodiversity_label: Label
	for node in main.screen.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text.begins_with("درختان سالم شهر:"):
			biodiversity_label = label
	_check(biodiversity_label != null and biodiversity_label.size.x > 250.0 and biodiversity_label.get_line_count() == 1, "ending biodiversity badge stays horizontal and leaves room for both actions")
	main._show_menu()
	await get_tree().process_frame
	main._continue_game()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(main._in_game and is_instance_valid(main.world), "continue restores the saved game")
	await _test_ui_audit_regressions(main)
	main._show_menu()
	main._request_new()
	_check(is_instance_valid(main.modal), "new-game confirmation protects an existing save")
	main._close_modal()
	main.free()
	await get_tree().process_frame
	# Restore singleton state and remove every smoke-test save before returning.
	GameState.data = {}
	GameState.settings = original_settings
	GameState.settings_path = original_settings_path
	for path in [ui_save, ui_backup, ui_save + ".tmp", ui_backup + ".tmp", ui_settings]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

# Exercise the confirmed touch, lifecycle, modal, HUD, and world-reuse regressions.
func _test_ui_audit_regressions(main) -> void:
	var old_reduced_motion := bool(GameState.settings.reduced_motion)
	var old_touch := bool(GameState.settings.touch)
	GameState.settings.reduced_motion = false
	GameState.settings.touch = true
	main._close_modal(false)
	main._close_tutorial(false)
	main._in_game = true
	if not is_instance_valid(main.world):
		main._show_game()
	await get_tree().process_frame
	await get_tree().process_frame
	# Title and ending screens must not advance the simulation or plant care off-screen.
	var day_before_idle := int(GameState.data.day)
	GameState.data.time_of_day = 23.99
	main._show_menu()
	await get_tree().process_frame
	GameState._process(0.2)
	_check(int(GameState.data.day) == day_before_idle and is_equal_approx(float(GameState.data.time_of_day), 23.99) and GameState.time_paused, "title screen freezes day, time, and plant care")
	main._show_ending()
	await get_tree().process_frame
	GameState._process(0.2)
	_check(int(GameState.data.day) == day_before_idle and is_equal_approx(float(GameState.data.time_of_day), 23.99) and GameState.time_paused, "ending screen freezes day, time, and plant care")
	main._show_game()
	GameState.data.time_of_day = 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	# HUD labels and chips must update in place instead of allocating forty-nine nodes per signal.
	var chip_ids: Array[int] = []
	for chip in main._hud.get_children():
		chip_ids.append(chip.get_instance_id())
	for index in range(100):
		GameState._touch()
		main._refresh_hud()
	var chips_reused: bool = chip_ids.size() == main._hud.get_child_count()
	for index in range(chip_ids.size()):
		chips_reused = chips_reused and main._hud.get_child(index).get_instance_id() == chip_ids[index]
	_check(chips_reused and main._hud.get_child_count() == 8, "one hundred HUD refreshes reuse all eight chip instances")
	# Zone visits must retain the live screen, world, and HUD owners.
	var screen_id: int = main.screen.get_instance_id()
	var world_id: int = main.world.get_instance_id()
	var original_chapter := int(GameState.data.chapter)
	GameState.data.chapter = 4
	main._visit_zone("school")
	await get_tree().process_frame
	_check(main.screen.get_instance_id() == screen_id and main.world.get_instance_id() == world_id and String(GameState.data.zone) == "school", "map travel reuses the live world instead of rebuilding the gameplay screen")
	GameState.data.chapter = original_chapter
	GameState.data.zone = "garden"
	main.world.refresh()
	# Closing modals must stop intercepting input before their dismissal tween ends.
	main._open_modal("آزمون بستن", Vector2(420, 260))
	var closing_modal: Node = main.modal
	main._close_modal()
	_check(is_instance_valid(closing_modal) and _ui_input_transparent(closing_modal), "dismissing modal is input-transparent during its fade-out")
	# A deferred close after focus loss must not resume audio in the background.
	main._open_modal("آزمون فوکوس", Vector2(420, 260))
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_close := _ui_find_button(main.modal, "بستن")
	if focus_close != null:
		focus_close.pressed.emit()
	await get_tree().process_frame
	_check(not is_instance_valid(main.modal) and AudioManager.is_paused(), "deferred modal close preserves focus-loss audio pause")
	main._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(not AudioManager.is_paused(), "focus return restores audio after the deferred modal close")
	# Back closes tutorial submodals first and offers quit confirmation without skipping the tutorial.
	main._start_tutorial("first_run", true)
	main._missions()
	main._handle_back_action()
	await get_tree().process_frame
	_check(not is_instance_valid(main.modal) and main._tutorial_active(), "Back closes a tutorial submodal before handling the tutorial")
	main._handle_back_action()
	await get_tree().process_frame
	_check(is_instance_valid(main.modal) and main._tutorial_active() and _ui_contains_text(main.modal, "خروج از بازی"), "Back during a tutorial opens quit confirmation and preserves the tutorial")
	main._close_modal()
	main._close_tutorial(false)
	# Backgrounding must preserve an already open modal instead of replacing it with Pause.
	main._missions()
	var paused_modal_id: int = main.modal.get_instance_id()
	main._notification(NOTIFICATION_APPLICATION_PAUSED)
	await get_tree().process_frame
	_check(is_instance_valid(main.modal) and main.modal.get_instance_id() == paused_modal_id and not get_tree().paused, "application pause preserves the active modal and navigation state")
	main._handle_back_action()
	# Compost tutorial completion depends on construction, not merely opening the station panel.
	GameState.data.chapter = 3
	GameState.data.compost_station.built = false
	main._start_tutorial("compost", true, [{"title": "ساخت کمپوست", "text": "کارگاه را بساز.", "target": "compost", "complete_on": "compost"}])
	main._interaction("compost", 0)
	_check(main._tutorial_active() and not main._tutorial_action_done, "opening the compost station does not complete its construction tutorial")
	GameState.data.stats.compost_built += 1
	main._process(0.01)
	_check(main._tutorial_action_done, "successful compost construction completes the tutorial step")
	main._close_tutorial(false)
	main._close_modal()
	GameState.data.chapter = original_chapter
	GameState.data.zone = "garden"
	main.world.refresh()
	_check(main.overlay.z_index > main.world._water_button.z_index and main.world._water_button is TouchActionButton, "tutorial overlay stays above the multitouch contextual water button")
	# Notification bursts remain bounded and preserve the newest message.
	main._notification_queue.clear()
	main._toast_timer.stop()
	main._toast_label.hide()
	for index in range(100):
		main._toast("پیام " + str(index))
	_check(main._notification_queue.size() <= main.MAX_NOTIFICATION_QUEUE and main._notification_queue.back() == "پیام 99", "notification queue is bounded and keeps the newest message")
	main._notification_queue.clear()
	main._toast_label.hide()
	main._toast_timer.stop()
	# Verify canvas-coordinate conversion, cancellation, and simultaneous Action/Water touches at 1920x1080.
	var old_window_size := get_tree().root.size
	get_tree().root.size = Vector2i(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	var joystick: Variant = main._joystick
	var joystick_transform: Transform2D = joystick.get_global_transform_with_canvas()
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = joystick_transform * Vector2(75, 75)
	joystick._input(press)
	_check(joystick._finger == 0, "joystick acquires a touch at its displayed center on a 1920x1080 viewport")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = joystick_transform * Vector2(127, 75)
	joystick._input(drag)
	_check(joystick._direction.x > 0.9 and absf(joystick._direction.y) < 0.1, "joystick drag direction remains accurate after canvas scaling")
	main.world.set_player_position(main.world.plot_position(0) + Vector2(0, 65))
	main.world._update_focus()
	var action_signal_count: Array[int] = [0]
	var action_callback := func() -> void:
		action_signal_count[0] += 1
	main._action_button.pressed.connect(action_callback)
	var action_press := InputEventScreenTouch.new()
	action_press.index = 1
	action_press.pressed = true
	action_press.position = Vector2(60, 44)
	main._action_button._gui_input(action_press)
	var action_was_multitouch: bool = main._action_button._touch_index == 1 and joystick._finger == 0 and main.world.touch_direction.x > 0.9
	var action_release := InputEventScreenTouch.new()
	action_release.index = 1
	action_release.pressed = false
	action_release.position = Vector2(60, 44)
	main._action_button._gui_input(action_release)
	main._action_button.pressed.disconnect(action_callback)
	await get_tree().process_frame
	_check(action_was_multitouch and action_signal_count[0] == 1 and main._action_button._touch_index == -1, "Action touch fires once while the joystick finger continues moving")
	if is_instance_valid(main.modal):
		main._close_modal()
	# Reacquire movement and verify the independent Water touch uses the same multitouch path.
	press.index = 2
	press.pressed = true
	press.position = joystick_transform * Vector2(75, 75)
	joystick._input(press)
	drag.index = 2
	drag.position = joystick_transform * Vector2(127, 75)
	joystick._input(drag)
	var water_signal_count: Array[int] = [0]
	var water_callback := func() -> void:
		water_signal_count[0] += 1
	main._water_action_button.pressed.connect(water_callback)
	var water_press := InputEventScreenTouch.new()
	water_press.index = 3
	water_press.pressed = true
	water_press.position = Vector2(60, 44)
	main._water_action_button._gui_input(water_press)
	var water_was_multitouch: bool = main._water_action_button._touch_index == 3 and joystick._finger == 2 and main.world.touch_direction.x > 0.9
	var water_release := InputEventScreenTouch.new()
	water_release.index = 3
	water_release.pressed = false
	water_release.position = Vector2(60, 44)
	main._water_action_button._gui_input(water_release)
	main._water_action_button.pressed.disconnect(water_callback)
	await get_tree().process_frame
	_check(water_was_multitouch and water_signal_count[0] == 1 and main._water_action_button._touch_index == -1, "Water touch fires once while the joystick finger continues moving")
	var cancel := InputEventScreenTouch.new()
	cancel.index = -1
	cancel.pressed = false
	cancel.canceled = true
	joystick._input(cancel)
	_check(joystick._finger == -1 and joystick._direction == Vector2.ZERO, "Android touch cancellation releases latched joystick movement")
	press.index = 4
	press.pressed = true
	press.position = joystick_transform * Vector2(75, 75)
	joystick._input(press)
	_check(joystick._finger == 4, "joystick accepts a new touch after Android cancellation")
	press.index = 4
	press.pressed = false
	press.position = joystick_transform * Vector2(75, 75)
	joystick._input(press)
	# Sliding off Action/Water or releasing the emulated mouse outside must cancel, not fire.
	var cancel_buttons: Array[TouchActionButton] = [main._action_button, main._water_action_button]
	var touch_cancel_ok: bool = true
	var mouse_cancel_ok: bool = true
	for button_index in range(cancel_buttons.size()):
		var cancel_button: TouchActionButton = cancel_buttons[button_index]
		var cancel_count: Array[int] = [0]
		var cancel_callback := func() -> void:
			cancel_count[0] += 1
		cancel_button.pressed.connect(cancel_callback)
		var touch_press := InputEventScreenTouch.new()
		touch_press.index = 10 + button_index * 2
		touch_press.pressed = true
		touch_press.position = Vector2(60, 44)
		cancel_button._gui_input(touch_press)
		var touch_drag := InputEventScreenDrag.new()
		touch_drag.index = touch_press.index
		touch_drag.position = Vector2(500, 500)
		cancel_button._gui_input(touch_drag)
		var touch_release := InputEventScreenTouch.new()
		touch_release.index = touch_press.index
		touch_release.pressed = false
		touch_release.position = Vector2(500, 500)
		cancel_button._gui_input(touch_release)
		touch_cancel_ok = touch_cancel_ok and cancel_count[0] == 0 and cancel_button._touch_index == -1
		var mouse_press := InputEventMouseButton.new()
		mouse_press.button_index = MOUSE_BUTTON_LEFT
		mouse_press.pressed = true
		mouse_press.position = Vector2(60, 44)
		cancel_button._gui_input(mouse_press)
		var mouse_release := InputEventMouseButton.new()
		mouse_release.button_index = MOUSE_BUTTON_LEFT
		mouse_release.pressed = false
		mouse_release.position = Vector2(500, 500)
		cancel_button._gui_input(mouse_release)
		mouse_cancel_ok = mouse_cancel_ok and cancel_count[0] == 0 and cancel_button._touch_index == -1
		cancel_button.pressed.disconnect(cancel_callback)
	_check(touch_cancel_ok, "sliding a finger off Action or Water cancels without firing")
	_check(mouse_cancel_ok, "releasing the emulated mouse outside Action or Water cancels without firing")
	get_tree().root.size = old_window_size
	await get_tree().process_frame
	GameState.settings.reduced_motion = old_reduced_motion
	GameState.settings.touch = old_touch
	main._refresh_touch_controls()

# Verify that every Control in a dismissed modal ignores input immediately.
func _ui_input_transparent(root: Node) -> bool:
	if root is Control and (root as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in root.get_children():
		if not _ui_input_transparent(child):
			return false
	return true

# Verify live layout, scene selection, collisions, touch targets, and interaction routing.
func _test_live_world(main) -> void:
	var world = main.world
	_check(is_instance_valid(world._player) and world._player._frames.size() == 24, "player caches all six animation rows")
	_check(not world._water_button.visible, "water button is hidden when no nearby plant needs water")
	_check(not _ui_contains_button(main.screen, "تعامل"), "generic interaction button is removed")
	_check(not _ui_contains_button(main._bottom_bar, "پرسش"), "quiz button is removed from the bottom HUD")
	_check(is_instance_valid(main._quest_button) and is_instance_valid(main._quest_label) and main._quest_label.text.begins_with("مأموریت"), "quest tracker is collapsed into a touch button")
	var game_texture_buttons: Array[Node] = main.screen.find_children("*", "TextureButton", true, false)
	var game_image_controls_ready := game_texture_buttons.size() == 6
	for node in game_texture_buttons:
		var texture_button := node as TextureButton
		game_image_controls_ready = game_image_controls_ready and texture_button != null and texture_button.texture_normal != null and texture_button.texture_hover != null and texture_button.texture_pressed != null
	_check(game_image_controls_ready, "map, pause, quest and three bottom actions use independent button images")
	var compact_buttons_ready: bool = main._bottom_bar.get_child_count() == 3
	for child in main._bottom_bar.get_children():
		var compact_button := child as TextureButton
		compact_buttons_ready = compact_buttons_ready and compact_button != null and compact_button.texture_normal != null and compact_button.texture_normal.resource_path.ends_with("button_compact.svg")
	_check(compact_buttons_ready, "bottom memorial, plants and achievements bar uses compact wooden image buttons")
	var hud_panel := main._hud.get_parent() as TextureRect
	var hud_chips_ready: bool = hud_panel != null and hud_panel.texture != null and hud_panel.texture.resource_path.ends_with("hud_panel.svg") and main._hud.get_child_count() == 8
	for child in main._hud.get_children():
		var chip := child as TextureRect
		hud_chips_ready = hud_chips_ready and chip != null and chip.texture != null and chip.texture.resource_path.ends_with("hud_chip.svg")
	_check(hud_chips_ready, "resource and clock groups share the new wooden HUD and green chip artwork")
	var expected_hud_captions := ["ستاره", "سبزی", "همکاری", "دانش", "آب", "بذر", "کمپوست", "زمان"]
	var hud_captions_ready: bool = main._hud.get_child_count() == expected_hud_captions.size()
	for index in range(expected_hud_captions.size()):
		var chip: TextureRect = main._hud.get_child(index) as TextureRect
		var column: VBoxContainer = null
		var caption_label: Label = null
		var value_label: Label = null
		if chip != null:
			column = chip.get_child(0) as VBoxContainer
		if column != null and column.get_child_count() > 1:
			caption_label = column.get_child(1) as Label
			var row := column.get_child(0) as HBoxContainer
			if row != null and row.get_child_count() > 1:
				value_label = row.get_child(1) as Label
		hud_captions_ready = hud_captions_ready and caption_label != null and value_label != null and caption_label.text == expected_hud_captions[index] and caption_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and value_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and caption_label.get_theme_font_size("font_size") <= 10 and caption_label.autowrap_mode == TextServer.AUTOWRAP_OFF and caption_label.get_line_count() <= 1 and chip.get_global_rect().encloses(caption_label.get_global_rect()) and chip.get_global_rect().encloses(value_label.get_global_rect())
	_check(hud_captions_ready, "every HUD value and tiny caption are centered inside their chip without clipping")
	_check(_ui_rtl_ready(main.screen), "live-world Persian UI is right-aligned with centered HUD text")
	_check(is_instance_valid(main._joystick) and main._joystick.visible, "touch movement joystick is visible")
	_check(is_instance_valid(main._action_button) and main._action_button.visible and main._action_button.size.x >= 120.0 and main._action_button.size.y >= 88.0, "touch action button is visible with a thumb-sized target")
	_check(is_instance_valid(main._water_action_button) and main._water_action_button.visible and main._water_action_button.size.x >= 120.0 and main._water_action_button.size.y >= 88.0, "touch water button is visible with a thumb-sized target")
	world._player.play_action("water")
	_check(world._player._row == 4 and world._player._frame == 0, "watering uses the dedicated fourth action row")
	world._player.play_action("plant")
	_check(world._player._row == 5 and world._player._frame == 0, "planting uses the dedicated fifth action row")
	world.play_action("plant")
	# Bursts self-free after their lifetime; the tracker must release stale nodes.
	await get_tree().create_timer(0.8).timeout
	_check(world._bursts.is_empty(), "finished action bursts are released from the world")
	_check(world._scene == "garden_overgrown" and world._background == world._backgrounds["garden_overgrown"], "first chapter selects the forgotten-garden scene")
	var original_zone := String(GameState.data.zone)
	var original_chapter := int(GameState.data.chapter)
	var chapter_scenes_ready := true
	var planting_areas_ready := true
	var map_collisions_ready := true
	# Chapter reloads must change artwork while retaining one reachable planting grid.
	for chapter in CONTENT.CHAPTERS:
		var chapter_id := int(chapter.id)
		var expected_scene := String(WorldController.CHAPTER_SCENES[chapter_id])
		GameState.data.chapter = chapter_id
		GameState.data.zone = String(chapter.location)
		world.reload_zone()
		await get_tree().process_frame
		chapter_scenes_ready = chapter_scenes_ready and world._scene == expected_scene and world._background == world._backgrounds[expected_scene]
		planting_areas_ready = planting_areas_ready and world._plots.size() == 6
		for plot in world._plots:
			var expected_position := WorldController.PLOT_POSITIONS[plot.index]
			planting_areas_ready = planting_areas_ready and plot.position.distance_to(expected_position) <= 0.1
			planting_areas_ready = planting_areas_ready and world._player.can_stand_at(expected_position + Vector2(0, 65))
			planting_areas_ready = planting_areas_ready and plot.contains_point(expected_position + Vector2(0, -10))
			map_collisions_ready = map_collisions_ready and not world._player.can_stand_at(expected_position)
		for obstacle in WorldController.SCENE_OBSTACLES.get(expected_scene, []):
			map_collisions_ready = map_collisions_ready and not world._player.can_stand_at(obstacle.get_center())
		for obstacle in WorldController.ZONE_PROP_OBSTACLES.get(String(GameState.data.zone), []):
			map_collisions_ready = map_collisions_ready and not world._player.can_stand_at(obstacle.get_center())
	_check(chapter_scenes_ready, "all eight chapters select their matching location scene")
	_check(planting_areas_ready, "every chapter exposes six visible and reachable planting beds")
	_check(map_collisions_ready, "planting beds and solid map scenery block the player without closing bed access")
	GameState.data.chapter = 4
	GameState.data.zone = "school"
	world.reload_zone()
	await get_tree().process_frame
	var school_compost := WorldController.COMPOST_POSITION
	var school_compost_ready: bool = is_instance_valid(world._compost_sprite) and (world._compost_sprite.get_parent() as Node2D).position == school_compost and world._player.can_stand_at(school_compost + Vector2(0, 40)) and not world._player.can_stand_at(school_compost)
	_check(school_compost_ready, "school compost is relocated to the shared station with collision and an accessible approach")
	world.set_player_position(school_compost + Vector2(0, 40))
	world.interact()
	_check(world.closest_target().get("kind", "") == "compost" and is_instance_valid(main.modal) and _ui_contains_text(main.modal, "ایستگاه کمپوست"), "school compost responds to the nearby action target")
	main._close_modal()
	world._last_pointer_ms = -1000
	world._click_target(school_compost)
	_check(is_instance_valid(main.modal) and _ui_contains_text(main.modal, "ایستگاه کمپوست"), "school compost also opens with direct touch or click")
	main._close_modal()
	world.set_player_position(Vector2(900, 650))
	world._last_pointer_ms = -1000
	world._click_target(school_compost)
	_check(not is_instance_valid(main.modal), "distant compost tap cannot bypass the interaction range")
	world._last_pointer_ms = -1000
	world._click_target(WorldController.NPC_POSITIONS[0])
	_check(not is_instance_valid(main.modal), "distant NPC tap cannot bypass the conversation range")
	# Off-location travel must not leak memorial ambience into another scene.
	GameState.data.chapter = 5
	GameState.data.zone = "school"
	world.reload_zone()
	_check(world._scene == "school_courtyard" and not world._memorial, "off-location travel never applies the memorial scene to school")
	GameState.data.chapter = 8
	GameState.data.zone = "garden"
	world.reload_zone()
	_check(world._scene == "garden_saplings" and not world._memorial, "off-location garden visits use a non-memorial garden scene")
	GameState.data.chapter = 5
	GameState.data.zone = "garden"
	world.reload_zone()
	_check(world._scene == "memorial_garden" and world._memorial, "memorial chapter selects its dedicated scene")
	# Restore the original location before later UI checks depend on it.
	GameState.data.zone = original_zone
	GameState.data.chapter = original_chapter
	world.reload_zone()
	_check(world._scene == String(WorldController.CHAPTER_SCENES[original_chapter]), "world rendering checks restore the original chapter scene")
	var mission_chapter := int(GameState.data.chapter)
	GameState.data.chapter = 5
	main._missions()
	_check(_ui_contains_button(main._modal_footer, "پرسش‌های فصل"), "mission menu keeps quiz access for quiz chapters")
	_check(_ui_contains_button(main._modal_footer, "روایت‌های فصل"), "mission menu keeps story access for story chapters")
	main._close_modal()
	GameState.data.chapter = mission_chapter

# Open one named screen, assert it exists, and close it for the next check.
func _show_ui_modal(main, method_name: String, description: String) -> void:
	main.call(method_name)
	_check(is_instance_valid(main.modal), description)
	main._close_modal()

# Recursively enforce RTL text while allowing explicitly centered HUD labels.
func _ui_rtl_ready(root: Node) -> bool:
	for child in root.get_children():
		if child is Label:
			var label := child as Label
			if label.text_direction != Control.TEXT_DIRECTION_LTR:
				var expected_alignment: int = HORIZONTAL_ALIGNMENT_CENTER if bool(label.get_meta("hud_text", false)) or bool(label.get_meta("center_aligned", false)) else HORIZONTAL_ALIGNMENT_RIGHT
				if label.horizontal_alignment != expected_alignment:
					return false
		elif child is Button:
			var button := child as Button
			if button.alignment != HORIZONTAL_ALIGNMENT_RIGHT:
				return false
		elif child is LineEdit:
			var line_edit := child as LineEdit
			if line_edit.text_direction != Control.TEXT_DIRECTION_RTL or line_edit.alignment != HORIZONTAL_ALIGNMENT_RIGHT:
				return false
		elif child is CheckButton:
			var check_button := child as CheckButton
			if check_button.text_direction != Control.TEXT_DIRECTION_RTL or check_button.alignment != HORIZONTAL_ALIGNMENT_RIGHT:
				return false
		elif child is TextEdit:
			var text_edit := child as TextEdit
			if text_edit.text_direction != Control.TEXT_DIRECTION_RTL:
				return false
		if not _ui_rtl_ready(child):
			return false
	return true

# Search descendants so checks work with nested footer and card layouts.
func _ui_find_button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text == text:
			return child as Button
		var found := _ui_find_button(child, text)
		if found != null:
			return found
	return null

# Check a whole UI subtree for a labeled action button.
func _ui_contains_button(root: Node, text: String) -> bool:
	for child in root.get_children():
		if child is Button and child.text == text:
			return true
		if _ui_contains_button(child, text):
			return true
	return false

# Find partial label matches anywhere in a UI subtree.
func _ui_contains_text(root: Node, text: String) -> bool:
	for child in root.get_children():
		if child is Label and text in child.text:
			return true
		if _ui_contains_text(child, text):
			return true
	return false

# Accumulate failures so one broken assertion does not hide later regressions.
func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
