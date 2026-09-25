class_name CrouchDucked
extends CrouchState


func _enter(_from_restore: bool = false) -> void:
	state_machine.crouch_progress = 1.0
	state_machine._eye_y_curr     = col_comp.DUCK_EYE
	
	if col_comp.collision_shape.shape != col_comp.duck_shape:
		col_comp._set_ducked()
	
	_update_input_duck_state(true)


func _physics_update(_delta: float) -> void:
	if not input_comp.isDuckRequested:
		transitioned.emit(self, "CrouchUnducking")
