@tool
extends EditorScript

var _pending: Dictionary = {}

func _run() -> void:
	_pending.clear()
	_collect_inputs()
	_write_inputs()
	_set_project_settings()

	var err := ProjectSettings.save()
	if err != OK:
		push_error("Could not save project.godot: %s" % error_string(err))
		return
	print("Setup complete.")


func _collect_inputs() -> void:
	bind_key("left", KEY_A)
	bind_key("right", KEY_D)
	bind_key("up", KEY_W)
	bind_key("down", KEY_S)

	bind_key("walk", KEY_SHIFT)
	bind_key("crouch", KEY_CTRL)
	bind_key("noclip", KEY_E)

	bind_key("jump", KEY_SPACE)
	bind_mouse("jump", MOUSE_BUTTON_WHEEL_UP)
	bind_mouse("jump", MOUSE_BUTTON_WHEEL_DOWN)

	bind_key("reset_pos", KEY_R)
	bind_key("set_start_pos", KEY_Q)

	bind_key("turn_left", KEY_LEFT)
	bind_key("turn_right", KEY_RIGHT)


func bind_event(action: String, event: InputEvent) -> void:
	if not _pending.has(action):
		_pending[action] = []
	var list: Array = _pending[action]
	for existing in list:
		if existing.is_match(event):
			return
	list.append(event)

func bind_key(action: String, keycode: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	bind_event(action, e)

func bind_mouse(action: String, button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	bind_event(action, e)


func _write_inputs() -> void:
	for action: String in _pending:
		var setting: String = "input/" + action
		if ProjectSettings.has_setting(setting):
			print("'%s' is already defined, skipped." % action)
			continue
		ProjectSettings.set_setting(setting, {
			"deadzone": 0.2,
			"events": _pending[action],
		})
		for event: InputEvent in _pending[action]:
			print("Bound '%s' -> %s" % [action, event.as_text()])


func _set_project_settings() -> void:
	_apply_setting("display/window/stretch/aspect", "keep")
	_apply_setting("display/window/vsync/vsync_mode", 0)

	_apply_setting("physics/3d/physics_engine", "Jolt Physics")

	_apply_setting("physics/common/physics_ticks_per_second", 67)
	_apply_setting("physics/common/max_physics_steps_per_frame", 16)
	_apply_setting("physics/common/physics_jitter_fix", 0.0)
	_apply_setting("physics/common/physics_interpolation", true)
	_apply_setting("physics/jolt_physics_3d/collisions/collision_margin_fraction", 0.0)

func _apply_setting(path: String, value: Variant) -> void:
	ProjectSettings.set_setting(path, value)
	print("Set %s = %s" % [path, var_to_str(value)])
