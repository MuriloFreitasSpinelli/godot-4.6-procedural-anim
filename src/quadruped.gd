extends Node3D
class_name Quadruped

@export var pelvis: Girdle
@export var shoulder: Girdle
@export var gait: Gait


@export_group("Look At")
@export var look_at_target: Node3D
@export var look_at_offset_y: float = 1.0
@export var look_at_adapt_speed: float = 5.0
@export var look_at_forward_dist: float = 2.0
@export var look_at_turn_offset: float = 1.0

@export_group("Body Pitch")
@export var pitch_speed: float = 0.8
@export var max_pitch_deg: float = 7.0

@export_group("Turn Lean")
@export var lean_skeleton: Skeleton3D
@export var lean_bone: String
@export var turn_lean: float = 0.1
@export var lean_speed: float = 5.0

@export_group("Debug")
@export var editor_debug: bool = true

var velocity: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0
var _cycle_index: int = 0
var _cycle_timer: float = 0.0
var _turn_input: float = 0.0
var _lean_z: float = 0.0
var _lean_bone_idx: int = -1
var _look_at_turn: float = 0.0

func _ready() -> void:
	_yaw   = rotation.y
	_pitch = rotation.x
	for limb in [shoulder.left_limb, shoulder.right_limb, pelvis.left_limb, pelvis.right_limb]:
		limb.gait = gait

func _process(delta: float) -> void:
	_handle_input(delta)
	var dir := velocity.normalized() if velocity.length() > 0.01 else Vector3.ZERO
	shoulder.update(delta, dir)
	pelvis.update(delta, dir)
	_update_cycle(delta)
	_update_look_at_target(delta)
	_update_pitch(delta)
	_update_turn_lean(delta)

func _flat_forward() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))

func _flat_right() -> Vector3:
	var fwd := _flat_forward()
	return Vector3(fwd.z, 0.0, -fwd.x)

func _limb_target_ok(l: Limb) -> bool:
	return is_instance_valid(l) and is_instance_valid(l.target) and l.target.is_inside_tree()

func _foot_midpoint(a: Limb, b: Limb) -> Vector3:
	return (a.target.global_position + b.target.global_position) * 0.5

func _get_limb(i: int) -> Limb:
	match i:
		0: return shoulder.left_limb
		1: return shoulder.right_limb
		2: return pelvis.left_limb
		3: return pelvis.right_limb
	return null

func _handle_input(delta: float) -> void:
	_turn_input = Input.get_axis("ui_right", "ui_left")
	_yaw += _turn_input * gait.turn_speed * delta

	var wish_dir := _flat_forward() * Input.get_axis("ui_down", "ui_up")
	if wish_dir.length() > 0.01:
		velocity = velocity.move_toward(wish_dir * gait.move_speed, gait.acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, gait.friction * delta)

	global_position += velocity * delta
	rotation.y = _yaw

func _update_cycle(delta: float) -> void:
	if not gait or gait.cycle.is_empty():
		return
	for i in 4:
		var l := _get_limb(i)
		if l: l.can_step = false
	var current := _get_limb(gait.cycle[_cycle_index])
	if not current:
		return
	current.can_step = true
	_cycle_timer -= delta
	if _cycle_timer <= 0.0:
		_cycle_timer = gait.cycle_step_time
		_cycle_index = (_cycle_index + 1) % gait.cycle.size()

func _update_look_at_target(delta: float) -> void:
	if not is_instance_valid(look_at_target) or not look_at_target.is_inside_tree():
		return
	_look_at_turn = lerpf(_look_at_turn, _turn_input, look_at_adapt_speed * delta)
	var fwd := _flat_forward()
	var right := _flat_right()
	look_at_target.global_position.x = global_position.x + fwd.x * look_at_forward_dist + right.x * _look_at_turn * look_at_turn_offset
	look_at_target.global_position.z = global_position.z + fwd.z * look_at_forward_dist + right.z * _look_at_turn * look_at_turn_offset

	var pos := look_at_target.global_position
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 10.0, pos + Vector3.DOWN * 100.0)
	)
	if hit:
		look_at_target.global_position.y = lerpf(look_at_target.global_position.y, hit.position.y + look_at_offset_y, look_at_adapt_speed * delta)

func _floor_y(limb: Limb) -> float:
	if limb.stepping and is_instance_valid(limb.lead) and limb.lead.is_inside_tree():
		return limb.lead.global_position.y
	return limb.target.global_position.y

func _update_pitch(delta: float) -> void:
	var sl := shoulder.left_limb
	var sr := shoulder.right_limb
	var pl := pelvis.left_limb
	var pr := pelvis.right_limb

	if not (_limb_target_ok(sl) and _limb_target_ok(sr) and _limb_target_ok(pl) and _limb_target_ok(pr)):
		return

	var front := _foot_midpoint(sl, sr)
	var back  := _foot_midpoint(pl, pr)
	var horiz := Vector2(front.x, front.z).distance_to(Vector2(back.x, back.z))
	if horiz < 0.01:
		return

	var front_y := (_floor_y(sl) + _floor_y(sr)) * 0.5
	var back_y  := (_floor_y(pl) + _floor_y(pr)) * 0.5
	var max_pitch := deg_to_rad(max_pitch_deg)
	var target_pitch := clampf(atan2(front_y - back_y, horiz), -max_pitch, max_pitch)
	_pitch = lerp_angle(_pitch, target_pitch, pitch_speed * delta)
	rotation.x = _pitch

func _update_turn_lean(delta: float) -> void:
	if not is_instance_valid(lean_skeleton) or lean_bone == "":
		return
	if _lean_bone_idx < 0:
		_lean_bone_idx = lean_skeleton.find_bone(lean_bone)
	if _lean_bone_idx < 0:
		return
	_lean_z = lerpf(_lean_z, -_turn_input * turn_lean, lean_speed * delta)
	var rest_rot := lean_skeleton.get_bone_rest(_lean_bone_idx).basis.get_rotation_quaternion()
	lean_skeleton.set_bone_pose_rotation(_lean_bone_idx, rest_rot * Quaternion(Vector3.FORWARD, _lean_z))
