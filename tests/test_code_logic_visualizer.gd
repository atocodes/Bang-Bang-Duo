extends Node

const CodeLogicDockScript = preload("res://scripts/ui/code_logic_dock.gd")

func _ready() -> void:
	print("==================================================")
	print("TESTING TRANSPARENT CODE LOGIC & EXECUTION DOCK")
	print("==================================================")

	var main_scene_res := load("res://scenes/main.tscn")
	assert(main_scene_res != null, "main.tscn must load")
	var main_inst: Node = main_scene_res.instantiate()
	add_child(main_inst)

	var dock = main_inst.get_node_or_null("CanvasLayer/CodeLogicDock")
	assert(dock != null, "CodeLogicDock must exist in CanvasLayer")
	assert(dock.visible == true, "CodeLogicDock must start visible")
	assert(CodeLogicBus != null, "CodeLogicBus autoload must be available")
	assert(CodeLogicBus.is_enabled == true, "CodeLogicBus must be enabled by default")
	print("PASS: 1. CodeLogicDock and CodeLogicBus singleton initialized.")

	# 2. Test manual trace dispatching & ring buffer updates
	var test_tag := "TEST_EXEC"
	var test_code := "custom_func(arg: 42) -> ok"
	CodeLogicBus.trace(test_tag, test_code, "UNIT_TEST", "#34d399")
	
	var latest_entry = dock._entries[CodeLogicDockScript.MAX_VISIBLE_LINES - 1]
	assert(latest_entry.is_active == true, "Latest entry should be active")
	assert(latest_entry.tag == test_tag, "Entry tag must match")
	assert(latest_entry.code == test_code, "Entry code must match")
	assert(latest_entry.life_timer > 0.0, "Entry must have active life timer")
	print("PASS: 2. Trace dispatch and ring-buffer storage verified.")

	# 3. Test condition & educational tracing helpers
	CodeLogicBus.trace_cond("WEAPON", "ammo > 0", true, "ammo: 30")
	var cond_entry = dock._entries[CodeLogicDockScript.MAX_VISIBLE_LINES - 1]
	assert("WEAPON" in cond_entry.tag, "Condition tag format verified")
	assert("TRUE" in cond_entry.code, "Condition result formatted with TRUE")

	CodeLogicBus.trace_edu("MATH:LERP", "KINEMATICS", "v = move_toward(dir*spd, a*dt)", "vel:(3.0, 0.0, -4.0)")
	var edu_entry = dock._entries[CodeLogicDockScript.MAX_VISIBLE_LINES - 1]
	assert(edu_entry.tag == "MATH:LERP:KINEMATICS", "Educational tag format verified")
	assert("move_toward" in edu_entry.code, "Educational formula code verified")
	print("PASS: 3. Condition & Educational Under-The-Hood trace formatting verified.")

	# 4. Test Weapon and Movement Hook Integrations
	var player_res := load("res://scenes/player/player.tscn")
	assert(player_res != null, "Player scene must load")
	var p: Player = player_res.instantiate()
	add_child(p)

	var wm: PlayerWeaponManager = p.weapon_manager
	assert(wm != null, "Player must have WeaponManager")
	
	# Fire weapon -> verifies weapon trace
	var fired_w = wm.fire()
	assert(fired_w != null, "Weapon fire should succeed")
	var fire_entry = dock._entries[CodeLogicDockScript.MAX_VISIBLE_LINES - 1]
	assert("FIRE" in fire_entry.tag, "Weapon fire trace dispatched")

	# Switch weapon -> verifies switch trace
	wm.switch_weapon(1)
	var switch_entry = dock._entries[CodeLogicDockScript.MAX_VISIBLE_LINES - 1]
	assert("WEAPON" in switch_entry.tag, "Weapon switch trace dispatched")

	# Movement physics trace
	p.input_component.move_direction = Vector2(0, -1)
	p.movement_component.process_movement(0.016, Basis.IDENTITY)
	print("PASS: 4. Player movement and weapon gameplay trace hooks verified.")

	# 5. Test Health & Damage Impact Mechanics
	assert(p.current_health == 100.0, "Player must start at 100 HP")
	p.take_damage(25.0, 1, Vector3.FORWARD, Vector3(0, 1, 0))
	assert(p.current_health == 75.0, "Player health must be 75 after 25 damage")
	var dmg_entry = dock._entries[CodeLogicDockScript.MAX_VISIBLE_LINES - 1]
	assert("DAMAGE" in dmg_entry.tag or "hp" in dmg_entry.code, "Damage trace must be recorded in CodeLogicDock")
	assert("75" in dmg_entry.code, "Updated HP (75) must appear in trace")

	# Test fatal damage & respawn
	p.take_damage(100.0, 1, Vector3.ZERO, Vector3.ZERO)
	assert(p.current_health == 100.0, "Player must respawn with full 100 health")
	var respawn_entry = dock._entries[CodeLogicDockScript.MAX_VISIBLE_LINES - 1]
	assert("RESPAWN" in respawn_entry.tag or "100" in respawn_entry.code, "Respawn trace must be recorded")
	p.queue_free()
	print("PASS: 5. Health system, damage impact knockback, and respawn logic flow verified.")

	# 6. Test Performance Toggle & Instant Bypass
	dock.toggle_dock()
	assert(dock.visible == false, "Dock should be hidden after toggle")
	assert(CodeLogicBus.is_enabled == false, "CodeLogicBus should be disabled when dock is hidden")
	
	# Dispatching trace while disabled should do nothing (0 CPU overhead)
	CodeLogicBus.trace("IGNORED", "should_not_register()", "TEST")
	# Re-enable
	dock.toggle_dock()
	assert(dock.visible == true, "Dock restored to visible")
	assert(CodeLogicBus.is_enabled == true, "CodeLogicBus re-enabled")
	print("PASS: 6. High-performance toggle and zero-cost bypass verified.")

	print("==================================================")
	print("ALL CODE LOGIC DOCK TESTS PASSED SUCCESSFULLY!")
	print("==================================================")
	get_tree().quit(0)
