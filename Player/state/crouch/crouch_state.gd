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
	input_comp.isDuckState = is_ducked


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
