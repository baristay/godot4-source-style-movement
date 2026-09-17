extends State
class_name PlayerGround

# --- Exports ---
@export var drag_curve: Curve
@export var accel_curve: Curve

# --- Private State ---
var isApplyLandingDrag: bool
var wasJustEntered: bool


func _store_state_info(dict: Dictionary = {}) -> Dictionary:
	dict = {"wasJustEntered": wasJustEntered}
	return dict


func _on_restore(dict) -> void:
	wasJustEntered = dict["wasJustEntered"]


func _enter(from_restore: bool = false) -> void:
	col_comp._set_collision_enabled(true)
	wasJustEntered = not from_restore


func _physics_update(delta: float) -> void:
	var cur_state: Dictionary = resp_comp.cur_state_surfaces 
	var wish_dir:     Vector2 = Vector2(input_comp.wish_dir.x, input_comp.wish_dir.z).normalized()
	var run_speed:      float = config.run_speed
	var walk_speed:     float = config.walk_speed
	var duck_speed:     float = config.duck_speed
	var cur_speed:      float = _cur_speed_calculator(run_speed, walk_speed, duck_speed)
	var accel:          float = _cur_accel_calculator() * config.accel_power * (cur_speed / run_speed)
	var drag:           float = config.friction * 220
	var landing_speed:  float = config.landing_speed if config.landing_speed != 0.0 else INF
	
	velocity_3d = body.velocity_HU
	velocity_2d = Vector2(velocity_3d.x, velocity_3d.z)
	isJumpRequested = input_comp.isJumpRequested
	
	var speed_len: float = velocity_2d.length()
	isApplyLandingDrag = speed_len > run_speed and not is_equal_approx(speed_len, run_speed)
	
	if isJumpRequested:
		velocity_3d = _handle_jump_physics(velocity_3d)
	elif isApplyLandingDrag: 
		_apply_landing_drag(delta, drag, run_speed)
		_apply_accel(accel, wish_dir, cur_speed, run_speed, delta)
	else: 
		_apply_drag(drag, delta, run_speed)
		_apply_accel(accel, wish_dir, cur_speed, run_speed, delta)
	
	if wasJustEntered and velocity_2d.length() > landing_speed:
		velocity_2d = velocity_2d.normalized() * landing_speed
	
	velocity_3d = Vector3(velocity_2d.x, velocity_3d.y, velocity_2d.y)
	body.velocity_HU = velocity_3d
	wasJustEntered = false
	
	var isOnFloor: bool = cur_state["type"] == ResponseComponent.CurrentState.FLOOR
	if input_comp.isNoclipRequested:
		transitioned.emit(self, "PlayerNoclip")
	elif not isOnFloor or isJumpRequested:
		transitioned.emit(self, "PlayerAir")


func _cur_speed_calculator(run_speed: float, walk_speed: float, duck_speed: float) -> float:
	if input_comp.isDuckState: return duck_speed
	elif input_comp.isWalkRequested: return walk_speed
	else: return run_speed


func _cur_accel_calculator() -> float:
	#the numbers I tested to achive cs:go's ground movement
	const run: float = 335
	const walk: float = 337.7
	const duck: float = 335.05
	
	if input_comp.isDuckState: return duck
	elif input_comp.isWalkRequested: return walk
	else: return run


func _apply_drag(drag: float, delta: float, run_speed: float) -> void:
	var speed:      float = velocity_2d.length()
	var normalized: float = clampf(speed / run_speed, 0.0, 1.0)
	var scale:      float = drag_curve.sample(normalized)
	var drag_speed: float = drag * scale * delta
	
	if speed > run_speed:
		drag_speed += speed - run_speed
	
	if speed - drag_speed <= 0.0:
		velocity_2d = Vector2.ZERO
		return
	
	velocity_2d = velocity_2d.normalized() * (speed - drag_speed)


func _apply_accel(accel: float, wish_dir: Vector2, cur_speed: float, run_speed: float, delta: float) -> void:
	var speed:       float = velocity_2d.length()
	var normalized:  float = velocity_2d.normalized().dot(wish_dir) * speed / run_speed
	var accel_speed: float = abs(accel_curve.sample(normalized)) * accel * delta
	var add_speed:   float = cur_speed - velocity_2d.dot(wish_dir.normalized())
	
	if isApplyLandingDrag:
		if speed <= cur_speed:
			isApplyLandingDrag = false
		else:
			_apply_accel_capped(wish_dir, cur_speed, accel_speed, add_speed)
			return
	
	if cur_speed < speed and speed <= run_speed: 
		return
	
	velocity_2d += wish_dir * minf(accel_speed, add_speed)
	velocity_2d  = velocity_2d.normalized() * minf(velocity_2d.length(), cur_speed)


func _apply_accel_capped(wish_dir: Vector2, cur_speed: float, accel_speed: float, add_speed: float) -> void:
	var speed: float = velocity_2d.length()
	if velocity_2d.dot(wish_dir) <= cur_speed:
		velocity_2d += wish_dir * minf(accel_speed, add_speed)
		velocity_2d  = velocity_2d.normalized() * minf(velocity_2d.length(), speed)


func _apply_landing_drag(delta: float, drag: float, run_speed: float) -> void:
	var speed: float = velocity_2d.length()
	var drag_speed: float = drag * delta * 1.455 * (speed / run_speed)
	
	if speed - drag_speed <= 0.0:
		velocity_2d = Vector2.ZERO
		return
	
	velocity_2d = velocity_2d.normalized() * (speed - drag_speed)
