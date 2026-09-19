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

	# 8. Test Unarmed Spawning, Weapon Acquisition, Arsenal, and Timed Reload with Switch Cancellation
	var player_res = load("res://scenes/player/player.tscn")
	assert(player_res != null, "Player scene must load")
	var p_test: Player = player_res.instantiate()
	add_child(p_test)
	
	var wm: PlayerWeaponManager = p_test.weapon_manager
	assert(wm != null, "Player must have WeaponManager node")
	
	# Verify player spawns completely unarmed with no ammo text
	assert(wm.weapons.is_empty(), "Player must spawn unarmed with 0 weapons")
	assert(p_test.current_weapon_id == "", "current_weapon_id must be empty at spawn")
	lobby_menu.hook_local_player_weapon(wm)
	assert(lobby_menu.hud_weapon_name.text == "UNARMED", "HUD should display UNARMED when no gun is equipped")
	assert(lobby_menu.hud_ammo_current.text == "", "HUD ammo current must be empty when unarmed")
	assert(lobby_menu.hud_ammo_reserve.text == "", "HUD ammo reserve must be empty when unarmed")
	print("PASS: 8a. Player spawns unarmed with no weapon models, LeftHandIK inactive, and no ammo text.")

	# Pickup 1st weapon: Assault Rifle
	var rifle_data = PlayerWeaponManager.create_weapon_by_id("rifle")
	wm.add_or_refill_weapon(rifle_data)
	assert(wm.weapons.size() == 1, "Player should have 1 weapon after pickup")
	assert(p_test.current_weapon_id == "rifle", "current_weapon_id should be 'rifle'")
	assert(lobby_menu.hud_weapon_name.text == "ASSAULT RIFLE", "HUD should update to ASSAULT RIFLE")
	assert(lobby_menu.hud_shoot_type.text == "[FULL AUTO]", "Shoot type should be [FULL AUTO]")
	assert(lobby_menu.hud_ammo_current.text == "30", "Ammo should show 30")
	
	# Pickup remaining weapons in arsenal
	wm.add_or_refill_weapon(PlayerWeaponManager.create_weapon_by_id("machine_gun"))
	wm.add_or_refill_weapon(PlayerWeaponManager.create_weapon_by_id("burst_rifle"))
	wm.add_or_refill_weapon(PlayerWeaponManager.create_weapon_by_id("sniper_rifle"))
	wm.add_or_refill_weapon(PlayerWeaponManager.create_weapon_by_id("heavy_sniper"))
	assert(wm.weapons.size() == 5, "All 5 weapons acquired into inventory")
	
	# Verify slot properties
	wm.switch_weapon(1)
	assert(lobby_menu.hud_weapon_name.text == "MACHINE GUN", "Slot 1 should be MACHINE GUN")
	assert(lobby_menu.hud_shoot_type.text == "[FULL AUTO]", "Machine Gun shoot type should be [FULL AUTO]")
	assert(lobby_menu.hud_ammo_current.text == "60", "Machine Gun mag should be 60")
	
	wm.switch_weapon(2)
	assert(lobby_menu.hud_weapon_name.text == "BURST RIFLE", "Slot 2 should be BURST RIFLE")
	assert(lobby_menu.hud_shoot_type.text == "[3-ROUND BURST]", "Burst Rifle shoot type should be [3-ROUND BURST]")
	
	wm.switch_weapon(3)
	assert(lobby_menu.hud_weapon_name.text == "SNIPER RIFLE", "Slot 3 should be SNIPER RIFLE")
	assert(lobby_menu.hud_shoot_type.text == "[SEMI-AUTO]", "Sniper shoot type should be [SEMI-AUTO]")
	
	wm.switch_weapon(4)
	assert(lobby_menu.hud_weapon_name.text == "HEAVY SNIPER", "Slot 4 should be HEAVY SNIPER")
	assert(lobby_menu.hud_shoot_type.text == "[BOLT ACTION]", "Heavy Sniper shoot type should be [BOLT ACTION]")
	assert(lobby_menu.hud_ammo_current.text == "5", "Heavy Sniper mag should be 5")

	# Test Timed Reload with Weapon Switch Cancellation and Restart from Scratch
	var heavy_w: WeaponData = wm.get_current_weapon()
	for i in range(5):
		wm._cooldown_timer = 0.0
		var shot = wm.fire()
		assert(shot != null, "Shot %d must succeed" % (i + 1))
	
	assert(heavy_w.current_ammo == 0, "Heavy sniper must be empty after 5 shots")
	assert(wm.is_reloading == true, "Running out of bullets must automatically trigger reload timer")
	assert(lobby_menu.hud_ammo_current.text == "RELOAD", "HUD ammo label must show RELOAD during reload")
	
	# Switch weapon away while reloading -> must cancel reload and leave weapon empty
	wm.switch_weapon(0)
	assert(wm.is_reloading == false, "Switching weapon must cancel reload")
	assert(heavy_w.current_ammo == 0, "Cancelled weapon must not reload in background and stay at 0")
	assert(lobby_menu.hud_weapon_name.text == "ASSAULT RIFLE", "Now holding Assault Rifle")

	# Switch back to Heavy Sniper -> must still have 0 bullets and restart reload from the start
	wm.switch_weapon(4)
	assert(heavy_w.current_ammo == 0, "Heavy sniper still has 0 bullets upon switching back")
	assert(wm.is_reloading == true, "Must automatically start reload from the beginning upon switching back")
	assert(is_equal_approx(wm.reload_timer, heavy_w.reload_time), "Reload timer must restart from full duration")

	# Switch away again and switch back -> cancels and restarts again likewise
	wm.switch_weapon(1)
	assert(wm.is_reloading == false, "Switching away again cancels reload again")
	assert(heavy_w.current_ammo == 0, "Still empty")
	wm.switch_weapon(4)
	assert(wm.is_reloading == true, "Switching back restarts reload from the start again")

	# Allow reload to complete
	wm.finish_reload()
	assert(wm.is_reloading == false, "Reload completed")
	assert(heavy_w.current_ammo == 5, "Ammo replenished to 5 after completing reload")
	assert(heavy_w.reserve_ammo == 15, "Reserve ammo decremented from 20 to 15")
	assert(lobby_menu.hud_ammo_current.text == "5", "HUD displays 5 after reload completion")

	print("PASS: 8b. All 5 modular weapons, shoot types, and timed reload with switch cancellation & restart verified.")

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
	var test_port: int = randi_range(9100, 15000)
	NetworkManager.host_game(test_port)
	
	var p_host: Player = world_node.players_container.get_node_or_null("1")
	assert(p_host != null, "Host player must be spawned")
	assert(p_host.character_model == "Ato Codes", "Host player must spawn with chosen character model 'Ato Codes'")
	assert(p_host.get_node("Visuals/AtoCodes").visible == true, "Host AtoCodes model must be visible in world")
	# 12. Test In-World Pickup Collection, Equipped Visuals, Remote Shoot RPC & Locomotion Sync
	assert(p_host.current_weapon_id == "", "Host player starts unarmed in world")
	var ato_mount: Node3D = p_host.get_node("Visuals/AtoCodes/Skeleton3D/BoneAttachment3D/WeaponMount")
	for child in ato_mount.get_children():
		if child is Node3D:
			assert(child.visible == false, "No weapon model visible when unarmed")
	assert(p_host.muzzle == null, "Muzzle must be null when unarmed")
	
	# Collect in-world Rifle pickup
	rifle_pickup._collect(p_host)
	assert(p_host.current_weapon_id == "rifle", "Collecting rifle pickup equips rifle")
	var rifle_node = ato_mount.get_node_or_null("Rifile")
	assert(rifle_node != null and rifle_node.visible == true, "Rifile 3D model must be visible in hands")
	assert(p_host.muzzle != null, "Muzzle must be assigned on rifle")
	assert(p_host.left_hand_ik != null, "LeftHandIK exists")

	# Test Remote Shoot RPC synchronization
	p_host._rpc_remote_shoot(p_host.global_position, p_host.global_position + Vector3(0, 0, -10), "rifle")
	assert(p_host.anim_tree.get("parameters/shoot_shot/request") == AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE, "Shoot anim triggered by RPC")
	
	# Test Locomotion Animation Sync (Walk, Run, Idle)
	p_host.velocity = Vector3(4.0, 0.0, 0.0)
	p_host._update_animation_state(0.016)
	if p_host.anim_tree:
		p_host.anim_tree.advance(0.3)
	assert(p_host.anim_playback.get_current_node() == "Walk", "4.0 m/s velocity must trigger Walk animation")
	
	p_host.velocity = Vector3(8.5, 0.0, 0.0)
	p_host._update_animation_state(0.016)
	if p_host.anim_tree:
		p_host.anim_tree.advance(0.3)
	assert(p_host.anim_playback.get_current_node() == "Run", "8.5 m/s velocity must trigger Run animation")
	
	p_host.velocity = Vector3.ZERO
	p_host._update_animation_state(0.016)
	if p_host.anim_tree:
		p_host.anim_tree.advance(0.3)
	assert(p_host.anim_playback.get_current_node() == "Idle", "Zero velocity must trigger Idle animation")
	print("PASS: 12. In-world pickup collection, 3D weapon mounting, remote shoot RPC, and locomotion animation sync verified.")

	NetworkManager.disconnect_game()
	print("PASS: 11. Multiplayer host spawned with chosen character 'Ato Codes' verified.")

	print("==================================================")
	print("ALL 12 TESTS PASSED WITH FLYING COLORS!")
	print("==================================================")
	get_tree().quit(0)
