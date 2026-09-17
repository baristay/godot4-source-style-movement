extends State
class_name PlayerNoclip

@export var drag_curve: Curve
@export var accel_curve: Curve


func _enter(_from_restore: bool = false) -> void:
	col_comp._set_collision_enabled(false)


func _physics_update(delta: float) -> void:
	var run_speed:  float = config.run_speed_n
	var walk_speed: float = config.walk_speed_n
	var duck_speed: float = config.duck_speed_n
	var cur_speed:  float = _cur_speed_calculator(run_speed, walk_speed, duck_speed)
	var accel:      float = _cur_accel_calculator() * config.accel_power_n * (cur_speed / run_speed)
	var drag:       float = config.friction_n * 220

	var wish_dir: Vector3 = input_comp.wish_dir_full.normalized()

	velocity_3d = body.velocity_HU

	_apply_drag(drag, delta, run_speed)
	_apply_accel(accel, wish_dir, cur_speed, run_speed, delta)

	body.velocity_HU = velocity_3d

	if input_comp.isNoclipRequested:
		transitioned.emit(self, "PlayerAir")

func _cur_speed_calculator(run_speed: float, walk_speed: float, duck_speed: float) -> float:
	if input_comp.isDuckState: return duck_speed
	elif input_comp.isWalkRequested: return walk_speed
	else: return run_speed

func _cur_accel_calculator() -> float:
	const run: float = 335
	const walk: float = 337.7
	const duck: float = 335.05
	if input_comp.isDuckState: return duck
	elif input_comp.isWalkRequested: return walk
	else: return run

func _apply_drag(drag: float, delta: float, run_speed: float) -> void:
	var speed:      float = velocity_3d.length()
	var normalized: float = clampf(speed / run_speed, 0.0, 1.0)
	var scale:      float = drag_curve.sample(normalized)
	var drag_speed: float = drag * scale * delta
	
	if speed > run_speed:
		drag_speed += speed - run_speed
	
	if speed - drag_speed <= 0.0:
		velocity_3d = Vector3.ZERO
		return
	
	velocity_3d = velocity_3d.normalized() * (speed - drag_speed)

func _apply_accel(accel: float, wish_dir: Vector3, cur_speed: float, run_speed: float, delta: float) -> void:
	var speed:       float = velocity_3d.length()
	var normalized:  float = velocity_3d.normalized().dot(wish_dir) * speed / run_speed
	var accel_speed: float = abs(accel_curve.sample(normalized)) * accel * delta
	var add_speed:   float = cur_speed - velocity_3d.dot(wish_dir)

	if cur_speed < speed and speed <= run_speed:
		return

	velocity_3d += wish_dir * minf(accel_speed, add_speed)
	velocity_3d  = velocity_3d.normalized() * minf(velocity_3d.length(), cur_speed)
