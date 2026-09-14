extends Control

@onready var loading_screen: Control = $"../LoadingScreen"

@export var normal_color := Color(1, 1, 1)
@export var hover_color := Color(1.25, 1.25, 1.25)
@export var pressed_color := Color(0.7, 0.7, 0.7)

@onready var button_maps: Dictionary = {
	$"PanelContainer/ScrollContainer/VBoxContainer/HBoxContainer2/Open Playground/TextureButton": "res://Maps/open_playground.tscn",
	$"PanelContainer/ScrollContainer/VBoxContainer/HBoxContainer2/Movement Test/TextureButton": "res://Maps/movement_test.tscn"
}

func _ready():
	visible = false
	for btn: TextureButton in button_maps.keys():
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_meta("is_hovering", false)
		btn.mouse_entered.connect(_on_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_hover.bind(btn, false))
		btn.button_down.connect(func(): btn.self_modulate = pressed_color)
		btn.button_up.connect(_refresh.bind(btn))
		btn.pressed.connect(_on_map_pressed.bind(btn))

func _on_hover(btn: TextureButton, hovering: bool) -> void:
	btn.set_meta("is_hovering", hovering)
	_refresh(btn)

func _refresh(btn: TextureButton) -> void:
	btn.self_modulate = hover_color if btn.get_meta("is_hovering") else normal_color

func _on_map_pressed(btn: TextureButton) -> void:
	var map_path: String = button_maps.get(btn, "")
	if map_path == "":
		push_warning("There is no map assigned to this button.: %s" % btn.name)
		return
	
	loading_screen.visible = true
	loading_screen.move_to_front()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	get_tree().change_scene_to_file(map_path)
