class_name LobbyMenu
extends Control

## LobbyMenu Controller
## Arcade-style menu navigation for hosting, joining, settings,
## and Voxide Voice Assistant integration strictly on the Main Menu.

# --- Background & Overlay ---
@onready var background_texture: TextureRect = $BackgroundTexture
@onready var overlay_tint: ColorRect = $OverlayTint

# --- CenterArea & Panels ---
@onready var center_area: CenterContainer = $CenterArea
@onready var menu_buttons_panel: PanelContainer = $CenterArea/MenuButtonsPanel
@onready var host_panel: PanelContainer = $CenterArea/HostPanel
@onready var join_panel: PanelContainer = $CenterArea/JoinPanel
@onready var voice_panel: PanelContainer = $CenterArea/VoicePanel
@onready var settings_panel: PanelContainer = $CenterArea/SettingsPanel

# --- Main Buttons ---
@onready var name_input: LineEdit = $CenterArea/MenuButtonsPanel/VBox/NameRow/NameInput
@onready var random_name_btn: Button = $CenterArea/MenuButtonsPanel/VBox/NameRow/RandomButton
@onready var host_game_btn: Button = $CenterArea/MenuButtonsPanel/VBox/HostGameBtn
@onready var join_game_btn: Button = $CenterArea/MenuButtonsPanel/VBox/JoinGameBtn
@onready var voice_assistant_btn: Button = $CenterArea/MenuButtonsPanel/VBox/VoiceAssistantBtn
@onready var settings_btn: Button = $CenterArea/MenuButtonsPanel/VBox/SettingsBtn
@onready var quit_btn: Button = $CenterArea/MenuButtonsPanel/VBox/QuitBtn

# --- Character Selection Buttons ---
@onready var weyzero_btn: Button = get_node_or_null("CenterArea/MenuButtonsPanel/VBox/CharacterRow/WeyzeroBtn")
@onready var ato_btn: Button = get_node_or_null("CenterArea/MenuButtonsPanel/VBox/CharacterRow/AtoBtn")

# --- Host Panel Controls ---
@onready var host_ip_label: Label = $CenterArea/HostPanel/VBox/IPDisplayContainer/HBox/HostIPValue
@onready var copy_ip_button: Button = $CenterArea/HostPanel/VBox/IPDisplayContainer/HBox/CopyIPButton
@onready var copy_feedback_label: Label = $CenterArea/HostPanel/VBox/CopyFeedbackLabel
@onready var host_port_input: LineEdit = $CenterArea/HostPanel/VBox/PortRow/HostPortInput
@onready var host_status_label: Label = $CenterArea/HostPanel/VBox/HostStatusLabel
@onready var start_host_button: Button = $CenterArea/HostPanel/VBox/StartHostButton
@onready var host_back_button: Button = $CenterArea/HostPanel/VBox/HostBackButton

# --- Join Panel Controls ---
@onready var join_ip_input: LineEdit = $CenterArea/JoinPanel/VBox/AddressRow/JoinIPLineEdit
@onready var join_port_input: LineEdit = $CenterArea/JoinPanel/VBox/AddressRow/JoinPortInput
@onready var join_status_label: Label = $CenterArea/JoinPanel/VBox/JoinStatusLabel
@onready var join_submit_button: Button = $CenterArea/JoinPanel/VBox/JoinSubmitButton
@onready var join_back_button: Button = $CenterArea/JoinPanel/VBox/JoinBackButton

# --- Voice Panel Controls ---
@onready var voxide_voice: VoxideVoice = $CenterArea/VoicePanel/VBox/VoxideVoice
@onready var voice_back_button: Button = $CenterArea/VoicePanel/VBox/VoiceBackButton

# --- Settings Panel Controls ---
@onready var settings_back_button: Button = $CenterArea/SettingsPanel/VBox/SettingsBackButton

# --- In-Game HUD (4 Corners) ---
@onready var hud_panel: Control = $HUD
@onready var hud_player_name: Label = $HUD/TopLeftCard/Panel/VBox/PlayerNameLabel
@onready var hud_role_badge: Label = $HUD/TopLeftCard/Panel/VBox/StatusRow/RoleBadge
@onready var hud_active_players: Label = $HUD/TopLeftCard/Panel/VBox/StatusRow/ActivePlayers
@onready var disconnect_button: Button = $HUD/TopRightCard/DisconnectButton
@onready var hud_weapon_name: Label = $HUD/BottomRightCard/Panel/VBox/WeaponNameLabel
@onready var hud_shoot_type: Label = get_node_or_null("HUD/BottomRightCard/Panel/VBox/ShootTypeLabel")
@onready var hud_ammo_current: Label = $HUD/BottomRightCard/Panel/VBox/AmmoRow/AmmoCurrentLabel
@onready var hud_ammo_reserve: Label = $HUD/BottomRightCard/Panel/VBox/AmmoRow/AmmoReserveLabel
@onready var pickup_toast: Label = get_node_or_null("HUD/PickupToast")

var _toast_tween: Tween = null
var _hooked_weapon_manager: PlayerWeaponManager = null

var _current_panel: Control
var _detected_ip: String = "127.0.0.1"

const RANDOM_NAMES: Array[String] = [
	"Maverick", "Shadow", "Blaster", "Pixel", "Nova",
	"Vortex", "Apex", "Echo", "Dash", "Ace",
	"Specter", "Rogue", "Striker", "Bullet", "Cipher", "Phantom"
]


func _ready() -> void:
	_current_panel = menu_buttons_panel

	# Wire Navigation
	host_game_btn.pressed.connect(func():
		_refresh_host_ip()
		_switch_to(host_panel)
	)
	join_game_btn.pressed.connect(func(): _switch_to(join_panel))
	voice_assistant_btn.pressed.connect(func(): _switch_to(voice_panel))
	settings_btn.pressed.connect(func(): _switch_to(settings_panel))
	quit_btn.pressed.connect(func(): get_tree().quit())

	host_back_button.pressed.connect(func(): _switch_to(menu_buttons_panel))
	join_back_button.pressed.connect(func(): _switch_to(menu_buttons_panel))
	voice_back_button.pressed.connect(func(): _switch_to(menu_buttons_panel))
	settings_back_button.pressed.connect(func(): _switch_to(menu_buttons_panel))

	# Wire Player Name & Randomizer
	name_input.text_changed.connect(_on_name_changed)
	random_name_btn.pressed.connect(_on_random_pressed)

	# Wire Character Selection
	if weyzero_btn:
		weyzero_btn.pressed.connect(func(): _select_character("Weyzero Codes"))
	if ato_btn:
		ato_btn.pressed.connect(func(): _select_character("Ato Codes"))
	_select_character(NetworkManager.local_player_character)

	# Wire Host Actions
	copy_ip_button.pressed.connect(_on_copy_ip_pressed)
	start_host_button.pressed.connect(_on_start_host_pressed)

	# Wire Join Actions
	join_submit_button.pressed.connect(_on_join_submit_pressed)

	# Wire HUD Actions
	disconnect_button.pressed.connect(_on_disconnect_pressed)

	# Focus safety for text inputs
	_setup_focus_safety([name_input, host_port_input, join_ip_input, join_port_input])

	# Wire NetworkManager events
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.connection_successful.connect(_on_connection_successful)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_closed.connect(_on_server_closed)
	NetworkManager.player_connected.connect(_update_player_hud)
	NetworkManager.player_disconnected.connect(func(_id: int): _update_player_hud())

	# Setup Voxide Voice AI
	_setup_voxide_integration()

	# Initial UI State
	_set_ui_state(false)
	_switch_to(menu_buttons_panel)


func _switch_to(target_panel: Control) -> void:
	if not target_panel:
		return
	menu_buttons_panel.visible = (target_panel == menu_buttons_panel)
	host_panel.visible = (target_panel == host_panel)
	join_panel.visible = (target_panel == join_panel)
	voice_panel.visible = (target_panel == voice_panel)
	settings_panel.visible = (target_panel == settings_panel)
	_current_panel = target_panel


func _refresh_host_ip() -> void:
	_detected_ip = IPHelper.get_local_ipv4()
	if host_ip_label:
		host_ip_label.text = _detected_ip


func _on_copy_ip_pressed() -> void:
	DisplayServer.clipboard_set(_detected_ip)
	if copy_feedback_label:
		copy_feedback_label.text = "IP COPIED TO CLIPBOARD!"
		var tween := create_tween()
		tween.tween_property(copy_feedback_label, "modulate:a", 1.0, 0.15)
		tween.tween_interval(1.8)
		tween.tween_property(copy_feedback_label, "modulate:a", 0.0, 0.3)


func _on_start_host_pressed() -> void:
	var port := host_port_input.text.to_int()
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT

	host_status_label.text = "STARTING SERVER ON PORT %d..." % port
	var error: Error = NetworkManager.host_game(port)
	if error != OK:
		host_status_label.text = "FAILED TO START SERVER (CODE: %d)" % error


func _on_join_submit_pressed() -> void:
	var ip := join_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = NetworkManager.DEFAULT_IP

	var port := join_port_input.text.to_int()
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT

	join_status_label.text = "CONNECTING TO %s:%d..." % [ip, port]
	var error: Error = NetworkManager.join_game(ip, port)
	if error != OK:
		join_status_label.text = "FAILED TO START CLIENT (CODE: %d)" % error


func _on_random_pressed() -> void:
	var handle: String = RANDOM_NAMES.pick_random()
	var num: int = randi_range(10, 99)
	var generated: String = "%s_%d" % [handle, num]
	name_input.text = generated
	_on_name_changed(generated)


func _on_name_changed(new_name: String) -> void:
	var clean := new_name.strip_edges()
	if clean.is_empty():
		NetworkManager.local_player_name = "Player"
	else:
		NetworkManager.local_player_name = clean


func _select_character(char_name: String) -> void:
	NetworkManager.local_player_character = char_name
	var is_weyzero := (char_name == "Weyzero Codes")
	if weyzero_btn:
		weyzero_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_weyzero else Color(0.65, 0.7, 0.8, 0.6)
	if ato_btn:
		ato_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if not is_weyzero else Color(0.65, 0.7, 0.8, 0.6)


func _on_disconnect_pressed() -> void:
	NetworkManager.disconnect_game()
	_set_ui_state(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Focus Safety ---
func _setup_focus_safety(inputs: Array[LineEdit]) -> void:
	for input in inputs:
		if input:
			input.focus_entered.connect(func():
				if voxide_voice:
					voxide_voice.push_to_talk = false
			)
			input.focus_exited.connect(func():
				if voxide_voice and not hud_panel.visible:
					voxide_voice.push_to_talk = true
			)


# --- Voxide Integration ---
func _setup_voxide_integration() -> void:
	if not voxide_voice:
		return

	voxide_voice.push_to_talk = true
	voxide_voice.auto_connect = true

	voxide_voice.ready.connect(_register_voxide_tools, CONNECT_ONE_SHOT)
	if voxide_voice.is_node_ready():
		_register_voxide_tools()


func _register_voxide_tools() -> void:
	if not voxide_voice:
		return

	if voxide_voice.state:
		voxide_voice.state.provider = func() -> Dictionary:
			return {
				"screen": "main_menu",
				"player_name": NetworkManager.local_player_name,
				"is_server": multiplayer.is_server(),
				"active_players": NetworkManager.players.size(),
				"default_port": NetworkManager.DEFAULT_PORT,
				"default_ip": NetworkManager.DEFAULT_IP
			}

	# Tool: Host Game
	var host_tool := VoxideTool.new("host_game", "Host a new Bang Bang Duo multiplayer server.")
	host_tool.parameters = {
		"port": { "type": "integer", "description": "Port to host on.", "required": false }
	}
	host_tool.handler = func(args: Dictionary) -> Dictionary:
		var port := int(args.get("port", 8910))
		if port <= 0:
			port = 8910
		call_deferred("_voice_cmd_host", port)
		return { "status": "success", "message": "Hosting on port %d" % port }

	# Tool: Join Game
	var join_tool := VoxideTool.new("join_game", "Join a Bang Bang Duo game server by IP address and port.")
	join_tool.parameters = {
		"ip": { "type": "string", "description": "IP address of the server.", "required": false },
		"port": { "type": "integer", "description": "Port of the server.", "required": false }
	}
	join_tool.handler = func(args: Dictionary) -> Dictionary:
		var ip := str(args.get("ip", "127.0.0.1")).strip_edges()
		if ip.is_empty():
			ip = "127.0.0.1"
		var port := int(args.get("port", 8910))
		if port <= 0:
			port = 8910
		call_deferred("_voice_cmd_join", ip, port)
		return { "status": "success", "message": "Connecting to %s:%d" % [ip, port] }

	# Tool: Set Player Name
	var name_tool := VoxideTool.new("set_player_name", "Set the player nickname.")
	name_tool.parameters = {
		"name": { "type": "string", "description": "The new nickname.", "required": true }
	}
	name_tool.handler = func(args: Dictionary) -> Dictionary:
		var new_name := str(args.get("name", "Player")).strip_edges()
		call_deferred("_voice_cmd_set_name", new_name)
		return { "status": "success", "player_name": new_name }

	# Tool: Select Character
	var char_tool := VoxideTool.new("select_character", "Choose player hero character: Weyzero Codes or Ato Codes.")
	char_tool.parameters = {
		"character": { "type": "string", "description": "Character name: Weyzero Codes or Ato Codes.", "required": true }
	}
	char_tool.handler = func(args: Dictionary) -> Dictionary:
		var choice := str(args.get("character", "Weyzero Codes"))
		if "ato" in choice.to_lower():
			choice = "Ato Codes"
		else:
			choice = "Weyzero Codes"
		call_deferred("_select_character", choice)
		return { "status": "success", "character": choice }

	voxide_voice.register_tool(host_tool)
	voxide_voice.register_tool(join_tool)
	voxide_voice.register_tool(name_tool)
	voxide_voice.register_tool(char_tool)


func _voice_cmd_host(port: int) -> void:
	host_port_input.text = str(port)
	_on_start_host_pressed()

func _voice_cmd_join(ip: String, port: int) -> void:
	join_ip_input.text = ip
	join_port_input.text = str(port)
	_on_join_submit_pressed()

func _voice_cmd_set_name(new_name: String) -> void:
	if not new_name.is_empty():
		name_input.text = new_name
		_on_name_changed(new_name)


# --- In-Game Weapon Hooking ---
func hook_local_player_weapon(wm: PlayerWeaponManager) -> void:
	if _hooked_weapon_manager and is_instance_valid(_hooked_weapon_manager):
		if _hooked_weapon_manager.weapon_changed.is_connected(_on_weapon_changed):
			_hooked_weapon_manager.weapon_changed.disconnect(_on_weapon_changed)
		if _hooked_weapon_manager.ammo_changed.is_connected(_on_ammo_changed):
			_hooked_weapon_manager.ammo_changed.disconnect(_on_ammo_changed)
	
	_hooked_weapon_manager = wm
	if not wm:
		return
	
	wm.weapon_changed.connect(_on_weapon_changed)
	wm.ammo_changed.connect(_on_ammo_changed)
	
	var cur := wm.get_current_weapon()
	if cur:
		_on_weapon_changed(cur)
		_on_ammo_changed(cur.current_ammo, cur.reserve_ammo, cur.is_infinite)


func _on_weapon_changed(w: WeaponData) -> void:
	if not w:
		return
	if hud_weapon_name:
		hud_weapon_name.text = w.weapon_name
		hud_weapon_name.modulate = w.bullet_color
	if hud_shoot_type:
		hud_shoot_type.text = "[%s]" % w.shoot_type
		hud_shoot_type.modulate = w.bullet_color.lerp(Color.WHITE, 0.25)


func show_pickup_notification(w: WeaponData) -> void:
	if not pickup_toast or not w:
		return
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	pickup_toast.text = "ACQUIRED: %s [%s]" % [w.weapon_name, w.shoot_type]
	pickup_toast.modulate = w.bullet_color
	pickup_toast.visible = true
	pickup_toast.modulate.a = 1.0

	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(pickup_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func(): pickup_toast.visible = false)


func _on_ammo_changed(cur: int, reserve: int, is_infinite: bool) -> void:
	if hud_ammo_current:
		hud_ammo_current.text = "INF" if is_infinite else str(cur)
	if hud_ammo_reserve:
		hud_ammo_reserve.text = "" if is_infinite else "/ %d" % reserve


# --- Network Events ---
func _on_server_started() -> void:
	_set_ui_state(true)
	_update_player_hud()


func _on_connection_successful() -> void:
	_set_ui_state(true)
	_update_player_hud()


func _on_connection_failed() -> void:
	_set_ui_state(false)
	join_status_label.text = "FAILED TO CONNECT TO HOST."


func _on_server_closed() -> void:
	_set_ui_state(false)
	if _current_panel == host_panel:
		host_status_label.text = "SESSION CLOSED."
	elif _current_panel == join_panel:
		join_status_label.text = "DISCONNECTED FROM HOST."


func _update_player_hud(_id: int = 0, _info: Dictionary = {}) -> void:
	if not hud_panel:
		return
	var my_id := multiplayer.get_unique_id()
	var my_name := NetworkManager.get_player_name(my_id)
	if hud_player_name:
		hud_player_name.text = my_name
	if hud_role_badge:
		hud_role_badge.text = "ROLE: HOST" if multiplayer.is_server() else "ROLE: CLIENT"
	if hud_active_players:
		var count := NetworkManager.players.size()
		if count == 0 and multiplayer.multiplayer_peer:
			count = 1
		hud_active_players.text = "PLAYERS: %d" % count


## Controls screen visibility and strict Voxide lifecycle between Main Menu and Gameplay.
func _set_ui_state(in_game: bool) -> void:
	if background_texture:
		background_texture.visible = not in_game
	if overlay_tint:
		overlay_tint.visible = not in_game
	center_area.visible = not in_game
	hud_panel.visible = in_game

	if in_game:
		# Strictly disable Voxide completely during gameplay
		if voxide_voice:
			voxide_voice.visible = false
			voxide_voice.set_process(false)
			voxide_voice.set_physics_process(false)
			voxide_voice.push_to_talk = false
			voxide_voice.disconnect_session()
	else:
		# Re-enable Voxide for easy access on the Main Menu
		_switch_to(menu_buttons_panel)
		if voxide_voice:
			voxide_voice.visible = true
			voxide_voice.set_process(true)
			voxide_voice.set_physics_process(true)
			voxide_voice.push_to_talk = true
			if voxide_voice.auto_connect:
				voxide_voice.connect_session()
