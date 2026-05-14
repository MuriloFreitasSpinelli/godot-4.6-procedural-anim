extends Resource
class_name Gait

@export var move_speed: float = 5.0
@export var acceleration: float = 8.0
@export var friction: float = 6.0
@export var turn_speed: float = 2.0

@export var stride: float = 0.5
@export var step_distance: float = 0.5
@export var step_duration: float = 0.3
@export var step_height: float = 0.3
@export var curve_x: Curve
@export var curve_y: Curve

@export_group("Cycle")
@export var cycle: Array[int] = [0, 3, 1, 2]
@export var cycle_step_time: float = 0.3
