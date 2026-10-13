class_name CrouchState
extends Node

@onready var state_machine: CrouchStateMachine = %CrouchStateMachine
@onready var body: CharacterBody3D             = owner as CharacterBody3D
@onready var resp_comp: ResponseComponent      = %ResponseComponent
@onready var input_comp: InputComponent        = %InputComponent
@onready var col_comp: CollisionComponent      = %CollisionComponent
@onready var head: Node3D                      = %Head

@warning_ignore("unused_signal")
signal transitioned(state: CrouchState, new_state_name: String)


func _enter(_from_restore: bool = false) -> void:
	pass


func _exit() -> void:
	pass


func _physics_update(_delta: float) -> void:
	pass


func _update(_delta: float) -> void:
	var f: float = Engine.get_physics_interpolation_fraction()
	head.position.y = lerpf(state_machine._eye_y_prev, state_machine._eye_y_curr, f)


func _set_duck_eye_offset(fraction: float) -> void:
	state_machine._eye_y_curr = lerpf(col_comp.STAND_EYE, col_comp.DUCK_EYE, fraction)


func _simple_spline(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _update_input_duck_state(is_ducked: bool) -> void:
	input_comp.is_duck_state = is_ducked


func _store_state_info(_dict: Dictionary = {}) -> Dictionary:
	_dict = {
		"crouch_progress": state_machine.crouch_progress,
		"eye_y_curr": state_machine._eye_y_curr,
		"eye_y_prev": state_machine._eye_y_prev
	}
	return _dict


func _on_restore(dict: Dictionary) -> void:
	if dict.is_empty(): 
		return
		
	state_machine.crouch_progress = dict.get("crouch_progress", state_machine.crouch_progress)
	state_machine._eye_y_curr = dict.get("eye_y_curr", state_machine._eye_y_curr)
	state_machine._eye_y_prev = dict.get("eye_y_prev", state_machine._eye_y_prev)


func _is_in_air() -> bool:
	return resp_comp.cur_state_surfaces["type"] != ResponseComponent.CurrentState.FLOOR


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


func _finish_unduck(is_in_air: bool) -> void:
	if not is_in_air or col_comp.collision_shape.shape != col_comp.duck_shape:
		return
	if is_in_air:
		if _can_snap_down_air():
			resp_comp._forced_snap_down_update(col_comp.HULL_DELTA + col_comp.CROUCH_MARGIN, -resp_comp.SAFE_MARGIN)
			body.force_update_transform()
			body.reset_physics_interpolation()
		else:
			body.global_position.y -= col_comp.HULL_DELTA - col_comp.CROUCH_MARGIN
			body.force_update_transform()


func _can_snap_down_air() -> bool:
	var result: PhysicsTestMotionResult3D
	result = col_comp._test_collision(col_comp.duck_shape, body.global_transform, (col_comp.HULL_DELTA - col_comp.CROUCH_MARGIN) * Vector3.DOWN, false, false)
	return result.get_collision_count() != 0


func _finish_duck_position_shift(is_in_air: bool, progress: float, p_started_on_ground: bool) -> void:
	col_comp._set_ducked()
	
	if is_in_air:
		if p_started_on_ground and progress < 1.0:
			body.global_position.y += col_comp.CROUCH_JUMP_MARGIN
		else:
			body.global_position.y += col_comp.HULL_DELTA - col_comp.CROUCH_MARGIN
	
	body.force_update_transform()
