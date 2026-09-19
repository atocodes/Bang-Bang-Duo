class_name Bullet
extends Node3D

## Bullet Projectile
## Moves at high speed from muzzle along aim vector.
## Emits impact visuals upon reaching target or colliding with world geometry.

@export var speed: float = 95.0
@export var max_lifetime: float = 2.5
@export var bullet_color: Color = Color(0.0, 1.0, 0.95)

var direction: Vector3 = Vector3.FORWARD
var target_point: Vector3 = Vector3.ZERO
var shooter_rid: RID
var _traveled_dist: float = 0.0
var _max_dist: float = 150.0
var _lifetime: float = 0.0

func setup(start_pos: Vector3, target_pos: Vector3, exclude_rid: RID = RID(), bullet_speed: float = 95.0, col: Color = Color(0.0, 1.0, 0.95)) -> void:
	speed = bullet_speed
	bullet_color = col
	position = start_pos
	target_point = target_pos
	shooter_rid = exclude_rid
	_max_dist = start_pos.distance_to(target_pos)
	if _max_dist > 0.001:
		direction = (target_pos - start_pos).normalized()
		look_at_from_position(start_pos, start_pos + direction, Vector3.UP)
	else:
		direction = -transform.basis.z

	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = bullet_color
		mesh_node.material_override = mat

	var light_node := get_node_or_null("Light") as OmniLight3D
	if light_node:
		light_node.light_color = bullet_color


func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= max_lifetime:
		queue_free()
		return

	var move_step := speed * delta
	var next_pos := global_position + direction * move_step

	# Raycast check for collision along this step
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, next_pos)
	if shooter_rid.is_valid():
		query.exclude = [shooter_rid]
	query.collision_mask = 1 | 2

	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		_impact(hit.position, hit.normal)
		return

	global_position = next_pos
	_traveled_dist += move_step

	# If we've reached or passed the aim target point
	if _traveled_dist >= _max_dist:
		_impact(target_point, -direction)


func _impact(pos: Vector3, normal: Vector3) -> void:
	if not is_inside_tree():
		queue_free()
		return

	set_physics_process(false)
	global_position = pos

	var bullet_mesh := get_node_or_null("Mesh") as MeshInstance3D
	if bullet_mesh:
		bullet_mesh.visible = false

	# Small glowing hit spark
	var spark_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	spark_mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = bullet_color
	spark_mesh.material_override = mat
	add_child(spark_mesh)

	var light_node := get_node_or_null("Light") as OmniLight3D
	if light_node:
		light_node.light_color = bullet_color
		light_node.light_energy = 2.4
		light_node.omni_range = 2.0

	var tween := create_tween()
	tween.parallel().tween_property(spark_mesh, "scale", Vector3(2.5, 2.5, 2.5), 0.15)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.15)
	if light_node:
		tween.parallel().tween_property(light_node, "light_energy", 0.0, 0.15)
	tween.tween_callback(queue_free)


func _spawn_impact_fx(pos: Vector3, normal: Vector3) -> void:
	_impact(pos, normal)
