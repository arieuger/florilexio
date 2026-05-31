extends CharacterBody2D

signal auto_move_finished(reached: bool)

@export var max_speed := 60.0
@export var acceleration := 420.0
@export var deceleration := 520.0
@export var auto_move_stop_distance := 2.0
@export var auto_move_timeout := 5.0
@export var auto_move_stuck_distance := 0.1
@export var auto_move_stuck_time := 0.8
@export var auto_move_stuck_speed := 3.0
@export var movement_enabled := true
@export var pathfinding_enabled := true
@export var pathfinding_cell_size := 4.0
@export var pathfinding_bounds := Rect2(0, 0, 320, 180)
@export var pathfinding_agent_size := Vector2(4, 2)
@export var pathfinding_waypoint_distance := 4.0
@export var pathfinding_nearest_target_radius := 32.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound_listener: Node2D = $SoundListener

var _last_facing := "down"
var _auto_move_target := Vector2.ZERO
var _auto_move_path: PackedVector2Array = []
var _auto_move_path_index := 0
var _auto_move_elapsed := 0.0
var _auto_move_current_timeout := 0.0
var _auto_move_stuck_elapsed := 0.0
var _auto_move_previous_distance := INF
var _auto_move_previous_position := Vector2.ZERO
var _is_auto_moving := false
var _last_sound_listener_transform := Transform2D()
var _has_synced_sound_listener := false

func _ready():
	add_to_group("player")
	resync_sound_listener()

func _unhandled_input(event):
	if not movement_enabled:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_auto_move(get_global_mouse_position())

func _physics_process(delta: float):
	if not movement_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		_update_animation(Vector2.ZERO)
		move_and_slide()
		_sync_sound_listener_to_fmod()
		return

	var input_direction := Input.get_vector("left", "right", "up", "down")

	if _is_auto_moving and input_direction != Vector2.ZERO:
		_finish_auto_move(false)

	if _is_auto_moving:
		_process_auto_move(delta)
	else:
		_process_player_input(delta, input_direction)

	move_and_slide()
	_sync_sound_listener_to_fmod()

	if _is_auto_moving:
		_check_auto_move_stuck(delta)

func move_to_point(global_target: Vector2) -> bool:
	if not movement_enabled:
		return false

	if global_position.distance_to(global_target) <= auto_move_stop_distance:
		return true

	if not start_auto_move(global_target):
		return false

	return await auto_move_finished

func start_auto_move(global_target: Vector2) -> bool:
	if not movement_enabled:
		return false

	if _is_auto_moving:
		_finish_auto_move(false)		

	var next_path := _find_auto_move_path(global_target)
	if next_path.is_empty():
		return false

	_auto_move_target = global_target
	_auto_move_path = next_path
	_auto_move_path_index = 0
	_auto_move_elapsed = 0.0
	_auto_move_current_timeout = maxf(auto_move_timeout, _get_path_length(next_path) / max_speed + 1.0)
	_auto_move_stuck_elapsed = 0.0
	_auto_move_previous_distance = global_position.distance_to(_get_current_auto_move_target())
	_auto_move_previous_position = global_position
	_is_auto_moving = true
	return true

func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not movement_enabled and _is_auto_moving:
		_finish_auto_move(false)

func _process_player_input(delta: float, input_direction: Vector2):
	var target_velocity := input_direction * max_speed

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)	

	play_footstep(delta)
	_update_animation(input_direction)

func _process_auto_move(delta: float):
	_auto_move_elapsed += delta

	_skip_reachable_auto_move_waypoints()
	var current_target := _get_current_auto_move_target()
	var target_offset := current_target - global_position
	var target_distance := target_offset.length()
	var arrival_distance := auto_move_stop_distance if _is_last_auto_move_waypoint() else pathfinding_waypoint_distance

	if target_distance <= arrival_distance:
		if _advance_auto_move_path():
			return
		_finish_auto_move(true)
		return

	if _auto_move_elapsed >= _auto_move_current_timeout:
		_finish_auto_move(false)
		return

	var move_direction := target_offset.normalized()
	velocity = velocity.move_toward(move_direction * max_speed, acceleration * delta)
	play_footstep(delta)
	_update_animation(move_direction)

func _finish_auto_move(reached: bool):
	_is_auto_moving = false
	_auto_move_path = []
	_auto_move_path_index = 0
	velocity = Vector2.ZERO
	_update_animation(Vector2.ZERO)
	auto_move_finished.emit(reached)

func _check_auto_move_stuck(delta: float):
	var current_distance := global_position.distance_to(_get_current_auto_move_target())
	var progress := _auto_move_previous_distance - current_distance
	var moved_distance := global_position.distance_to(_auto_move_previous_position)
	var is_moving := moved_distance > auto_move_stuck_speed * delta

	if progress <= auto_move_stuck_distance and not is_moving:
		_auto_move_stuck_elapsed += delta
	else:
		_auto_move_stuck_elapsed = 0.0

	_auto_move_previous_distance = current_distance
	_auto_move_previous_position = global_position

	if _auto_move_stuck_elapsed >= auto_move_stuck_time:
		_finish_auto_move(false)

func _get_current_auto_move_target() -> Vector2:
	if _auto_move_path_index >= 0 and _auto_move_path_index < _auto_move_path.size():
		return _auto_move_path[_auto_move_path_index]

	return _auto_move_target

func _advance_auto_move_path() -> bool:
	_auto_move_path_index += 1
	if _auto_move_path_index < _auto_move_path.size():
		_auto_move_stuck_elapsed = 0.0
		_auto_move_previous_distance = global_position.distance_to(_get_current_auto_move_target())
		_auto_move_previous_position = global_position
		return true

	return false

func _is_last_auto_move_waypoint() -> bool:
	return _auto_move_path_index >= _auto_move_path.size() - 1

func _skip_reachable_auto_move_waypoints() -> void:
	while _auto_move_path_index + 1 < _auto_move_path.size():
		var next_target := _auto_move_path[_auto_move_path_index + 1]
		if not _is_pathfinding_segment_walkable(global_position, next_target):
			return

		_auto_move_path_index += 1
		_auto_move_stuck_elapsed = 0.0
		_auto_move_previous_distance = global_position.distance_to(_get_current_auto_move_target())
		_auto_move_previous_position = global_position

func _find_auto_move_path(global_target: Vector2) -> PackedVector2Array:
	if not pathfinding_enabled:
		return PackedVector2Array([global_target])

	if not pathfinding_bounds.has_point(global_target):
		return PackedVector2Array()

	var start_cell := _pathfinding_cell_from_position(global_position)
	var target_cell := _pathfinding_cell_from_position(global_target)
	var grid_size := _pathfinding_grid_size()

	if not _is_cell_inside_pathfinding_bounds(start_cell, grid_size) or not _is_cell_inside_pathfinding_bounds(target_cell, grid_size):
		return PackedVector2Array()

	var astar := AStar2D.new()
	var walkable_cells := {}

	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			var point := _pathfinding_position_from_cell(cell)
			if _is_pathfinding_point_walkable(point):
				var point_id := _pathfinding_cell_id(cell, grid_size.x)
				walkable_cells[cell] = true
				astar.add_point(point_id, point)

	if not walkable_cells.has(start_cell):
		return PackedVector2Array()

	var target_is_walkable := _is_pathfinding_point_walkable(global_target)
	var target_point_id := _pathfinding_cell_id(target_cell, grid_size.x)
	var reachable_target := global_target
	var use_exact_target_point := target_is_walkable and not walkable_cells.has(target_cell)

	if use_exact_target_point:
		target_point_id = grid_size.x * grid_size.y
		astar.add_point(target_point_id, global_target)
	elif not target_is_walkable:
		target_cell = _get_nearest_walkable_target_cell(target_cell, global_target, walkable_cells, grid_size)
		if not walkable_cells.has(target_cell):
			return PackedVector2Array()

		target_point_id = _pathfinding_cell_id(target_cell, grid_size.x)
		reachable_target = _pathfinding_position_from_cell(target_cell)

	for cell in walkable_cells.keys():
		var cell_id := _pathfinding_cell_id(cell, grid_size.x)
		for offset in _get_pathfinding_neighbor_offsets():
			var neighbor: Vector2i = cell + offset
			if not walkable_cells.has(neighbor):
				continue
			if offset.x != 0 and offset.y != 0:
				if not walkable_cells.has(Vector2i(cell.x + offset.x, cell.y)) or not walkable_cells.has(Vector2i(cell.x, cell.y + offset.y)):
					continue

			var neighbor_id := _pathfinding_cell_id(neighbor, grid_size.x)
			if not astar.are_points_connected(cell_id, neighbor_id):
				astar.connect_points(cell_id, neighbor_id)

	if use_exact_target_point:
		_connect_exact_target_point(astar, target_point_id, global_target, walkable_cells, grid_size)

	var id_path := astar.get_id_path(_pathfinding_cell_id(start_cell, grid_size.x), target_point_id)
	if id_path.is_empty():
		return PackedVector2Array()

	var path := PackedVector2Array()
	for point_id in id_path:
		path.append(astar.get_point_position(point_id))

	if path.size() > 0:
		path.remove_at(0)

	path = _smooth_auto_move_path(path)

	path = _add_reachable_target_to_auto_move_path(path, reachable_target, target_is_walkable)

	return path

func _connect_exact_target_point(astar: AStar2D, target_point_id: int, global_target: Vector2, walkable_cells: Dictionary, grid_size: Vector2i) -> void:
	var target_cell := _pathfinding_cell_from_position(global_target)
	var max_cell_radius := ceili(pathfinding_nearest_target_radius / pathfinding_cell_size)

	for y in range(target_cell.y - max_cell_radius, target_cell.y + max_cell_radius + 1):
		for x in range(target_cell.x - max_cell_radius, target_cell.x + max_cell_radius + 1):
			var candidate := Vector2i(x, y)
			if not _is_cell_inside_pathfinding_bounds(candidate, grid_size):
				continue
			if not walkable_cells.has(candidate):
				continue

			var candidate_position := _pathfinding_position_from_cell(candidate)
			if candidate_position.distance_to(global_target) > pathfinding_nearest_target_radius:
				continue
			if not _is_pathfinding_segment_walkable(candidate_position, global_target):
				continue

			astar.connect_points(_pathfinding_cell_id(candidate, grid_size.x), target_point_id)

func _add_reachable_target_to_auto_move_path(path: PackedVector2Array, reachable_target: Vector2, target_is_walkable: bool) -> PackedVector2Array:
	var approach_origin := global_position if path.is_empty() else path[path.size() - 1]
	if not _is_pathfinding_segment_walkable(approach_origin, reachable_target):
		return PackedVector2Array() if target_is_walkable else path

	if path.is_empty() or path[path.size() - 1].distance_to(reachable_target) > pathfinding_waypoint_distance:
		path.append(reachable_target)
	else:
		path[path.size() - 1] = reachable_target

	return path

func _get_nearest_walkable_target_cell(target_cell: Vector2i, global_target: Vector2, walkable_cells: Dictionary, grid_size: Vector2i) -> Vector2i:
	if walkable_cells.has(target_cell):
		return target_cell

	var max_cell_radius := ceili(pathfinding_nearest_target_radius / pathfinding_cell_size)
	var nearest_cell := Vector2i(-1, -1)
	var nearest_distance := INF

	for radius in range(1, max_cell_radius + 1):
		for y in range(target_cell.y - radius, target_cell.y + radius + 1):
			for x in range(target_cell.x - radius, target_cell.x + radius + 1):
				if abs(x - target_cell.x) != radius and abs(y - target_cell.y) != radius:
					continue

				var candidate := Vector2i(x, y)
				if not _is_cell_inside_pathfinding_bounds(candidate, grid_size):
					continue
				if not walkable_cells.has(candidate):
					continue

				var candidate_position := _pathfinding_position_from_cell(candidate)
				var candidate_distance := candidate_position.distance_squared_to(global_target)
				if candidate_distance < nearest_distance:
					nearest_cell = candidate
					nearest_distance = candidate_distance

		if nearest_cell != Vector2i(-1, -1):
			return nearest_cell

	return nearest_cell

func _smooth_auto_move_path(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2:
		return path

	var smoothed_path := PackedVector2Array()
	var anchor := global_position
	var index := 0

	while index < path.size():
		var furthest_reachable_index := index
		for candidate_index in range(path.size() - 1, index - 1, -1):
			if _is_pathfinding_segment_walkable(anchor, path[candidate_index]):
				furthest_reachable_index = candidate_index
				break

		var next_point := path[furthest_reachable_index]
		smoothed_path.append(next_point)
		anchor = next_point
		index = furthest_reachable_index + 1

	return smoothed_path

func _get_path_length(path: PackedVector2Array) -> float:
	var total_length := 0.0
	var previous_point := global_position
	for point in path:
		total_length += previous_point.distance_to(point)
		previous_point = point

	return total_length

func _pathfinding_grid_size() -> Vector2i:
	return Vector2i(
		ceili(pathfinding_bounds.size.x / pathfinding_cell_size),
		ceili(pathfinding_bounds.size.y / pathfinding_cell_size)
	)

func _pathfinding_cell_from_position(global_point: Vector2) -> Vector2i:
	var local_point := global_point - pathfinding_bounds.position
	return Vector2i(
		floori(local_point.x / pathfinding_cell_size),
		floori(local_point.y / pathfinding_cell_size)
	)

func _pathfinding_position_from_cell(cell: Vector2i) -> Vector2:
	return pathfinding_bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * pathfinding_cell_size

func _pathfinding_cell_id(cell: Vector2i, grid_width: int) -> int:
	return cell.y * grid_width + cell.x

func _is_cell_inside_pathfinding_bounds(cell: Vector2i, grid_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

func _is_pathfinding_point_walkable(global_point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = pathfinding_agent_size
	query.shape = shape
	query.transform = Transform2D(0.0, global_point)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]

	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _is_pathfinding_segment_walkable(from: Vector2, to: Vector2) -> bool:
	var distance := from.distance_to(to)
	var step_count := ceili(distance / (pathfinding_cell_size * 0.5))

	for step in range(1, step_count + 1):
		var point := from.lerp(to, float(step) / float(step_count))
		if not _is_pathfinding_point_walkable(point):
			return false

	return true

func _get_pathfinding_neighbor_offsets() -> Array[Vector2i]:
	return [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1),
	]

func _update_animation(direction: Vector2):
	if direction == Vector2.ZERO:
		_play_animation_if_needed("idle_" + _last_facing)
	elif direction.y < 0:
		_last_facing = "up"
		_play_animation_if_needed("walk_up")
	else:
		_last_facing = "down"
		_play_animation_if_needed("walk_down")

func _play_animation_if_needed(animation_name: String) -> void:
	if animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return

	animated_sprite.play(animation_name)

# Sounds
const MIN_STEP_GAP := 0.25  # segundos mínimos entre pasos
const STEP_INTERVAL := 1.5
var last_step_time := 0.0
var step_distance := 0.0

func play_footstep(delta):
	if velocity.length() > 10.0:
		step_distance += velocity.length() * delta
		if step_distance >= STEP_INTERVAL:
			step_distance = fmod(step_distance, STEP_INTERVAL)
			play_footstep_sound()
	else:
		step_distance = 0.0  # reset ao parar

func play_footstep_sound():
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_step_time < MIN_STEP_GAP:
		return
	last_step_time = now

	SoundManager.play_simple_sound("Player/Steps")

# Funcións necesarias para que o SoundListener do Player siga funcionando cando se introduce na escea

func resync_sound_listener() -> void:
	force_update_transform()
	if is_instance_valid(sound_listener):
		sound_listener.force_update_transform()
	_sync_sound_listener_to_fmod(true)
	call_deferred("_deferred_resync_sound_listener")

func _deferred_resync_sound_listener() -> void:
	force_update_transform()
	if is_instance_valid(sound_listener):
		sound_listener.force_update_transform()
	_sync_sound_listener_to_fmod(true)

func _sync_sound_listener_to_fmod(force: bool = false) -> void:
	if not is_instance_valid(sound_listener):
		return
	if not FmodServer.has_method("set_listener_transform2d"):
		return

	var listener_transform := sound_listener.global_transform
	if not force and _has_synced_sound_listener and listener_transform == _last_sound_listener_transform:
		return

	FmodServer.set_listener_transform2d(_get_sound_listener_index(), listener_transform)
	_last_sound_listener_transform = listener_transform
	_has_synced_sound_listener = true

func _get_sound_listener_index() -> int:
	if not is_instance_valid(sound_listener):
		return 0

	for property in sound_listener.get_property_list():
		var property_name := StringName(property.get("name", ""))
		if property_name == &"listener_index" or property_name == &"listener_number":
			return int(sound_listener.get(property_name))

	return 0
