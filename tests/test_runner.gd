extends Node

func _ready() -> void:
	print("==================================================")
	print("RUNNING BANG BANG DUO ARCADE UI & VOXIDE TEST")
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

	# 1. Assert UI Nodes Exist
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
	assert(lobby_menu.hud_status != null, "hud_status missing")
	assert(lobby_menu.disconnect_button != null, "disconnect_button missing")
	print("PASS: 1. All arcade UI panels, buttons, and Voxide nodes resolved.")

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

	# 4. Test Random Name Generator
	var initial_name = lobby_menu.name_input.text
	lobby_menu._on_random_pressed()
	var rolled_name = lobby_menu.name_input.text
	assert(rolled_name != initial_name, "Rolled name should update")
	assert(NetworkManager.local_player_name == rolled_name, "NetworkManager name should match rolled name")
	print("PASS: 4. Random name generator works. Handle: '%s'" % rolled_name)

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

	# 7. Test Return to Main Menu State Transition
	lobby_menu._set_ui_state(false)
	assert(lobby_menu.background_texture.visible == true, "background_texture restored on menu")
	assert(lobby_menu.overlay_tint.visible == true, "overlay_tint restored on menu")
	assert(lobby_menu.center_area.visible == true, "center_area must be visible after return")
	assert(lobby_menu.menu_buttons_panel.visible == true, "menu_buttons_panel visible on return")
	assert(lobby_menu.hud_panel.visible == false, "hud_panel must be hidden after return")
	assert(lobby_menu.voxide_voice.visible == true, "voxide_voice must be visible on return")
	assert(lobby_menu.voxide_voice.is_processing() == true, "voxide_voice processing restored on return")
	assert(lobby_menu.voxide_voice.push_to_talk == true, "voxide_voice PTT restored on return")
	print("PASS: 7. Return to Menu: Background and Voxide cleanly restored for easy access.")

	# 8. Test Player Third-Person Camera Structure
	var player_res = load("res://scenes/player/player.tscn")
	assert(player_res != null, "Player scene must load")
	var player_inst = player_res.instantiate()
	var spring_arm: SpringArm3D = player_inst.get_node_or_null("CameraPivot/SpringArm3D")
	assert(spring_arm != null, "Player must have SpringArm3D for 3rd person collision safety")
	assert(spring_arm.position.x > 0.4, "SpringArm3D must be offset right (> 0.4) for over-the-shoulder view")
	var cam: Camera3D = player_inst.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
	assert(cam != null, "Camera3D must be parented under SpringArm3D")
	player_inst.queue_free()
	print("PASS: 8. Player: SpringArm3D over-the-shoulder 3rd-person camera setup confirmed.")

	print("==================================================")
	print("ALL TESTS PASSED SUCCESSFULLY!")
	print("==================================================")
	get_tree().quit(0)
