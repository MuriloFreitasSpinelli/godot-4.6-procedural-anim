extends Camera3D

@export var target: Node3D
@export var offset: Vector3 = Vector3.ZERO
@export var distance: float = 6.0
@export var sensitivity: float = 0.3
@export var zoom_speed: float = 0.5
@export var min_distance: float = 1.0
@export var max_distance: float = 30.0
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

var _yaw: float = 0.0
var _pitch: float = 20.0
var _dragging: bool = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				distance = clamp(distance - zoom_speed, min_distance, max_distance)
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = clamp(distance + zoom_speed, min_distance, max_distance)

	if event is InputEventMouseMotion and _dragging:
		_yaw   -= event.relative.x * sensitivity
		_pitch -= event.relative.y * sensitivity
		_pitch  = clamp(_pitch, min_pitch, max_pitch)


func _process(_delta: float) -> void:
	if not target:
		return
	var pivot := target.global_position + offset
	var rot := Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0))
	global_position = pivot + rot * Vector3(0.0, 0.0, distance)
	look_at(pivot)
