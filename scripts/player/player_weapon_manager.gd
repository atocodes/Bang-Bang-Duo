class_name PlayerWeaponManager
extends Node

## Player Weapon Manager
## Manages modular equipped weapons, ammunition, reloading, and firing cooldowns.
## Players spawn unarmed (empty inventory) and must pick up weapons in the world.
## Supports timed reload, automatic reload on empty, and reload cancellation/restart on weapon switch.

signal weapon_changed(weapon: WeaponData)
signal ammo_changed(current: int, reserve: int, is_infinite: bool)
signal weapon_fired(weapon: WeaponData)
signal reload_started(weapon: WeaponData, duration: float)
signal reload_completed(weapon: WeaponData)
signal reload_cancelled(weapon: WeaponData)

@export var weapons: Array[WeaponData] = []
var current_index: int = -1
var _cooldown_timer: float = 0.0

# Reload state
var is_reloading: bool = false
var reload_timer: float = 0.0
var reload_duration: float = 0.0
var _reloading_weapon: WeaponData = null


func _ready() -> void:
	# Players start with no weapons at spawn
	if not weapons.is_empty():
		current_index = 0
	else:
		current_index = -1
	
	call_deferred("_emit_initial_state")


func _emit_initial_state() -> void:
	var cur := get_current_weapon()
	weapon_changed.emit(cur)
	if cur:
		ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)
	else:
		ammo_changed.emit(0, 0, false)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			finish_reload()


func _unhandled_input(event: InputEvent) -> void:
	var player = get_parent()
	if player and not player.is_multiplayer_authority():
		return

	if weapons.is_empty():
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
			if is_reloading and _reloading_weapon == existing:
				cancel_reload()
			switch_weapon(i)
			if current_index == i:
				ammo_changed.emit(existing.current_ammo, existing.reserve_ammo, existing.is_infinite)
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
	if current_index < 0 or current_index >= weapons.size() or weapons.is_empty():
		return null
	return weapons[current_index]


func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current_index:
		return

	# If currently reloading, switching away cancels the reload!
	# The weapon is not reloaded and keeps its current ammo.
	if is_reloading:
		cancel_reload()

	current_index = index
	var cur := get_current_weapon()
	weapon_changed.emit(cur)
	if cur:
		ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)
		# If the newly selected weapon has 0 ammo in clip and has reserve,
		# start reload from the beginning!
		if cur.current_ammo == 0 and cur.reserve_ammo > 0 and not cur.is_infinite:
			start_reload(cur)


func cycle_weapon(delta: int) -> void:
	if weapons.size() <= 1:
		return
	var new_index = posmod(current_index + delta, weapons.size())
	switch_weapon(new_index)


func can_fire() -> bool:
	if is_reloading:
		return false
	if _cooldown_timer > 0.0:
		return false
	var cur := get_current_weapon()
	return cur != null and cur.can_shoot()


func fire() -> WeaponData:
	var cur := get_current_weapon()
	if not cur:
		return null

	if is_reloading:
		return null

	if cur.current_ammo <= 0:
		# Auto reload on empty if reserve is available
		if cur.reserve_ammo > 0 and not is_reloading:
			start_reload(cur)
		return null

	if _cooldown_timer > 0.0:
		return null
	
	cur.consume_ammo()
	_cooldown_timer = cur.fire_rate
	weapon_fired.emit(cur)
	ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)

	# If the shot exhausted the magazine, immediately trigger reload with timer!
	if cur.current_ammo == 0 and cur.reserve_ammo > 0 and not cur.is_infinite:
		start_reload(cur)

	return cur


func start_reload(w: WeaponData) -> void:
	if not w or is_reloading:
		return
	if w.is_infinite or w.current_ammo >= w.max_ammo or w.reserve_ammo <= 0:
		return

	is_reloading = true
	_reloading_weapon = w
	reload_duration = w.reload_time if w.reload_time > 0.0 else 1.8
	reload_timer = reload_duration
	reload_started.emit(w, reload_duration)


func cancel_reload() -> void:
	if not is_reloading:
		return
	var w := _reloading_weapon
	is_reloading = false
	_reloading_weapon = null
	reload_timer = 0.0
	reload_duration = 0.0
	if w:
		reload_cancelled.emit(w)


func finish_reload() -> void:
	if not is_reloading or not _reloading_weapon:
		return
	var w := _reloading_weapon
	is_reloading = false
	_reloading_weapon = null
	reload_timer = 0.0
	reload_duration = 0.0
	
	if w.reload():
		reload_completed.emit(w)
		if w == get_current_weapon():
			ammo_changed.emit(w.current_ammo, w.reserve_ammo, w.is_infinite)


func reload_current() -> void:
	var cur := get_current_weapon()
	if cur and not is_reloading:
		if cur.current_ammo < cur.max_ammo and cur.reserve_ammo > 0:
			start_reload(cur)


## Utility factory for creating full weapon instances by ID
static func create_weapon_by_id(id: String) -> WeaponData:
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
			w.reload_time = 2.2
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
			w.reload_time = 1.8
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
			w.reload_time = 2.0
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
			w.reload_time = 2.5
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
			w.reload_time = 1.6
			w.bullet_speed = 115.0
			w.damage = 25.0
			w.bullet_color = Color(0.1, 0.9, 1.0)
			w.sfx_pitch = 1.25
			w.spread_degrees = 0.5
			w.model_name = "Rifile"
	return w
