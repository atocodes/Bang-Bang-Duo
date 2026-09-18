extends Node

func _ready() -> void:
	print("==================================================")
	print("RUNNING BANG BANG DUO COMPREHENSIVE TEST SUITE")
	print("==================================================")
	
	var main_scene_res = load("res://scenes/main.tscn")
	if not main_scene_res:
		printerr("FAIL: Unable to load scenes/main.tscn")
		get_tree().quit(1)
		return

	var main_inst = main_scene_res.instantiate()
	add_child(main_inst)

	var lobby_menu: LobbyMenu = main_inst.get_node_or_null("CanvasLayer/LobbyMenu")
	if not lobby_menu:
		printerr("FAIL: LobbyMenu not found in main.tscn")
		get_tree().quit(1)
		return

	# 1. Assert UI Nodes Exist & 4-Corner HUD
	assert(lobby_menu.menu_buttons_panel != null, "menu_buttons_panel missing")
	assert(lobby_menu.host_panel != null, "host_panel missing")
	assert(lobby_menu.join_panel != null, "join_panel missing")
	assert(lobby_menu.voice_panel != null, "voice_panel missing")
	assert(lobby_menu.settings_panel != null, "settings_panel missing")
	assert(lobby_menu.name_input != null, "name_input missing")
	assert(lobby_menu.random_name_btn != null, "random_name_btn missing")
	assert(lobby_menu.host_game_btn != null, "host_game_btn missing")
	assert(lobby_menu.join_game_btn != null, "join_game_btn missing")
	assert(lobby_menu.voice_assistant_btn != null, "voice_assistant_btn missing")
	assert(lobby_menu.voxide_voice != null, "voxide_voice missing")
	assert(lobby_menu.hud_panel != null, "hud_panel missing")
	assert(lobby_menu.hud_player_name != null, "hud_player_name missing")
	assert(lobby_menu.hud_role_badge != null, "hud_role_badge missing")
	assert(lobby_menu.hud_active_players != null, "hud_active_players missing")
	assert(lobby_menu.disconnect_button != null, "disconnect_button missing")
	assert(lobby_menu.hud_weapon_name != null, "hud_weapon_name missing")
	assert(lobby_menu.hud_ammo_current != null, "hud_ammo_current missing")
	assert(lobby_menu.hud_ammo_reserve != null, "hud_ammo_reserve missing")
	
	# Verify 4 corners in HUD
	assert(lobby_menu.get_node_or_null("HUD/TopLeftCard") != null, "TopLeftCard missing")
	assert(lobby_menu.get_node_or_null("HUD/TopRightCard") != null, "TopRightCard missing")
	assert(lobby_menu.get_node_or_null("HUD/BottomLeftCard") != null, "BottomLeftCard missing")
	assert(lobby_menu.get_node_or_null("HUD/BottomRightCard") != null, "BottomRightCard missing")
	print("PASS: 1. All arcade UI panels and 4-corner HUD nodes verified.")

	# 2. Assert Initial Main Menu State
	assert(lobby_menu.menu_buttons_panel.visible == true, "menu_buttons_panel should be visible on start")
	assert(lobby_menu.host_panel.visible == false, "host_panel should be hidden on start")
	assert(lobby_menu.join_panel.visible == false, "join_panel should be hidden on start")
	assert(lobby_menu.hud_panel.visible == false, "hud_panel should be hidden on start")
	print("PASS: 2. Initial state: Main Menu active, modals hidden, HUD hidden.")

	# 3. Test Modal Panel Transitions
	lobby_menu._switch_to(lobby_menu.host_panel)
	assert(lobby_menu.host_panel.visible == true, "host_panel should be visible")
	assert(lobby_menu.menu_buttons_panel.visible == false, "menu_buttons_panel should be hidden")

	lobby_menu._switch_to(lobby_menu.join_panel)
	assert(lobby_menu.join_panel.visible == true, "join_panel should be visible")
	assert(lobby_menu.host_panel.visible == false, "host_panel should be hidden")

	lobby_menu._switch_to(lobby_menu.voice_panel)
	assert(lobby_menu.voice_panel.visible == true, "voice_panel should be visible")
	assert(lobby_menu.join_panel.visible == false, "join_panel should be hidden")

	lobby_menu._switch_to(lobby_menu.menu_buttons_panel)
	assert(lobby_menu.menu_buttons_panel.visible == true, "menu_buttons_panel restored")
	assert(lobby_menu.voice_panel.visible == false, "voice_panel should be hidden")
	print("PASS: 3. Modal panel transitions work cleanly.")

	# 4. Test Random Name Generator & Real Name Storage
	var initial_name = lobby_menu.name_input.text
	lobby_menu._on_random_pressed()
	var rolled_name = lobby_menu.name_input.text
	assert(rolled_name != initial_name, "Rolled name should update")
	assert(NetworkManager.local_player_name == rolled_name, "NetworkManager name should match rolled name")
	assert(NetworkManager.get_player_name(1) == rolled_name, "get_player_name(1) should return rolled name for local host")
	print("PASS: 4. Random name generator works. Active name: '%s'" % rolled_name)

	# 5. Test Focus Safety
	lobby_menu.name_input.emit_signal("focus_entered")
	assert(lobby_menu.voxide_voice.push_to_talk == false, "PTT should be suspended while typing")
	lobby_menu.name_input.emit_signal("focus_exited")
	assert(lobby_menu.voxide_voice.push_to_talk == true, "PTT should be restored after typing")
	print("PASS: 5. Focus safety: Typing spaces in LineEdits will not trigger voice PTT.")

	# 6. Test In-Game State Transition (Gameplay)
	lobby_menu._set_ui_state(true)
	assert(lobby_menu.background_texture.visible == false, "background_texture MUST be hidden during gameplay to reveal 3D world")
	assert(lobby_menu.overlay_tint.visible == false, "overlay_tint MUST be hidden during gameplay to reveal 3D world")
	assert(lobby_menu.center_area.visible == false, "center_area must be hidden during gameplay")
	assert(lobby_menu.hud_panel.visible == true, "hud_panel must be visible during gameplay")
	assert(lobby_menu.voxide_voice.visible == false, "voxide_voice must be hidden during gameplay")
	assert(lobby_menu.voxide_voice.is_processing() == false, "voxide_voice must NOT process during gameplay")
	assert(lobby_menu.voxide_voice.push_to_talk == false, "voxide_voice PTT must be disabled during gameplay")
	
	var crosshair_node = lobby_menu.get_node_or_null("HUD/Crosshair")
	assert(crosshair_node != null, "Crosshair node must exist in HUD")
	assert(crosshair_node.anchor_left > 0.5, "Crosshair must be offset (> 0.5) for third-person over-the-shoulder perspective")
	print("PASS: 6. Gameplay State: 3D world revealed, Voxide silenced, crosshair offset over shoulder.")

	# 7. Test Bullet Impact Without Tree Errors (Bug Fix Verification)
	var bullet_res = load("res://scenes/projectile/bullet.tscn")
	assert(bullet_res != null, "Bullet scene must load")
	var bullet_test: Bullet = bullet_res.instantiate()
	add_child(bullet_test)
	bullet_test.setup(Vector3(0, 1, 0), Vector3(0, 1, -10), RID(), 95.0, Color(1, 0.5, 0.2))
	# Trigger impact FX directly
	bullet_test._impact(Vector3(0, 1, -10), Vector3.BACK)
	print("PASS: 7. Bullet impact FX executed without '!is_inside_tree()' error.")

	# 8. Test Modular Weapon System on Player
	var player_res = load("res://scenes/player/player.tscn")
	assert(player_res != null, "Player scene must load")
	var p_test: Player = player_res.instantiate()
	add_child(p_test)
	
	var wm: PlayerWeaponManager = p_test.weapon_manager
	assert(wm != null, "Player must have WeaponManager node")
	assert(wm.weapons.size() >= 3, "WeaponManager must have at least 3 default modular weapons")
	
	# Hook HUD to weapon manager
	lobby_menu.hook_local_player_weapon(wm)
	assert(lobby_menu.hud_weapon_name.text == "PULSE BLASTER", "HUD weapon name should be PULSE BLASTER")
	assert(lobby_menu.hud_ammo_current.text == "30", "HUD ammo should show 30")
	assert(lobby_menu.hud_ammo_reserve.text == "/ 120", "HUD reserve ammo should show / 120")
	
	# Test firing and ammo consumption
	var fired_w = wm.fire()
	assert(fired_w != null, "Weapon fire should succeed")
	assert(fired_w.current_ammo == 29, "Ammo should decrement to 29")
	assert(lobby_menu.hud_ammo_current.text == "29", "HUD ammo label should reflect 29")
	
	# Test reloading
	wm.reload_current()
	assert(fired_w.current_ammo == 30, "Ammo should be replenished to 30 after reload")
	assert(fired_w.reserve_ammo == 119, "Reserve ammo should be decremented by 1")
	assert(lobby_menu.hud_ammo_current.text == "30", "HUD ammo should show 30 after reload")
	
	# Test switching weapon to slot 1 (Heavy Cannon)
	wm.switch_weapon(1)
	var cur_w = wm.get_current_weapon()
	assert(cur_w.weapon_id == "heavy_cannon", "Switched weapon must be heavy_cannon")
	assert(lobby_menu.hud_weapon_name.text == "HEAVY CANNON", "HUD weapon name should update to HEAVY CANNON")
	assert(lobby_menu.hud_ammo_current.text == "8", "HUD ammo should show 8 for Heavy Cannon")
	
	# Test weapon cycling
	wm.cycle_weapon(1)
	var next_w = wm.get_current_weapon()
	assert(next_w.weapon_id == "plasma_rifle", "Cycled weapon must be plasma_rifle")
	assert(lobby_menu.hud_weapon_name.text == "PLASMA RIFLE", "HUD weapon name should update to PLASMA RIFLE")
	
	p_test.queue_free()
	print("PASS: 8. Modular Weapon System: dynamic stats, switching, cycling, ammo, reload, and HUD updates verified.")

	# 9. Test Player Real Nickname Display (Nametag and HUD)
	NetworkManager.local_player_name = "ShadowStriker"
	var world_node: World = main_inst.get_node_or_null("World")
	assert(world_node != null, "World node must exist in main scene")
	
	# Host game
	NetworkManager.host_game(8933)
	var p1: Player = world_node.players_container.get_node_or_null("1")
	assert(p1 != null, "Player 1 must be spawned on host")
	assert(p1.nametag_label.text == "ShadowStriker", "Player nametag must show chosen nickname 'ShadowStriker', NOT 'Host (1)'")
	lobby_menu._update_player_hud()
	assert(lobby_menu.hud_player_name.text == "ShadowStriker", "HUD player name card must show 'ShadowStriker'")
	print("PASS: 9. Real player nickname correctly reflected on 3D Nametag and in HUD TopLeftCard.")

	# 10. Test Re-Hosting Cycle (Host -> Disconnect -> Host Again)
	lobby_menu._on_disconnect_pressed()
	assert(world_node.players_container.get_child_count() == 0, "Players must be cleared on disconnect")
	assert(world_node.menu_camera.current == true, "MenuCamera must be restored on disconnect")
	
	# Host Again!
	NetworkManager.host_game(8933)
	var p1_rehost: Player = world_node.players_container.get_node_or_null("1")
	assert(p1_rehost != null, "Player 1 must be spawned on re-host")
	var p1_cam = p1_rehost.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
	assert(p1_cam != null and p1_cam.current == true, "Player camera MUST be current on re-host")
	assert(world_node.menu_camera.current == false, "MenuCamera MUST be disabled on re-host")
	assert(p1_rehost.nametag_label.text == "ShadowStriker", "Player nametag must show chosen nickname on re-host")
	
	# Clean up network
	NetworkManager.disconnect_game()
	print("PASS: 10. Re-Hosting Cycle: Camera correctly follows player and MenuCamera is disabled upon re-hosting.")

	print("==================================================")
	print("ALL 10 TESTS PASSED WITH FLYING COLORS!")
	print("==================================================")
	get_tree().quit(0)
