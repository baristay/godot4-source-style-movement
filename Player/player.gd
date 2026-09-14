extends CharacterBody3D
class_name Player

# --- Exports & Node References ---
var config: MovementConfig = preload("res://Player/resource/movement_config.tres")
@onready var input_comp:    InputComponent     = %InputComponent
@onready var resp_comp:     ResponseComponent  = %ResponseComponent
@onready var state_machine: StateMachine       = %StateMachine
@onready var crouch_comp:   CrouchComponent    = %CrouchComponent

# --- Signals ---
signal speed_changed(speed: float)
signal start_position_saved()

# --- Public State ---
var velocity_HU: Vector3 = Vector3.ZERO
var start_position: Vector3 = Vector3.ZERO
var start_head_rotation: Vector3 = Vector3.ZERO
var start_cam_rotation: Vector3 = Vector3.ZERO
var start_velocity: Vector3 = Vector3.ZERO
var start_cur_surfaces: Dictionary
var start_surfaces: Array
var start_wasOnFloor: bool
var start_leaving_motion: float
var start_state: State


var initial_position: Vector3 = Vector3.ZERO
var initial_head_rotation: Vector3 = Vector3.ZERO
var initial_cam_rotation: Vector3 = Vector3.ZERO
var initial_velocity: Vector3 = Vector3.ZERO
var initial_cur_surfaces: Dictionary
var initial_surfaces: Array
var initial_wasOnFloor: bool
var initial_leaving_motion: float
var initial_state: State


func _ready() -> void:
	add_to_group("player")
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_ON)
	reset_physics_interpolation()
	call_deferred("_connect_ui")
	_set_start_position()
	_capture_initial_state()


func _physics_process(delta: float) -> void:
	if input_comp.isSetPosRequested: _set_start_position()
	if input_comp.isResetRequested: _reset_player_position()
	input_comp._input_update(delta)
	velocity_HU = velocity / config.HU_TO_M
	state_machine._physics_process_update(delta)
	velocity = velocity_HU * config.HU_TO_M
	
	resp_comp._resolve_motion(delta)
	crouch_comp._duck_update_process(delta)
	
	speed_changed.emit(velocity/config.HU_TO_M, global_position, state_machine.current_state.name == "PlayerAir", delta)


func _connect_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("ui")
	if ui:
		speed_changed.connect(ui._on_speed_changed)
		start_position_saved.connect(ui._on_start_position_saved)


func _reset_player_position() -> void:
	global_position = start_position
	velocity = start_velocity
	input_comp.head.global_rotation = start_head_rotation
	input_comp.cam.rotation = start_cam_rotation
	resp_comp.cur_state_surfaces = start_cur_surfaces
	resp_comp.surfaces = start_surfaces
	resp_comp.wasOnFloorLastFrame = start_wasOnFloor
	resp_comp.leaving_floor_motion = start_leaving_motion
	state_machine.current_state = start_state
	reset_physics_interpolation()


func _set_start_position() -> void:
	start_position = global_position
	start_head_rotation = input_comp.head.global_rotation
	start_cam_rotation = input_comp.cam.rotation
	start_velocity = velocity
	start_cur_surfaces = resp_comp.cur_state_surfaces
	start_surfaces = resp_comp.surfaces
	start_wasOnFloor = resp_comp.wasOnFloorLastFrame
	start_leaving_motion = resp_comp.leaving_floor_motion
	start_state = state_machine.current_state
	start_position_saved.emit()


func _capture_initial_state() -> void:
	initial_position = global_position
	initial_head_rotation = input_comp.head.global_rotation
	initial_cam_rotation = input_comp.cam.rotation
	initial_velocity = velocity
	initial_cur_surfaces = resp_comp.cur_state_surfaces.duplicate()
	initial_surfaces = resp_comp.surfaces.duplicate()
	initial_wasOnFloor = resp_comp.wasOnFloorLastFrame
	initial_leaving_motion = resp_comp.leaving_floor_motion
	initial_state = state_machine.current_state


func _reset_set_position() -> void:
	start_position = initial_position
	start_head_rotation = initial_head_rotation
	start_cam_rotation = initial_cam_rotation
	start_velocity = initial_velocity
	start_cur_surfaces = initial_cur_surfaces.duplicate()
	start_surfaces = initial_surfaces.duplicate()
	start_wasOnFloor = initial_wasOnFloor
	start_leaving_motion = initial_leaving_motion
	start_state = initial_state
	start_position_saved.emit()
