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
@onready var spring_arm: SpringArm3D = get_node_or_null("SpringArm3D")
@onready var camera_node: Camera3D = (
	get_node_or_null("SpringArm3D/Camera3D") if has_node("SpringArm3D/Camera3D")
	else get_node_or_null("Camera3D")
)

var _pitch: float = 0.0

func _ready() -> void:
	if player.is_multiplayer_authority():
		if camera_node:
			camera_node.current = true
		var menu_cam: Camera3D = get_tree().root.find_child("MenuCamera", true, false) as Camera3D
		if menu_cam:
			menu_cam.current = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		if camera_node:
			camera_node.current = false
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not player.is_multiplayer_authority():
		return

	# Recapture mouse on click if in-game
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	# Handle mouse release on UI cancel (Escape) or toggle
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Handle mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation (Yaw) rotates the entire player
		player.rotate_y(-event.relative.x * mouse_sensitivity)

		# Vertical rotation (Pitch) rotates the camera mount only
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		rotation.x = _pitch


## Returns the yaw transform basis for movement calculation
func get_yaw_basis() -> Basis:
	return player.global_transform.basis


## Returns the exact 2D screen coordinate of the crosshair.
func get_crosshair_screen_position() -> Vector2:
	var viewport := player.get_viewport()
	if not viewport:
		return Vector2.ZERO
	var vp_size := viewport.get_visible_rect().size
	# If the HUD crosshair is present in the tree, query its exact center
	var crosshair: Control = viewport.get_node_or_null("CanvasLayer/LobbyMenu/HUD/Crosshair")
	if crosshair and crosshair.is_inside_tree() and crosshair.visible:
		var rect := crosshair.get_global_rect()
		return rect.get_center()
	# Fallback to configured over-the-shoulder offset (55% X, 46% Y)
	return Vector2(vp_size.x * 0.55, vp_size.y * 0.46)


## Returns direct ray from camera projected through the crosshair for third-person over-the-shoulder aiming
func get_aim_ray(max_distance: float = 150.0) -> Dictionary:
	if not camera_node:
		return {}
	var screen_pos := get_crosshair_screen_position()
	var from := camera_node.project_ray_origin(screen_pos)
	var dir := camera_node.project_ray_normal(screen_pos)
	var to := from + dir * max_distance

	var space_state := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	query.collision_mask = 1 | 2 # collide with environment and other players
	return space_state.intersect_ray(query)


## Returns the 3D aim target point in the world projected straight through the crosshair
func get_aim_point(max_distance: float = 150.0) -> Vector3:
	var hit := get_aim_ray(max_distance)
	if not hit.is_empty():
		return hit.position
	if camera_node:
		var screen_pos := get_crosshair_screen_position()
		var from := camera_node.project_ray_origin(screen_pos)
		var dir := camera_node.project_ray_normal(screen_pos)
		return from + dir * max_distance
	return player.global_position - player.global_transform.basis.z * max_distance
