extends MovementState
class_name PlayerAir

# --- Private State ---
var wall_normal: Vector3 = Vector3.ZERO
var wish_dir_3d: Vector3 = Vector3.ZERO
var wish_dir_2d: Vector2 = Vector2.ZERO
var is_surfing:       bool = false
var is_bunnying:      bool = false
var was_just_entered: bool = false


func _store_state_info(dict: Dictionary = {}) -> Dictionary:
	dict["was_just_entered"] = was_just_entered
	return dict


func _on_restore(dict) -> void:
	was_just_entered = dict["was_just_entered"]


func _enter(from_restore: bool = false) -> void:
	col_comp._set_collision_enabled(true)
	was_just_entered = not from_restore


func _physics_update(delta: float) -> void:
	velocity_3d = body.velocity_HU
	velocity_2d = Vector2(velocity_3d.x, velocity_3d.z)
	is_jump_requested = input_comp.is_jump_requested
	
	wish_dir_3d = input_comp.wish_dir
	wish_dir_2d = Vector2(wish_dir_3d.x, wish_dir_3d.z)
	
	_state_handler()
	_handle_air_physics(delta)
	
	if is_bunnying and !was_just_entered:
		velocity_3d = _handle_jump_physics(velocity_3d)
	else:
		_handle_fall_physics(delta)
	
	if is_surfing:
		_handle_surf_physics()
	
	body.velocity_HU = velocity_3d
	was_just_entered = false


func _state_handler() -> void:
	var cur_state: Dictionary = resp_comp.cur_state_surfaces
	
	is_surfing  = false
	is_bunnying = false
	
	if cur_state["type"] == ResponseComponent.CurrentState.SURF:
		is_surfing  = true
		wall_normal = cur_state["normal"]
	
	if input_comp.is_noclip_requested:
		transitioned.emit(self, "PlayerNoclip")
	elif cur_state["type"] == ResponseComponent.CurrentState.FLOOR:
		if is_jump_requested:
			is_bunnying = true
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
