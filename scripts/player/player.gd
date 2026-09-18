class_name Player
extends CharacterBody3D

## Player Root Controller
## Coordinates sub-components (Input, Movement, Camera, Visuals) and manages multiplayer authority.
##
## Node naming convention: When instantiated by the server, the node name is set to the peer ID
## (e.g. "1" for host, "12345678" for client).

@export var peer_id: int = 1:
	set(value):
		peer_id = value
		_update_authority()

@onready var input_component: PlayerInput = $PlayerInput
@onready var movement_component: PlayerMovement = $PlayerMovement
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var nametag_label: Label3D = $Nametag
@onready var mesh_instance: MeshInstance3D = $Visuals/BodyMesh
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

func _enter_tree() -> void:
	# Ensure node name determines multiplayer authority if it represents an int ID
	var id_from_name = str(name).to_int()
	if id_from_name > 0:
		set_multiplayer_authority(id_from_name)
		peer_id = id_from_name


func _ready() -> void:
	_update_authority()
	_setup_visuals()


func _update_authority() -> void:
	# Pass authority down to components where needed
	if synchronizer:
		synchronizer.set_multiplayer_authority(peer_id)


func _setup_visuals() -> void:
	# Set player nametag
	var player_name = "Player %d" % peer_id
	if peer_id == 1:
		player_name = "Host (1)"
	elif is_multiplayer_authority():
		player_name = "You (%d)" % peer_id

	if nametag_label:
		nametag_label.text = player_name

	# Apply a distinctive color based on peer_id
	if mesh_instance:
		var mat = StandardMaterial3D.new()
		var hue = fmod(float(peer_id) * 0.381966, 1.0) # Golden ratio distribution for pleasant distinct colors
		mat.albedo_color = Color.from_hsv(hue, 0.75, 0.95)
		mesh_instance.material_override = mat


func _physics_process(delta: float) -> void:
	# Only the player authority simulates local physics and movement
	if is_multiplayer_authority():
		movement_component.process_movement(delta, camera_pivot.get_yaw_basis())
		if input_component and input_component.is_firing:
			_shoot()


func _shoot() -> void:
	var aim_point: Vector3 = camera_pivot.get_aim_point(100.0)
	var shoot_origin: Vector3 = global_position + Vector3(0.4, 1.2, 0)
	
	# Spawn a tracer beam
	_spawn_tracer(shoot_origin, aim_point)

	# Audio feedback
	_play_shoot_sound()


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	var imm_mesh := ImmediateMesh.new()
	mesh_inst.mesh = imm_mesh
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 1.0, 0.9, 0.9)
	mesh_inst.material_override = mat

	imm_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	imm_mesh.surface_add_vertex(from_pos)
	imm_mesh.surface_add_vertex(to_pos)
	imm_mesh.surface_end()

	get_tree().root.add_child(mesh_inst)

	# Fade and destroy tracer quickly
	var tween := mesh_inst.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(mesh_inst.queue_free)


func _play_shoot_sound() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = load("res://assets/kenney_ui/Sounds/tap-a.ogg")
	sfx.pitch_scale = randf_range(1.2, 1.4)
	sfx.volume_db = -4.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
