class_name PlayerCamera
extends Node3D

## PlayerCamera Component
## Manages first/third-person camera rotation, mouse capturing, and pitch/yaw.
##
## Note: Only the local multiplayer authority captures the mouse and activates Camera3D.

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

@onready var player: CharacterBody3D = get_parent()
@onready var camera_node: Camera3D = $Camera3D

var _pitch: float = 0.0

func _ready() -> void:
	if player.is_multiplayer_authority():
		camera_node.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera_node.current = false
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not player.is_multiplayer_authority():
		return

	# Handle mouse release on UI cancel (Escape) or recapture on click
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Handle mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation (Yaw) rotates the entire player or camera mount
		player.rotate_y(-event.relative.x * mouse_sensitivity)

		# Vertical rotation (Pitch) rotates the camera mount only
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		rotation.x = _pitch


## Returns the yaw transform basis for movement calculation
func get_yaw_basis() -> Basis:
	return player.global_transform.basis
