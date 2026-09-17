extends State
class_name PlayerAir

# --- Private State ---
var wall_normal: Vector3 = Vector3.ZERO
var wish_dir_3d: Vector3 = Vector3.ZERO
var wish_dir_2d: Vector2 = Vector2.ZERO
var isSurfing:      bool = false
var isBunnying:     bool = false
var wasJustEntered: bool = false


func _store_state_info(dict: Dictionary = {}) -> Dictionary:
	dict = {"wasJustEntered": wasJustEntered}
	return dict


func _on_restore(dict) -> void:
	wasJustEntered = dict["wasJustEntered"]


func _enter(from_restore: bool = false) -> void:
	col_comp._set_collision_enabled(true)
	wasJustEntered = not from_restore


func _physics_update(delta: float) -> void:
	velocity_3d = body.velocity_HU
	velocity_2d = Vector2(velocity_3d.x, velocity_3d.z)
	isJumpRequested = input_comp.isJumpRequested
	
	wish_dir_3d = input_comp.wish_dir
	wish_dir_2d = Vector2(wish_dir_3d.x, wish_dir_3d.z)
	
	_state_handler()
	_handle_air_physics(delta)
	
	if isBunnying and !wasJustEntered:
		velocity_3d = _handle_jump_physics(velocity_3d)
	else:
		_handle_fall_physics(delta)
	
	if isSurfing:
		_handle_surf_physics()
	
	body.velocity_HU = velocity_3d
	wasJustEntered = false


func _state_handler() -> void:
	var cur_state: Dictionary = resp_comp.cur_state_surfaces
	
	isSurfing  = false
	isBunnying = false
	
	if cur_state["type"] == ResponseComponent.CurrentState.SURF:
		isSurfing   = true
		wall_normal = cur_state["normal"]
	
	if input_comp.isNoclipRequested:
		transitioned.emit(self, "PlayerNoclip")
	elif cur_state["type"] == ResponseComponent.CurrentState.FLOOR:
		if isJumpRequested:
			isBunnying = true
		else:
			transitioned.emit(self, "PlayerGround")


func _handle_air_physics(delta: float) -> void:
	if wish_dir_2d.length() == 0:
		return
	
	var wish_norm     : Vector2 = wish_dir_2d.normalized()
	var wish_spd_full : float   = wish_dir_2d.length() * config.run_speed
	var wish_spd_cap  : float   = minf(wish_spd_full, config.air_wish_speed)
	var add_speed     : float   = wish_spd_cap - velocity_2d.dot(wish_norm)
	
	if add_speed <= 0:
		return
	
	var accel_speed: float = minf(config.air_acceleration * wish_spd_full * delta, add_speed)
	
	velocity_2d += wish_norm * accel_speed
	velocity_3d  = Vector3(velocity_2d.x, velocity_3d.y, velocity_2d.y)


func _handle_surf_physics() -> void:
	var backoff: float = velocity_3d.dot(wall_normal)
	if backoff >= 0:
		return
	
	velocity_3d -= wall_normal * backoff


func _handle_fall_physics(delta: float) -> void:
	velocity_3d.y -= config.gravity * delta
	velocity_3d.y  = clamp(velocity_3d.y, -config.max_vertical_speed, config.max_vertical_speed)


#Old Code Territory.
#I couldn't figure out how air physics should work, so I coded my own version.
#But it had its rough edges.
#So I ultimately decided to abandon it.
#I wanted it to have its own graveyard, so here it is.

#func _handle_air_physics(delta: float) -> void:
	#var legacy_vel: Vector2 = _legacy_air_physics(delta)
	#if isStrafing:
		#_strafe_air_physics(delta, legacy_vel)
	#else:
		#velocity_2d = legacy_vel
		#world_old_player_forward_2d = Vector2.ZERO
		#strafe_consistent_time = 0.0
	#return

#func _strafe_air_physics(delta: float, legacy_vel: Vector2) -> void:
	#player_forward_2d = _strafe_position_finder()
	#if player_forward_2d.length() == 0: return
	#
	#var scale: float = _scale_calculator(velocity_2d.length(), delta)
	#scale = scale * config.strafe_penalty if scale < 0 else scale
	#
	#velocity_2d = player_forward_2d * (velocity_2d.length() + (config.air_wish_speed * scale * delta))
	#
	#if !wasStrafing:
		#velocity_2d = legacy_vel
		#strafe_consistent_time = 0.0
		#return
	#
	#var current_forward = player_forward_2d.rotated(body.rotation.y)
	#var dot_check = current_forward.dot(world_old_player_forward_2d)
	#world_old_player_forward_2d = current_forward
	#
	#var dynamic_threshold = 1.0 - (delta * 3.5)
	#dynamic_threshold = clamp(dynamic_threshold, 0.85, 0.97)
	#
	#if dot_check < dynamic_threshold:
		#velocity_2d = legacy_vel
		#strafe_consistent_time = 0.0
		#return
	#else:
		#strafe_consistent_time += delta
		#if strafe_consistent_time < STRAFE_WARMUP_TIME:
			#velocity_2d = legacy_vel
			#return
	#return

#func _scale_calculator(current_speed: float, delta: float) -> float:
	#var abs_rot: float = abs(rotation_delta) / delta
	#if abs_rot == 0: return config.max_air_speed
	#
	#var equilibrium: float = (config.air_acceleration * config.air_wish_speed) / abs_rot
	#var optimal_rot: float = asin(clamp((config.air_acceleration * config.air_wish_speed * delta) / current_speed, -1.0, 1.0)) / delta
	#var half_rot: float = optimal_rot * 0.5
	#
	#if abs_rot <= half_rot:
		#var t: float = abs_rot / half_rot
		#return pow(t, 0.5)
	#elif abs_rot <= optimal_rot:
		#var t: float = (abs_rot - half_rot) / (optimal_rot - half_rot)
		#return pow(1.0 - t, 0.5)
	#else:
		#return (equilibrium - current_speed) / current_speed

#func _strafe_position_finder() -> Vector2:
	#if sign(rotation_delta) == 1:
		#return wish_dir_2d.normalized().rotated(PI / 2)
	#elif sign(rotation_delta) == -1:
		#return wish_dir_2d.normalized().rotated(-PI / 2)
	#else:
		#return Vector2.ZERO

#func _strafe_checker(delta: float) -> bool:
	#if wish_dir_2d.length() == 0 or rotation_delta == 0 or wishDirWasChanged:
		#return false
	#
	#var local_vel: Vector2 = velocity_2d.normalized().rotated(last_rotation).snapped(Vector2(0.01, 0.01))
	#var cross: float = local_vel.cross(normal_wish_dir_2d)
	#
	#var abs_rot: float = abs(rotation_delta) / delta
	#var optimal_rot: float = asin(clamp((config.air_acceleration * config.air_wish_speed * delta) / velocity_2d.length(), -1.0, 1.0)) / delta
	#var rot_t = clamp(abs_rot / optimal_rot, 0.0, 1.0)
	#var threshold = lerp(0.99, 0.3, rot_t)
	#
	#return sign(cross) == sign(-rotation_delta) and abs(cross) > threshold

#func _physics_update(delta: float) -> void:
	#var cur_state: Dictionary = col_comp.cur_state_surfaces
	#var is_on_wall: Dictionary = col_comp.is_on_wall
	#var wall_normal: Vector3 = Vector3.ZERO
	#velocity_3d = body.velocity_HU
	#velocity_2d = Vector2(velocity_3d.x, velocity_3d.z)
	#isJumpRequested = input_comp.isJumpRequested
	#
	#wish_dir_3d = input_comp.wish_input_dir
	#wish_dir_2d = Vector2(wish_dir_3d.x, wish_dir_3d.z)
	#normal_wish_dir_2d = Vector2(input_comp.normal_input_dir.x, input_comp.normal_input_dir.z)
	#
	#wishDirWasChanged = false
	#if normal_wish_dir_2d != old_normal_wishdir_2d:
		#wishDirWasChanged = true
	#old_normal_wishdir_2d = normal_wish_dir_2d
	#
	#rotation_delta = input_comp.rotation_delta
	#
	#isSurfing = false
	#isBunnying = false
	#if cur_state["type"] == CollisionComponent.CurrentState.SURF:
		#isSurfing = true
		#isStrafing = false
		#wall_normal = cur_state["normal"]
	#if cur_state["type"] == CollisionComponent.CurrentState.FLOOR:
		#if isJumpRequested: isBunnying = true
		#else: transitioned.emit(self, "PlayerGround")
	#
	#wasStrafing = isStrafing
	#isStrafing = _strafe_checker(delta)
	#isStrafing = false
	#
	#if is_on_wall["bool"]:
		#isStrafing = false
	#
	#_handle_air_physics(delta)
	#velocity_3d = Vector3(velocity_2d.x, velocity_3d.y, velocity_2d.y)
	#if isBunnying: _handle_jump_physics()
	#else: _handle_fall_physics(delta)
	#if isSurfing: _handle_surf_physics(wall_normal)
	#
	#body.velocity_HU = velocity_3d
	#last_rotation = input_comp.head.rotation.y
	#return
