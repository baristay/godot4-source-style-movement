class_name CrouchComponent
extends Node


# --- Exports & Node References ---
@onready var body: CharacterBody3D           = owner as CharacterBody3D
@onready var resp_comp:   ResponseComponent  = %ResponseComponent
@onready var head:        Node3D             = %Head
@onready var col_comp:    CollisionComponent = %CollisionComponent
@onready var input_comp:  InputComponent     = %InputComponent


# --- State ---
const COLLISION_MARGIN: float = 0.003
@onready var duck_time : float = col_comp.DUCK_TIME
var is_ducked       : bool  = false
var is_ducking      : bool  = false
var is_unducking    : bool  = false
var last_can_unduck : bool  = true
var was_duck_pressed: bool  = false
var is_in_air       : bool  = false
var crouch_state    : bool  = false 
var duck_percentage : float = 1.0


# --- Eye offset (render-frame interpolation) ---
@onready var _eye_y_prev: float = col_comp.STAND_EYE
@onready var _eye_y_curr: float = col_comp.STAND_EYE


func _ready() -> void:
	_eye_y_prev = col_comp.STAND_EYE
	_eye_y_curr = col_comp.STAND_EYE


func _process(_delta: float) -> void:
	var f: float = Engine.get_physics_interpolation_fraction()
	head.position.y = lerpf(_eye_y_prev, _eye_y_curr, f)


func _duck_update_process(delta: float) -> void:
	is_in_air = resp_comp.cur_state_surfaces["type"] != ResponseComponent.CurrentState.FLOOR
	duck_time = maxf(0.0, duck_time - delta)
	_eye_y_prev = _eye_y_curr
	_duck(delta)


func _duck(delta: float) -> void:
	var is_duck_requested: bool = input_comp.isDuckRequested
	var was_input_changed: bool = not (was_duck_pressed == is_duck_requested)
	was_duck_pressed = is_duck_requested
	
	if is_duck_requested:
		is_unducking = false
		last_can_unduck = false
		if (not is_ducked and not is_ducking) and was_input_changed:
			duck_time = col_comp.DUCK_TIME - (1 - duck_percentage) * col_comp.TIME_TO_DUCK
			is_ducking = true
		
		if is_ducking: 
			var elapsed: float = col_comp.DUCK_TIME - duck_time
			duck_percentage = 1 - (elapsed / col_comp.TIME_TO_DUCK)
			if duck_percentage < 0: duck_percentage = 0
			if elapsed >= col_comp.TIME_TO_DUCK or is_ducked or is_in_air:
				_finish_duck()
				is_ducked  = true
				is_ducking = false
			else:
				_set_duck_eye_offset(_simple_spline(elapsed / col_comp.TIME_TO_DUCK))
	else:
		is_ducking = false
		
		var can_unduck: bool = _can_unduck()
		var can_unduck_changed: bool = not (last_can_unduck == can_unduck)
		last_can_unduck = true if can_unduck else false
		
		if (is_ducked and not is_unducking) or was_input_changed or can_unduck_changed:
			duck_time = col_comp.DUCK_TIME - duck_percentage * col_comp.TIME_TO_UNDUCK
			is_unducking = true
		
		if can_unduck:
			if is_unducking:
				var elapsed: float = col_comp.DUCK_TIME - duck_time
				duck_percentage = (elapsed / col_comp.TIME_TO_UNDUCK)
				if duck_percentage > 1: duck_percentage = 1
				if elapsed >= col_comp.TIME_TO_UNDUCK or is_in_air:
					_finish_unduck(delta)
					is_unducking = false
				else:
					_set_duck_eye_offset(_simple_spline(1.0 - elapsed / col_comp.TIME_TO_UNDUCK))
			
			last_can_unduck = true
			if col_comp.collision_shape.shape != col_comp.box_shape:
				col_comp._set_standing()
			is_ducked  = false
			
		else:
			last_can_unduck = false
			if duck_percentage > 0:
				duck_percentage = 0
				duck_time  = col_comp.DUCK_TIME
				is_ducked  = true
				is_unducking = false
				_set_duck_eye_offset(1.0)
				if col_comp.collision_shape.shape != col_comp.duck_shape:
					col_comp._set_ducked()


func _finish_duck() -> void:
	col_comp._set_ducked()
	
	if is_in_air:
		if duck_percentage > 0 and duck_percentage < 1:
			body.global_position.y += col_comp.CROUCH_JUMP_MARGIN
		else:
			body.global_position.y += col_comp.HULL_DELTA - col_comp.CROUCH_MARGIN
	
	body.force_update_transform()
	duck_percentage = 0
	_eye_y_curr = col_comp.DUCK_EYE


func _finish_unduck(_delta) -> void:
	duck_time  = 0.0
	
	if is_in_air:
		var can_snap_down_air: bool = _can_snap_down_air()
		if can_snap_down_air:
			resp_comp._forced_snap_down_update(col_comp.HULL_DELTA + col_comp.CROUCH_MARGIN, -resp_comp.SAFE_MARGIN)
			body.force_update_transform()
			body.reset_physics_interpolation()
		else:
			body.global_position.y -= col_comp.HULL_DELTA - col_comp.CROUCH_MARGIN
			body.force_update_transform()
	
	duck_percentage = 1
	_eye_y_curr = col_comp.STAND_EYE
	
	if col_comp.collision_shape.shape != col_comp.box_shape:
		col_comp._set_standing()


func _can_unduck() -> bool:
	if duck_percentage >= 1 or col_comp.collision_shape.shape == col_comp.box_shape:
		return true
	
	var colliding: bool = true
	var result: PhysicsTestMotionResult3D
	
	result = col_comp._test_collision(col_comp.collision_shape.shape, body.global_transform, col_comp.HULL_DELTA * Vector3.UP, false, false)
	
	if result.get_collision_count() != 0:
		colliding = false
	
	var test_center: Vector3 = body.global_position + (Vector3.UP * COLLISION_MARGIN)
	var transform: = Transform3D(col_comp.collision_shape.global_basis, test_center)
	
	col_comp._set_test_shape(col_comp.box_shape)
	col_comp._expand_collision(col_comp.test_shape, -(Vector3(1, 1, 1)) * COLLISION_MARGIN)
	result = col_comp._test_collision(col_comp.test_shape, transform, Vector3.ZERO, true, false)
	
	if result.get_collision_count() != 0:
		colliding = false
	
	return colliding


func _can_snap_down_air() -> bool:
	var result: PhysicsTestMotionResult3D
	result = col_comp._test_collision(col_comp.duck_shape, body.global_transform, (col_comp.HULL_DELTA - col_comp.CROUCH_MARGIN) * Vector3.DOWN, false, false)
	
	if result.get_collision_count() == 0:
		return false
	
	return true


# --- Helper Functions ---
func _set_duck_eye_offset(fraction: float) -> void:
	_eye_y_curr = lerpf(col_comp.STAND_EYE, col_comp.DUCK_EYE, fraction)


func _simple_spline(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
