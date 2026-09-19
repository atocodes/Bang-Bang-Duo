class_name PlayerMovement
extends Node

## PlayerMovement Component
## Encapsulates all physics calculations: walk, sprint, jump, gravity, and ground friction.
##
## Applied directly to the CharacterBody3D by the controlling authority.

@export_group("Movement Settings")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var acceleration: float = 20.0
@export var friction: float = 14.0
@export var air_control_acceleration: float = 6.0

@export_group("Jump & Gravity")
@export var jump_velocity: float = 5.5
@export var gravity: float = 16.0

# References
@onready var player: CharacterBody3D = get_parent()
@onready var input_component: PlayerInput = $"../PlayerInput"


## Computes and applies velocity for the character body during physics tick.
func process_movement(delta: float, look_yaw_basis: Basis) -> void:
	if not player:
		return

	var current_velocity: Vector3 = player.velocity

	# Apply gravity if in air
	var was_on_floor: bool = player.is_on_floor()
	if not was_on_floor:
		current_velocity.y -= gravity * delta

	# Process jump only when on floor
	if input_component.is_jumping:
		var can_jump := was_on_floor
		if can_jump:
			current_velocity.y = jump_velocity
			if CodeLogicBus:
				CodeLogicBus.trace_cond("PHYSICS", "is_jumping and is_on_floor()", true, "velocity.y = %.1f" % jump_velocity)
		elif not was_on_floor and CodeLogicBus:
			CodeLogicBus.trace_cond("PHYSICS", "is_jumping and is_on_floor()", false, "in_air (can_jump=false)")

	# Determine target speed
	var is_sprint: bool = input_component.is_sprinting
	var target_speed: float = sprint_speed if is_sprint else walk_speed

	# Calculate desired horizontal movement vector relative to camera look direction
	var input_vec: Vector2 = input_component.move_direction
	var desired_direction: Vector3 = (look_yaw_basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()

	# Horizontal acceleration & friction
	var current_horizontal_vel: Vector3 = Vector3(current_velocity.x, 0, current_velocity.z)
	var accel: float = acceleration if was_on_floor else air_control_acceleration

	if desired_direction.length_squared() > 0.001:
		var target_horizontal_vel: Vector3 = desired_direction * target_speed
		current_horizontal_vel = current_horizontal_vel.move_toward(target_horizontal_vel, accel * delta)
		if CodeLogicBus:
			var mode_str := "SPRINT" if is_sprint else "WALK"
			CodeLogicBus.trace_movement_throttled(mode_str, current_velocity, current_horizontal_vel.length())
	else:
		current_horizontal_vel = current_horizontal_vel.move_toward(Vector3.ZERO, friction * delta)
		if current_horizontal_vel.length_squared() > 0.01 and CodeLogicBus:
			CodeLogicBus.trace_movement_throttled("DECEL", current_velocity, current_horizontal_vel.length())

	current_velocity.x = current_horizontal_vel.x
	current_velocity.z = current_horizontal_vel.z

	# Apply velocity to the CharacterBody3D
	player.velocity = current_velocity
	player.move_and_slide()
