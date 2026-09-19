class_name Player
extends CharacterBody3D

## Player Root Controller
## Coordinates sub-components (Input, Movement, Camera, Visuals, Weapons) and manages multiplayer authority.
## Supports character model selection (Weyzero Codes / Ato Codes) and modular weapons with LeftHandIK.
## Players spawn unarmed and show weapon only when acquired from pickups.
## Fully synchronizes locomotion, rotation, equipped weapon, and gunshot FX across all peers.

@export var peer_id: int = 1:
	set(value):
		peer_id = value
		_update_authority()

@export_enum("Weyzero Codes", "Ato Codes") var character_model: String = "Weyzero Codes":
	set(value):
		character_model = value
		if is_node_ready():
			_apply_character_model()

@export var current_weapon_id: String = "":
	set(value):
		current_weapon_id = value
		if is_node_ready():
			_update_active_weapon_visual()

@onready var input_component: PlayerInput = $PlayerInput
@onready var movement_component: PlayerMovement = $PlayerMovement
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var nametag_label: Label3D = $Nametag
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var weapon_manager: PlayerWeaponManager = get_node_or_null("WeaponManager")

var anim_tree: AnimationTree = null
var anim_playback: AnimationNodeStateMachinePlayback = null
var left_hand_ik: SkeletonIK3D = null
var muzzle: Marker3D = null
var _current_active_char: Node3D = null
var _prev_global_pos: Vector3 = Vector3.ZERO

const HAND_MOUNT_TRANSFORM := Transform3D(
	Vector3(0.09297797, -0.036952548, -0.48988742),
	Vector3(0.47958136, -0.101325534, 0.09866498),
	Vector3(-0.10656808, -0.48822916, 0.016601466),
	Vector3(0.05050964, 0.13812436, 0.043544248)
)

const WEAPON_CONFIGS: Dictionary = {
	"rifle": {
		"model_name": "Rifile",
		"scene": "res://assets/kenny_blaster_kit/Rifile.fbx",
		"grip_pos": Vector3(0.058, 0.032, -0.286),
		"muzzle_pos": Vector3(0.0, 0.08, -0.45),
		"offset": Vector3.ZERO
	},
	"machine_gun": {
		"model_name": "MachineGun",
		"scene": "res://assets/kenny_blaster_kit/MachineGun.fbx",
		"grip_pos": Vector3(0.05, 0.03, -0.25),
		"muzzle_pos": Vector3(0.0, 0.08, -0.45),
		"offset": Vector3.ZERO
	},
	"burst_rifle": {
		"model_name": "Rifile2",
		"scene": "res://assets/kenny_blaster_kit/Rifile2.fbx",
		"grip_pos": Vector3(0.05, 0.02, -0.20),
		"muzzle_pos": Vector3(0.0, 0.07, -0.32),
		"offset": Vector3.ZERO
	},
	"sniper_rifle": {
		"model_name": "Sniper",
		"scene": "res://assets/kenny_blaster_kit/Sniper.fbx",
		"grip_pos": Vector3(0.05, 0.03, -0.30),
		"muzzle_pos": Vector3(0.0, 0.06, -0.75),
		"offset": Vector3(0.045, 0.0, -0.745)
	},
	"heavy_sniper": {
		"model_name": "Sniper1",
		"scene": "res://assets/kenny_blaster_kit/Sniper1.fbx",
		"grip_pos": Vector3(0.05, 0.03, -0.30),
		"muzzle_pos": Vector3(0.0, 0.06, -0.66),
		"offset": Vector3.ZERO
	}
}


func _enter_tree() -> void:
	# Ensure node name determines multiplayer authority if it represents an int ID
	var id_from_name = str(name).to_int()
	if id_from_name > 0:
		set_multiplayer_authority(id_from_name)
		peer_id = id_from_name


func _ready() -> void:
	_update_authority()
	_setup_visuals()
	_apply_character_model()

	var net = get_node_or_null("/root/NetworkManager")
	if net:
		net.player_connected.connect(_on_network_player_connected)

	if weapon_manager:
		weapon_manager.weapon_changed.connect(_on_weapon_changed)
		weapon_manager.reload_started.connect(_on_reload_started)
		weapon_manager.reload_completed.connect(_on_reload_completed)
		weapon_manager.reload_cancelled.connect(_on_reload_cancelled)
		var initial_weapon := weapon_manager.get_current_weapon()
		current_weapon_id = initial_weapon.weapon_id if initial_weapon else ""

	_update_active_weapon_visual()

	if is_multiplayer_authority():
		call_deferred("_setup_local_player")


func _apply_character_model() -> void:
	var weyzero: Node3D = get_node_or_null("Visuals/WeyzeroCodes")
	var ato: Node3D = get_node_or_null("Visuals/AtoCodes")
	var is_ato := (character_model == "Ato Codes")

	# Update WeyzeroCodes visibility and anims
	if weyzero:
		weyzero.visible = not is_ato
		var w_tree: AnimationTree = weyzero.get_node_or_null("AnimationTree")
		if w_tree:
			w_tree.active = not is_ato
		var w_ik: SkeletonIK3D = weyzero.get_node_or_null("Skeleton3D/LeftHandIK")
		if w_ik and is_ato:
			w_ik.stop()

	# Update AtoCodes visibility and anims
	if ato:
		ato.visible = is_ato
		var a_tree: AnimationTree = ato.get_node_or_null("AnimationTree")
		if a_tree:
			a_tree.active = is_ato
		var a_ik: SkeletonIK3D = ato.get_node_or_null("Skeleton3D/LeftHandIK")
		if a_ik and not is_ato:
			a_ik.stop()

	_current_active_char = ato if is_ato else weyzero
	if not _current_active_char:
		return

	anim_tree = _current_active_char.get_node_or_null("AnimationTree")
	if anim_tree:
		anim_tree.active = true
		anim_playback = anim_tree.get("parameters/locomotion/playback")
		call_deferred("_fetch_anim_playback")

	left_hand_ik = _current_active_char.get_node_or_null("Skeleton3D/LeftHandIK")

	# Setup modular weapon mounts on the active character
	_setup_character_weapons(_current_active_char)
	_update_active_weapon_visual()


func _fetch_anim_playback() -> void:
	if anim_tree:
		anim_playback = anim_tree.get("parameters/locomotion/playback")


func _setup_character_weapons(char_node: Node3D) -> void:
	var bone_att: BoneAttachment3D = char_node.get_node_or_null("Skeleton3D/BoneAttachment3D")
	if not bone_att:
		return

	# Hide any legacy standalone blaster-d node
	var old_blaster = bone_att.get_node_or_null("blaster-d")
	if old_blaster:
		old_blaster.visible = false

	# Ensure WeaponMount container exists under BoneAttachment3D
	var mount: Node3D = bone_att.get_node_or_null("WeaponMount")
	if not mount:
		mount = Node3D.new()
		mount.name = "WeaponMount"
		mount.transform = HAND_MOUNT_TRANSFORM
		bone_att.add_child(mount)

	# Instantiate each modular weapon scene if not already present
	for wid in WEAPON_CONFIGS:
		var cfg: Dictionary = WEAPON_CONFIGS[wid]
		var model_name: String = cfg["model_name"]
		if not mount.has_node(model_name):
			var scn: PackedScene = load(cfg["scene"])
			if scn:
				var w_node: Node3D = scn.instantiate()
				w_node.name = model_name
				w_node.position = cfg["offset"]
				w_node.visible = false

				# Add Grip Marker for LeftHandIK
				var grip := Marker3D.new()
				grip.name = "LeftHandGrip"
				grip.position = cfg["grip_pos"]
				w_node.add_child(grip)

				# Add Muzzle Marker for Projectiles
				var muzz := Marker3D.new()
				muzz.name = "Muzzle"
				muzz.position = cfg["muzzle_pos"]
				w_node.add_child(muzz)

				mount.add_child(w_node)


func _update_active_weapon_visual() -> void:
	if not _current_active_char:
		return
	var bone_att: BoneAttachment3D = _current_active_char.get_node_or_null("Skeleton3D/BoneAttachment3D")
	if not bone_att:
		return

	var mount: Node3D = bone_att.get_node_or_null("WeaponMount")
	if not mount:
		_setup_character_weapons(_current_active_char)
		mount = bone_att.get_node_or_null("WeaponMount")
		if not mount:
			return

	var old_blaster = bone_att.get_node_or_null("blaster-d")
	if old_blaster:
		old_blaster.visible = false

	# If no weapon equipped, hide all weapon models and stop IK
	if current_weapon_id.is_empty():
		for child in mount.get_children():
			if child is Node3D:
				child.visible = false
		muzzle = null
		set_left_hand_ik_active(false)
		return

	var active_cfg: Dictionary = WEAPON_CONFIGS.get(current_weapon_id, WEAPON_CONFIGS["rifle"])
	var target_model_name: String = active_cfg["model_name"]

	var active_weapon_node: Node3D = null
	for child in mount.get_children():
		if child is Node3D:
			var match_model: bool = (child.name == target_model_name)
			child.visible = match_model
			if match_model:
				active_weapon_node = child

	if active_weapon_node:
		muzzle = active_weapon_node.get_node_or_null("Muzzle")
		var grip = active_weapon_node.get_node_or_null("LeftHandGrip")
		if left_hand_ik and grip:
			left_hand_ik.target_node = NodePath("../BoneAttachment3D/WeaponMount/" + target_model_name + "/LeftHandGrip")
			set_left_hand_ik_active(true)


func _setup_local_player() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if not tree or not tree.root:
		return
	var lobby_menu: Node = tree.root.find_child("LobbyMenu", true, false)
	if lobby_menu and weapon_manager and lobby_menu.has_method("hook_local_player_weapon"):
		lobby_menu.hook_local_player_weapon(weapon_manager)


func _update_authority() -> void:
	if synchronizer:
		synchronizer.set_multiplayer_authority(peer_id)


func _setup_visuals() -> void:
	if not is_inside_tree():
		return
	var net = get_node_or_null("/root/NetworkManager")
	var player_name: String = net.get_player_name(peer_id) if net else ("Player %d" % peer_id)
	if nametag_label:
		nametag_label.text = player_name


func _on_network_player_connected(connected_id: int, _info: Dictionary) -> void:
	if not is_inside_tree():
		return
	var net = get_node_or_null("/root/NetworkManager")
	if connected_id == peer_id and nametag_label and net:
		nametag_label.text = net.get_player_name(peer_id)


func _on_weapon_changed(w: WeaponData) -> void:
	current_weapon_id = w.weapon_id if w else ""
	_update_active_weapon_visual()


func _on_reload_started(_w: WeaponData, _duration: float) -> void:
	_play_sfx("res://assets/kenney_ui/Sounds/click-b.ogg", 1.25, -2.0)
	if _current_active_char:
		var bone_att = _current_active_char.get_node_or_null("Skeleton3D/BoneAttachment3D")
		var mount = bone_att.get_node_or_null("WeaponMount") if bone_att else null
		if mount:
			var tw := create_tween()
			tw.tween_property(mount, "position:y", HAND_MOUNT_TRANSFORM.origin.y - 0.05, 0.15)


func _on_reload_completed(_w: WeaponData) -> void:
	_play_sfx("res://assets/kenney_ui/Sounds/click-a.ogg", 1.4, -2.0)
	if _current_active_char:
		var bone_att = _current_active_char.get_node_or_null("Skeleton3D/BoneAttachment3D")
		var mount = bone_att.get_node_or_null("WeaponMount") if bone_att else null
		if mount:
			var tw := create_tween()
			tw.tween_property(mount, "position:y", HAND_MOUNT_TRANSFORM.origin.y, 0.12)


func _on_reload_cancelled(_w: WeaponData) -> void:
	if _current_active_char:
		var bone_att = _current_active_char.get_node_or_null("Skeleton3D/BoneAttachment3D")
		var mount = bone_att.get_node_or_null("WeaponMount") if bone_att else null
		if mount:
			mount.position.y = HAND_MOUNT_TRANSFORM.origin.y


func _physics_process(delta: float) -> void:
	var has_net := multiplayer.has_multiplayer_peer()
	# Only the local authority (or standalone test without net) simulates physics
	if not has_net or is_multiplayer_authority():
		movement_component.process_movement(delta, camera_pivot.get_yaw_basis())
		if input_component and input_component.is_firing:
			_shoot()
	else:
		# Remote peer replica: update velocity from displacement if not zero
		if _prev_global_pos != Vector3.ZERO:
			var displacement := (global_position - _prev_global_pos) / maxf(delta, 0.001)
			if velocity.length_squared() < 0.01:
				velocity = displacement
		_prev_global_pos = global_position

	# Synchronize animation states for all peers (local + remote replica display)
	_update_animation_state(delta)


func _update_animation_state(_delta: float) -> void:
	if not anim_playback and anim_tree:
		anim_playback = anim_tree.get("parameters/locomotion/playback")
	if not anim_playback:
		return

	# In-air / jumping has highest priority when airborne
	var in_air: bool = (not is_on_floor() and absf(velocity.y) > 0.5)
	if in_air:
		anim_playback.travel("Jump")
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := horizontal_speed > 0.3
	var is_sprinting := horizontal_speed > 7.0

	if is_multiplayer_authority() and input_component:
		var input_moving = input_component.move_direction.length_squared() > 0.01
		is_moving = is_moving or input_moving
		is_sprinting = (is_sprinting or input_component.is_sprinting) and is_moving

	if is_sprinting:
		anim_playback.travel("Run")
	elif is_moving:
		anim_playback.travel("Walk")
	else:
		anim_playback.travel("Idle")


func _shoot() -> void:
	if weapon_manager and not weapon_manager.can_fire():
		return

	var fired_weapon: WeaponData = null
	if weapon_manager:
		fired_weapon = weapon_manager.fire()
		if not fired_weapon:
			return

	if fired_weapon.burst_count > 1:
		_fire_burst(fired_weapon)
	else:
		_execute_single_shot(fired_weapon)


func _fire_burst(w: WeaponData) -> void:
	for i in range(w.burst_count):
		if not is_instance_valid(self) or not is_inside_tree():
			return
		_execute_single_shot(w)
		if i < w.burst_count - 1:
			await get_tree().create_timer(w.burst_interval).timeout


func _execute_single_shot(fired_weapon: WeaponData) -> void:
	if anim_tree:
		anim_tree.set("parameters/shoot_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	var aim_point: Vector3 = camera_pivot.get_aim_point(150.0)
	var shoot_origin: Vector3 = (
		muzzle.global_position if muzzle and is_instance_valid(muzzle)
		else (global_position + global_transform.basis * Vector3(0.36, 0.88, -0.6))
	)
	
	# Spawn bullet projectile directly aligned with crosshair aim target
	_spawn_bullet(shoot_origin, aim_point, fired_weapon)
	if CodeLogicBus:
		CodeLogicBus.trace_cond("COMBAT", "is_firing and can_fire()", true, "w:'%s'" % fired_weapon.weapon_name)

	# Audio feedback
	_play_shoot_sound(fired_weapon)

	# Weapon recoil impulse
	if _current_active_char:
		var bone_att = _current_active_char.get_node_or_null("Skeleton3D/BoneAttachment3D")
		var mount = bone_att.get_node_or_null("WeaponMount") if bone_att else null
		if mount:
			var tw := create_tween()
			var kick_dist := 0.08 if (fired_weapon and fired_weapon.shoot_type == "BOLT ACTION") else 0.035
			tw.tween_property(mount, "position:z", HAND_MOUNT_TRANSFORM.origin.z - kick_dist, 0.03)
			tw.tween_property(mount, "position:z", HAND_MOUNT_TRANSFORM.origin.z, 0.08)

	# Broadcast shot to all other multiplayer peers
	if multiplayer.has_multiplayer_peer():
		_rpc_remote_shoot.rpc(shoot_origin, aim_point, fired_weapon.weapon_id if fired_weapon else "")


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_remote_shoot(from_pos: Vector3, to_pos: Vector3, w_id: String) -> void:
	if anim_tree:
		anim_tree.set("parameters/shoot_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var w: WeaponData = null
	if weapon_manager:
		w = weapon_manager.get_weapon_by_id(w_id)
	_spawn_bullet(from_pos, to_pos, w)
	_play_shoot_sound(w)


func _spawn_bullet(from_pos: Vector3, to_pos: Vector3, weapon: WeaponData = null) -> void:
	var bullet_scene: PackedScene = preload("res://scenes/projectile/bullet.tscn")
	var bullet: Node3D = bullet_scene.instantiate()
	var spd: float = weapon.bullet_speed if weapon else 95.0
	var col: Color = weapon.bullet_color if weapon else Color(0.0, 1.0, 0.95)
	if bullet.has_method("setup"):
		bullet.setup(from_pos, to_pos, get_rid(), spd, col)
		if CodeLogicBus:
			CodeLogicBus.trace_exec("BALLISTICS", "_spawn_bullet()", "speed:%.1fm/s | aim:(%.1f, %.1f, %.1f)" % [spd, to_pos.x, to_pos.y, to_pos.z], "#38bdf8")


func _play_shoot_sound(weapon: WeaponData = null) -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = load("res://assets/kenney_ui/Sounds/tap-a.ogg")
	var base_pitch: float = weapon.sfx_pitch if weapon else 1.3
	sfx.pitch_scale = base_pitch * randf_range(0.96, 1.04)
	sfx.volume_db = -4.0
	sfx.unit_size = 15.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _play_sfx(stream_path: String, pitch: float = 1.0, vol: float = 0.0) -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = load(stream_path)
	sfx.pitch_scale = pitch
	sfx.volume_db = vol
	sfx.unit_size = 12.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func notify_pickup(w: WeaponData) -> void:
	var tree := get_tree()
	if not tree or not tree.root:
		return
	var lobby_menu: Node = tree.root.find_child("LobbyMenu", true, false)
	if lobby_menu and lobby_menu.has_method("show_pickup_notification"):
		lobby_menu.show_pickup_notification(w)


## Toggle Left Hand IK for two-handed weapons vs one-handed / holstered / unarmed
func set_left_hand_ik_active(active: bool) -> void:
	if not left_hand_ik:
		return
	if active and is_inside_tree() and left_hand_ik.is_inside_tree():
		left_hand_ik.start()
	else:
		left_hand_ik.stop()
