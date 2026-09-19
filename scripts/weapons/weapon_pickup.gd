class_name WeaponPickup
extends Area3D

## In-World Weapon Pickup
## Displays an interactive floating 3D weapon model with bobbing and rotation,
## glowing aura matching the weapon color, and a billboard Label3D with shoot type.

signal picked_up(player: Node, weapon: WeaponData)

@export var weapon_id: String = "rifle"
@export var respawn_time: float = 12.0

@onready var model_pivot: Node3D = $ModelPivot
@onready var label: Label3D = $Label3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _weapon_data: WeaponData = null
var _is_active: bool = true
var _time_passed: float = 0.0
var _base_y: float = 0.6

const WEAPON_SCENES: Dictionary = {
	"machine_gun": "res://assets/kenny_blaster_kit/MachineGun.fbx",
	"rifle": "res://assets/kenny_blaster_kit/Rifile.fbx",
	"burst_rifle": "res://assets/kenny_blaster_kit/Rifile2.fbx",
	"sniper_rifle": "res://assets/kenny_blaster_kit/Sniper.fbx",
	"heavy_sniper": "res://assets/kenny_blaster_kit/Sniper1.fbx"
}

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 # Players are on collision layer 2
	body_entered.connect(_on_body_entered)
	
	_setup_weapon()


func _setup_weapon() -> void:
	_weapon_data = _create_weapon_data(weapon_id)
	if not _weapon_data:
		return

	# Setup Label
	if label:
		label.text = "%s\n[%s]" % [_weapon_data.weapon_name, _weapon_data.shoot_type]
		label.modulate = _weapon_data.bullet_color

	# Setup Light
	if light:
		light.light_color = _weapon_data.bullet_color
		light.light_energy = 1.8
		light.omni_range = 3.5

	# Setup 3D Model in pivot
	if model_pivot:
		for child in model_pivot.get_children():
			child.queue_free()
		
		var scene_path: String = WEAPON_SCENES.get(weapon_id, "res://assets/kenny_blaster_kit/Rifile.fbx")
		var scn: PackedScene = load(scene_path)
		if scn:
			var inst: Node3D = scn.instantiate()
			inst.scale = Vector3(1.2, 1.2, 1.2)
			if weapon_id == "sniper_rifle":
				inst.position = Vector3(0.05, 0.0, -0.85)
			model_pivot.add_child(inst)


func _create_weapon_data(id: String) -> WeaponData:
	var w := WeaponData.new()
	match id:
		"machine_gun":
			w.weapon_id = "machine_gun"
			w.weapon_name = "MACHINE GUN"
			w.shoot_type = "FULL AUTO"
			w.max_ammo = 60
			w.current_ammo = 60
			w.reserve_ammo = 240
			w.fire_rate = 0.08
			w.bullet_speed = 105.0
			w.damage = 14.0
			w.bullet_color = Color(1.0, 0.65, 0.15)
			w.sfx_pitch = 1.45
			w.spread_degrees = 2.2
			w.model_name = "MachineGun"
		"burst_rifle":
			w.weapon_id = "burst_rifle"
			w.weapon_name = "BURST RIFLE"
			w.shoot_type = "3-ROUND BURST"
			w.max_ammo = 30
			w.current_ammo = 30
			w.reserve_ammo = 90
			w.fire_rate = 0.38
			w.burst_count = 3
			w.burst_interval = 0.06
			w.bullet_speed = 125.0
			w.damage = 22.0
			w.bullet_color = Color(0.2, 1.0, 0.4)
			w.sfx_pitch = 1.35
			w.spread_degrees = 0.8
			w.model_name = "Rifile2"
		"sniper_rifle":
			w.weapon_id = "sniper_rifle"
			w.weapon_name = "SNIPER RIFLE"
			w.shoot_type = "SEMI-AUTO"
			w.max_ammo = 10
			w.current_ammo = 10
			w.reserve_ammo = 40
			w.fire_rate = 0.55
			w.bullet_speed = 180.0
			w.damage = 60.0
			w.bullet_color = Color(0.95, 0.2, 0.85)
			w.sfx_pitch = 0.85
			w.spread_degrees = 0.0
			w.model_name = "Sniper"
		"heavy_sniper":
			w.weapon_id = "heavy_sniper"
			w.weapon_name = "HEAVY SNIPER"
			w.shoot_type = "BOLT ACTION"
			w.max_ammo = 5
			w.current_ammo = 5
			w.reserve_ammo = 20
			w.fire_rate = 1.15
			w.bullet_speed = 220.0
			w.damage = 95.0
			w.bullet_color = Color(1.0, 0.25, 0.1)
			w.sfx_pitch = 0.65
			w.spread_degrees = 0.0
			w.model_name = "Sniper1"
		_:
			w.weapon_id = "rifle"
			w.weapon_name = "ASSAULT RIFLE"
			w.shoot_type = "FULL AUTO"
			w.max_ammo = 30
			w.current_ammo = 30
			w.reserve_ammo = 120
			w.fire_rate = 0.14
			w.bullet_speed = 115.0
			w.damage = 25.0
			w.bullet_color = Color(0.1, 0.9, 1.0)
			w.sfx_pitch = 1.25
			w.spread_degrees = 0.5
			w.model_name = "Rifile"
	return w


func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_time_passed += delta
	# Continuous slow rotation
	if model_pivot:
		model_pivot.rotation.y += delta * 1.6
		model_pivot.position.y = _base_y + sin(_time_passed * 2.8) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if not _is_active:
		return
	
	# Check if entity is player
	if body is CharacterBody3D and body.is_in_group("players"):
		_collect(body)


func _collect(player: CharacterBody3D) -> void:
	var wm: PlayerWeaponManager = player.get_node_or_null("WeaponManager")
	if not wm:
		return
	
	if not _weapon_data:
		_weapon_data = _create_weapon_data(weapon_id)
	
	wm.add_or_refill_weapon(_weapon_data)
	picked_up.emit(player, _weapon_data)
	
	# Play arcade pickup sound
	_play_pickup_sfx()

	# Notify HUD if local player
	if player.is_multiplayer_authority() and player.has_method("notify_pickup"):
		player.notify_pickup(_weapon_data)

	# Trigger respawn cycle locally and via RPC if in network
	if multiplayer.has_multiplayer_peer():
		_rpc_set_active.rpc(false)
		get_tree().create_timer(respawn_time).timeout.connect(func():
			if multiplayer.is_server():
				_rpc_set_active.rpc(true)
		)
	else:
		_set_active(false)
		get_tree().create_timer(respawn_time).timeout.connect(func():
			_set_active(true)
		)


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_active(active: bool) -> void:
	_set_active(active)


func _set_active(active: bool) -> void:
	_is_active = active
	visible = active
	if collision_shape:
		collision_shape.set_deferred("disabled", not active)


func _play_pickup_sfx() -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = load("res://assets/kenney_ui/Sounds/switch-a.ogg")
	sfx.pitch_scale = 1.3
	sfx.unit_size = 10.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
