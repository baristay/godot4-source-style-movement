extends CharacterBody3D
class_name Player

# --- Exports & Node References ---
var config: MovementConfig = preload("res://Player/resource/movement_config.tres")

@onready var input_comp:   InputComponent       = %InputComponent
@onready var resp_comp:    ResponseComponent    = %ResponseComponent
@onready var mov_state:    MovementStateMachine = %MovementStateMachine
@onready var crouch_state: CrouchStateMachine   = %CrouchStateMachine

# --- Signals ---
signal speed_changed(velocity_hu: Vector3, pos: Vector3, is_air: bool, delta: float)
signal start_position_saved()

# --- Public State ---
var velocity_HU: Vector3 = Vector3.ZERO

var start_snapshot: PlayerStateSnapshot = PlayerStateSnapshot.new()
var initial_snapshot: PlayerStateSnapshot = PlayerStateSnapshot.new()


func _ready() -> void:
	add_to_group("player")
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_ON)
	reset_physics_interpolation()
	call_deferred("_connect_ui")
	
	initial_snapshot.capture(self)
	start_snapshot.capture(self)


func _process(delta: float) -> void:
	crouch_state._process_update(delta)


func _physics_process(delta: float) -> void:
	# Checkpoint & Reset controls
	if input_comp.isSetPosRequested: 
		_save_checkpoint()
	if input_comp.isResetRequested: 
		_load_checkpoint()
	
	input_comp._input_update(delta)
	
	velocity_HU = velocity / config.HU_TO_M
	mov_state._physics_process_update(delta)
	velocity = velocity_HU * config.HU_TO_M
	
	resp_comp._resolve_motion(delta)
	crouch_state._physics_process_update(delta)
	
	var is_in_air: bool = false
	if mov_state.current_state:
		is_in_air = (mov_state.current_state.name == "PlayerAir")
	
	speed_changed.emit(velocity / config.HU_TO_M, global_position, is_in_air, delta)


func _connect_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("ui")
	if ui:
		if not speed_changed.is_connected(ui._on_speed_changed):
			speed_changed.connect(ui._on_speed_changed)
		if not start_position_saved.is_connected(ui._on_start_position_saved):
			start_position_saved.connect(ui._on_start_position_saved)


# --- Checkpoint ---
func _save_checkpoint() -> void:
	start_snapshot.capture(self)
	start_position_saved.emit()


func _load_checkpoint() -> void:
	start_snapshot.apply(self)


func _reset_to_initial_state() -> void:
	initial_snapshot.apply(self)
	start_snapshot.capture(self)
	start_position_saved.emit()


# --- Inner Class: PlayerStateSnapshot ---
class PlayerStateSnapshot:
	var position: Vector3
	var head_rotation: Vector3
	var cam_rotation: Vector3
	var velocity: Vector3
	var cur_surfaces: Dictionary
	var surfaces: Array
	var wasOnFloor: bool
	var leaving_motion: float
	var movement_state: MovementState
	var movement_state_info: Dictionary
	var crouch_state: CrouchState
	var crouch_state_info: Dictionary
	
	
	func capture(player: Player) -> void:
		position = player.global_position
		head_rotation = player.input_comp.head.global_rotation
		cam_rotation = player.input_comp.cam.rotation
		velocity = player.velocity
		
		cur_surfaces = player.resp_comp.cur_state_surfaces.duplicate(true)
		surfaces = player.resp_comp.surfaces.duplicate(true)
		
		wasOnFloor = player.resp_comp.wasOnFloorLastFrame
		leaving_motion = player.resp_comp.leaving_floor_motion
		
		movement_state = player.mov_state.current_state
		if movement_state and movement_state.has_method("_store_state_info"):
			movement_state_info = movement_state._store_state_info()
		else:
			movement_state_info = {}
		
		crouch_state = player.crouch_state.current_state
		if crouch_state and crouch_state.has_method("_store_state_info"):
			crouch_state_info = crouch_state._store_state_info()
		else:
			crouch_state_info = {}
	
	
	func apply(player: Player) -> void:
		player.global_position = position
		player.velocity = velocity
		player.input_comp.head.global_rotation = head_rotation
		player.input_comp.cam.rotation = cam_rotation
		
		player.resp_comp.cur_state_surfaces = cur_surfaces.duplicate(true)
		player.resp_comp.surfaces = surfaces.duplicate(true)
		player.resp_comp.wasOnFloorLastFrame = wasOnFloor
		player.resp_comp.leaving_floor_motion = leaving_motion
		
		if movement_state:
			player.mov_state.transition_to_state(movement_state, movement_state_info)
		
		if crouch_state:
			player.crouch_state.transition_to_state(crouch_state, crouch_state_info)
		
		player.reset_physics_interpolation()
