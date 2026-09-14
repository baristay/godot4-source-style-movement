extends Node
class_name State

# --- Exports & Node References ---
var config: MovementConfig = preload("res://Player/resource/movement_config.tres")
@onready var resp_comp:  ResponseComponent  = %ResponseComponent
@onready var input_comp: InputComponent     = %InputComponent
@onready var body:       CharacterBody3D    = owner as CharacterBody3D

# --- Signals ---
@warning_ignore("unused_signal")
signal transitioned

# --- Constants ---
const HU_TO_M = MovementConfig.HU_TO_M

# --- State ---
var velocity_3d:     Vector3 = Vector3.ZERO
var velocity_2d:     Vector2 = Vector2.ZERO
var isJumpRequested: bool    = false


func _enter() -> void:
	pass

func _exit() -> void:
	pass

func _physics_update(_delta: float) -> void:
	pass

func _update(_delta: float) -> void:
	pass


func _handle_jump_physics(_velocity_3d: Vector3) -> Vector3:
	var jump_force:     float = config.jump_force
	var max_air_speed:  float = config.max_air_speed
	var _velocity_2d: Vector2 = Vector2(_velocity_3d.x, _velocity_3d.z)
	
	_velocity_3d.y = clamp(jump_force, -config.max_vertical_speed, config.max_vertical_speed)
	if _velocity_2d.length() > max_air_speed:
		_velocity_2d = _velocity_2d.normalized() * max_air_speed
		_velocity_3d = Vector3(_velocity_2d.x, _velocity_3d.y, _velocity_2d.y)
	
	return _velocity_3d
