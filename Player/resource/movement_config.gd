extends Resource
class_name MovementConfig

const HU_TO_M = 0.01905

# "Default" butonu bu alanları resetler. Sensitivity kasıtlı olarak dışarıda.
const DEFAULTS := {
	"yaw_speed": 210.0,
	"camera_fov": 74.0,
	"time_scale": 1.0,
	"tick_rate": 67,
	"auto_bunny": true,
	"bunny_buffer": 0.1,

	"run_speed_n": 1090.0,
	"walk_speed_n": 250.0,
	"duck_speed_n": 300.0,
	"accel_power_n": 15.0,
	"friction_n": 15.0,

	"run_speed": 250.0,
	"walk_speed": 130.0,
	"duck_speed": 85.0,
	"accel_power": 4.0,
	"friction": 5.5,

	"landing_speed": 200.0,
	"air_wish_speed": 30.0,
	"air_acceleration": 100.0,
	"max_vertical_speed": 3500.0,
	"max_air_speed": 4000.0,
	"jump_force": 301.0,
	"gravity": 800.0,
}

# Default'a dahil değil — kullanıcı ayarında kalır
@export var sensitivity: float = 3.0

@export var yaw_speed: float = DEFAULTS.yaw_speed
@export var camera_fov: float = DEFAULTS.camera_fov
@export var time_scale: float = DEFAULTS.time_scale:
	set(value):
		time_scale = value
		Engine.time_scale = value
@export var tick_rate: int = DEFAULTS.tick_rate:
	set(value):
		tick_rate = value
		Engine.physics_ticks_per_second = value
@export var auto_bunny: bool = DEFAULTS.auto_bunny
@export var bunny_buffer: float = DEFAULTS.bunny_buffer

@export var run_speed_n: float = DEFAULTS.run_speed_n
@export var walk_speed_n: float = DEFAULTS.walk_speed_n
@export var duck_speed_n: float = DEFAULTS.duck_speed_n
@export var accel_power_n: float = DEFAULTS.accel_power_n
@export var friction_n: float = DEFAULTS.friction_n

@export var run_speed: float = DEFAULTS.run_speed
@export var walk_speed: float = DEFAULTS.walk_speed
@export var duck_speed: float = DEFAULTS.duck_speed
@export var accel_power: float = DEFAULTS.accel_power
@export var friction: float = DEFAULTS.friction

@export var landing_speed: float = DEFAULTS.landing_speed
@export var air_wish_speed: float = DEFAULTS.air_wish_speed
@export var air_acceleration: float = DEFAULTS.air_acceleration
@export var max_vertical_speed: float = DEFAULTS.max_vertical_speed
@export var max_air_speed: float = DEFAULTS.max_air_speed
@export var jump_force: float = DEFAULTS.jump_force
@export var gravity: float = DEFAULTS.gravity

const slope_max_angle: float = 45
const surf_max_angle: float = 85
const step_height: float = 0.35
const snap_height: float = 0.35


func reset_movement_to_default() -> void:
	for key in DEFAULTS.keys():
		set(key, DEFAULTS[key])
