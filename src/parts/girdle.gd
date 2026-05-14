extends Node
class_name Girdle

@export var root: Node3D
@export var adapt_speed: float = 5.0

@export var left_limb: Limb
@export var right_limb: Limb

@export_group("Sway")
@export var step_sway: float = 0.05
@export var sway_speed: float = 4.0
@export var skeleton: Skeleton3D
@export var sway_bone: String
@export var counter_sway_bone: String

@export_group("Root Bone")
@export var is_root_bone: bool = false
@export var extension_bias: float = 1.0

@export_group("Height Bone")
@export var height_bone: String = ""
@export var height_bone_length: float = 1.0
@export var height_bone_axis: Vector3 = Vector3.RIGHT
@export var height_scale_down: float = 1.0
@export var height_scale_up: float = 1.0

var _rot_y: float = 0.0
var _prev_rot_y: float = 0.0
var _height_angle: float = 0.0
var _bone_idx: int = -1
var _counter_bone_idx: int = -1
var _counter_bone_searched: bool = false
var _height_bone_idx: int = -1

func update(delta: float, move_dir: Vector3 = Vector3.ZERO) -> void:
	left_limb.update(delta, move_dir)
	right_limb.update(delta, move_dir)
	update_height(delta)
	update_sway(delta)

func update_height(delta: float) -> void:
	var extension := maxf(left_limb.calculate_limb_extension(), right_limb.calculate_limb_extension())

	if is_root_bone:
		var target_y := root.global_position.y - extension
		if extension > 0.0:
			target_y -= extension * extension_bias
		root.global_position.y = lerpf(root.global_position.y, target_y, adapt_speed * delta)
	else:
		if _height_bone_idx < 0:
			_height_bone_idx = skeleton.find_bone(height_bone)
		if _height_bone_idx >= 0:
			var scaled_ext := extension * height_scale_down if extension > 0.0 else extension * height_scale_up
			var target_angle := -asin(clamp(scaled_ext / height_bone_length, -1.0, 1.0))
			_height_angle = lerpf(_height_angle, target_angle, adapt_speed * delta)
			skeleton.set_bone_pose_rotation(_height_bone_idx, Quaternion(height_bone_axis.normalized(), _height_angle) * _rest_rot(_height_bone_idx))

func update_sway(delta: float) -> void:
	if _bone_idx < 0:
		_bone_idx = skeleton.find_bone(sway_bone)
	if _bone_idx < 0:
		return

	var target_rot_y := step_sway if left_limb.stepping else (-step_sway if right_limb.stepping else 0.0)
	_rot_y = lerpf(_rot_y, target_rot_y, sway_speed * delta)

	if is_root_bone:
		var current := skeleton.get_bone_pose_rotation(_bone_idx)
		skeleton.set_bone_pose_rotation(_bone_idx, current * Quaternion(Vector3.UP, _rot_y - _prev_rot_y))
		_prev_rot_y = _rot_y
	else:
		var base_rot := Quaternion(height_bone_axis.normalized(), _height_angle) * _rest_rot(_bone_idx) if _bone_idx == _height_bone_idx else _rest_rot(_bone_idx)
		skeleton.set_bone_pose_rotation(_bone_idx, base_rot * Quaternion(Vector3.UP, _rot_y))

	if counter_sway_bone != "" and not _counter_bone_searched:
		_counter_bone_idx = skeleton.find_bone(counter_sway_bone)
		_counter_bone_searched = true
	if _counter_bone_idx >= 0:
		skeleton.set_bone_pose_rotation(_counter_bone_idx, _rest_rot(_counter_bone_idx) * Quaternion(Vector3.UP, -_rot_y))

func _rest_rot(bone_idx: int) -> Quaternion:
	return skeleton.get_bone_rest(bone_idx).basis.get_rotation_quaternion()
