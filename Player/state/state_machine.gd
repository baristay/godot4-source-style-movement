extends Node
class_name StateMachine

# --- Exports & Node References ---
@export var initial_state: State
@onready var resp_comp: ResponseComponent = %ResponseComponent
@onready var body: CharacterBody3D = owner as CharacterBody3D

# --- Private State ---
var states:        Dictionary     = {}
var current_state: State


func _ready() -> void:
	for child in get_children():
		if child is State:
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


func _on_child_transition(_state: State, new_state_name: String) -> void:
	if _state != current_state:
		return
	
	var new_state: State = states.get(new_state_name.to_lower())
	if not new_state:
		return
	
	current_state._exit()
	current_state = new_state
	new_state._enter()
