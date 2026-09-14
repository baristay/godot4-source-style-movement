extends Control
class_name SidePanel

@onready var game_rules: Control = $"../Game Rules"
@onready var map_select: Control = $"../MapSelect"

@onready var resume_btn = $PanelContainer/MarginContainer/Buttons/Resume
@onready var game_rules_btn = $"PanelContainer/MarginContainer/Buttons/Game Rules"
@onready var options_btn = $PanelContainer/MarginContainer/Buttons/Options
@onready var map_select_btn = $"PanelContainer/MarginContainer/Buttons/Map Select"
@onready var quit_btn = $PanelContainer/MarginContainer/Buttons/Quit

enum CurrentTab {GAMERULES, OPTIONS, MAPSELECT, NONE}

signal tab_changed(new_tab: CurrentTab)
signal active_changed(is_active: bool)

const IsActiveOnStart: bool = true
const StartTab: CurrentTab = CurrentTab.GAMERULES
var _last_tab: CurrentTab = StartTab

var current_tab: CurrentTab = CurrentTab.GAMERULES:
	set(value):
		if current_tab == value:
			return
		current_tab = value
		if value != CurrentTab.NONE:
			_last_tab = value
		tab_changed.emit(value)
		_update_tab_visibility(value)

var is_active: bool = false:
	set(value):
		if is_active == value:
			return
		is_active = value
		active_changed.emit(value)
		_update_active_state(value)


func _ready() -> void:
	resume_btn.focus_mode = Control.FOCUS_NONE
	game_rules_btn.focus_mode = Control.FOCUS_NONE
	options_btn.focus_mode = Control.FOCUS_NONE
	map_select_btn.focus_mode = Control.FOCUS_NONE
	quit_btn.focus_mode = Control.FOCUS_NONE
	resume_btn.pressed.connect(_on_resume)
	game_rules_btn.pressed.connect(_on_game_rules)
	options_btn.pressed.connect(_on_options)
	map_select_btn.pressed.connect(_on_map_select)
	quit_btn.pressed.connect(_on_quit)
	
	call_deferred("_activate_on_start")

func _activate_on_start() -> void:
	is_active = IsActiveOnStart

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		toggle_menu()

func toggle_menu() -> void:
	is_active = !is_active

func _on_resume() -> void:
	toggle_menu()

func _on_game_rules() -> void:
	current_tab = CurrentTab.NONE if current_tab == CurrentTab.GAMERULES else CurrentTab.GAMERULES

func _on_options() -> void:
	current_tab = CurrentTab.NONE if current_tab == CurrentTab.OPTIONS else CurrentTab.OPTIONS

func _on_map_select() -> void:
	current_tab = CurrentTab.NONE if current_tab == CurrentTab.MAPSELECT else CurrentTab.MAPSELECT

func _on_quit() -> void:
	get_tree().quit()

func _update_active_state(active: bool) -> void:
	visible = active
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if current_tab == CurrentTab.NONE:
			current_tab = _last_tab
		else:
			_update_tab_visibility(current_tab)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_hide_all_panels()

func _update_tab_visibility(tab: CurrentTab) -> void:
	game_rules.visible = (tab == CurrentTab.GAMERULES)
	map_select.visible = (tab == CurrentTab.MAPSELECT)

func _hide_all_panels() -> void:
	game_rules.visible = false
	map_select.visible = false
