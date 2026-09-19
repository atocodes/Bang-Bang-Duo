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
	ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)
	if CodeLogicBus and cur:
		CodeLogicBus.trace_exec("WEAPON", "switch_weapon(slot:%d)" % index, "equipped:'%s' | ammo:%d/%d" % [cur.weapon_name, cur.current_ammo, cur.reserve_ammo], "#a78bfa")


func cycle_weapon(delta: int) -> void:
	if weapons.size() <= 1:
		return
	var new_index = posmod(current_index + delta, weapons.size())
	if CodeLogicBus:
		CodeLogicBus.trace_exec("WEAPON", "cycle_weapon(%+d)" % delta, "slot:%d -> %d" % [current_index, new_index], "#a78bfa")
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
	if not cur or not can_fire():
		if CodeLogicBus:
			var reason := "cooldown:%.2fs" % _cooldown_timer if _cooldown_timer > 0.0 else "no_ammo"
			CodeLogicBus.trace_cond("WEAPON", "can_fire()", false, reason)
		return null
	
	cur.consume_ammo()
	_cooldown_timer = cur.fire_rate
	weapon_fired.emit(cur)
	ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)
	if CodeLogicBus:
		CodeLogicBus.trace_exec("WEAPON", "fire('%s')" % cur.weapon_name, "ammo:%d/%d | cd:%.2fs" % [cur.current_ammo, cur.reserve_ammo, cur.fire_rate], "#34d399")
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
	if not cur:
		return
	var reloaded := cur.reload()
	if reloaded:
		ammo_changed.emit(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)
		if CodeLogicBus:
			CodeLogicBus.trace_exec("WEAPON", "reload_current('%s')" % cur.weapon_name, "ammo:%d/%d [RELOADED]" % [cur.current_ammo, cur.reserve_ammo], "#fbbf24")
	elif CodeLogicBus:
		CodeLogicBus.trace_cond("WEAPON", "reload('%s')" % cur.weapon_name, false, "full_or_empty_reserve")
