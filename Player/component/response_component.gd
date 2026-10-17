## Custom "collide and slide" movement resolver for a CharacterBody3D.
##
## Replaces move_and_slide() to give precise, Source/Quake-style control over
## slopes, steps, ramps (surf) and wall/crease sliding.
##
## Per-frame pipeline (see _resolve_motion):
## _handle_collision: seed probe, simulate the movement, step up ledges, apply it, end probe
## _update_collisions: build the surface list and the current state (FLOOR / SURF / AIR)
## _snap_down_update: fallback that re-attaches to the ground when it was suddenly lost
## _correct_velocity: remove velocity components that point into surfaces
extends Node
class_name ResponseComponent

# --- Exports & Node References ---
var config: MovementConfig = MovementConfig.get_shared()
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
const MIN_HORIZONTAL_ACCEL: float = 3.9
const SAFE_MARGIN: float = 0.002
const SNAP_SAFE_MARGIN: float = 0.002
const COLLISION_CHECK_MARGIN: float = 0.0025
const DISTANCE_MARGIN: float = 0.003
const RAMP_DUPLICATE_DOT_THRESHOLD: float = 0.95

# --- Parameters ---
var snap_height: float = 0
var step_height: float = 0.0
var was_on_floor_last_frame: bool = false
var snapped_normals: Array[Vector3] = []
var leaving_floor_motion: float = 0.0
var sim_motion: Vector3 = Vector3.ZERO
var start_position: Vector3 = Vector3.ZERO
var _snap_test_shape: BoxShape3D = BoxShape3D.new()


func _ready() -> void:
	step_height = config.step_height
	snap_height = config.snap_height


## Entry point. Call once per physics frame instead of move_and_slide().
func _resolve_motion(delta: float) -> void:
	if delta <= 0.0:
		return
	
	start_position = body.global_position
	
	_handle_collision(body.velocity, delta)
	_update_collisions()
	_snap_down_update()
	_correct_velocity(body.velocity, delta)
	was_on_floor_last_frame = cur_state_surfaces["type"] == CurrentState.FLOOR


## Moves the body by velocity * delta using collide and slide.
##
## The motion is first simulated on a copy of the body's transform: a seed
## probe finds the starting surface, then up to MAX_BOUNCE sweeps
## slide the motion along the hit planes (1 plane: slide, 2 planes: follow the
## crease, 3+: stop). Hitting a wall may trigger a step-up. The result is then
## applied to the real body, and an end probe records the surface it ended on.
func _handle_collision(velocity: Vector3, delta: float) -> void:
	var move_start := start_position
	var motion := velocity * delta
	var total := Vector3.ZERO
	collided_surfaces = []
	
	# Planes constraining the motion this frame (plane_types is parallel to planes)
	var planes: Array[Vector3] = []
	var plane_types: Array[int] = []
	
	var query_transform := body.global_transform
	
	# Seed probe: learn the starting surface up front.
	# Floor is not seeded while moving upward (jumping).
	var seed_ground := _probe_ground(query_transform)
	if not seed_ground.is_empty():
		var seed_type: int = seed_ground["type"]
		var seed_normal: Vector3 = seed_ground["normal"]
		if seed_type == SurfaceType.RAMP or (seed_type == SurfaceType.FLOOR and motion.y <= 0.0):
			planes.append(seed_normal)
			plane_types.append(seed_type)
			motion = _project(motion, seed_normal, seed_type)
	
	for _i in MAX_BOUNCE:
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
		
		# Step up
		# A wall may just be a ledge. If the body was grounded, try to climb it
		# _step_up_update sweeps up, forward and down.
		#
		# Unlike the rest of the simulation, a successful step-up moves the REAL body
		# onto the ledge immediately. The simulation then restarts from there:
		if surf_type == SurfaceType.WALL and not _is_negligible_horizontal(motion, delta):
			var step := _step_up_update(query_transform, remainder, collided_surfaces)
			if not step.is_empty():
				# The final move should only measure what happens after the step.
				move_start = body.global_position
				# Motion accumulated so far is already included in the climb.
				total = Vector3.ZERO
				# Resync the simulation copy with the body's new position.
				query_transform = body.global_transform
				# Old planes (wall, previous floor) no longer apply. The ledge's
				# floor is the only constraint now.
				planes = [step["normal"]]
				plane_types = [SurfaceType.FLOOR]
				# Continue with the horizontal motion left after the forward sweep,
				# following the ledge's floor.
				motion = _follow_floor(step["motion"], step["normal"])
				# Skip plane registration for this hit, the wall is already handled.
				continue
		
		# Plane registration: a new floor replaces the old one (avoids a floor+floor
		# crease), other types are skipped if a similar plane is already registered.
		var is_new_plane := true
		if surf_type == SurfaceType.FLOOR:
			for i in range(planes.size() - 1, -1, -1):
				if plane_types[i] == SurfaceType.FLOOR:
					planes.remove_at(i)
					plane_types.remove_at(i)
		else:
			for i in planes.size():
				if plane_types[i] == surf_type and planes[i].dot(normal) > RAMP_DUPLICATE_DOT_THRESHOLD:
					is_new_plane = false
					break
		
		if is_new_plane:
			planes.append(normal)
			plane_types.append(surf_type)
		
		match planes.size():
			1:
				motion = _project(remainder, normal, surf_type)
			2:
				var crease := planes[0].cross(planes[1])
				if crease.length_squared() > 0.0001:
					crease = crease.normalized()
					motion = crease * remainder.dot(crease)
				else:
					motion = _slide(remainder, Vector3.UP if surf_type == SurfaceType.FLOOR else normal)
				
				# Sloped floor + vertical wall: slide along the wall, then stick to the floor
				var floor_idx := plane_types.find(SurfaceType.FLOOR)
				if floor_idx != -1:
					var floor_normal := planes[floor_idx]
					var wall_normal := planes[1 - floor_idx]
					if absf(wall_normal.y) < 0.001 and absf(floor_normal.y) > 0.001 and not floor_normal.is_equal_approx(Vector3.UP):
						var h := Vector3(remainder.x, 0.0, remainder.z)
						h = _slide(h, Vector3(wall_normal.x, 0.0, wall_normal.z).normalized())
						motion = _follow_floor(h, floor_normal)
			_:
				motion = Vector3.ZERO
		
		query_transform.origin += normal * DISTANCE_MARGIN
	
	if _is_negligible_horizontal(total, delta):
		total.x = 0.0
		total.z = 0.0
	sim_motion = total
	
	var real_shape := col_comp.collision_shape.shape
	var saved_size := _shrink_shape(real_shape, Vector3.ONE * SAFE_MARGIN)
	body.move_and_collide(total, false, 0, false, 1)
	_restore_shape(real_shape, saved_size)
	body.move_and_collide(Vector3.ZERO, false, 0, false, 1)
	
	var moved := body.global_position - move_start
	if _is_negligible_horizontal(moved, delta):
		body.global_position.x = move_start.x
		body.global_position.z = move_start.z
	body.force_update_transform()
	
	# End probe: the end-of-frame state (FLOOR / SURF / AIR) comes from here
	var ground := _probe_ground(body.global_transform)
	if not ground.is_empty():
		_add_surface(collided_surfaces, ground["type"], ground["normal"], ground["distance"])


## Casts a short probe straight down from the given transform.
## Returns {} when nothing is hit, otherwise {type, normal, distance}.
func _probe_ground(from: Transform3D) -> Dictionary:
	if !col_comp.collision_shape:
		return {}
	var r := col_comp._test_collision(
		col_comp.collision_shape.shape, from,
		Vector3.DOWN * COLLISION_CHECK_MARGIN, true, false)
	if r.get_collision_count() == 0:
		return {}
	var n := _pick_ground_normal(r)
	return {"type": _classify(n), "normal": n, "distance": r.get_travel().length()}


## Removes the parts of the velocity that point into the touched surfaces, and
## writes the result to the body. Runs last in the pipeline, after the position
## has been fully resolved (collide and slide, step-up and snapping).
##
## Also keeps the body glued to downward slopes: walking off one would otherwise
## launch it horizontally, so the slope's downward speed is kept for a frame
## (see leaving_floor_motion).
func _correct_velocity(velocity: Vector3, delta: float):
	var motion := body.global_position - start_position
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
	
	if _is_negligible_horizontal(motion, delta):
		out_velocity.x = 0.0
		out_velocity.z = 0.0
	
	if (surfaces.size() > 0 or Vector2(motion.x, motion.z).length() / delta < 0.0001):
		body.velocity.x = out_velocity.x
		body.velocity.y = out_velocity.y
		body.velocity.z = out_velocity.z
	
	if cur_state_surfaces["type"] == CurrentState.FLOOR:
		body.velocity.y = 0.0
	
	if leaving_floor_motion < 0.0 and was_on_floor_last_frame and cur_state_surfaces["type"] != CurrentState.FLOOR and !input_comp.is_jump_requested:
		body.velocity.y = leaving_floor_motion
	
	if was_on_floor_last_frame and cur_state_surfaces["type"] == CurrentState.FLOOR:
		leaving_floor_motion = sim_motion.y / delta
	else:
		leaving_floor_motion = 0.0


## Rebuilds the current surface list from this frame's collisions (including the
## end probe) and any floors found by snapping, then updates the current state.
## Called again after snapping because the body's position may have changed.
func _update_collisions() -> void:
	surfaces = collided_surfaces.duplicate()
	for n in snapped_normals:
		_add_surface(surfaces, SurfaceType.FLOOR, n, 0.0)
	snapped_normals.clear()
	_keep_closest_floor(surfaces)
	_get_current_state(surfaces)


## Re-attaches the body to the ground when it was suddenly lost, for example when
## walking off a slope or a small drop. Only snaps right after leaving the floor
## and not while moving upward, so jumps are never cancelled.
func _snap_down_update() -> void:
	if was_on_floor_last_frame and cur_state_surfaces["type"] != CurrentState.FLOOR and body.velocity.y <= 0.0:
		_snap_down(snap_height, SNAP_SAFE_MARGIN)
	
	# Snapping moved the body, so rebuild the surfaces and state.
	# This also picks up floors from _forced_snap_down_update.
	if not snapped_normals.is_empty(): _update_collisions()


## Snaps without the "just left the floor" condition of _snap_down_update.
## Meant to be called from other components. It does not rebuild the surfaces itself.
## The snapped floor is picked up by the next _update_collisions.
func _forced_snap_down_update(_snap_height, _safe_margin) -> bool:
	return _snap_down(_snap_height, _safe_margin)



## Moves the body down onto the floor below it, up to _snap_height.
## Returns true if it snapped. On success the floor normal is stored in
## snapped_normals and the vertical velocity is zeroed.
##
## If _safe_margin is not zero, a failed first attempt is retried with a
## horizontally narrower shape (see below).
func _snap_down(_snap_height: float, _safe_margin: float) -> bool:
	# First attempt: test with the real collision shape
	var floor_info := _find_floor_below(col_comp.collision_shape.shape, body.global_transform, _snap_height)
	
	if not floor_info.is_empty():
		body.move_and_collide(Vector3(0, floor_info["travel_y"], 0), false, 0, false, 1)
		body.force_update_transform()
	elif _safe_margin != 0.0:
		# Second attempt: shrink the shape horizontally in case a wall/ledge
		# edge was caught instead of the floor surface below it
		var real_shape := col_comp.collision_shape.shape
		var real_box := real_shape as BoxShape3D
		if real_box == null:
			return false
		
		_snap_test_shape.size = real_box.size - Vector3(1, 0, 1) * (_safe_margin * 2.0)
		
		floor_info = _find_floor_below(_snap_test_shape, body.global_transform, _snap_height)
		if floor_info.is_empty():
			return false
		
		# Shrink the real shape, move down, then restore it and
		# resolve any resulting overlap from the expansion
		var saved_size := _shrink_shape(real_shape, Vector3(1, 0, 1) * _safe_margin)
		body.move_and_collide(Vector3(0, floor_info["travel_y"], 0), false, 0, false, 1)
		_restore_shape(real_shape, saved_size)
		body.move_and_collide(Vector3.ZERO, false, 0, false, 1)
		body.force_update_transform()
	
	if floor_info.is_empty():
		return false
	snapped_normals.append(floor_info["normal"])
	body.velocity.y = 0.0
	return true


## Sweeps shape downward by _snap_height and returns {normal, travel_y}
## if it lands on a walkable floor, otherwise {}.
## travel_y is negative (downward). Returns {} when nothing is hit,
## when the shape could not move down (already touching), or when the surface is
## not a floor, so steep slopes and walls are never snapped to.
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


## Tries to climb a ledge hit during the simulation, and applies it if it works.
##
## Only allowed right after being grounded and while not moving upward (so jumps
## are never turned into steps). On success the real body is moved on top of the
## ledge, and p_collided_surfaces is updated: the blocking wall(s) are
## removed and the ledge's floor is added.
## Returns {} on failure, otherwise {normal, motion}: the ledge's floor normal and
## the horizontal motion left to apply.
func _step_up_update(query_transform: Transform3D, motion: Vector3, p_collided_surfaces: Array) -> Dictionary:
	if not was_on_floor_last_frame:
		return {}
	if body.velocity.y > 0.0:
		return {}
	
	var step_result := _try_step_up(query_transform, motion)
	if step_result.is_empty():
		return {}
	
	var real_shape := col_comp.collision_shape.shape
	var saved_size := _shrink_shape(real_shape, Vector3.ONE * SAFE_MARGIN)
	body.global_position = step_result["origin"]
	body.force_update_transform()
	_restore_shape(real_shape, saved_size)
	body.move_and_collide(Vector3.ZERO, false, 0, false, 1)
	body.force_update_transform()
	
	for i in range(p_collided_surfaces.size() - 1, -1, -1):
		if p_collided_surfaces[i]["type"] == SurfaceType.WALL:
			p_collided_surfaces.remove_at(i)
	
	_add_surface(p_collided_surfaces, SurfaceType.FLOOR, step_result["normal"], 0.0)
	
	return {"normal": step_result["normal"], "motion": step_result["remainder"]}


## Checks whether the wall in front of the body is a climbable ledge.
## Only a query: nothing is moved.
##
## Three sweeps from query_transform: up by step_height (or until a ceiling),
## forward by the horizontal part of original_motion, then down to find
## the landing surface.
## Fails (returns {}) if the forward sweep is still blocked, which means the
## obstacle is taller than the step height, or if the landing surface is not a
## walkable floor (so steep slopes are never stepped onto).
## Otherwise returns {origin, normal, remainder}: where the body would end up, the
## ledge's floor normal, and the horizontal motion left after the forward sweep.
func _try_step_up(query_transform: Transform3D, original_motion: Vector3) -> Dictionary:
	var shape := col_comp.collision_shape.shape
	var h_motion := Vector3(original_motion.x, 0.0, original_motion.z)
	
	# Phase 1: UP
	var up_result := col_comp._test_collision(shape, query_transform, Vector3.UP * step_height, true, false)
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
## Floor: stick the motion to the plane. Anything else: only remove the part going into it.
func _project(v: Vector3, n: Vector3, type: int) -> Vector3:
	return _follow_floor(v, n) if type == SurfaceType.FLOOR else _slide(v, n)


## Projects a motion onto a floor plane. On slopes dy is computed from the plane
## equation (m·n = 0); on flat floor y becomes 0.
func _follow_floor(v: Vector3, n: Vector3) -> Vector3:
	if absf(n.y) < 0.001 or n.is_equal_approx(Vector3.UP):
		return Vector3(v.x, 0.0, v.z)
	var dy := -(v.x * n.x + v.z * n.z) / n.y
	return Vector3(v.x, dy, v.z)


## Removes the part of v that points into the plane with normal n.
## Motion moving away from the plane is returned unchanged.
func _slide(v: Vector3, n: Vector3) -> Vector3:
	var d := v.dot(n)
	return v if d >= 0.0 else v - n * d


## A probe can touch several surfaces at once (for example at an edge). The most
## upward-facing normal is the one that best represents the ground.
func _pick_ground_normal(r: PhysicsTestMotionResult3D) -> Vector3:
	var best := r.get_collision_normal(0)
	for i in range(1, r.get_collision_count()):
		var n := r.get_collision_normal(i)
		if n.y > best.y:
			best = n
	return best


## Shrinks a BoxShape3D by margin on each side and returns the original
## size to pass to _restore_shape. Does nothing for other shape types.
func _shrink_shape(shape: Shape3D, margin: Vector3) -> Vector3:
	var box := shape as BoxShape3D
	if box == null:
		return Vector3.ZERO
	var saved := box.size
	box.size = saved - margin * 2.0
	return saved


func _restore_shape(shape: Shape3D, saved_size: Vector3) -> void:
	var box := shape as BoxShape3D
	if box != null:
		box.size = saved_size


func _is_negligible_horizontal(motion: Vector3, delta: float) -> bool:
	return Vector2(motion.x, motion.z).length() < MIN_HORIZONTAL_ACCEL * delta * delta


## Classifies a normal as floor, ramp, wall or ceiling using FLOOR_DOT and RAMP_DOT.
## Normals pointing only slightly downward still count as walls.
func _classify(normal: Vector3) -> SurfaceType:
	var up_dot := normal.dot(Vector3.UP)
	if   normal == Vector3.ZERO: return SurfaceType.NONE
	elif up_dot >= FLOOR_DOT:    return SurfaceType.FLOOR
	elif up_dot >  RAMP_DOT:     return SurfaceType.RAMP
	elif up_dot < -0.01:         return SurfaceType.CEILING
	else:                        return SurfaceType.WALL


## Adds a surface unless one of the same type with a nearly identical normal is
## already in the list.
func _add_surface(new_surfaces: Array, type: SurfaceType, normal: Vector3, distance: float) -> void:
	for s in new_surfaces:
		if s["type"] == type and s["normal"].dot(normal) > RAMP_DUPLICATE_DOT_THRESHOLD:
			return
	new_surfaces.append({"type": type, "normal": normal, "distance": distance})


## Any floor wins and means FLOOR. Otherwise the closest ramp means SURF, else AIR.
func _get_current_state(_surface: Array) -> void:
	var is_on_ground: bool = false
	var is_surfing:  bool = false
	var normal:  Vector3 = Vector3.ZERO
	var closest_ramp_distance: float = INF
	
	for surface in _surface:
		if surface["type"] == SurfaceType.FLOOR:
			is_on_ground = true
			normal       = surface["normal"]
			break
		elif surface["type"] == SurfaceType.RAMP:
			if surface["distance"] < closest_ramp_distance:
				closest_ramp_distance = surface["distance"]
				is_surfing = true
				normal     = surface["normal"]
	
	if is_on_ground:
		cur_state_surfaces = {"type": CurrentState.FLOOR, "normal": normal}
	elif is_surfing:
		cur_state_surfaces = {"type": CurrentState.SURF, "normal": normal}
	else:
		cur_state_surfaces = {"type": CurrentState.AIR, "normal": normal}


## Keeps only the closest floor, so at most one floor is ever in the list.
## Otherwise two floors would be treated as a crease in _correct_velocity.
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
