class_name TouchActionButton
extends Button

# Preserve Button visuals while routing each screen touch independently for multitouch gameplay.
var _touch_index := -1

# Disable single-pointer mouse emulation so custom touch handling cannot fire twice.
func _ready() -> void:
	button_mask = MOUSE_BUTTON_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

# Releases held input when focus, pause, or visibility changes.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_VISIBILITY_CHANGED]:
		_cancel_input()

# Handles each finger separately while retaining mouse input for desktop testing.
func _gui_input(event: InputEvent) -> void:
	if disabled:
		_cancel_input()
		return
	if event is InputEventScreenTouch:
		if event.canceled or (not event.pressed and event.index == -1):
			_cancel_input()
			accept_event()
			return
		if event.pressed and _touch_index == -1 and Rect2(Vector2.ZERO, size).has_point(event.position):
			_touch_index = event.index
			_press()
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				_release()
			else:
				_cancel_input()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		if not Rect2(Vector2.ZERO, size).has_point(event.position):
			_cancel_input()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _touch_index == -1 and Rect2(Vector2.ZERO, size).has_point(event.position):
			_touch_index = -2
			_press()
			accept_event()
		elif not event.pressed and _touch_index == -2:
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				_release()
			else:
				_cancel_input()
			accept_event()

# Applies normal Button press feedback without relying on touch-to-mouse emulation.
func _press() -> void:
	set_pressed_no_signal(true)
	button_down.emit()

# Emits one action on release and restores the normal visual state.
func _release() -> void:
	if _touch_index == -1:
		return
	_touch_index = -1
	set_pressed_no_signal(false)
	button_up.emit()
	pressed.emit()

# Clears any held finger or mouse state without emitting an action.
func _cancel_input() -> void:
	if _touch_index == -1:
		return
	_touch_index = -1
	set_pressed_no_signal(false)
	button_up.emit()
