extends Node3D
class_name Quadruped

@export var pelvis: Girdle
@export var shoulder: Girdle
@export var gait: Gait
@export var run_gait: Gait
@export var gait_crossfade_time: float = 0.3


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
var _active_gait: Gait
var _blend_t: float = 0.0
var _blend_target: float = 0.0
var _limb_gaits: Array = []
var _limb_was_stepping: Array = []

func _ready() -> void:
	_yaw   = rotation.y
	_pitch = rotation.x
	_active_gait = gait
	for i in 4:
		var lg := Gait.new()
		_apply_blend_to(lg)
		_limb_gaits.append(lg)
		_limb_was_stepping.append(false)
		var limb := _get_limb(i)
		if limb:
			limb.gait = lg

func _process(delta: float) -> void:
	_handle_input(delta)
	var dir := velocity.normalized() if velocity.length() > 0.01 else Vector3.ZERO
	shoulder.update(delta, dir)
	pelvis.update(delta, dir)
	_update_blend(delta)
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

func _switch_gait(new_gait: Gait) -> void:
	if new_gait == null or new_gait == _active_gait:
		return
	_active_gait = new_gait

func _handle_input(delta: float) -> void:
	var shift_held := Input.is_key_pressed(KEY_SHIFT) and run_gait != null
	var over_walk_speed := velocity.length() > gait.move_speed

	_blend_target = 1.0 if shift_held else 0.0

	if shift_held:
		_switch_gait(run_gait)
	elif not over_walk_speed:
		_switch_gait(gait)
	# else: releasing shift but still fast — keep run gait until speed bleeds down

	_turn_input = Input.get_axis("ui_right", "ui_left")
	_yaw += _turn_input * _active_gait.turn_speed * delta

	var wish_dir := _flat_forward() * Input.get_axis("ui_down", "ui_up")
	if wish_dir.length() > 0.01:
		var target_speed := run_gait.move_speed if shift_held else gait.move_speed
		var step := gait.friction * delta if (not shift_held and over_walk_speed) else _active_gait.acceleration * delta
		velocity = velocity.move_toward(wish_dir * target_speed, step)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, _active_gait.friction * delta)

	global_position += velocity * delta
	rotation.y = _yaw

func _apply_blend_to(dst: Gait) -> void:
	var t := _blend_t
	if run_gait == null:
		dst.stride          = gait.stride
		dst.step_distance   = gait.step_distance
		dst.step_duration   = gait.step_duration
		dst.step_height     = gait.step_height
		dst.cycle_step_time = gait.cycle_step_time
		dst.curve_x         = gait.curve_x
		dst.curve_y         = gait.curve_y
		return
	dst.stride          = lerpf(gait.stride,          run_gait.stride,          t)
	dst.step_distance   = lerpf(gait.step_distance,   run_gait.step_distance,   t)
	dst.step_duration   = lerpf(gait.step_duration,   run_gait.step_duration,   t)
	dst.step_height     = lerpf(gait.step_height,     run_gait.step_height,     t)
	dst.cycle_step_time = lerpf(gait.cycle_step_time, run_gait.cycle_step_time, t)
	dst.curve_x = run_gait.curve_x if t >= 0.5 else gait.curve_x
	dst.curve_y = run_gait.curve_y if t >= 0.5 else gait.curve_y

func _update_blend(delta: float) -> void:
	_blend_t = move_toward(_blend_t, _blend_target, delta / gait_crossfade_time)
	for i in 4:
		var limb := _get_limb(i)
		if limb == null:
			continue
		var was: bool = _limb_was_stepping[i]
		_limb_was_stepping[i] = limb.stepping
		if limb.stepping and was:
			continue  # mid-step: freeze params so step completes under outgoing gait
		_apply_blend_to(_limb_gaits[i])

func _update_cycle(delta: float) -> void:
	if not _active_gait or _active_gait.cycle.is_empty():
		return
	for i in 4:
		var l := _get_limb(i)
		if l: l.can_step = false
	var current := _get_limb(_active_gait.cycle[_cycle_index])
	if not current:
		return
	current.can_step = true
	_cycle_timer -= delta
	if _cycle_timer <= 0.0:
		var cycle_time := lerpf(gait.cycle_step_time, run_gait.cycle_step_time if run_gait else gait.cycle_step_time, _blend_t)
		_cycle_timer = cycle_time
		_cycle_index = (_cycle_index + 1) % _active_gait.cycle.size()

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
