class_name PlayerController
extends CharacterBody2D

# Move the player with touch or keyboard input while respecting world collision and animation state.
const SPEED: float = 180.0
const FOOT_RADIUS: float = 9.0
const NPC_RADIUS: float = 18.0
const WALK_BOUNDS: Rect2 = Rect2(120.0, 200.0, 1050.0, 435.0)

var motion: Vector2 = Vector2.ZERO
var blocked_rects: Array[Rect2] = []
var blocked_points: Array[Vector2] = []
var external_direction: Vector2 = Vector2.ZERO
var enabled: bool = true:
	# Disabling input clears momentum and animation so the player cannot keep sliding.
	set(value):
		enabled = value
		if not enabled:
			motion = Vector2.ZERO
			velocity = Vector2.ZERO
			_frame = 0
			queue_redraw()

var _frames: Array[Texture2D] = []
var _row: int = 0
var _facing_row: int = 0
var _frame: int = 0
var _walk_time: float = 0.0
var _step_time: float = 0.0
var _action := ""
var _action_time: float = 0.0
var _reaction_time: float = 0.0

# Loads the sprite grid and places the player at the nearest safe starting position.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for row in range(6):
		for column in range(4):
			_frames.append(GameAtlas.cell("player.svg", column, row))
	position = safe_position(position)
	queue_redraw()

# Accepts normalized movement from touch controls without exceeding walking speed.
func set_external_direction(direction: Vector2) -> void:
	external_direction = direction.limit_length(1.0)

# Plays a supported garden action animation and temporarily suppresses walking.
func play_action(action: String) -> void:
	if action not in ["water", "plant", "collect", "compost"]:
		return
	_action = action
	_action_time = 0.72
	_walk_time = 0.0
	_row = 4 if action == "water" else 5
	_frame = 0
	queue_redraw()

# Triggers the short NPC reaction bounce without changing movement input.
func react() -> void:
	_reaction_time = 0.72
	queue_redraw()

# Updates timers, combines touch and keyboard movement, and animates only actual motion.
func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if _reaction_time > 0.0:
		_reaction_time = maxf(0.0, _reaction_time - delta)
		queue_redraw()
	# Action frames take precedence over locomotion until their timer expires.
	if _action_time > 0.0:
		_action_time = maxf(0.0, _action_time - delta)
		_walk_time += delta
		_frame = int(_walk_time / 0.16) % 4
		if _action_time <= 0.0:
			_action = ""
			_row = _facing_row
			_frame = 0
		queue_redraw()
		return
	var direction := external_direction.limit_length(1.0)
	direction.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	direction.x -= float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	direction.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	direction.y -= float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	direction = direction.limit_length(1.0)
	var before := position
	# Small, axis-separated steps prevent tunnelling without physics colliders.
	var displacement := direction * SPEED * minf(delta, 0.1)
	var steps := maxi(1, int(ceil(displacement.length() / 4.0)))
	var step := displacement / float(steps)
	for i in range(steps):
		var candidate := position + Vector2(step.x, 0.0)
		if can_stand_at(candidate):
			position.x = candidate.x
		candidate = position + Vector2(0.0, step.y)
		if can_stand_at(candidate):
			position.y = candidate.y
	motion = (position - before) / maxf(delta, 0.00001)
	velocity = motion
	var old_row := _row
	var old_frame := _frame
	_step_time = maxf(0.0, _step_time - delta)
	# Facing follows input even when an obstacle prevents translation.
	if direction.length_squared() > 0.01:
		if absf(direction.x) > absf(direction.y):
			_row = 3 if direction.x > 0.0 else 2
		else:
			_row = 0 if direction.y > 0.0 else 1
		_facing_row = _row
	if motion.length_squared() > 1.0:
		_walk_time += delta
		_frame = int(_walk_time / 0.13) % 4
		if _step_time <= 0.0:
			AudioManager.play_sfx("steps", randf_range(0.16, 0.22), randf_range(0.92, 1.08))
			_step_time = 0.28
	else:
		_walk_time = 0.0
		_frame = 0
		_step_time = 0.0
	if old_row != _row or old_frame != _frame:
		queue_redraw()

# Rejects positions outside walkable bounds or within scenery and NPC clearance radii.
func can_stand_at(point: Vector2) -> bool:
	if point.x < WALK_BOUNDS.position.x or point.x > WALK_BOUNDS.end.x:
		return false
	if point.y < WALK_BOUNDS.position.y or point.y > WALK_BOUNDS.end.y:
		return false
	for obstacle in blocked_rects:
		if obstacle.grow(FOOT_RADIUS).has_point(point):
			return false
	for obstacle in blocked_points:
		if point.distance_squared_to(obstacle) < pow(FOOT_RADIUS + NPC_RADIUS, 2.0):
			return false
	return true

# Clamps a requested position and searches outward if obstacles or NPCs occupy it.
func safe_position(requested: Vector2) -> Vector2:
	var point := Vector2(
		clampf(requested.x, WALK_BOUNDS.position.x, WALK_BOUNDS.end.x),
		clampf(requested.y, WALK_BOUNDS.position.y, WALK_BOUNDS.end.y)
	)
	if can_stand_at(point):
		return point
	# A saved position can fall inside a new NPC or scenery after a zone change.
	for ring in range(1, 49):
		for spoke in range(24):
			var angle := TAU * float(spoke) / 24.0
			var candidate := point + Vector2(cos(angle), sin(angle)) * float(ring) * 12.0
			if can_stand_at(candidate):
				return candidate
	return Vector2(660.0, 460.0)

# Draws the flattened shadow, reaction offset, and current sprite-frame texture.
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2(0.0, 3.0), 17.0, Color(0.08, 0.16, 0.12, 0.22))
	draw_set_transform(Vector2.ZERO)
	if not _frames.is_empty():
		var bounce := -absf(sin((0.72 - _reaction_time) * TAU * 1.5)) * 5.0 if _reaction_time > 0.0 else 0.0
		draw_set_transform(Vector2(0.0, bounce))
		draw_texture_rect(_frames[_row * 4 + _frame], Rect2(-38.4, -68.4, 76.8, 76.8), false)
		draw_set_transform(Vector2.ZERO)
