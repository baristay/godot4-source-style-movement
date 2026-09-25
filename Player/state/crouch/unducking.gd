class_name CrouchUnducking
extends CrouchState


func _physics_update(delta: float) -> void:
	if input_comp.isDuckRequested:
		transitioned.emit(self, "CrouchDucking")
		return
		
	if not _can_unduck():
		_update_input_duck_state(true)
		transitioned.emit(self, "CrouchDucked")
		return
		
	var is_in_air: bool = resp_comp.cur_state_surfaces["type"] != ResponseComponent.CurrentState.FLOOR
	
	state_machine.crouch_progress -= delta / col_comp.TIME_TO_UNDUCK
	
	if state_machine.crouch_progress <= 0.0 or is_in_air:
		state_machine.crouch_progress = 0.0
		_finish_unduck(is_in_air)
		transitioned.emit(self, "CrouchStanding")
	else:
		_set_duck_eye_offset(_simple_spline(state_machine.crouch_progress))
	
	_update_input_duck_state(false)


func _finish_unduck(is_in_air: bool) -> void:
	if is_in_air:
		if _can_snap_down_air():
			resp_comp._forced_snap_down_update(col_comp.HULL_DELTA + col_comp.CROUCH_MARGIN, -resp_comp.SAFE_MARGIN)
			body.force_update_transform()
			body.reset_physics_interpolation()
		else:
			body.global_position.y -= col_comp.HULL_DELTA - col_comp.CROUCH_MARGIN
			body.force_update_transform()


func _can_unduck() -> bool:
	if state_machine.crouch_progress <= 0.0 or col_comp.collision_shape.shape == col_comp.box_shape:
		return true
	
	var colliding: bool = true
	var result: PhysicsTestMotionResult3D
	
	result = col_comp._test_collision(col_comp.collision_shape.shape, body.global_transform, col_comp.HULL_DELTA * Vector3.UP, false, false)
	
	if result.get_collision_count() != 0:
		colliding = false
	
	var test_center: Vector3 = body.global_position + (Vector3.UP * state_machine.COLLISION_MARGIN)
	var transform: = Transform3D(col_comp.collision_shape.global_basis, test_center)
	
	col_comp._set_test_shape(col_comp.box_shape)
	col_comp._expand_collision(col_comp.test_shape, -(Vector3(1, 1, 1)) * state_machine.COLLISION_MARGIN)
	result = col_comp._test_collision(col_comp.test_shape, transform, Vector3.ZERO, true, false)
	
	if result.get_collision_count() != 0:
		colliding = false
	
	return colliding


func _can_snap_down_air() -> bool:
	var result: PhysicsTestMotionResult3D
	result = col_comp._test_collision(col_comp.duck_shape, body.global_transform, (col_comp.HULL_DELTA - col_comp.CROUCH_MARGIN) * Vector3.DOWN, false, false)
	return result.get_collision_count() != 0
