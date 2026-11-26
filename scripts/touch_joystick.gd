extends Control

signal direction_changed(direction: Vector2)

# Only one touch controls the stick, and its released state always maps to zero movement.
var _finger := -1
var _direction := Vector2.ZERO

# Sets a fixed touch target that consumes input instead of passing it through.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(150, 150)
	size = Vector2(150, 150)

# Clears held input when the app pauses or loses focus to prevent stuck movement.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		reset()

# Tracks a touch that starts inside the stick and ignores drags from other fingers.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		reset()
		return
	if event is InputEventScreenTouch:
		# Capture a new press only when no other finger already owns the joystick.
		if event.pressed and _finger == -1 and get_global_rect().has_point(event.position):
			_finger = event.index
			_update_direction(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _finger:
			reset()
	elif event is InputEventScreenDrag and event.index == _finger:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()

# Converts the touch offset to a clamped direction with a small neutral dead zone.
func _update_direction(point: Vector2) -> void:
	var center := get_global_rect().get_center()
	_direction = ((point - center) / 52.0).limit_length()
	if _direction.length() < 0.15:
		_direction = Vector2.ZERO
	direction_changed.emit(_direction)
	queue_redraw()

# Releases the active finger and emits neutral movement only when the direction changes.
func reset() -> void:
	_finger = -1
	if _direction != Vector2.ZERO:
		_direction = Vector2.ZERO
		direction_changed.emit(_direction)
		queue_redraw()

# Draws the fixed base and the movable thumb using the current normalized direction.
func _draw() -> void:
	draw_circle(Vector2(75, 75), 62, Color(0.07, 0.18, 0.12, 0.35))
	draw_arc(Vector2(75, 75), 62, 0, TAU, 40, Color(1, 0.94, 0.8, 0.5), 3)
	draw_circle(Vector2(75, 75) + _direction * 38, 29, Color(0.93, 0.85, 0.63, 0.8))
	draw_arc(Vector2(75, 75) + _direction * 38, 29, 0, TAU, 28, Color(1, 0.97, 0.84, 0.8), 3)
