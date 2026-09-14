extends Control

var config: MovementConfig = preload("res://Player/resource/movement_config.tres")

@onready var velocity = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Velocity
@onready var horizontal_speed = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/HorizontalSpeed
@onready var body_position = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/Position
@onready var optimal_rotation = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/OptimalRotation
@onready var fps = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer5/FPS

@onready var spawn_saved_label: Control = $PositionSet

const SPAWN_SAVED_VISIBLE_DURATION := 1.5 
const SPAWN_SAVED_FADE_DURATION := 0.5

var _spawn_label_token: int = 0
var _spawn_label_tween: Tween


func _ready() -> void:
	add_to_group("ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	spawn_saved_label.modulate.a = 0.0


func _on_speed_changed(_velocity: Vector3, _position: Vector3, is_in_air: bool, delta: float) -> void:
	_position /= config.HU_TO_M
	var rotationf = asin(clamp((config.air_acceleration * config.air_wish_speed * delta) / Vector2(_velocity.x, _velocity.z).length(), -1.0, 1.0)) / delta
	rotationf = 0.0 if !is_in_air else rotationf
	velocity.text = " %.2f, x: %.2f y: %.2f z: %.2f" % [_velocity.length(), _velocity.x, _velocity.y, _velocity.z]
	horizontal_speed.text = "%.2f" % Vector2(_velocity.x, _velocity.z).length()
	body_position.text = "x: %.2f y: %.2f z: %.2f" % [_position.x, _position.y, _position.z]
	optimal_rotation.text = "%.2f°" % rotationf
	fps.text = "%.0f" % Engine.get_frames_per_second()


func _on_start_position_saved() -> void:
	if _spawn_label_tween and _spawn_label_tween.is_valid():
		_spawn_label_tween.kill()

	spawn_saved_label.modulate.a = 1.0
	_spawn_label_token += 1
	var token := _spawn_label_token

	await get_tree().create_timer(SPAWN_SAVED_VISIBLE_DURATION).timeout
	if token == _spawn_label_token:
		_spawn_label_tween = create_tween()
		_spawn_label_tween.tween_property(spawn_saved_label, "modulate:a", 0.0, SPAWN_SAVED_FADE_DURATION)
