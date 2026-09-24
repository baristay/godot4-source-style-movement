extends Control

var config: MovementConfig = preload("res://Player/resource/movement_config.tres")

const PROPERTY_MAP := {
	"Yaw Speed": "yaw_speed",
	"Camera FOV": "camera_fov",
	"Time Scale": "time_scale",
	"Tick Rate": "tick_rate",
	"Bunny Buffer": "bunny_buffer",
	"Run Speed N": "run_speed_n",
	"Walk Speed N": "walk_speed_n",
	"Duck Speed N": "duck_speed_n",
	"Acceleration N": "accel_power_n",
	"Friction N": "friction_n",
	"Run Speed": "run_speed",
	"Walk Speed": "walk_speed",
	"Duck Speed": "duck_speed",
	"Acceleration": "accel_power",
	"Friction": "friction",
	"Landing Speed": "landing_speed",
	"Air Wish Speed": "air_wish_speed",
	"Air Acceleration": "air_acceleration",
	"Max Air Speed": "max_air_speed",
	"Jump Force": "jump_force",
	"Gravity": "gravity",
	"Max Vertical Speed": "max_vertical_speed",
}

@onready var default_btn = $PanelContainer/MarginContainer/VBoxContainer/Buttons/Default
@onready var reset_btn = $"PanelContainer/MarginContainer/VBoxContainer/Buttons/Reset Position"
@onready var value_container = $PanelContainer/MarginContainer/VBoxContainer

@onready var autobunny = $"PanelContainer/MarginContainer/VBoxContainer/Customisation/Bunny Buffer/CheckBox"
@onready var bunny_buffer_s = $"PanelContainer/MarginContainer/VBoxContainer/Customisation/Bunny Buffer/Spinbox"
@onready var bunny_buffer_h = $"PanelContainer/MarginContainer/VBoxContainer/Customisation/Bunny Buffer/HSlider"

signal reset_pressed()

func _process(_delta: float) -> void:
	config.auto_bunny = true if autobunny.button_pressed else false
	if autobunny.button_pressed:
		bunny_buffer_s.get_line_edit().mouse_filter = Control.MOUSE_FILTER_IGNORE
		bunny_buffer_s.get_line_edit().focus_mode = Control.FOCUS_NONE
		bunny_buffer_s.editable = false
	else:
		bunny_buffer_s.get_line_edit().mouse_filter = 1
		bunny_buffer_s.get_line_edit().focus_mode = 2
		bunny_buffer_s.editable = true
	bunny_buffer_h.editable = false if autobunny.button_pressed else true

func _ready():
	add_to_group("rules")
	visible = false

	_connect_all_pairs($PanelContainer)
	_connect_sliders()
	call_deferred("_connect_player")

	default_btn.pressed.connect(_on_default)
	reset_btn.pressed.connect(_on_reset)
	default_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.focus_mode = Control.FOCUS_NONE
	autobunny.focus_mode = Control.FOCUS_NONE
	
	_sync_ui_from_config($PanelContainer)


func _on_reset():
	reset_pressed.emit()


func _on_default():
	config.reset_movement_to_default()
	autobunny.button_pressed = config.auto_bunny
	_sync_ui_from_config($PanelContainer)


func _sync_ui_from_config(node: Node) -> void:
	for child in node.get_children():
		if PROPERTY_MAP.has(child.name):
			var value = config.get(PROPERTY_MAP[child.name])
			var slider = child.find_child("HSlider", true, false)
			var spinbox = child.find_child("Spinbox", true, false)
			if slider:
				slider.value = value
			if spinbox:
				spinbox.value = value
		_sync_ui_from_config(child)
	_set_pair_value("Sensitivity", config.sensitivity)


func _set_pair_value(node_name: String, value):
	var parent = value_container.find_child(node_name, true, false)
	if not parent:
		push_warning("Node bulunamadı: " + node_name)
		return
	var slider = parent.find_child("HSlider", true, false)
	var spinbox = parent.find_child("Spinbox", true, false)
	if slider:
		slider.value = value
	if spinbox:
		spinbox.value = value


func _connect_all_pairs(node: Node):
	var slider = node.find_child("HSlider", false, false)
	var spinbox = node.find_child("Spinbox", false, false)
	if slider and spinbox:
		slider.value_changed.connect(func(val): spinbox.set_value_no_signal(val))
		spinbox.value_changed.connect(func(val): slider.set_value_no_signal(val))
	if spinbox:
		_restrict_spinbox_input(spinbox)
	for child in node.get_children():
		_connect_all_pairs(child)


func _restrict_spinbox_input(spinbox: SpinBox):
	var line_edit := spinbox.get_line_edit()
	line_edit.text_changed.connect(func(new_text: String):
		var regex := RegEx.new()
		regex.compile("[^0-9.\\-]")
		var filtered := regex.sub(new_text, "", true)
		if filtered != new_text:
			var caret := line_edit.caret_column
			line_edit.text = filtered
			line_edit.caret_column = clamp(caret - (new_text.length() - filtered.length()), 0, filtered.length())
	)


func _connect_sliders():
	_find_pair("Sensitivity", func(v): config.sensitivity = v)
	_find_pair("Yaw Speed", func(v): config.yaw_speed = v)
	_find_pair("Camera FOV", func(v): config.camera_fov = v)
	_find_pair("Time Scale", func(v): config.time_scale = v)
	_find_pair("Tick Rate", func(v): config.tick_rate = v)
	_find_pair("Bunny Buffer", func(v): config.bunny_buffer = v)
	_find_pair("Run Speed N", func(v): config.run_speed_n = v)
	_find_pair("Walk Speed N", func(v): config.walk_speed_n = v)
	_find_pair("Duck Speed N", func(v): config.duck_speed_n = v)
	_find_pair("Acceleration N", func(v): config.accel_power_n = v)
	_find_pair("Friction N", func(v): config.friction_n = v)
	_find_pair("Run Speed", func(v): config.run_speed = v)
	_find_pair("Walk Speed", func(v): config.walk_speed = v)
	_find_pair("Duck Speed", func(v): config.duck_speed = v)
	_find_pair("Acceleration", func(v): config.accel_power = v)
	_find_pair("Friction", func(v): config.friction = v)
	_find_pair("Landing Speed", func(v): config.landing_speed = v)
	_find_pair("Air Wish Speed", func(v): config.air_wish_speed = v)
	_find_pair("Air Acceleration", func(v): config.air_acceleration = v)
	_find_pair("Max Air Speed", func(v): config.max_air_speed = v)
	_find_pair("Jump Force", func(v): config.jump_force = v)
	_find_pair("Gravity", func(v): config.gravity = v)
	_find_pair("Max Vertical Speed", func(v): config.max_vertical_speed = v)


func _find_pair(node_name: String, callback: Callable):
	var parent = value_container.find_child(node_name, true, false)
	if not parent:
		push_warning("Node bulunamadı: " + node_name)
		return
	var slider = parent.find_child("HSlider", true, false)
	var spinbox = parent.find_child("Spinbox", true, false)
	if slider:
		slider.value_changed.connect(callback)
	if spinbox:
		spinbox.value_changed.connect(callback)


func _connect_player():
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		reset_pressed.connect(player._reset_to_initial_state)
