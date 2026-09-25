class_name CrouchStanding
extends CrouchState


func _enter(_from_restore: bool = false) -> void:
	state_machine.crouch_progress = 0.0
	state_machine._eye_y_curr     = col_comp.STAND_EYE
	
	if col_comp.collision_shape.shape != col_comp.box_shape:
		col_comp._set_standing()
	
	_update_input_duck_state(false)


func _physics_update(_delta: float) -> void:
	if input_comp.isDuckRequested:
		transitioned.emit(self, "CrouchDucking")
