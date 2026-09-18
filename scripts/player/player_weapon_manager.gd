class_name PlayerWeaponManager
extends Node

## Player Weapon Manager
## Manages modular equipped weapons, ammunition, reloading, and firing cooldowns.

signal weapon_changed(weapon: WeaponData)
signal ammo_changed(current: int, reserve: int, is_infinite: bool)
signal weapon_fired(weapon: WeaponData)

@export var weapons: Array[WeaponData] = []
var current_index: int = 0
var _cooldown_timer: float = 0.0

func _ready() -> void:
	if weapons.is_empty():
		_init_default_weapons()
	
	call_deferred("_emit_initial_state")


func _init_default_weapons() -> void:
	# Weapon 1: Standard Pulse Blaster
	var blaster := WeaponData.new()
	blaster.weapon_id = "pulse_blaster"
	blaster.weapon_name = "PULSE BLASTER"
	blaster.max_ammo = 30
	blaster.current_ammo = 30
	blaster.reserve_ammo = 120
	blaster.fire_rate = 0.15
	blaster.bullet_speed = 95.0
	blaster.damage = 25.0
	blaster.bullet_color = Color(0.0, 1.0, 0.95)
	blaster.sfx_pitch = 1.3
	weapons.append(blaster)

	# Weapon 2: Heavy Cannon
	var cannon := WeaponData.new()
	cannon.weapon_id = "heavy_cannon"
	cannon.weapon_name = "HEAVY CANNON"
	cannon.max_ammo = 8
	cannon.current_ammo = 8
	cannon.reserve_ammo = 32
	cannon.fire_rate = 0.45
	cannon.bullet_speed = 120.0
	cannon.damage = 65.0
	cannon.bullet_color = Color(1.0, 0.65, 0.15)
	cannon.sfx_pitch = 0.9
	weapons.append(cannon)

	# Weapon 3: Plasma Rapid Rifle
	var plasma := WeaponData.new()
	plasma.weapon_id = "plasma_rifle"
	plasma.weapon_name = "PLASMA RIFLE"
	plasma.max_ammo = 45
	plasma.current_ammo = 45
	plasma.reserve_ammo = 180
	plasma.fire_rate = 0.09
	plasma.bullet_speed = 110.0
	plasma.damage = 18.0
	plasma.bullet_color = Color(0.2, 1.0, 0.4)
	plasma.sfx_pitch = 1.6
	weapons.append(plasma)


func _emit_initial_state() -> void:
	var cur := get_current_weapon()
	if cur:
		weapon_changed.emit(cur)
		ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func _unhandled_input(event: InputEvent) -> void:
	var player = get_parent()
	if player and not player.is_multiplayer_authority():
		return

	# Quick weapon slot switching 1, 2, 3
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			switch_weapon(0)
		elif event.keycode == KEY_2:
			switch_weapon(1)
		elif event.keycode == KEY_3:
			switch_weapon(2)
		elif event.keycode == KEY_R:
			reload_current()

	# Mouse wheel weapon cycling
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(1)


func get_current_weapon() -> WeaponData:
	if weapons.is_empty():
		return null
	return weapons[current_index]


func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current_index:
		return
	current_index = index
	var cur := get_current_weapon()
	weapon_changed.emit(cur)
	ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)


func cycle_weapon(delta: int) -> void:
	if weapons.size() <= 1:
		return
	var new_index = posmod(current_index + delta, weapons.size())
	switch_weapon(new_index)


func can_fire() -> bool:
	if _cooldown_timer > 0.0:
		return false
	var cur := get_current_weapon()
	return cur != null and cur.can_shoot()


func fire() -> WeaponData:
	var cur := get_current_weapon()
	if not cur or not can_fire():
		return null
	
	cur.consume_ammo()
	_cooldown_timer = cur.fire_rate
	weapon_fired.emit(cur)
	ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)
	return cur


func reload_current() -> void:
	var cur := get_current_weapon()
	if cur and cur.reload():
		ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)
