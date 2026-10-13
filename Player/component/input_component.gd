## Reads player input and turns it into movement requests.
##
## Mouse and keyboard look run every rendered frame (_input_process) for smooth
## camera control. Everything else is sampled once per physics frame through
## _input_physics_process, so the movement code always sees a consistent snapshot:
## _handle_mouse_look: apply the accumulated mouse motion to head (yaw) and cam (pitch)
## _handle_keyboard_turn: turn the head with the keyboard
## _handle_input: sample buttons and build wish_dir / wish_dir_full
extends Node
class_name InputComponent

# --- Exports & Node References ---
var config: MovementConfig = preload("res://Player/resource/movement_config.tres")
@onready var head: Node = %Head
@onready var cam: Camera3D = %Camera3D

# --- Public State ---
## Movement direction in world space, flattened to the head's yaw (no pitch).
var wish_dir:       Vector3 = Vector3.ZERO
## Same input, but rotated by the camera's full basis (pitch included).
var wish_dir_full:  Vector3 = Vector3.ZERO
var is_jump_requested:   bool = false
var is_walk_requested:   bool = false
var is_duck_requested:   bool = false
var is_duck_state:       bool = false
var is_noclip_requested: bool = false
var is_reset_requested:  bool = false
var is_set_pos_requested: bool = false

# --- Private State ---
var _mouse_accumulated: Vector2 = Vector2.ZERO
var _jump_buffer_counter: float = 0.0
## Converts config.sensitivity into radians per pixel of mouse motion.
const SENSITIVITY_SCALE: float = 0.000384


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Receive every mouse event instead of one merged event per frame,
	# so no motion is lost or smoothed out. _unhandled_input sums them up.
	Input.use_accumulated_input = false


## Collects mouse motion into _mouse_accumulated. Ignored while the mouse is not captured.
## screen_relative is used instead of relative so the look speed does not
## depend on the window's stretch settings.
func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		_mouse_accumulated += event.screen_relative


## Entry point. Call once per rendered frame from the owner's _process.
## Applies the look input, then clears the accumulated mouse motion so it is
## never applied twice.
func _input_process(delta: float) -> void:
	_handle_mouse_look()
	_handle_keyboard_turn(delta)
	_mouse_accumulated = Vector2.ZERO


## Entry point. Call once per physics frame before the movement is resolved.
## Refreshes the camera FOV from the config, then samples the input.
func _input_physics_process(delta: float) -> void:
	cam.fov = config.camera_fov
	_handle_input(delta)


## Rotates the view with the accumulated mouse motion.
## Yaw goes to the head and pitch goes to the camera, so only the camera
## tilts while the head (and wish_dir) stays level.
## Pitch is clamped to +-89 degrees to prevent flipping over the top.
func _handle_mouse_look() -> void:
	if _mouse_accumulated == Vector2.ZERO:
		return
	
	var rotation_amount := -_mouse_accumulated * config.sensitivity * SENSITIVITY_SCALE
	head.rotate_y(rotation_amount.x)
	cam.rotate_x(rotation_amount.y)
	cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-89), deg_to_rad(89))

## Turns the head left / right with the keyboard at config.yaw_speed (degrees per second).
## Scaled by delta, so the turn speed does not depend on the frame rate.
func _handle_keyboard_turn(delta: float) -> void:
	var turn_speed: float = deg_to_rad(config.yaw_speed)
	var turn_dir: float = Input.get_axis("turn_right", "turn_left")
	head.rotate_y(turn_speed * turn_dir * delta)


## Samples all the actions and rebuilds wish_dir / wish_dir_full.
## Button states are overwritten every call, so they are only valid for the current physics frame.
func _handle_input(delta) -> void:
	# Jump
	# auto_bunny: holding the key keeps requesting jumps, no buffer needed.
	# Otherwise a press is remembered for config.bunny_buffer seconds, so a jump
	# pressed slightly before landing still counts when the body touches the floor.
	if config.auto_bunny and Input.is_action_pressed("jump"):
		is_jump_requested = true
		_jump_buffer_counter = 0.0
	else:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer_counter = config.bunny_buffer
			is_jump_requested = true
		else:
			_jump_buffer_counter = maxf(_jump_buffer_counter - delta, 0.0)
			is_jump_requested = _jump_buffer_counter > 0.0
	
	# Walk
	is_walk_requested = Input.is_action_pressed("walk")
	
	# Crouch
	is_duck_requested = Input.is_action_pressed("crouch")
	
	# Noclip: one-frame toggle request, true only on the frame the key is pressed
	is_noclip_requested = Input.is_action_just_pressed("noclip")
	
	# Reset: one-frame request, true only on the frame the key is pressed
	is_reset_requested = Input.is_action_just_pressed("resetpos")
	
	# Set Position: one-frame request, true only on the frame the key is pressed
	is_set_pos_requested = Input.is_action_just_pressed("set_start_pos")
	
	# Movement
	# The input is normalized so diagonals are not faster than straight lines.
	# It is then rotated twice: by the head for ground movement (level, yaw only),
	# and by the camera for wish_dir_full (follows the pitch too).
	var raw: Vector2 = Input.get_vector("left", "right", "up", "down")
	if raw == Vector2.ZERO:
		wish_dir = Vector3.ZERO
		wish_dir_full = Vector3.ZERO
		return
	var local_dir: Vector3 = Vector3(raw.x, 0.0, raw.y).normalized()
	wish_dir      = head.global_transform.basis * local_dir
	wish_dir_full = cam.global_transform.basis  * local_dir
