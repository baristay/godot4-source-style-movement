extends Node
class_name CollisionComponent

@onready var head: Node3D          = %Head
@onready var body: CharacterBody3D = owner as CharacterBody3D
@onready var foot_position: Marker3D = %FootPosition

const HU_TO_M   : float = MovementConfig.HU_TO_M
const STAND_H   : float = 72 * HU_TO_M
const DUCK_H    : float = 54 * HU_TO_M
const HULL_DELTA: float = STAND_H - DUCK_H
const WIDTH     : float = 32 * HU_TO_M

const EYE_DIFFERENCE: float = 8 * HU_TO_M
const STAND_EYE     : float = STAND_H - EYE_DIFFERENCE
const DUCK_EYE      : float = DUCK_H - EYE_DIFFERENCE

const CROUCH_MARGIN     : float = 6 * HU_TO_M
const CROUCH_JUMP_MARGIN: float = HULL_DELTA - (2 * HU_TO_M)
const DELTA_BOX_MARGIN  : float = 0.003
const BODY_MARGIN       : float = 0.001

const BOX_VECTOR   : Vector3 = Vector3(WIDTH, STAND_H,    WIDTH)
const DUCK_VECTOR  : Vector3 = Vector3(WIDTH, DUCK_H,     WIDTH)
const DELTA_VECTOR : Vector3 = Vector3(WIDTH, HULL_DELTA, WIDTH)

const DUCK_TIME     : float = 1.0
const TIME_TO_DUCK  : float = 0.25
const TIME_TO_UNDUCK: float = 0.1

var box_shape   : BoxShape3D = BoxShape3D.new()
var duck_shape  : BoxShape3D = BoxShape3D.new()
var delta_shape : BoxShape3D = BoxShape3D.new()

var collision_shape: CollisionShape3D
var test_shape: Shape3D

var test_body_rid: RID
var cur_shape: Shape3D
var cur_shape_local_transform: Transform3D

var node3d: Node3D
@export var debug_draw: bool = false
var debug_mesh: MeshInstance3D


func _ready() -> void:
	test_body_rid = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_space(test_body_rid, body.get_world_3d().space)
	PhysicsServer3D.body_set_mode(test_body_rid, PhysicsServer3D.BODY_MODE_KINEMATIC)
	PhysicsServer3D.body_set_collision_layer(test_body_rid, 0)
	PhysicsServer3D.body_set_collision_mask(test_body_rid, PhysicsServer3D.body_get_collision_mask(body.get_rid()))
	
	collision_shape = %CollisionShape3D 
	box_shape.size   = BOX_VECTOR
	duck_shape.size  = DUCK_VECTOR
	delta_shape.size = DELTA_VECTOR
	
	_set_standing()
	head.position.y = STAND_EYE
	if debug_draw:
		_setup_debug_mesh()


func _setup_debug_mesh() -> void:
	debug_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_mesh.material_override = mat
	debug_mesh.top_level = true
	get_tree().root.add_child.call_deferred(debug_mesh)


func _expand_collision(shape: Shape3D, expand_vector3: Vector3) -> void:
	if shape is BoxShape3D:
		shape.size += expand_vector3 * 2.0


func _set_test_shape(shape: Shape3D) -> void:
	test_shape = shape
	if test_shape:
		test_shape = test_shape.duplicate()


func _set_standing() -> void:
	collision_shape.shape = box_shape
	collision_shape.global_position = _calculate_body_middle()
	body.force_update_transform()


func _set_ducked() -> void:
	collision_shape.shape = duck_shape
	collision_shape.global_position = _calculate_body_middle()
	body.force_update_transform()


func _test_collision(
	shape: Shape3D,
	from: Transform3D,
	motion: Vector3,
	recovery: bool,
	debug: bool) -> PhysicsTestMotionResult3D:
	
	var result: PhysicsTestMotionResult3D
	
	if shape is BoxShape3D:
		result = _box_test(shape, from, motion, recovery, debug)
	else:
		result = PhysicsTestMotionResult3D.new()
	
	return result

func _box_test(shape: BoxShape3D,
	from: Transform3D,
	motion: Vector3,
	recovery: bool,
	debug: bool) -> PhysicsTestMotionResult3D:
	
	var offset: Transform3D = Transform3D(Basis(), Vector3(0, shape.size.y / 2.0, 0))
	
	if cur_shape != shape or cur_shape_local_transform != offset:
		if PhysicsServer3D.body_get_shape_count(test_body_rid) > 0:
			PhysicsServer3D.body_remove_shape(test_body_rid, 0)
		PhysicsServer3D.body_add_shape(test_body_rid, shape.get_rid(), offset)
		cur_shape = shape
		cur_shape_local_transform = offset
	
	if debug_draw and shape is BoxShape3D and debug and debug_mesh.is_inside_tree():
		var box_mesh := BoxMesh.new()
		box_mesh.size = shape.size
		debug_mesh.mesh = box_mesh
		debug_mesh.transform = from
		debug_mesh.global_position += Vector3(0, shape.size.y / 2.0, 0)
	
	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()
	params.from = from
	params.motion = motion
	params.margin = 0.0
	params.max_collisions = 3
	params.recovery_as_collision = recovery
	params.exclude_bodies = [body.get_rid()]
	
	PhysicsServer3D.body_test_motion(test_body_rid, params, result)
	
	return result


func _exit_tree() -> void:
	if test_body_rid.is_valid():
		PhysicsServer3D.free_rid(test_body_rid)
	if debug_mesh:
		debug_mesh.queue_free()


func _set_collision_enabled(enabled: bool) -> void:
	collision_shape.disabled = not enabled
	var mask: int = body.collision_mask if enabled else 0
	PhysicsServer3D.body_set_collision_layer(body.get_rid(), body.collision_layer if enabled else 0)
	PhysicsServer3D.body_set_collision_mask(body.get_rid(), mask)
	PhysicsServer3D.body_set_collision_mask(test_body_rid, mask)


func _calculate_body_middle() -> Vector3:
	return foot_position.global_position + (Vector3.UP * collision_shape.shape.size.y / 2)
