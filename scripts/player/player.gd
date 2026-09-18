class_name Player
extends CharacterBody3D

## Player Root Controller
## Coordinates sub-components (Input, Movement, Camera, Visuals, Weapons) and manages multiplayer authority.
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
@onready var weapon_mount: Node3D = get_node_or_null("Visuals/WeaponMount")
@onready var muzzle: Marker3D = get_node_or_null("Visuals/WeaponMount/Muzzle")
@onready var energy_core: MeshInstance3D = get_node_or_null("Visuals/WeaponMount/EnergyCore")
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var weapon_manager: PlayerWeaponManager = get_node_or_null("WeaponManager")

func _enter_tree() -> void:
	# Ensure node name determines multiplayer authority if it represents an int ID
	var id_from_name = str(name).to_int()
	if id_from_name > 0:
		set_multiplayer_authority(id_from_name)
		peer_id = id_from_name


func _ready() -> void:
	_update_authority()
	_setup_visuals()
	
	if NetworkManager:
		NetworkManager.player_connected.connect(_on_network_player_connected)

	if weapon_manager:
		weapon_manager.weapon_changed.connect(_on_weapon_changed)
		var initial_weapon := weapon_manager.get_current_weapon()
		if initial_weapon:
			_on_weapon_changed(initial_weapon)

	if is_multiplayer_authority():
		call_deferred("_setup_local_player")


func _setup_local_player() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if not tree or not tree.root:
		return
	var lobby_menu := tree.root.find_child("LobbyMenu", true, false) as LobbyMenu
	if lobby_menu and weapon_manager:
		lobby_menu.hook_local_player_weapon(weapon_manager)


func _update_authority() -> void:
	# Pass authority down to components where needed
	if synchronizer:
		synchronizer.set_multiplayer_authority(peer_id)


func _setup_visuals() -> void:
	# Set player nametag to the real chosen player name
	var player_name := NetworkManager.get_player_name(peer_id)
	if nametag_label:
		nametag_label.text = player_name

	# Apply a distinctive color based on peer_id
	if mesh_instance:
		var mat = StandardMaterial3D.new()
		var hue = fmod(float(peer_id) * 0.381966, 1.0) # Golden ratio distribution for pleasant distinct colors
		mat.albedo_color = Color.from_hsv(hue, 0.75, 0.95)
		mesh_instance.material_override = mat


func _on_network_player_connected(connected_id: int, _info: Dictionary) -> void:
	if connected_id == peer_id and nametag_label:
		nametag_label.text = NetworkManager.get_player_name(peer_id)


func _on_weapon_changed(w: WeaponData) -> void:
	if not w:
		return
	if energy_core:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = w.bullet_color
		energy_core.material_override = mat


func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	# Only the player authority simulates local physics and movement
	if is_multiplayer_authority():
		movement_component.process_movement(delta, camera_pivot.get_yaw_basis())
		_update_weapon_aim(delta)
		if input_component and input_component.is_firing:
			_shoot()


func _update_weapon_aim(delta: float) -> void:
	if not weapon_mount or not camera_pivot:
		return
	var aim_target := camera_pivot.get_aim_point(100.0)
	var weapon_pos := weapon_mount.global_position
	if weapon_pos.distance_squared_to(aim_target) > 0.25:
		var target_transform := weapon_mount.global_transform.looking_at(aim_target, Vector3.UP)
		weapon_mount.global_transform = weapon_mount.global_transform.interpolate_with(target_transform, minf(delta * 25.0, 1.0))


func _shoot() -> void:
	if weapon_manager and not weapon_manager.can_fire():
		return

	var fired_weapon: WeaponData = null
	if weapon_manager:
		fired_weapon = weapon_manager.fire()
		if not fired_weapon:
			return

	var aim_point: Vector3 = camera_pivot.get_aim_point(150.0)
	var shoot_origin: Vector3 = (
		muzzle.global_position if muzzle
		else (global_position + global_transform.basis * Vector3(0.36, 0.88, -0.6))
	)
	
	# Spawn bullet projectile directly aligned with crosshair aim target
	_spawn_bullet(shoot_origin, aim_point, fired_weapon)

	# Audio feedback
	_play_shoot_sound(fired_weapon)

	# Recoil animation on weapon mount
	if weapon_mount:
		var tw := create_tween()
		tw.tween_property(weapon_mount, "position:z", -0.18, 0.04)
		tw.tween_property(weapon_mount, "position:z", -0.25, 0.08)


func _spawn_bullet(from_pos: Vector3, to_pos: Vector3, weapon: WeaponData = null) -> void:
	var bullet_scene: PackedScene = preload("res://scenes/projectile/bullet.tscn")
	var bullet: Node3D = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	if bullet.has_method("setup"):
		var spd: float = weapon.bullet_speed if weapon else 95.0
		var col: Color = weapon.bullet_color if weapon else Color(0.0, 1.0, 0.95)
		bullet.setup(from_pos, to_pos, get_rid(), spd, col)


func _play_shoot_sound(weapon: WeaponData = null) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = load("res://assets/kenney_ui/Sounds/tap-a.ogg")
	var base_pitch: float = weapon.sfx_pitch if weapon else 1.3
	sfx.pitch_scale = base_pitch * randf_range(0.96, 1.04)
	sfx.volume_db = -4.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
