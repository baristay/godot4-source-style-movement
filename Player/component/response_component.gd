extends Node
class_name ResponseComponent

# --- Exports & Node References ---
var config: MovementConfig = preload("res://Player/resource/movement_config.tres")
@onready var col_comp: CollisionComponent = %CollisionComponent
@onready var input_comp: InputComponent = %InputComponent
@onready var body: CharacterBody3D = owner as CharacterBody3D
@onready var FLOOR_DOT: float = cos(deg_to_rad(config.slope_max_angle))
@onready var RAMP_DOT: float = cos(deg_to_rad(config.surf_max_angle))

# --- Enums ---
enum SurfaceType { NONE, FLOOR, RAMP, WALL, CEILING }
enum CurrentState { FLOOR, AIR, SURF }

# --- Public State ---
var surfaces: Array = [{"type": SurfaceType.NONE, "normal": Vector3.ZERO, "distance": 0}]
var collided_surfaces: Array = []
var cur_state_surfaces: Dictionary = {"type": CurrentState.AIR, "normal": Vector3.ZERO}

# --- Collide and Slide Parameters ---
const MAX_BOUNCE: int = 5
const MOTION_EPSILON: float = 3.9
const SAFE_MARGIN: float = 0.002
const SNAP_SAFE_MARGIN: float = 0.002
const COLLISION_CHECK_MARGIN: float = 0.0025
const DISTANCE_MARGIN: float = 0.003
const RAMP_DUPLICATE_DOT_THRESHOLD: float = 0.95

# --- Parameters ---
var snap_height: float = 0
var step_height: float = 0.0
var wasOnFloorLastFrame: bool = false
var snapped_normals: Array[Vector3] = []
var motion_epsilon: float = 0.0
var leaving_floor_motion: float = 0.0


func _ready() -> void:
	step_height = config.step_height
	snap_height = config.snap_height


func _resolve_motion(delta: float) -> void:
	motion_epsilon = MOTION_EPSILON * delta
	var start_position := body.global_position
	
	_handle_collision(body.velocity, delta)
	_update_collisions()
	_snap_down_update()
	if not snapped_normals.is_empty(): _update_collisions()
	
	var total := body.global_position - start_position
	_correct_velocity(body.velocity, total, delta)
	wasOnFloorLastFrame = cur_state_surfaces["type"] == CurrentState.FLOOR


func _handle_collision(velocity: Vector3, delta: float) -> void:
	var start_position := body.global_position
	var motion := velocity * delta
	var total := Vector3.ZERO
	collided_surfaces = []
	
	var bump_planes: Array[Vector3] = []
	var bump_is_floor: Array[bool] = []
	var bump_surf_types: Array = []
	
	var query_transform := body.global_transform
	
	for _i in MAX_BOUNCE:
		var is_on_floor: bool = false
		var result := col_comp._test_collision(col_comp.collision_shape.shape, query_transform, motion, true, false)
		if result.get_collision_count() == 0:
			total += motion
			break
		
		var normal := result.get_collision_normal()
		var surf_type := _classify(normal)
		var remainder := result.get_remainder()
		var travel := result.get_travel()
		
		total += travel
		query_transform.origin += travel
		
		_add_surface(collided_surfaces, surf_type, normal, travel.length())
		
		if surf_type == SurfaceType.WALL and Vector2(motion.x, motion.z).length() / delta >= motion_epsilon:
			var step := _step_up_update(query_transform, remainder, collided_surfaces, bump_planes, bump_is_floor, bump_surf_types)
			if not step.is_empty():
				start_position = step["start_position"]
				total = step["total"]
				query_transform = step["query_transform"]
				motion = step["motion"]
				continue
		
		if surf_type == SurfaceType.FLOOR:
			is_on_floor = true
		
		var is_new_plane := true
		for p in bump_planes:
			if p.is_equal_approx(normal):
				is_new_plane = false
				break
		
		if is_new_plane:
			for i in bump_planes.size():
				if bump_surf_types[i] == surf_type \
				and bump_planes[i].dot(normal) > RAMP_DUPLICATE_DOT_THRESHOLD:
					is_new_plane = false
					break
		
		if is_new_plane:
			bump_planes.append(normal)
			bump_is_floor.append(is_on_floor)
			bump_surf_types.append(surf_type)
		
		match bump_planes.size():
			1:
				if is_on_floor and absf(normal.y) > 0.001 and !normal.is_equal_approx(Vector3.UP):
					var horizontal_remainder := Vector3(remainder.x, 0.0, remainder.z)
					var dy: float = -(horizontal_remainder.dot(normal)) / normal.y
					if dy > 0:
						motion = Vector3(remainder.x, dy, remainder.z)
					else:
						motion = _slide(remainder, Vector3.UP if is_on_floor else normal)
				else:
					motion = _slide(remainder, Vector3.UP if is_on_floor else normal)
			2:
				var crease := bump_planes[0].cross(bump_planes[1])
				if crease.length_squared() > 0.0001:
					crease = crease.normalized()
					var signed_dist := remainder.dot(crease)
					motion = crease * signed_dist
				else:
					motion = _slide(remainder, Vector3.UP if is_on_floor else normal)
				
				var floor_idx := -1
				var other_idx := -1
				if bump_is_floor[0]:
					floor_idx = 0; other_idx = 1
				elif bump_is_floor[1]:
					floor_idx = 1; other_idx = 0
				
				if floor_idx != -1 and absf(bump_planes[other_idx].y) < 0.001:
					var floor_normal: Vector3 = bump_planes[floor_idx]
					if absf(floor_normal.y) > 0.001 and !floor_normal.is_equal_approx(Vector3.UP):
						var horizontal_vel := Vector3(motion.x, 0.0, motion.z)
						var dy2: float = -(horizontal_vel.dot(floor_normal)) / floor_normal.y
						if dy2 != 0.0:
							motion.y = dy2
			_:
				motion = Vector3.ZERO
		
		query_transform.origin += normal * DISTANCE_MARGIN
	
	if Vector2(total.x, total.z).length() / delta < motion_epsilon:
		total.x = 0.0
		total.z = 0.0
	
	col_comp._expand_collision(col_comp.collision_shape.shape, -(Vector3.ONE * SAFE_MARGIN))
	body.move_and_collide(total, false, 0, false, 1)
	col_comp._expand_collision(col_comp.collision_shape.shape, (Vector3.ONE * SAFE_MARGIN))
	body.move_and_collide(Vector3.ZERO, false, 0, false, 1)
	
	total = body.global_position - start_position
	
	if Vector2(total.x, total.z).length() / delta < motion_epsilon:
		body.global_position.x = start_position.x
		body.global_position.z = start_position.z
		total.x = 0.0
		total.z = 0.0
	body.force_update_transform()


func _correct_velocity(velocity: Vector3, motion: Vector3, delta: float):
	var out_velocity := velocity
	match surfaces.size():
		0:
			pass
		1:
			var n: Vector3 = Vector3.UP if surfaces[0]["type"] == SurfaceType.FLOOR else surfaces[0]["normal"]
			out_velocity = _slide(out_velocity, n)
		2:
			var floor_check := false
			for i in surfaces.size():
				if surfaces[i]["type"] == SurfaceType.FLOOR:
					floor_check = true
			
			var crease: Vector3 = surfaces[0]["normal"].cross(surfaces[1]["normal"])
			if crease.length_squared() > 0.0001:
				crease = crease.normalized()
				
				if floor_check:
					var flat_crease := Vector3(crease.x, 0.0, crease.z).normalized()
					out_velocity = flat_crease * out_velocity.dot(flat_crease)
				else:
					out_velocity = crease * out_velocity.dot(crease)
			else:
				out_velocity = _slide(out_velocity, surfaces[0]["normal"])
		_:
			out_velocity = Vector3.ZERO
	
	if Vector2(motion.x, motion.z).length() / delta < motion_epsilon:
		out_velocity.x = 0.0
		out_velocity.z = 0.0
	
	if (surfaces.size() > 0 or Vector2(motion.x, motion.z).length() / delta < 0.0001):
		body.velocity.x = out_velocity.x
		body.velocity.y = out_velocity.y
		body.velocity.z = out_velocity.z
	
	if cur_state_surfaces["type"] == CurrentState.FLOOR:
		body.velocity.y = 0.0
	
	if leaving_floor_motion < 0.0 and wasOnFloorLastFrame and cur_state_surfaces["type"] != CurrentState.FLOOR and !input_comp.isJumpRequested:
		body.velocity.y = leaving_floor_motion
	
	leaving_floor_motion = motion.y / delta


func _update_collisions() -> void:
	surfaces = []
	
	var result: PhysicsTestMotionResult3D
	
	result = _check_for_ground()
	if result.get_collision_count() != 0:
		var normal := result.get_collision_normal()
		_add_surface(surfaces, _classify(normal), normal, result.get_travel().length())
	
	for i in range(collided_surfaces.size()):
		_add_surface(surfaces, collided_surfaces[i]["type"], collided_surfaces[i]["normal"], collided_surfaces[i]["distance"])
	
	if not snapped_normals.is_empty():
		for n in snapped_normals:
			_add_surface(surfaces, SurfaceType.FLOOR, n, 0.0)
	
	_keep_closest_floor(surfaces)
	_get_current_state(surfaces)
	
	snapped_normals.clear()


func _check_for_ground() -> PhysicsTestMotionResult3D:
	var motion: = Vector3.DOWN * COLLISION_CHECK_MARGIN
	var start_position := body.global_position
	var transform = Transform3D(body.global_basis, start_position)
	
	if !col_comp.collision_shape:
		return PhysicsTestMotionResult3D.new()
	
	return col_comp._test_collision(col_comp.collision_shape.shape, transform, motion, true, false)


func _snap_down_update() -> void:
	var can_snap: bool = true
	
	var is_floor_state: bool = cur_state_surfaces["type"] == CurrentState.FLOOR
	
	if is_floor_state and body.velocity.y <= 0.0:
		_snap_down(snap_height, 0.0)
	
	var should_snap: bool = wasOnFloorLastFrame and not is_floor_state
	
	if not should_snap:
		can_snap = false
	if body.velocity.y > 0.0:
		can_snap = false
	
	if can_snap:
		_snap_down(snap_height, SNAP_SAFE_MARGIN)


func _forced_snap_down_update(_snap_height, _safe_margin) -> bool:
	return _snap_down(_snap_height, _safe_margin)


func _snap_down(_snap_height: float, _safe_margin: float) -> bool:
	# First attempt: test with the real collision shape
	var floor_info := _find_floor_below(col_comp.collision_shape.shape, body.global_transform, _snap_height)
	
	if not floor_info.is_empty():
		body.move_and_collide(Vector3(0, floor_info["travel_y"], 0), false, 0, false, 1)
		body.force_update_transform()
	elif _safe_margin != 0.0:
		# Second attempt: shrink the shape horizontally in case a wall/ledge
		# edge was caught instead of the floor surface below it
		col_comp._set_test_shape(col_comp.collision_shape.shape)
		col_comp._expand_collision(col_comp.test_shape, -(Vector3(1, 0, 1) * _safe_margin))
		
		floor_info = _find_floor_below(col_comp.test_shape, body.global_transform, _snap_height)
		if floor_info.is_empty():
			return false
		
		# Shrink the real shape, move down, then expand it back out and
		# resolve any resulting overlap from the expansion
		col_comp._expand_collision(col_comp.collision_shape.shape, -(Vector3(1, 0, 1) * _safe_margin))
		body.move_and_collide(Vector3(0, floor_info["travel_y"], 0), false, 0, false, 1)
		col_comp._expand_collision(col_comp.collision_shape.shape, (Vector3(1, 0, 1) * _safe_margin))
		body.move_and_collide(Vector3.ZERO, false, 0, false, 1)
		body.force_update_transform()
	
	if floor_info.is_empty():
		return false
	snapped_normals.append(floor_info["normal"])
	body.velocity.y = 0.0
	return true


func _find_floor_below(shape: Shape3D, test_transform: Transform3D, _snap_height: float) -> Dictionary:
	var result := col_comp._test_collision(shape, test_transform, Vector3.DOWN * _snap_height, true, false)
	if result.get_collision_count() == 0:
		return {}
	if result.get_travel().y >= 0:
		return {}
	
	var normal := result.get_collision_normal()
	if _classify(normal) != SurfaceType.FLOOR:
		return {}
	
	return {"normal": normal, "travel_y": result.get_travel().y}


func _step_up_update(
	query_transform: Transform3D,
	motion: Vector3,
	p_collided_surfaces: Array,
	bump_planes: Array[Vector3],
	bump_is_floor: Array[bool],
	bump_surf_types: Array,
	) -> Dictionary:
	
	if not wasOnFloorLastFrame:
		return {}
	if body.velocity.y > 0.0:
		return {}
	
	var step_result := _try_step_up(query_transform, motion)
	if step_result.is_empty():
		return {}
	
	col_comp._expand_collision(col_comp.collision_shape.shape, -(Vector3.ONE * SAFE_MARGIN))
	body.global_position = step_result["origin"]
	body.force_update_transform()
	col_comp._expand_collision(col_comp.collision_shape.shape, (Vector3.ONE * SAFE_MARGIN))
	body.move_and_collide(Vector3.ZERO, false, 0, false, 1)
	body.force_update_transform()
	
	for i in range(p_collided_surfaces.size() - 1, -1, -1):
		if p_collided_surfaces[i]["type"] == SurfaceType.WALL:
			p_collided_surfaces.remove_at(i)
	
	_add_surface(p_collided_surfaces, SurfaceType.FLOOR, step_result["normal"], 0.0)
	
	bump_planes.clear()
	bump_is_floor.clear()
	bump_surf_types.clear()
	
	return {
		"start_position": body.global_position,
		"total": Vector3.ZERO,
		"query_transform": body.global_transform,
		"motion": step_result["remainder"],
	}


func _try_step_up(query_transform: Transform3D, original_motion: Vector3) -> Dictionary:
	var shape := col_comp.collision_shape.shape
	var h_motion := Vector3(original_motion.x, 0.0, original_motion.z)
	
	# Phase 1: UP
	var up_result := col_comp._test_collision(col_comp.collision_shape.shape, query_transform, Vector3.UP * step_height, true, false)
	var up_y := step_height
	if up_result.get_collision_count() > 0:
		up_y = up_result.get_travel().y
	
	var raised := Transform3D(query_transform)
	raised.origin.y += up_y
	
	# Phase 2: FORWARD
	var fwd_result := col_comp._test_collision(shape, raised, h_motion, true, false)
	var fwd_travel: Vector3
	var fwd_remainder: Vector3
	if fwd_result.get_collision_count() > 0:
		fwd_travel = fwd_result.get_travel()
		fwd_remainder = fwd_result.get_remainder()
	else:
		fwd_travel = h_motion
		fwd_remainder = Vector3.ZERO
	
	if fwd_travel.length() < h_motion.length() * 0.1:
		return {}
	
	raised.origin += fwd_travel
	
	# Phase 3: DOWN
	var down_result := col_comp._test_collision(shape, raised, Vector3.DOWN * (up_y + COLLISION_CHECK_MARGIN), true, false)
	if down_result.get_collision_count() == 0:
		return {}
	
	var step_normal := down_result.get_collision_normal()
	if _classify(step_normal) != SurfaceType.FLOOR:
		return {}
	
	var final_origin := raised.origin + down_result.get_travel()
	
	return {
		"origin": final_origin,
		"normal": step_normal,
		"remainder": fwd_remainder,
	}


# --- Helpers ---
func _slide(v: Vector3, n: Vector3) -> Vector3:
	var d := v.dot(n)
	return v if d >= 0.0 else v - n * d


func _classify(normal: Vector3) -> SurfaceType:
	var up_dot := normal.dot(Vector3.UP)
	if   normal == Vector3.ZERO: return SurfaceType.NONE
	elif up_dot >= FLOOR_DOT:    return SurfaceType.FLOOR
	elif up_dot >  RAMP_DOT:     return SurfaceType.RAMP
	elif up_dot < -0.01:         return SurfaceType.CEILING
	else:                        return SurfaceType.WALL


func _add_surface(new_surfaces: Array, type: SurfaceType, normal: Vector3, distance: float) -> void:
	for s in new_surfaces:
		if s["type"] == type and s["normal"].dot(normal) > RAMP_DUPLICATE_DOT_THRESHOLD:
			return
	new_surfaces.append({"type": type, "normal": normal, "distance": distance})


func _get_current_state(_surface: Array) -> void:
	var isOnGround: bool = false
	var isSurfing:  bool = false
	var normal:  Vector3 = Vector3.ZERO
	var closest_ramp_distance: float = INF
	
	for surface in _surface:
		if surface["type"] == SurfaceType.FLOOR:
			isOnGround = true
			normal     = surface["normal"]
			break
		elif surface["type"] == SurfaceType.RAMP:
			if surface["distance"] < closest_ramp_distance:
				closest_ramp_distance = surface["distance"]
				isSurfing = true
				normal    = surface["normal"]
	
	if isOnGround:
		cur_state_surfaces = {"type": CurrentState.FLOOR, "normal": normal}
	elif isSurfing:
		cur_state_surfaces = {"type": CurrentState.SURF, "normal": normal}
	else:
		cur_state_surfaces = {"type": CurrentState.AIR, "normal": normal}


func _keep_closest_floor(surface_list: Array) -> void:
	var closest_index := -1
	var closest_distance := INF
	
	for i in range(surface_list.size()):
		if surface_list[i]["type"] == SurfaceType.FLOOR:
			if surface_list[i]["distance"] < closest_distance:
				closest_distance = surface_list[i]["distance"]
				closest_index = i
	
	if closest_index == -1:
		return
	
	for i in range(surface_list.size() - 1, -1, -1):
		if surface_list[i]["type"] == SurfaceType.FLOOR and i != closest_index:
			surface_list.remove_at(i)
