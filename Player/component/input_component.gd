extends Node
class_name InputComponent

# --- Exports & Node References ---
var config: MovementConfig = preload("res://Player/resource/movement_config.tres")
@onready var head: Node = %Head
@onready var cam: Camera3D = %Camera3D

# --- Public State ---
var wish_dir:       Vector3 = Vector3.ZERO
var wish_dir_full:  Vector3 = Vector3.ZERO
var isJumpRequested:   bool = false
var isWalkRequested:   bool = false
var isDuckRequested:   bool = false
var isDuckState:       bool = false
var isNoclipRequested: bool = false
var isResetRequested:  bool = false
var isSetPosRequested: bool = false

# --- Private State ---
var _mouse_accumulated: Vector2 = Vector2.ZERO
var _jump_buffer_counter: float = 0.0
const SENSITIVITY_SCALE: float = 0.000384


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.use_accumulated_input = false


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		_mouse_accumulated += event.screen_relative


func _process(delta: float) -> void:
	_handle_mouse_look()
	_handle_keyboard_turn(delta)
	_mouse_accumulated = Vector2.ZERO


func _input_update(delta: float) -> void:
	cam.fov = config.camera_fov
	_handle_input(delta)


func _handle_mouse_look() -> void:
	if _mouse_accumulated == Vector2.ZERO:
		return
	
	var rotation_amount := -_mouse_accumulated * config.sensitivity * SENSITIVITY_SCALE
	head.rotate_y(rotation_amount.x)
	cam.rotate_x(rotation_amount.y)
	cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _handle_keyboard_turn(delta: float) -> void:
	var turn_speed: float = deg_to_rad(config.yaw_speed)
	var turn_dir: float = Input.get_axis("turn_right", "turn_left")
	head.rotate_y(turn_speed * turn_dir * delta)


func _handle_input(delta) -> void:
	#Jump
	if config.auto_bunny and Input.is_action_pressed("jump"):
		isJumpRequested = true
		_jump_buffer_counter = 0.0
	else:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer_counter = config.bunny_buffer
			isJumpRequested = true
		else:
			_jump_buffer_counter = maxf(_jump_buffer_counter - delta, 0.0)
			isJumpRequested = _jump_buffer_counter > 0.0
	
	#Walk
	isWalkRequested = Input.is_action_pressed("walk")
	
	#Crouch
	isDuckRequested = Input.is_action_pressed("crouch")
	
	#Noclip
	isNoclipRequested = Input.is_action_just_pressed("noclip")
	
	#Reset
	isResetRequested = Input.is_action_just_pressed("resetpos")
	
	#Set Position
	isSetPosRequested = Input.is_action_just_pressed("set_start_pos")
	
	#Movement
	var raw: Vector2 = Input.get_vector("left", "right", "up", "down")
	if raw == Vector2.ZERO:
		wish_dir = Vector3.ZERO
		wish_dir_full = Vector3.ZERO
		return
	var local_dir: Vector3 = Vector3(raw.x, 0.0, raw.y).normalized()
	wish_dir      = head.global_transform.basis * local_dir
	wish_dir_full = cam.global_transform.basis  * local_dir
