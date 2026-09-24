extends Node
class_name MovementStateMachine

# --- Exports & Node References ---
@export var initial_state: MovementState
@onready var resp_comp: ResponseComponent = %ResponseComponent
@onready var body: CharacterBody3D = owner as CharacterBody3D

# --- Private State ---
var states:        Dictionary     = {}
var current_state: MovementState


func _ready() -> void:
	for child in get_children():
		if child is MovementState:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_child_transition)
	
	if initial_state:
		current_state = initial_state
		initial_state._enter()


func _physics_process_update(delta: float) -> void:
	if current_state:
		current_state._physics_update(delta)


func _process_update(delta: float) -> void:
	if current_state:
		current_state._update(delta)


func _on_child_transition(_state: MovementState, new_state_name: String) -> void:
	if _state != current_state:
		return
	
	var new_state: MovementState = states.get(new_state_name.to_lower())
	transition_to_state(new_state)


func transition_to_state(new_state: MovementState, is_restore: Dictionary = {}) -> void:
	if not new_state:
		return
	if new_state == current_state:
		return
	
	if current_state and is_restore.is_empty():
		current_state._exit()
	current_state = new_state
	new_state._enter()
	
	if !is_restore.is_empty():
		new_state._on_restore(is_restore)
