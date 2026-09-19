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
	# 1. Assault Rifle (Rifile.fbx) - Standard Full Auto
	var rifle := WeaponData.new()
	rifle.weapon_id = "rifle"
	rifle.weapon_name = "ASSAULT RIFLE"
	rifle.shoot_type = "FULL AUTO"
	rifle.max_ammo = 30
	rifle.current_ammo = 30
	rifle.reserve_ammo = 120
	rifle.fire_rate = 0.14
	rifle.bullet_speed = 115.0
	rifle.damage = 25.0
	rifle.bullet_color = Color(0.1, 0.9, 1.0)
	rifle.sfx_pitch = 1.25
	rifle.spread_degrees = 0.5
	rifle.model_name = "Rifile"
	weapons.append(rifle)

	# 2. Machine Gun (MachineGun.fbx) - Rapid Suppression Full Auto
	var lmg := WeaponData.new()
	lmg.weapon_id = "machine_gun"
	lmg.weapon_name = "MACHINE GUN"
	lmg.shoot_type = "FULL AUTO"
	lmg.max_ammo = 60
	lmg.current_ammo = 60
	lmg.reserve_ammo = 240
	lmg.fire_rate = 0.08
	lmg.bullet_speed = 105.0
	lmg.damage = 14.0
	lmg.bullet_color = Color(1.0, 0.65, 0.15)
	lmg.sfx_pitch = 1.45
	lmg.spread_degrees = 2.2
	lmg.model_name = "MachineGun"
	weapons.append(lmg)

	# 3. Burst Rifle (Rifile2.fbx) - 3-Round Tactical Burst
	var burst := WeaponData.new()
	burst.weapon_id = "burst_rifle"
	burst.weapon_name = "BURST RIFLE"
	burst.shoot_type = "3-ROUND BURST"
	burst.max_ammo = 30
	burst.current_ammo = 30
	burst.reserve_ammo = 90
	burst.fire_rate = 0.38
	burst.burst_count = 3
	burst.burst_interval = 0.06
	burst.bullet_speed = 125.0
	burst.damage = 22.0
	burst.bullet_color = Color(0.2, 1.0, 0.4)
	burst.sfx_pitch = 1.35
	burst.spread_degrees = 0.8
	burst.model_name = "Rifile2"
	weapons.append(burst)

	# 4. Sniper Rifle (Sniper.fbx) - High Velocity Precision Semi-Auto
	var sniper := WeaponData.new()
	sniper.weapon_id = "sniper_rifle"
	sniper.weapon_name = "SNIPER RIFLE"
	sniper.shoot_type = "SEMI-AUTO"
	sniper.max_ammo = 10
	sniper.current_ammo = 10
	sniper.reserve_ammo = 40
	sniper.fire_rate = 0.55
	sniper.bullet_speed = 180.0
	sniper.damage = 60.0
	sniper.bullet_color = Color(0.95, 0.2, 0.85)
	sniper.sfx_pitch = 0.85
	sniper.spread_degrees = 0.0
	sniper.model_name = "Sniper"
	weapons.append(sniper)

	# 5. Heavy Sniper (Sniper1.fbx) - Devastating Bolt Action Anti-Materiel
	var heavy := WeaponData.new()
	heavy.weapon_id = "heavy_sniper"
	heavy.weapon_name = "HEAVY SNIPER"
	heavy.shoot_type = "BOLT ACTION"
	heavy.max_ammo = 5
	heavy.current_ammo = 5
	heavy.reserve_ammo = 20
	heavy.fire_rate = 1.15
	heavy.bullet_speed = 220.0
	heavy.damage = 95.0
	heavy.bullet_color = Color(1.0, 0.25, 0.1)
	heavy.sfx_pitch = 0.65
	heavy.spread_degrees = 0.0
	heavy.model_name = "Sniper1"
	weapons.append(heavy)


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

	# Quick weapon slot switching 1, 2, 3, 4, 5
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			switch_weapon(0)
		elif event.keycode == KEY_2:
			switch_weapon(1)
		elif event.keycode == KEY_3:
			switch_weapon(2)
		elif event.keycode == KEY_4:
			switch_weapon(3)
		elif event.keycode == KEY_5:
			switch_weapon(4)
		elif event.keycode == KEY_R:
			reload_current()

	# Mouse wheel weapon cycling
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(1)


func add_or_refill_weapon(w_data: WeaponData) -> WeaponData:
	if not w_data:
		return null
	for i in range(weapons.size()):
		if weapons[i].weapon_id == w_data.weapon_id:
			var existing = weapons[i]
			existing.current_ammo = existing.max_ammo
			existing.reserve_ammo += w_data.max_ammo * 2
			switch_weapon(i)
			return existing
	
	# Create a clean duplicate instance to add
	var new_w: WeaponData = w_data.duplicate()
	new_w.current_ammo = new_w.max_ammo
	weapons.append(new_w)
	switch_weapon(weapons.size() - 1)
	return new_w


func get_weapon_by_id(id: String) -> WeaponData:
	for w in weapons:
		if w.weapon_id == id:
			return w
	return null


func switch_weapon_by_id(id: String) -> void:
	for i in range(weapons.size()):
		if weapons[i].weapon_id == id:
			switch_weapon(i)
			return


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
