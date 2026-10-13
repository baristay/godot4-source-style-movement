## The player body. Wires the components together and runs them in order.
##
## It holds no movement logic itself. Each physics frame it runs this pipeline
## (see _physics_process):
## input_comp: sample the input for this frame
## checkpoint requests: save or load the checkpoint before anything reads the state
## mov_state: change the velocity (works in HU, see velocity_HU)
## resp_comp: collide and slide the body with that velocity
## crouch_state: update the crouch after the position has been resolved
##
## Also owns the checkpoint system, which stores and restores the whole player
## state through PlayerStateSnapshot.
extends CharacterBody3D
class_name Player
 
# --- Exports & Node References ---
var config: MovementConfig = preload("res://Player/resource/movement_config.tres")
 
@onready var input_comp:   InputComponent       = %InputComponent
@onready var resp_comp:    ResponseComponent    = %ResponseComponent
@onready var mov_state:    MovementStateMachine = %MovementStateMachine
@onready var crouch_state: CrouchStateMachine   = %CrouchStateMachine
 
# --- Signals ---
## Emitted every physics frame for the UI. velocity_hu is in HU, not meters.
signal speed_changed(velocity_hu: Vector3, pos: Vector3, is_air: bool, delta: float)
## Emitted when a new checkpoint is stored (also after a full reset).
signal start_position_saved()
 
# --- Public State ---
## The body's velocity in HU. Only valid during the movement state update,
## see _physics_process.
var velocity_HU: Vector3 = Vector3.ZERO
 
## Checkpoint set by the player. Overwritten by _save_checkpoint.
var start_snapshot: PlayerStateSnapshot = PlayerStateSnapshot.new()
## State at spawn. Never overwritten, used by _reset_to_initial_state.
var initial_snapshot: PlayerStateSnapshot = PlayerStateSnapshot.new()
 
 
func _ready() -> void:
	add_to_group("player")
	# Physics runs at a fixed rate, so the rendered position is interpolated
	# between physics frames. The reset avoids interpolating from a stale transform on frame one.
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_ON)
	reset_physics_interpolation()
	# Deferred so the UI node is already in the tree when we look for it.
	call_deferred("_connect_ui")
	
	# Both snapshots start as the spawn state.
	initial_snapshot.capture(self)
	start_snapshot.capture(self)
 
 
## Runs every rendered frame: look input first, then the crouch visuals.
func _process(delta: float) -> void:
	input_comp._input_process(delta)
	crouch_state._process_update(delta)


## Runs the per-frame pipeline described at the top of the file.
func _physics_process(delta: float) -> void:
	input_comp._input_physics_process(delta)
	
	# Checkpoint & Reset controls
	if input_comp.is_set_pos_requested: 
		_save_checkpoint()
	if input_comp.is_reset_requested: 
		_load_checkpoint()
	
	# The movement states work in HU, the physics body in meters.
	# Convert in, run the states, then convert back.
	velocity_HU = velocity / config.HU_TO_M
	mov_state._physics_process_update(delta)
	velocity = velocity_HU * config.HU_TO_M
	
	resp_comp._resolve_motion(delta)
	crouch_state._physics_process_update(delta)
	
	var is_in_air: bool = false
	if mov_state.current_state:
		is_in_air = (mov_state.current_state.name == "PlayerAir")
	
	speed_changed.emit(velocity / config.HU_TO_M, global_position, is_in_air, delta)


## Connects the player's signals to the first node in the "ui" group.
func _connect_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("ui")
	if ui:
		if not speed_changed.is_connected(ui._on_speed_changed):
			speed_changed.connect(ui._on_speed_changed)
		if not start_position_saved.is_connected(ui._on_start_position_saved):
			start_position_saved.connect(ui._on_start_position_saved)


# --- Checkpoint ---
## Stores the current state as the new checkpoint and tells the UI.
func _save_checkpoint() -> void:
	start_snapshot.capture(self)
	start_position_saved.emit()
 
 
## Restores the player to the last saved checkpoint.
func _load_checkpoint() -> void:
	start_snapshot.apply(self)
 
 
## Restores the spawn state and makes it the new checkpoint, so the next
## _load_checkpoint returns here instead of to an older one.
func _reset_to_initial_state() -> void:
	initial_snapshot.apply(self)
	start_snapshot.capture(self)
	start_position_saved.emit()
 
 
# --- Inner Class: PlayerStateSnapshot ---
## A copy of everything needed to put the player back exactly where it was:
## position, view, velocity, the surface state of ResponseComponent and the
## movement / crouch states.
##
## Without the surface state, a restored player would be treated as if it had
## just left the floor or landed, and the first frame after loading would behave differently.
class PlayerStateSnapshot:
	var position: Vector3
	var head_rotation: Vector3
	var cam_rotation: Vector3
	var velocity: Vector3
	var cur_surfaces: Dictionary
	var surfaces: Array
	var was_on_floor: bool
	var leaving_motion: float
	var movement_state: MovementState
	var movement_state_info: Dictionary
	var crouch_state: CrouchState
	var crouch_state_info: Dictionary
	
	## Copies the player's current state into this snapshot.
	## Dictionaries and arrays are deep copied, so later changes in the
	## ResponseComponent do not modify the snapshot.
	## The states themselves are only referenced. What they need to remember
	## is stored in *_state_info, if the state has a _store_state_info method.
	func capture(player: Player) -> void:
		position = player.global_position
		# The head holds the yaw and the camera the pitch (see InputComponent)
		head_rotation = player.input_comp.head.global_rotation
		cam_rotation = player.input_comp.cam.rotation
		velocity = player.velocity
		
		cur_surfaces = player.resp_comp.cur_state_surfaces.duplicate(true)
		surfaces = player.resp_comp.surfaces.duplicate(true)
		
		was_on_floor = player.resp_comp.was_on_floor_last_frame
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
	
	## Writes this snapshot back to the player.
	## A state that was null at capture time is skipped and the player keeps its
	## current one. The states are re-entered with transition_to_state, so their
	## enter logic runs again with the stored info.
	## Ends by resetting the physics interpolation, otherwise the player would
	## be drawn sliding from the old position to the restored one.
	func apply(player: Player) -> void:
		player.global_position = position
		player.velocity = velocity
		player.input_comp.head.global_rotation = head_rotation
		player.input_comp.cam.rotation = cam_rotation
		
		player.resp_comp.cur_state_surfaces = cur_surfaces.duplicate(true)
		player.resp_comp.surfaces = surfaces.duplicate(true)
		player.resp_comp.was_on_floor_last_frame = was_on_floor
		player.resp_comp.leaving_floor_motion = leaving_motion
		
		if movement_state:
			player.mov_state.transition_to_state(movement_state, movement_state_info)
		
		if crouch_state:
			player.crouch_state.transition_to_state(crouch_state, crouch_state_info)
		
		player.reset_physics_interpolation()
