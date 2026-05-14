extends Node
class_name Limb

const _RAY_REACH := 10.0

@export var root: IKRoot
@export var target: IKTarget
@export var lead: IKLead

@export var limb_length: float
var gait: Gait

var stepping: bool = false
var step_t: float = 0.0
var can_step: bool = false
var _step_from: Vector3

func update(delta: float, move_dir: Vector3 = Vector3.ZERO) -> void:
	if not stepping:
		target.global_position.y = _ground_y(target.global_position)
	_update_lead(move_dir)
	_update_step(delta)

func calculate_limb_extension() -> float:
	var floor_y := _ground_y(target.global_position) if stepping else target.global_position.y
	var floor_pos := Vector3(target.global_position.x, floor_y, target.global_position.z)
	return root.global_position.distance_to(floor_pos) - limb_length

func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	return root.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to)
	)

func _ground_y(pos: Vector3) -> float:
	var hit := _raycast(pos + Vector3.UP * _RAY_REACH, pos + Vector3.DOWN * _RAY_REACH)
	return hit.position.y if hit else pos.y

func _update_lead(move_dir: Vector3) -> void:
	var stride := gait.stride if gait else 0.0
	var step_height := gait.step_height if gait else 0.0

	if move_dir.length() > 0.01:
		var fwd_hit := _raycast(
			root.global_position + Vector3.UP * step_height,
			root.global_position + Vector3.UP * step_height + move_dir * stride
		)
		if fwd_hit:
			lead.global_position = fwd_hit.position
			return

	lead.global_position.x = root.global_position.x + move_dir.x * stride
	lead.global_position.z = root.global_position.z + move_dir.z * stride
	lead.global_position.y = _ground_y(lead.global_position)

func _update_step(delta: float) -> void:
	if gait and can_step and not stepping and target.global_position.distance_to(lead.global_position) > gait.step_distance:
		stepping = true
		_step_from = target.global_position
		step_t = 0.0

	if gait and stepping:
		step_t = minf(step_t + delta / gait.step_duration, 1.0)
		var tx := gait.curve_x.sample(step_t) if gait.curve_x else step_t
		var ty := gait.curve_y.sample(step_t) if gait.curve_y else sin(step_t * PI)
		target.global_position = Vector3(
			lerpf(_step_from.x, lead.global_position.x, tx),
			lerpf(_step_from.y, lead.global_position.y, tx) + ty * gait.step_height,
			lerpf(_step_from.z, lead.global_position.z, tx)
		)
		if step_t >= 1.0:
			stepping = false
