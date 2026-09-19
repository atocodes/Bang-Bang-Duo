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
	assert(lobby_menu.weyzero_btn != null, "weyzero_btn missing")
	assert(lobby_menu.ato_btn != null, "ato_btn missing")
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
	assert(lobby_menu.hud_shoot_type != null, "hud_shoot_type missing")
	assert(lobby_menu.hud_ammo_current != null, "hud_ammo_current missing")
	assert(lobby_menu.hud_ammo_reserve != null, "hud_ammo_reserve missing")
	assert(lobby_menu.pickup_toast != null, "pickup_toast missing")
	
	# Verify 4 corners in HUD
	assert(lobby_menu.get_node_or_null("HUD/TopLeftCard") != null, "TopLeftCard missing")
	assert(lobby_menu.get_node_or_null("HUD/TopRightCard") != null, "TopRightCard missing")
	assert(lobby_menu.get_node_or_null("HUD/BottomLeftCard") != null, "BottomLeftCard missing")
	assert(lobby_menu.get_node_or_null("HUD/BottomRightCard") != null, "BottomRightCard missing")
	print("PASS: 1. All arcade UI panels, character buttons, and 4-corner HUD nodes verified.")

	# 2. Assert Initial Main Menu State
	assert(lobby_menu.menu_buttons_panel.visible == true, "menu_buttons_panel should be visible on start")
	assert(lobby_menu.host_panel.visible == false, "host_panel should be hidden on start")
	assert(lobby_menu.join_panel.visible == false, "join_panel should be hidden on start")
	assert(lobby_menu.hud_panel.visible == false, "hud_panel should be hidden on start")
	print("PASS: 2. Initial state: Main Menu active, modals hidden, HUD hidden.")

	# 3. Test Character Selection Buttons on Main Menu
	lobby_menu.ato_btn.emit_signal("pressed")
	assert(NetworkManager.local_player_character == "Ato Codes", "Clicking AtoBtn should select Ato Codes")
	lobby_menu.weyzero_btn.emit_signal("pressed")
	assert(NetworkManager.local_player_character == "Weyzero Codes", "Clicking WeyzeroBtn should select Weyzero Codes")
	print("PASS: 3. Main Menu character selection between Weyzero Codes and Ato Codes works.")

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
	assert(lobby_menu.background_texture.visible == false, "background_texture MUST be hidden during gameplay")
	assert(lobby_menu.overlay_tint.visible == false, "overlay_tint MUST be hidden during gameplay")
	assert(lobby_menu.center_area.visible == false, "center_area must be hidden during gameplay")
	assert(lobby_menu.hud_panel.visible == true, "hud_panel must be visible during gameplay")
	assert(lobby_menu.voxide_voice.visible == false, "voxide_voice must be hidden during gameplay")
	
	var crosshair_node = lobby_menu.get_node_or_null("HUD/Crosshair")
	assert(crosshair_node != null, "Crosshair node must exist in HUD")
	assert(crosshair_node.anchor_left > 0.5, "Crosshair must be offset for over-the-shoulder view")
	print("PASS: 6. Gameplay State: 3D world revealed, Voxide silenced, crosshair offset.")

	# 7. Test Bullet Impact Without Tree Errors
	var bullet_res = load("res://scenes/projectile/bullet.tscn")
	assert(bullet_res != null, "Bullet scene must load")
	var bullet_test: Bullet = bullet_res.instantiate()
	add_child(bullet_test)
	bullet_test.setup(Vector3(0, 1, 0), Vector3(0, 1, -10), RID(), 95.0, Color(1, 0.5, 0.2))
	bullet_test._impact(Vector3(0, 1, -10), Vector3.BACK)
	print("PASS: 7. Bullet impact FX executed cleanly.")

	# 8. Test 5-Weapon Arsenal and Shoot Types
	var player_res = load("res://scenes/player/player.tscn")
	assert(player_res != null, "Player scene must load")
	var p_test: Player = player_res.instantiate()
	add_child(p_test)
	
	var wm: PlayerWeaponManager = p_test.weapon_manager
	assert(wm != null, "Player must have WeaponManager node")
	assert(wm.weapons.size() == 5, "WeaponManager must have exactly 5 modular weapons (All except blast FBXs)")
	
	# Slot 0: Assault Rifle
	wm.switch_weapon(0)
	lobby_menu.hook_local_player_weapon(wm)
	assert(lobby_menu.hud_weapon_name.text == "ASSAULT RIFLE", "Slot 0 should be ASSAULT RIFLE")
	assert(lobby_menu.hud_shoot_type.text == "[FULL AUTO]", "Assault Rifle shoot type should be [FULL AUTO]")
	
	# Slot 1: Machine Gun
	wm.switch_weapon(1)
	assert(lobby_menu.hud_weapon_name.text == "MACHINE GUN", "Slot 1 should be MACHINE GUN")
	assert(lobby_menu.hud_shoot_type.text == "[FULL AUTO]", "Machine Gun shoot type should be [FULL AUTO]")
	assert(lobby_menu.hud_ammo_current.text == "60", "Machine Gun mag should be 60")
	
	# Slot 2: Burst Rifle
	wm.switch_weapon(2)
	assert(lobby_menu.hud_weapon_name.text == "BURST RIFLE", "Slot 2 should be BURST RIFLE")
	assert(lobby_menu.hud_shoot_type.text == "[3-ROUND BURST]", "Burst Rifle shoot type should be [3-ROUND BURST]")
	
	# Slot 3: Sniper Rifle
	wm.switch_weapon(3)
	assert(lobby_menu.hud_weapon_name.text == "SNIPER RIFLE", "Slot 3 should be SNIPER RIFLE")
	assert(lobby_menu.hud_shoot_type.text == "[SEMI-AUTO]", "Sniper shoot type should be [SEMI-AUTO]")
	
	# Slot 4: Heavy Sniper
	wm.switch_weapon(4)
	assert(lobby_menu.hud_weapon_name.text == "HEAVY SNIPER", "Slot 4 should be HEAVY SNIPER")
	assert(lobby_menu.hud_shoot_type.text == "[BOLT ACTION]", "Heavy Sniper shoot type should be [BOLT ACTION]")
	assert(lobby_menu.hud_ammo_current.text == "5", "Heavy Sniper mag should be 5")
	
	# Test Ammo Consumption & Reload
	var fired_w = wm.fire()
	assert(fired_w != null, "Weapon fire should succeed")
	assert(fired_w.current_ammo == 4, "Heavy Sniper ammo should decrement to 4")
	wm.reload_current()
	assert(fired_w.current_ammo == 5, "Ammo should replenish to 5 after reload")

	print("PASS: 8. All 5 modular weapons (Assault Rifle, Machine Gun, Burst Rifle, Sniper, Heavy Sniper) & distinct shoot types verified.")

	# 9. Test Character Model Switching & LeftHandIK on Player
	# Switch to Ato Codes
	p_test.character_model = "Ato Codes"
	var ato_node: Node3D = p_test.get_node("Visuals/AtoCodes")
	var weyzero_node: Node3D = p_test.get_node("Visuals/WeyzeroCodes")
	assert(ato_node.visible == true, "AtoCodes mesh must be visible when character_model is Ato Codes")
	assert(weyzero_node.visible == false, "WeyzeroCodes mesh must be hidden when character_model is Ato Codes")
	assert(p_test.anim_tree != null and p_test.anim_tree.get_parent() == ato_node, "anim_tree must belong to AtoCodes")
	assert(p_test.left_hand_ik != null and p_test.left_hand_ik.get_parent() == ato_node.get_node("Skeleton3D"), "LeftHandIK must belong to AtoCodes")
	assert(p_test.muzzle != null, "Muzzle must be active on AtoCodes weapon mount")
	
	# Switch back to Weyzero Codes
	p_test.character_model = "Weyzero Codes"
	assert(weyzero_node.visible == true, "WeyzeroCodes mesh must be visible")
	assert(ato_node.visible == false, "AtoCodes mesh must be hidden")
	assert(p_test.anim_tree.get_parent() == weyzero_node, "anim_tree must belong to WeyzeroCodes")
	assert(p_test.left_hand_ik.get_parent() == weyzero_node.get_node("Skeleton3D"), "LeftHandIK must belong to WeyzeroCodes")
	
	# Test Pickup Notification
	p_test.notify_pickup(wm.get_current_weapon())
	assert(lobby_menu.pickup_toast.visible == true, "PickupToast must show on HUD when weapon picked up")
	assert("ACQUIRED" in lobby_menu.pickup_toast.text, "PickupToast should say ACQUIRED")
	
	p_test.queue_free()
	print("PASS: 9. Character Model switching (Ato Codes / Weyzero Codes) with dynamic LeftHandIK, Muzzle, and AnimationTree verified.")

	# 10. Test In-World Weapon Pickups
	var world_node: World = main_inst.get_node_or_null("World")
	assert(world_node != null, "World node must exist")
	var pickups_container = world_node.get_node_or_null("WeaponPickups")
	assert(pickups_container != null, "WeaponPickups container must exist in World")
	assert(pickups_container.get_child_count() >= 5, "World must contain at least 5 weapon pickups")
	
	var rifle_pickup: Node = pickups_container.get_node_or_null("Pickup_Rifle")
	assert(rifle_pickup != null, "Pickup_Rifle must exist in world")
	assert(rifle_pickup.weapon_id == "rifle", "Pickup weapon_id must match")
	print("PASS: 10. In-world 3D weapon pickups verified across the map.")

	# 11. Test Multiplayer Hosting with Character Choice
	NetworkManager.local_player_name = "CyberAto"
	NetworkManager.local_player_character = "Ato Codes"
	NetworkManager.host_game(8944)
	
	var p_host: Player = world_node.players_container.get_node_or_null("1")
	assert(p_host != null, "Host player must be spawned")
	assert(p_host.character_model == "Ato Codes", "Host player must spawn with chosen character model 'Ato Codes'")
	assert(p_host.get_node("Visuals/AtoCodes").visible == true, "Host AtoCodes model must be visible in world")
	assert(p_host.get_node("Visuals/WeyzeroCodes").visible == false, "Host WeyzeroCodes model must be hidden")
	
	NetworkManager.disconnect_game()
	print("PASS: 11. Multiplayer host spawned with chosen character 'Ato Codes' verified.")

	print("==================================================")
	print("ALL 11 TESTS PASSED WITH FLYING COLORS!")
	print("==================================================")
	get_tree().quit(0)
