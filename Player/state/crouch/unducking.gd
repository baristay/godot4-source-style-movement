class_name CrouchUnducking
extends CrouchState


func _physics_update(delta: float) -> void:
	if input_comp.is_duck_requested:
		transitioned.emit(self, "CrouchDucking")
		return
		
	if not _can_unduck():
		state_machine.crouch_progress = minf(1.0, state_machine.crouch_progress + delta / col_comp.TIME_TO_DUCK)
		_set_duck_eye_offset(_simple_spline(state_machine.crouch_progress))
		if state_machine.crouch_progress >= 1.0:
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
