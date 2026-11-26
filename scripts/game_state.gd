extends Node

signal changed
signal notification(message: String)
signal chapter_finished(chapter_id: int)
signal achievement_unlocked(id: String)
signal time_changed
signal day_started(day: int)

const SAVE_PATH := "user://garden.save"
const BACKUP_PATH := "user://garden.backup"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_VERSION := 3
const DAY_SECONDS := 240.0
const DEFAULT_SETTINGS := {"music": 0.45, "sound": 0.65, "touch": true, "reduced_motion": false, "day_length": 240.0}
const DAY_START_HOUR := 7.0
const NIGHT_START_HOUR := 19.0
const CONTENT = preload("res://scripts/data/game_content.gd")
const LOCATIONS := ["garden", "school", "park", "city"]

var data: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var settings_path := SETTINGS_PATH
var save_available := false
var save_error := ""
var save_path := SAVE_PATH
var backup_path := BACKUP_PATH
var _dirty := false
# Clock pausing is independent of SceneTree.paused so settings can stop time without freezing UI.
var time_paused := false
var _time_signal_timer := 0.0

# Loads preferences, detects existing saves, and starts the ten-second autosave timer.
func _ready() -> void:
	load_settings()
	save_available = has_valid_save()
	var timer := Timer.new()
	timer.wait_time = 10.0
	timer.timeout.connect(_autosave)
	add_child(timer)
	timer.start()

# Advances the in-game clock only during active play and rolls over into a new day at midnight.
func _process(delta: float) -> void:
	if data.is_empty() or get_tree().paused or time_paused:
		return
	var next_time := float(data.time_of_day) + delta * 24.0 / current_day_seconds()
	var wrapped := next_time >= 24.0
	if wrapped:
		next_time = fmod(next_time, 24.0)
	data.time_of_day = next_time
	if wrapped:
		advance_day()
	_dirty = true
	_time_signal_timer += delta
	# UI updates are throttled except on day rollover, which needs an immediate refresh.
	if wrapped or _time_signal_timer >= 0.1:
		_time_signal_timer = 0.0
		time_changed.emit()

# Initializes all persistent state and six plots per location, then immediately saves.
func new_game() -> bool:
	data = {
		"version": SAVE_VERSION, "chapter": 1, "zone": "garden", "day": 1, "time_of_day": 1.0,
		"scores": {"eco": 0, "social": 0, "culture": 0, "stars": 0},
		"resources": {"water": 8, "seeds": 8, "compost": 6}, "completed": [],
		"progress": {}, "seen": [], "zones": {}, "achievements": [], "memorials": [],
		"quiz_solved": [], "tutorials": [], "npc_stories": [],
		"compost_station": {"built": false, "construction_done": false, "batch_active": false, "ready_day": -1, "ready_compost": 0},
		"stats": {"planted": 0, "watered": 0, "recycled": 0, "helped": 0, "compost_built": 0, "compost_batches": 0, "plants_lost": 0},
		"player": [660.0, 460.0], "finished": false
	}
	# Every location receives an independent copy of the initial plot state.
	for zone in LOCATIONS:
		var plots: Array = []
		for i in range(6):
			plots.append({"prepared": false, "species": "", "stage": 0, "moisture": 25,
				"soil": 45, "health": 100, "growth": 0.0, "healthy_days": 0, "watered_day": -1, "planted_day": 0,
				"compost_day": -1, "sun": 2 + (i % 2), "name": "", "dead": false, "neglect_days": 0})
		data.zones[zone] = {"plots": plots}
	_touch()
	return save_game()

# Resolves the content definition for the active chapter.
func current_chapter() -> Dictionary:
	return CONTENT.chapter_by_id(int(data.get("chapter", 1)))

# Returns plots for an explicit zone or for the player's current zone by default.
func plots(zone: String = "") -> Array:
	var key := String(data.get("zone", "garden")) if zone.is_empty() else zone
	return data.zones[key].plots

# Reads the current chapter's progress count for one mission ID.
func task_count(id: String) -> int:
	return int(data.get("progress", {}).get(id, 0))

# Marks state dirty and notifies listeners after a gameplay mutation.
func _touch() -> void:
	_dirty = true
	changed.emit()

# Credits a mission once per chapter, event ID, and unique key, stopping at its target.
func register_event(id: String, unique_key: String) -> bool:
	if data.is_empty() or data.finished:
		return false
	var key := str(data.chapter) + ":" + id + ":" + unique_key
	if key in data.seen:
		return false
	for task in current_chapter().tasks:
		if task.id == id and task_count(id) < int(task.target):
			data.seen.append(key)
			data.progress[id] = task_count(id) + 1
			if task_count(id) == int(task.target):
				data.scores.stars += 5
				notification.emit("مأموریت کامل شد: " + String(task.label))
			_touch()
			return true
	return false

# Reports whether every mission in the active chapter has reached its target.
func chapter_ready() -> bool:
	if data.is_empty():
		return false
	for task in current_chapter().tasks:
		if task_count(task.id) < int(task.target):
			return false
	return true

# Awards one chapter's rewards and milestone achievement exactly once.
func complete_chapter() -> bool:
	if not chapter_ready() or int(data.chapter) in data.completed:
		return false
	var chapter := int(data.chapter)
	var reward: Dictionary = current_chapter().reward
	for key in reward:
		data.scores[key] += int(reward[key])
	data.completed.append(chapter)
	var ids := ["first_step", "first_sapling", "water_keeper", "green_school", "story_keeper", "people_helper", "green_city", "lasting_roots"]
	unlock_achievement(ids[chapter - 1])
	if chapter == 8:
		data.finished = true
	_touch()
	save_game()
	chapter_finished.emit(chapter)
	return true

# Advances chapter state while preserving world progress and replenishing minimum resources.
func next_chapter() -> void:
	if int(data.chapter) >= 8:
		return
	data.chapter = int(data.chapter) + 1
	data.progress = {}
	data.quiz_solved = []
	# Reconcile older saves whose memorial or story activity predates the new chapter counters.
	_credit_existing_memorials()
	_credit_story_mission()
	data.zone = current_chapter().location
	data.player = [660.0, 460.0]
	data.resources.water = maxi(8, int(data.resources.water))
	data.resources.seeds = maxi(6, int(data.resources.seeds))
	data.resources.compost = maxi(6, int(data.resources.compost))
	_check_mature()
	_touch()
	save_game()

# Backfills chapter five memorial missions from notes saved before mission tracking existed.
func _credit_existing_memorials() -> void:
	if int(data.chapter) != 5:
		return
	for entry in data.memorials:
		var key := String(entry.key)
		register_event("write_memorial", key)
		register_event("add_memorial", key)

# Repairs read_story progress by counting distinct NPCs already read in the active chapter.
func _credit_story_mission() -> bool:
	var before := task_count("read_story")
	var target := 0
	var mission_label := ""
	for task in current_chapter().tasks:
		if task.id == "read_story":
			target = int(task.target)
			mission_label = String(task.label)
			break
	if target <= 0:
		return false
	var chapter := int(data.chapter)
	var read_count := 0
	for npc_index in CONTENT.npc_story_npcs():
		if npc_story_seen(int(npc_index), chapter):
			read_count += 1
	# Mission targets count NPCs, while older event keys may have counted individual stories.
	var credited := mini(target, read_count)
	if credited <= before:
		return false
	data.progress["read_story"] = credited
	if credited == target:
		data.scores.stars += 5
		notification.emit("ماموریت کامل شد: " + mission_label)
	_touch()
	return true

# Checks both known locations and their chapter unlock thresholds.
func zone_unlocked(zone: String) -> bool:
	var requirements := {"garden": 1, "school": 4, "park": 6, "city": 7}
	return LOCATIONS.has(zone) and int(data.get("chapter", 1)) >= int(requirements.get(zone, 99))

# Moves the player to an unlocked zone and resets the spawn position.
func set_zone(zone: String) -> bool:
	if not zone_unlocked(zone):
		return false
	data.zone = zone
	data.player = [660.0, 460.0]
	_touch()
	return true

# Prepares an empty plot once and credits the chapter's soil mission.
func prepare_plot(index: int) -> bool:
	var plot: Dictionary = plots()[index]
	if plot.prepared:
		notification.emit("این بستر آماده است؛ برای بهبود خاک از کمپوست استفاده کن.")
		return false
	plot.prepared = true
	plot.soil = 65
	data.scores.eco += 2
	register_event("prepare_soil", str(data.zone) + ":" + str(index))
	_touch()
	return true

# Applies one compost unit per plant per day to improve soil and health.
func apply_compost(index: int) -> bool:
	var plot: Dictionary = plots()[index]
	if String(plot.species).is_empty() or bool(plot.get("dead", false)):
		notification.emit("کمپوست را به یک نهال زنده بده.")
		return false
	if int(plot.compost_day) == int(data.day):
		notification.emit("این نهال امروز کمپوست گرفته است؛ فردا دوباره خاک را بررسی کن.")
		return false
	if int(data.resources.compost) < 1:
		notification.emit("کمپوست نداری؛ در کارگاه باغ یک دسته آماده کن.")
		return false
	data.resources.compost -= 1
	plot.compost_day = data.day
	plot.soil = mini(100, int(plot.soil) + 20)
	plot.health = mini(100, int(plot.health) + 10)
	register_event("prepare_soil", str(data.zone) + ":" + str(index) + ":" + str(data.day))
	_touch()
	return true

# Resets a dead plot for replanting while retaining improved soil quality.
func clear_dead_plot(index: int) -> bool:
	var plot: Dictionary = plots()[index]
	if not bool(plot.get("dead", false)):
		return false
	plot.species = ""
	plot.stage = 0
	plot.growth = 0.0
	plot.healthy_days = 0
	plot.health = 100
	plot.moisture = 25
	plot.soil = maxi(45, int(plot.soil))
	plot.watered_day = -1
	plot.planted_day = 0
	plot.compost_day = -1
	plot.name = ""
	plot.dead = false
	plot.neglect_days = 0
	_touch()
	return true

# Spends compost to begin station construction, which completes on the next day.
func build_compost_station() -> bool:
	var station: Dictionary = data.compost_station
	if bool(station.built):
		notification.emit("کارگاه کمپوست ساخته شده است.")
		return false
	if int(data.resources.compost) < 4:
		notification.emit("برای ساخت کارگاه به ۴ واحد کمپوست نیاز داری.")
		return false
	data.resources.compost -= 4
	station.built = true
	station.construction_done = false
	station.batch_active = false
	station.ready_day = int(data.day) + 1
	data.stats.compost_built += 1
	notification.emit("ساخت کارگاه آغاز شد؛ فردا آماده خواهد شد.")
	_touch()
	return true

# Starts one next-day compost batch when the station is ready and no batch is active.
func start_compost_batch() -> bool:
	var station: Dictionary = data.compost_station
	if not bool(station.built) or not bool(station.construction_done):
		notification.emit("نخست ساخت کارگاه را کامل کن.")
		return false
	if bool(station.batch_active):
		notification.emit("یک دسته کمپوست در حال آماده‌سازی است.")
		return false
	if int(data.resources.compost) < 1:
		notification.emit("برای آغاز یک دسته به ۱ واحد کمپوست نیاز داری.")
		return false
	data.resources.compost -= 1
	station.batch_active = true
	station.ready_day = int(data.day) + 1
	data.stats.compost_batches += 1
	notification.emit("آماده‌سازی کمپوست آغاز شد؛ فردا ۲ واحد به دست می‌آوری.")
	_touch()
	return true

# Transfers ready compost into inventory without exceeding its twelve-unit capacity.
func collect_compost() -> int:
	var station: Dictionary = data.compost_station
	var ready := int(station.get("ready_compost", 0))
	if ready <= 0:
		notification.emit("کمپوست آماده‌ای برای دریافت نداری.")
		return 0
	var amount := mini(ready, 12 - int(data.resources.compost))
	if amount <= 0:
		notification.emit("ظرف کمپوست پر است؛ نخست از موجودی استفاده کن.")
		return 0
	station.ready_compost = ready - amount
	data.resources.compost += amount
	notification.emit("کمپوست به کیف پرسه اضافه شد.")
	_touch()
	return amount

# Reports whether a living plant is below the moisture threshold and has not been watered today.
func plant_needs_water(plot: Dictionary) -> bool:
	return not String(plot.species).is_empty() and not bool(plot.get("dead", false)) and int(plot.moisture) < 70 and int(plot.watered_day) != int(data.day)

# Returns whole game days until station construction or the active compost batch is ready.
func compost_days_remaining() -> int:
	var station: Dictionary = data.get("compost_station", {})
	if station.is_empty() or int(station.get("ready_day", -1)) < 0:
		return 0
	return maxi(0, int(station.ready_day) - int(data.day))

# Plants a valid species in a prepared empty plot and credits all matching chapter missions.
func plant_tree(index: int, species: String) -> bool:
	var plot: Dictionary = plots()[index]
	var plant := CONTENT.species_by_id(species)
	if plant.is_empty() or not plot.prepared or not String(plot.species).is_empty() or bool(plot.get("dead", false)):
		return false
	if int(data.resources.seeds) < 1:
		notification.emit("نهال کافی نداری؛ راهنمای باغ میتواند نهال تازه بدهد.")
		return false
	plot.species = species
	plot.stage = 1
	plot.planted_day = data.day
	plot.moisture = 20
	data.resources.seeds -= 1
	data.stats.planted += 1
	data.scores.eco += int(plant.reward_eco)
	var key := str(data.zone) + ":" + str(index)
	register_event("plant_tree", key)
	if data.zone == "school":
		register_event("plant_school", key)
	if species in ["cypress", "native_oak", "pomegranate", "arghavan", "olive", "willow"]:
		register_event("plant_native", key)
	unlock_achievement("first_sapling")
	if species == "native_oak":
		unlock_achievement("native_planter")
	_touch()
	return true

# Waters a needy living plant at most once per day and consumes one water unit.
func water_plot(index: int) -> bool:
	var plot: Dictionary = plots()[index]
	if String(plot.species).is_empty() or bool(plot.get("dead", false)):
		notification.emit("اول یک نهال زنده بکار؛ آب را روی خاک خالی یا گیاه خراب هدر نده.")
		return false
	if int(plot.watered_day) == int(data.day) or int(plot.moisture) >= 70:
		notification.emit("خاک هنوز نمناک است؛ آبیاری بیشتر لازم نیست.")
		return false
	if int(data.resources.water) < 1:
		notification.emit("آبپاش خالی است؛ کنار حوض آن را پر کن.")
		return false
	data.resources.water -= 1
	plot.moisture = mini(100, int(plot.moisture) + 45)
	plot.health = mini(100, int(plot.health) + 10)
	plot.watered_day = data.day
	data.stats.watered += 1
	data.scores.eco += 2
	register_event("water_tree", str(data.zone) + ":" + str(index) + ":" + str(data.day))
	_touch()
	return true

# Tops the watering can up to its fixed eight-unit capacity.
func refill_water() -> void:
	if int(data.resources.water) >= 8:
		notification.emit("آبپاش پر است؛ بهاندازهٔ نیاز مصرف کن.")
		return
	data.resources.water = 8
	notification.emit("آبپاش پر شد؛ هر بار آبیاری، یک واحد آب مصرف میکند.")
	_touch()

# Collects each trash pile once per chapter and zone, converting it into capped compost.
func collect_trash(index: int) -> bool:
	var key := str(data.chapter) + ":trash:" + str(data.zone) + ":" + str(index)
	if key in data.seen:
		return false
	data.seen.append(key)
	data.resources.compost = mini(12, int(data.resources.compost) + 1)
	data.scores.eco += 2
	data.stats.recycled += 1
	register_event("clean_trash", key)
	register_event("collect_recycle", key)
	if int(data.stats.recycled) >= 5:
		unlock_achievement("recycle_friend")
	_touch()
	return true

# Checks the chapter-scoped seen key for a trash pile.
func trash_collected(index: int) -> bool:
	return (str(data.chapter) + ":trash:" + str(data.zone) + ":" + str(index)) in data.seen

# Credits guide dialogue and lets the garden guide replenish a low seed supply.
func talk_npc(index: int) -> void:
	register_event("talk_guide", str(index))
	if index == 0 and int(data.resources.seeds) < 6:
		data.resources.seeds = 6
	_touch()

# Records one helpful interaction per volunteer per chapter and grants shared compost.
func help_npc(index: int) -> bool:
	var key := str(int(data.chapter)) + ":help:" + str(index)
	if key in data.seen:
		notification.emit("این داوطلب همراه شده است؛ به دیگران هم سر بزن.")
		return false
	data.seen.append(key)
	data.scores.social += 3
	data.stats.helped += 1
	data.resources.compost = mini(12, int(data.resources.compost) + 1)
	register_event("help_people", str(index))
	if int(data.stats.helped) >= 3:
		unlock_achievement("people_helper")
	notification.emit("کار تقسیم شد؛ یک واحد کمپوست برای مراقبت مشترک آماده شد.")
	_touch()
	return true

# Credits a generic story mission event using its caller-provided key.
func read_story(index: int) -> void:
	register_event("read_story", str(index))

# Records a unique NPC chapter story and repairs active-chapter mission progress from read history.
func read_npc_story(npc_index: int, chapter: int) -> bool:
	if data.is_empty() or CONTENT.npc_story(npc_index, chapter).is_empty():
		return false
	var current_chapter_story := chapter == int(data.chapter)
	# Repair before the duplicate check so revisiting an old story can persist a one-time backfill.
	var credited := _credit_story_mission() if current_chapter_story else false
	var key := str(npc_index) + ":" + str(chapter)
	var listened: Array = data.get("npc_stories", [])
	if key in listened:
		if credited:
			save_game()
		return false
	listened.append(key)
	data["npc_stories"] = listened
	if current_chapter_story:
		_credit_story_mission()
	if listened.size() >= CONTENT.npc_story_total():
		unlock_achievement("martyr_voices")
	_touch()
	save_game()
	return true

# Checks the persistent read-history key for one NPC chapter story.
func npc_story_seen(npc_index: int, chapter: int) -> bool:
	return str(npc_index) + ":" + str(chapter) in data.get("npc_stories", [])

# Returns the number of distinct NPC chapter stories recorded in the save.
func npc_story_count() -> int:
	return data.get("npc_stories", []).size()

# Tests whether a zone and plot already have a memorial entry.
func has_memorial(zone: String, index: int) -> bool:
	var key := zone + ":" + str(index)
	for entry in data.get("memorials", []):
		if entry is Dictionary and String(entry.get("key", "")) == key:
			return true
	return false

# Validates and stores one trimmed memorial note on an occupied plot, then saves immediately.
func save_memorial(zone: String, index: int, name_text: String, message: String) -> bool:
	if name_text.strip_edges().is_empty() or message.strip_edges().is_empty():
		return false
	if name_text.length() > 40 or message.length() > 240:
		return false
	var plot: Dictionary = plots(zone)[index]
	if String(plot.species).is_empty():
		return false
	var key := zone + ":" + str(index)
	if has_memorial(zone, index):
		notification.emit("این بستر پلاک یادبود دارد؛ بستر دیگری انتخاب کن.")
		return false
	data.memorials.append({"key": key, "zone": zone, "plot": index, "name": name_text.strip_edges(),
		"message": message.strip_edges(), "day": data.day, "species": plot.species})
	plot.name = name_text.strip_edges()
	data.scores.culture += 5
	register_event("write_memorial", key)
	register_event("add_memorial", key)
	unlock_achievement("story_keeper")
	_touch()
	save_game()
	return true

# Lists global question indices belonging to the active chapter.
func quiz_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(CONTENT.QUESTIONS.size()):
		if int(CONTENT.QUESTIONS[i].chapter) == int(data.chapter):
			result.append(i)
	return result

# Accepts a correct current-chapter answer once and credits both quiz mission IDs.
func answer_question(index: int, option: int) -> bool:
	if not index in quiz_indices() or option < 0 or option > 3:
		return false
	if int(CONTENT.QUESTIONS[index].correct) != option:
		return false
	if index in data.quiz_solved:
		return true
	data.quiz_solved.append(index)
	data.scores.culture += 4
	register_event("answer_quiz", str(index))
	register_event("final_quiz", str(index))
	_touch()
	return true

# Allows the final celebration only after all other chapter eight missions are complete.
func celebrate() -> bool:
	if int(data.chapter) != 8:
		return false
	for task in current_chapter().tasks:
		if task.id != "celebrate_city" and task_count(task.id) < int(task.target):
			notification.emit("پیش از جشن، مراقبت و کار گروهی را کامل کن.")
			return false
	return register_event("celebrate_city", "celebration")

# Selects the deterministic four-day weather cycle, including one rainy day.
func weather() -> String:
	return ["آفتابی", "نیمه‌ابری", "بارانی", "آفتابی"][int(data.get("day", 1)) % 4]

# Returns the configured day duration constrained to supported bounds.
func current_day_seconds() -> float:
	return clampf(float(settings.get("day_length", DAY_SECONDS)), 120.0, 480.0)

# Formats the offset game clock as a zero-padded twenty-four-hour time.
func clock_text() -> String:
	var clock := fmod(float(data.get("time_of_day", 1.0)) + DAY_START_HOUR, 24.0)
	var hour := int(clock)
	var minute := int((clock - float(hour)) * 60.0)
	return "%02d:%02d" % [hour, minute]

# Reports night once the displayed clock reaches nineteen o'clock.
func is_night() -> bool:
	return float(data.get("time_of_day", 1.0)) >= 12.0

# Ramps the night overlay in at dusk and out at dawn over two-hour transitions.
func night_amount() -> float:
	var time := float(data.get("time_of_day", 1.0))
	if time >= 10.0:
		return clampf((time - 10.0) / 2.0, 0.0, 1.0)
	if time >= 22.0:
		return clampf((24.0 - time) / 2.0, 0.0, 1.0)
	return 0.0

# Checks whether a tutorial ID has already been recorded for this save.
func tutorial_seen(id: String) -> bool:
	return id in data.get("tutorials", [])

# Persists a tutorial only on its first completion.
func mark_tutorial_seen(id: String) -> void:
	if not tutorial_seen(id):
		data.tutorials.append(id)
		_touch()
		save_game()

# Returns remaining healthy growth days, or zero for empty, dead, and mature plants.
func growth_days_left(plot: Dictionary) -> int:
	if String(plot.species).is_empty() or bool(plot.get("dead", false)) or int(plot.stage) >= 5:
		return 0
	var species := CONTENT.species_by_id(String(plot.species))
	return maxi(0, int(species.growth_days) - int(plot.get("healthy_days", 0)))

# Applies weather, plant care, compost timers, and notifications for one new game day.
func advance_day() -> void:
	var previous_day := int(data.day)
	data.day += 1
	var rainy := weather() == "بارانی"
	var lost := 0
	var grown := 0
	for zone in LOCATIONS:
		for plot in plots(zone):
			if String(plot.species).is_empty() or bool(plot.get("dead", false)):
				continue
			var spec := CONTENT.species_by_id(plot.species)
			if rainy:
				plot.moisture = mini(100, int(plot.moisture) + 30)
			# Care from the previous day counts toward today's growth evaluation.
			var watered := int(plot.watered_day) == previous_day
			var moisture_ok := rainy or watered or int(plot.moisture) >= 30
			var soil_ok := int(plot.soil) >= 35
			var sun_ok := int(plot.sun) >= int(spec.sun_need)
			if moisture_ok and soil_ok and sun_ok:
				plot.healthy_days = int(plot.get("healthy_days", 0)) + 1
				plot.growth = float(plot.healthy_days)
				plot.health = mini(100, int(plot.health) + 6)
				plot.neglect_days = 0
				var growth_days := maxi(1, int(spec.growth_days))
				plot.stage = clampi(1 + int(int(plot.healthy_days) * 4 / growth_days), 1, 5)
				grown += 1
			else:
				# Each unmet need adds damage on top of the base daily health loss.
				var damage := 22
				if not moisture_ok:
					damage += 8
				if not soil_ok:
					damage += 6
				if not sun_ok:
					damage += 6
				plot.health = maxi(0, int(plot.health) - damage)
				plot.neglect_days = int(plot.get("neglect_days", 0)) + 1
			# Daily consumption and soil depletion occur after care has been evaluated.
			plot.moisture = maxi(0, int(plot.moisture) - int(spec.water_need) * 12)
			plot.soil = maxi(25, int(plot.soil) - 2)
			if int(plot.health) <= 0 or int(plot.neglect_days) >= 3:
				plot.dead = true
				plot.health = 0
				plot.stage = 0
				lost += 1
				data.stats.plants_lost += 1
	# Construction and batch timers are independent and resolve on their scheduled day.
	var station: Dictionary = data.compost_station
	if bool(station.built) and not bool(station.construction_done) and int(data.day) >= int(station.ready_day):
		station.construction_done = true
		station.ready_day = -1
		notification.emit("کارگاه کمپوست آماده شد؛ می‌توانی دستهٔ تازه‌ای آغاز کنی.")
	if bool(station.built) and bool(station.construction_done) and bool(station.batch_active) and int(data.day) >= int(station.ready_day):
		station.batch_active = false
		station.ready_day = -1
		station.ready_compost = mini(6, int(station.get("ready_compost", 0)) + 2)
		notification.emit("۲ واحد کمپوست در ایستگاه آماده شد؛ آن را دریافت کن.")
	_check_mature()
	if lost > 0:
		notification.emit("یک یا چند نهال به‌دلیل کمبود مراقبت خراب شد؛ بستر را پاک کن و دوباره بکار.")
	elif grown > 0:
		notification.emit("روز تازه آغاز شد و نهال‌های تحت مراقبت رشد کردند.")
	else:
		notification.emit("روز تازه آغاز شد؛ رطوبت خاک و حال نهال‌ها را بررسی کن.")
	_touch()
	save_game()
	day_started.emit(int(data.day))

# Credits mature-tree missions for healthy living plots at stage four or later.
func _check_mature() -> void:
	for zone in LOCATIONS:
		for i in range(plots(zone).size()):
			if int(plots(zone)[i].stage) >= 4 and int(plots(zone)[i].health) >= 60 and not bool(plots(zone)[i].get("dead", false)):
				register_event("mature_tree", zone + ":" + str(i))

# Counts distinct healthy species across every unlocked or saved location.
func biodiversity() -> int:
	var species: Array = []
	for zone in LOCATIONS:
		for plot in plots(zone):
			if not String(plot.species).is_empty() and int(plot.health) >= 60 and not bool(plot.get("dead", false)) and not plot.species in species:
				species.append(plot.species)
	return species.size()

# Adds an achievement once and announces the unlock to listeners.
func unlock_achievement(id: String) -> void:
	if id not in data.achievements:
		data.achievements.append(id)
		achievement_unlocked.emit(id)

# Autosaves only when gameplay state has changed and a game is active.
func _autosave() -> void:
	if _dirty and not data.is_empty():
		save_game()

# Writes a checksummed save through a temporary file and protects the previous save with a backup.
func save_game(path_override: String = "") -> bool:
	if data.is_empty():
		return false
	var target := save_path if path_override.is_empty() else path_override
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({"payload": payload, "checksum": payload.sha256_text()})
	var temp := target + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		save_error = "ذخیرهسازی انجام نشد؛ فضای خالی دستگاه را بررسی کن."
		return false
	file.store_string(envelope)
	file.flush()
	file.close()
	# Back up only the normal save path; a failed backup leaves the current save untouched.
	if path_override.is_empty() and FileAccess.file_exists(target):
		var old := _read_save(target)
		if not old.is_empty():
			var backup_err := DirAccess.copy_absolute(target, backup_path)
			if backup_err != OK:
				save_error = "ساخت نسخهٔ پشتیبان انجام نشد؛ ذخیرهٔ اصلی جایگزین نشد."
				return false
	# Atomic replacement prevents a partially written envelope from becoming the live save.
	var err := DirAccess.rename_absolute(temp, target)
	if err != OK:
		save_error = "جابهجایی فایل ذخیره انجام نشد."
		return false
	_dirty = false
	if path_override.is_empty():
		save_available = true
	save_error = ""
	return true

# Reads a bounded save envelope, verifies its checksum, migrates it, and validates the resulting state.
func _read_save(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 2000000:
		if file != null:
			file.close()
		return {}
	var source := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary or not parsed.get("payload") is String or not parsed.get("checksum") is String:
		return {}
	if String(parsed.payload).sha256_text() != String(parsed.checksum):
		return {}
	if parser.parse(String(parsed.payload)) != OK:
		return {}
	var state = _migrate_state(parser.data)
	if not _valid_save(state):
		return {}
	return state

# Upgrades older save schemas in place while rejecting structurally unsafe input.
func _migrate_state(state: Variant) -> Variant:
	if not state is Dictionary:
		return state
	# Validate the shared containers before applying any version-specific defaults.
	var raw_version: Variant = state.get("version", 0)
	if not (raw_version is int or raw_version is float):
		return state
	if not state.get("zones") is Dictionary or not state.get("stats") is Dictionary or not state.get("memorials") is Array:
		return state
	if state.has("tutorials") and not state.tutorials is Array:
		return state
	if state.has("compost_station") and not state.compost_station is Dictionary:
		return state
	if state.stats.has("planted") and not _is_number(state.stats.planted):
		return state
	if not state.has("chapter") or not (state.chapter is int or state.chapter is float):
		return state
	for zone in LOCATIONS:
		var zone_data: Variant = state.zones.get(zone)
		if not zone_data is Dictionary or not zone_data.get("plots") is Array:
			return state
		for plot in zone_data.plots:
			if not plot is Dictionary:
				return state
	for entry in state.memorials:
		if not entry is Dictionary:
			return state
	if not state.has("tutorials") or not state.tutorials is Array:
		state.tutorials = []
	var version := int(raw_version)
	if version == 1:
		# Version two introduced healthy-day tracking, compost state, and tutorial resets.
		state.version = 2
		state.time_of_day = 1.0
		state.tutorials = []
		state.compost_station = {"built": false, "construction_done": false, "batch_active": false, "ready_day": -1, "ready_compost": 0}
		for key in ["compost_built", "compost_batches", "plants_lost"]:
			var stat_value: Variant = state.stats.get(key, 0)
			if not _is_number(stat_value):
				return state
			state.stats[key] = int(stat_value)
		for zone in LOCATIONS:
			for plot in state.zones[zone].plots:
				var growth_value: Variant = plot.get("growth", 0)
				if not _is_number(growth_value):
					return state
				plot.healthy_days = int(growth_value)
				plot.dead = false
				plot.neglect_days = 0
	if version <= 2:
		# Version three renamed retired species in both plots and memorial metadata.
		state.version = SAVE_VERSION
		for zone in LOCATIONS:
			for plot in state.zones[zone].plots:
				if String(plot.species) == "rose":
					plot.species = "arghavan"
				elif String(plot.species) == "lavender":
					plot.species = "olive"
		for entry in state.memorials:
			if String(entry.species) == "rose":
				entry.species = "arghavan"
			elif String(entry.species) == "lavender":
				entry.species = "olive"
		# Established saves should not be shown the first-run tutorial again.
		if int(state.chapter) > 1 or int(state.stats.planted) > 0:
			if not state.tutorials.has("first_run"):
				state.tutorials.append("first_run")
	if not state.has("compost_station"):
		state.compost_station = {"built": false, "construction_done": false, "batch_active": false, "ready_day": -1, "ready_compost": 0}
	elif not state.compost_station.has("ready_compost"):
		state.compost_station.ready_compost = 0
	if not state.has("npc_stories"):
		state.npc_stories = []
	return state

# Accepts only Godot numeric scalar types during save validation.
func _is_number(value: Variant) -> bool:
	return value is int or value is float

# Rejects NaN and infinity in addition to nonnumeric values.
func _is_finite_number(value: Variant) -> bool:
	return _is_number(value) and is_finite(float(value))

# Checks required fields, ranges, references, and uniqueness before a save is loaded.
func _valid_save(state: Variant) -> bool:
	if not state is Dictionary:
		return false
	# Every current-schema top-level field must be present.
	for key in ["version", "chapter", "zone", "day", "time_of_day", "scores", "resources", "completed", "progress", "seen", "zones", "achievements", "memorials", "quiz_solved", "tutorials", "compost_station", "stats", "player", "finished"]:
		if not state.has(key):
			return false
	if not _is_number(state.version) or not _is_number(state.chapter) or not _is_number(state.day):
		return false
	if int(state.version) != SAVE_VERSION or int(state.chapter) < 1 or int(state.chapter) > 8 or int(state.day) < 1:
		return false
	if state.zone not in LOCATIONS or not state.player is Array or state.player.size() != 2:
		return false
	if not _is_finite_number(state.player[0]) or not _is_finite_number(state.player[1]):
		return false
	if not _is_finite_number(state.time_of_day) or float(state.time_of_day) < 0.0 or float(state.time_of_day) >= 24.0:
		return false
	# Validate the container types shared by gameplay systems.
	for key in ["scores", "resources", "progress", "zones", "compost_station", "stats"]:
		if not state[key] is Dictionary:
			return false
	for key in ["completed", "seen", "achievements", "memorials", "quiz_solved", "tutorials"]:
		if not state[key] is Array:
			return false
	for value in state.progress.values():
		if not _is_finite_number(value) or float(value) < 0:
			return false
	# Optional story history remains compatible with saves created before NPC tracking.
	if state.has("npc_stories"):
		if not state.npc_stories is Array:
			return false
		for story_key in state.npc_stories:
			if not story_key is String:
				return false
			var parts := String(story_key).split(":")
			if parts.size() != 2 or parts[0] not in ["0", "1", "2", "3"] or not parts[1].is_valid_int() or int(parts[1]) < 1 or int(parts[1]) > 8:
				return false
	# Scores and resources must be finite and nonnegative.
	for key in ["eco", "social", "culture", "stars"]:
		if not state.scores.has(key) or not _is_finite_number(state.scores[key]) or float(state.scores[key]) < 0:
			return false
	for key in ["water", "seeds", "compost"]:
		if not state.resources.has(key) or not _is_finite_number(state.resources[key]) or float(state.resources[key]) < 0:
			return false
	# Compost flags, timers, and station capacity have strict schema bounds.
	for key in ["built", "construction_done", "batch_active", "ready_day", "ready_compost"]:
		if not state.compost_station.has(key):
			return false
	for key in ["built", "construction_done", "batch_active"]:
		if not state.compost_station[key] is bool:
			return false
	for key in ["ready_day", "ready_compost"]:
		if not _is_finite_number(state.compost_station[key]):
			return false
	if int(state.compost_station.ready_compost) < 0 or int(state.compost_station.ready_compost) > 6:
		return false
	for key in ["planted", "watered", "recycled", "helped", "compost_built", "compost_batches", "plants_lost"]:
		if not state.stats.has(key) or not _is_finite_number(state.stats[key]) or float(state.stats[key]) < 0:
			return false
	# Each location must contain exactly six structurally valid plots.
	for zone in LOCATIONS:
		if not state.zones.has(zone) or not state.zones[zone] is Dictionary:
			return false
		var saved_plots = state.zones[zone].get("plots")
		if not saved_plots is Array or saved_plots.size() != 6:
			return false
		for plot in saved_plots:
			if not plot is Dictionary:
				return false
			for key in ["prepared", "species", "stage", "moisture", "soil", "health", "growth", "healthy_days", "watered_day", "planted_day", "compost_day", "sun", "name", "dead", "neglect_days"]:
				if not plot.has(key):
					return false
			if not plot.prepared is bool or not plot.dead is bool or not plot.name is String:
				return false
			for key in ["stage", "moisture", "soil", "health", "growth", "healthy_days", "watered_day", "planted_day", "compost_day", "sun", "neglect_days"]:
				if not _is_finite_number(plot[key]):
					return false
			if not plot.species is String or not (plot.species == "" or not CONTENT.species_by_id(plot.species).is_empty()):
				return false
			if int(plot.stage) < 0 or int(plot.stage) > 5:
				return false
	# Memorial keys must match their zone and plot and cannot be duplicated.
	var memorial_keys := {}
	for entry in state.memorials:
		if not entry is Dictionary:
			return false
		for key in ["key", "zone", "plot", "name", "message", "day", "species"]:
			if not entry.has(key):
				return false
		if not entry.key is String or not entry.zone is String or not LOCATIONS.has(entry.zone):
			return false
		if not _is_finite_number(entry.plot) or float(entry.plot) != float(int(entry.plot)):
			return false
		var plot_index := int(entry.plot)
		if plot_index < 0 or plot_index >= 6 or String(entry.key) != String(entry.zone) + ":" + str(plot_index):
			return false
		if memorial_keys.has(String(entry.key)):
			return false
		memorial_keys[String(entry.key)] = true
		if not entry.name is String or not entry.message is String or not entry.species is String:
			return false
		if CONTENT.species_by_id(String(entry.species)).is_empty() or not _is_finite_number(entry.day) or int(entry.day) < 1:
			return false
	return true

func has_valid_save() -> bool:
	return not _read_save(save_path).is_empty() or not _read_save(backup_path).is_empty()

func load_game(path_override: String = "") -> bool:
	var target := save_path if path_override.is_empty() else path_override
	var saved := _read_save(target)
	if saved.is_empty() and path_override.is_empty():
		saved = _read_save(backup_path)
		if not saved.is_empty():
			notification.emit("نسخهٔ پشتیبان پیشرفت بازی بازیابی شد.")
	if saved.is_empty():
		save_available = false
		save_error = "ذخیرهٔ معتبری پیدا نشد؛ میتوانی بازی تازه شروع کنی."
		return false
	save_available = true
	data = saved
	_credit_existing_memorials()
	var story_mission_repaired := _credit_story_mission()
	_touch()
	if story_mission_repaired:
		save_game()
	return true

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	for key in DEFAULT_SETTINGS:
		var value = config.get_value("game", key, DEFAULT_SETTINGS[key])
		if key in ["music", "sound"] and _is_finite_number(value):
			settings[key] = clampf(float(value), 0.0, 1.0)
		elif key == "day_length" and _is_finite_number(value):
			settings[key] = clampf(float(value), 120.0, 480.0)
		elif key in ["touch", "reduced_motion"] and value is bool:
			settings[key] = value

func set_setting(key: String, value: Variant) -> bool:
	if not DEFAULT_SETTINGS.has(key):
		return false
	if key in ["music", "sound"]:
		if not _is_finite_number(value):
			return false
		settings[key] = clampf(float(value), 0.0, 1.0)
	elif key == "day_length":
		if not _is_finite_number(value):
			return false
		settings[key] = clampf(float(value), 120.0, 480.0)
	elif key in ["touch", "reduced_motion"]:
		if value is not bool:
			return false
		settings[key] = value
	save_settings()
	return true

func reset_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in DEFAULT_SETTINGS:
		config.set_value("game", key, settings[key])
	var error := config.save(settings_path)
	if error != OK:
		push_error("SETTINGS_SAVE_FAILED: " + error_string(error))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not data.is_empty():
			save_game()
