class_name CrouchDucking
extends CrouchState

var started_on_ground: bool = false


func _store_state_info(dict: Dictionary = {}) -> Dictionary:
	dict = {
		"crouch_progress": state_machine.crouch_progress,
		"eye_y_curr": state_machine._eye_y_curr,
		"eye_y_prev": state_machine._eye_y_prev
	}
	
	dict["started_on_ground"] = started_on_ground
	return dict


func _on_restore(dict) -> void:
	if dict.is_empty(): 
		return
		
	state_machine.crouch_progress = dict.get("crouch_progress", state_machine.crouch_progress)
	state_machine._eye_y_curr = dict.get("eye_y_curr", state_machine._eye_y_curr)
	state_machine._eye_y_prev = dict.get("eye_y_prev", state_machine._eye_y_prev)
	started_on_ground = dict["started_on_ground"]


func _enter(_from_restore: bool = false) -> void:
	started_on_ground = (resp_comp.cur_state_surfaces["type"] == ResponseComponent.CurrentState.FLOOR)


func _physics_update(delta: float) -> void:
	if not input_comp.isDuckRequested:
		transitioned.emit(self, "CrouchUnducking")
		return
		
	var is_in_air: bool = resp_comp.cur_state_surfaces["type"] != ResponseComponent.CurrentState.FLOOR
	
	state_machine.crouch_progress += delta / col_comp.TIME_TO_DUCK
	
	if state_machine.crouch_progress >= 1.0 or is_in_air:
		_finish_duck_position_shift(is_in_air, state_machine.crouch_progress, started_on_ground)
		state_machine.crouch_progress = 1.0
		transitioned.emit(self, "CrouchDucked")
	else:
		_set_duck_eye_offset(_simple_spline(state_machine.crouch_progress))
	
	_update_input_duck_state(true)


func _finish_duck_position_shift(is_in_air: bool, progress: float, p_started_on_ground: bool) -> void:
	col_comp._set_ducked()
	
	if is_in_air:
		if p_started_on_ground and (progress > 0.0 and progress < 1.0):
			body.global_position.y += col_comp.CROUCH_JUMP_MARGIN
			print("a")
		else:
			body.global_position.y += col_comp.HULL_DELTA - col_comp.CROUCH_MARGIN
	
	body.force_update_transform()
