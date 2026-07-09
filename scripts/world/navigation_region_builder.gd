extends NavigationRegion2D

@export var outer_outline := PackedVector2Array()
@export var obstacle_padding := 1.0
@export_range(6, 32, 1) var circle_segments := 12


func _ready() -> void:
	call_deferred("_rebuild_navigation_polygon")


func _rebuild_navigation_polygon() -> void:
	if outer_outline.size() < 3:
		push_warning("NavigationRegionBuilder requires an outer outline with at least three points")
		return

	var walkable_polygons: Array[PackedVector2Array] = [_ensure_clockwise(outer_outline)]
	var obstacle_polygons: Array[PackedVector2Array] = _collect_obstacle_polygons()
	for obstacle_polygon in obstacle_polygons:
		var typed_obstacle_polygon: PackedVector2Array = obstacle_polygon
		if typed_obstacle_polygon.size() < 3:
			continue

		var expanded_obstacles: Array[PackedVector2Array] = [typed_obstacle_polygon]
		if obstacle_padding > 0.0:
			var offset_polygons: Array[PackedVector2Array] = Geometry2D.offset_polygon(typed_obstacle_polygon, obstacle_padding)
			if not offset_polygons.is_empty():
				expanded_obstacles = offset_polygons

		for expanded_obstacle in expanded_obstacles:
			var typed_expanded_obstacle: PackedVector2Array = expanded_obstacle
			walkable_polygons = _subtract_polygon_list(walkable_polygons, typed_expanded_obstacle)
			if walkable_polygons.is_empty():
				break

	if walkable_polygons.is_empty():
		push_warning("NavigationRegionBuilder produced an empty navigation polygon")
		return

	self.navigation_polygon = _build_navigation_polygon_from_walkable_polygons(walkable_polygons)


func _subtract_polygon_list(polygons: Array[PackedVector2Array], obstacle: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []

	for polygon in polygons:
		var typed_polygon: PackedVector2Array = polygon
		var difference: Array[PackedVector2Array] = Geometry2D.exclude_polygons(typed_polygon, obstacle)
		if difference.is_empty():
			var intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(typed_polygon, obstacle)
			if not intersections.is_empty():
				continue
			result.append(typed_polygon)
			continue

		for difference_polygon in difference:
			var typed_difference_polygon: PackedVector2Array = difference_polygon
			if typed_difference_polygon.size() >= 3:
				result.append(_ensure_clockwise(typed_difference_polygon))

	return result


func _build_navigation_polygon_from_walkable_polygons(walkable_polygons: Array[PackedVector2Array]) -> NavigationPolygon:
	var navigation_polygon := NavigationPolygon.new()
	var navigation_vertices := PackedVector2Array()

	for polygon in walkable_polygons:
		var typed_polygon: PackedVector2Array = polygon
		if typed_polygon.size() < 3:
			continue

		var simple_polygon := _ensure_counter_clockwise(typed_polygon)
		var triangle_indices: PackedInt32Array = Geometry2D.triangulate_polygon(simple_polygon)
		if triangle_indices.is_empty():
			continue

		var vertex_offset := navigation_vertices.size()
		for point in simple_polygon:
			var typed_point: Vector2 = point
			navigation_vertices.append(typed_point)

		for triangle_index in range(0, triangle_indices.size(), 3):
			navigation_polygon.add_polygon(PackedInt32Array([
				vertex_offset + triangle_indices[triangle_index],
				vertex_offset + triangle_indices[triangle_index + 1],
				vertex_offset + triangle_indices[triangle_index + 2],
			]))

	navigation_polygon.vertices = navigation_vertices
	return navigation_polygon


func _collect_obstacle_polygons() -> Array[PackedVector2Array]:
	var source_root: Node = get_parent()
	var polygons: Array[PackedVector2Array] = []

	if not is_instance_valid(source_root):
		return polygons

	for static_body in source_root.find_children("*", "StaticBody2D", true, false):
		var body := static_body as StaticBody2D
		if not body or not _should_include_static_body(body):
			continue

		for child in body.find_children("*", "CollisionPolygon2D", true, false):
			var collision_polygon := child as CollisionPolygon2D
			if not collision_polygon or collision_polygon.disabled or collision_polygon.polygon.size() < 3:
				continue
			polygons.append(_transform_polygon(collision_polygon.polygon, collision_polygon.global_transform))

		for child in body.find_children("*", "CollisionShape2D", true, false):
			var collision_shape := child as CollisionShape2D
			if not collision_shape or collision_shape.disabled or not collision_shape.shape:
				continue

			var polygon := _polygon_from_shape(collision_shape.shape, collision_shape.global_transform)
			if polygon.size() >= 3:
				polygons.append(polygon)

	return polygons


func _should_include_static_body(body: StaticBody2D) -> bool:
	if body.name == "WorldCollision":
		return true

	var current: Node = body
	while is_instance_valid(current):
		var script: Variant = current.get_script()
		if script is GDScript:
			var typed_script: GDScript = script as GDScript
			var script_path: String = typed_script.resource_path
			if script_path.ends_with("collectable_plant.gd"):
				return false
		current = current.get_parent()

	return true


func _polygon_from_shape(shape: Shape2D, global_transform: Transform2D) -> PackedVector2Array:
	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		var half_size := rectangle.size * 0.5
		return _transform_polygon(
			PackedVector2Array([
				Vector2(-half_size.x, -half_size.y),
				Vector2(half_size.x, -half_size.y),
				Vector2(half_size.x, half_size.y),
				Vector2(-half_size.x, half_size.y),
			]),
			global_transform
		)

	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return _transform_polygon(_build_circle_polygon(circle.radius), global_transform)

	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return _transform_polygon(_build_capsule_polygon(capsule.radius, capsule.height), global_transform)

	return PackedVector2Array()


func _build_circle_polygon(radius: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var segment_count: int = max(circle_segments, 6)

	for index in range(segment_count):
		var angle := TAU * float(index) / float(segment_count)
		polygon.append(Vector2(cos(angle), sin(angle)) * radius)

	return polygon


func _build_capsule_polygon(radius: float, height: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var segment_count: int = max(circle_segments, 6)
	var half_body_height := maxf(0.0, height * 0.5 - radius)
	var half_segments: int = max(segment_count / 2, 3)

	for index in range(half_segments + 1):
		var angle := lerpf(PI, 0.0, float(index) / float(half_segments))
		polygon.append(Vector2(cos(angle), sin(angle)) * radius + Vector2(0.0, -half_body_height))

	for index in range(half_segments + 1):
		var angle := lerpf(0.0, PI, float(index) / float(half_segments))
		polygon.append(Vector2(cos(angle), sin(angle)) * radius + Vector2(0.0, half_body_height))

	return polygon


func _transform_polygon(polygon: PackedVector2Array, transform_2d: Transform2D) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in polygon:
		var typed_point: Vector2 = point
		transformed.append(transform_2d * typed_point)
	return transformed


func _ensure_clockwise(polygon: PackedVector2Array) -> PackedVector2Array:
	if Geometry2D.is_polygon_clockwise(polygon):
		return polygon

	var reversed_polygon := PackedVector2Array()
	for index in range(polygon.size() - 1, -1, -1):
		reversed_polygon.append(polygon[index])
	return reversed_polygon


func _ensure_counter_clockwise(polygon: PackedVector2Array) -> PackedVector2Array:
	if not Geometry2D.is_polygon_clockwise(polygon):
		return polygon

	var reversed_polygon := PackedVector2Array()
	for index in range(polygon.size() - 1, -1, -1):
		reversed_polygon.append(polygon[index])
	return reversed_polygon
