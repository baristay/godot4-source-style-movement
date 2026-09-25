class_name CrouchStateMachine
extends Node

@export var initial_state: CrouchState
@onready var body: CharacterBody3D = owner as CharacterBody3D
@onready var resp_comp: ResponseComponent = %ResponseComponent
@onready var head: Node3D = %Head
@onready var col_comp: CollisionComponent = %CollisionComponent
@onready var input_comp: InputComponent = %InputComponent

const COLLISION_MARGIN: float = 0.003

var states: Dictionary = {}
var current_state: CrouchState

var _eye_y_prev: float
var _eye_y_curr: float
var crouch_progress: float = 0.0


func _ready() -> void:
	_eye_y_prev = col_comp.STAND_EYE
	_eye_y_curr = col_comp.STAND_EYE
	
	for child in get_children():
		if child is CrouchState:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_child_transition)
	
	if initial_state:
		current_state = initial_state
		initial_state._enter()


func _physics_process_update(delta: float) -> void:
	_eye_y_prev = _eye_y_curr
	if current_state:
		current_state._physics_update(delta)


func _process_update(delta: float) -> void:
	if current_state:
		current_state._update(delta)


func _on_child_transition(_state: CrouchState, new_state_name: String) -> void:
	if _state != current_state:
		return
	
	var new_state: CrouchState = states.get(new_state_name.to_lower())
	transition_to_state(new_state)


func transition_to_state(new_state: CrouchState, is_restore: Dictionary = {}) -> void:
	if not new_state or (new_state == current_state and is_restore.is_empty()):
		return
	
	if current_state and is_restore.is_empty():
		current_state._exit()
		
	current_state = new_state
	new_state._enter(not is_restore.is_empty())
	
	if not is_restore.is_empty():
		new_state._on_restore(is_restore)
