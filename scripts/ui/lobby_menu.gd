class_name LobbyMenu
extends Control

## LobbyMenu Controller
## Clean, modern UI for hosting, joining, setting player profiles, and HUD status feedback.

@onready var menu_panel: PanelContainer = $MenuPanel
@onready var backdrop: ColorRect = $Backdrop
@onready var name_input: LineEdit = $MenuPanel/VBoxContainer/ProfileSection/NameInput
@onready var tab_join_btn: Button = $MenuPanel/VBoxContainer/TabContainer/TabJoinBtn
@onready var tab_host_btn: Button = $MenuPanel/VBoxContainer/TabContainer/TabHostBtn
@onready var join_section: VBoxContainer = $MenuPanel/VBoxContainer/ModeStack/JoinSection
@onready var host_section: VBoxContainer = $MenuPanel/VBoxContainer/ModeStack/HostSection

@onready var ip_input: LineEdit = $MenuPanel/VBoxContainer/ModeStack/JoinSection/AddressRow/IPCol/IPInput
@onready var join_port_input: LineEdit = $MenuPanel/VBoxContainer/ModeStack/JoinSection/AddressRow/PortCol/PortInput
@onready var host_port_input: LineEdit = $MenuPanel/VBoxContainer/ModeStack/HostSection/PortRow/PortInput
@onready var join_button: Button = $MenuPanel/VBoxContainer/ModeStack/JoinSection/JoinButton
@onready var host_button: Button = $MenuPanel/VBoxContainer/ModeStack/HostSection/HostButton

@onready var status_container: PanelContainer = $MenuPanel/VBoxContainer/StatusContainer
@onready var status_dot: ColorRect = $MenuPanel/VBoxContainer/StatusContainer/StatusHBox/StatusDot
@onready var status_label: Label = $MenuPanel/VBoxContainer/StatusContainer/StatusHBox/StatusLabel

@onready var hud_panel: Control = $HUD
@onready var hud_status: Label = $HUD/TopBar/MarginContainer/HBoxContainer/HUDStatus
@onready var hud_players_badge: Label = $HUD/TopBar/MarginContainer/HBoxContainer/PlayersBadge
@onready var disconnect_button: Button = $HUD/TopBar/MarginContainer/HBoxContainer/DisconnectButton

enum Mode { JOIN, HOST }
var current_mode: Mode = Mode.JOIN

# Colors for status indicators
const COLOR_IDLE: Color = Color(0.3, 0.8, 0.4, 1.0)      # Green
const COLOR_CONNECTING: Color = Color(0.95, 0.75, 0.2, 1.0) # Amber
const COLOR_ERROR: Color = Color(0.95, 0.3, 0.35, 1.0)     # Red
const COLOR_INFO: Color = Color(0.3, 0.7, 1.0, 1.0)        # Cyan

var status_tween: Tween

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

	# Wire Host Actions
	copy_ip_button.pressed.connect(_on_copy_ip_pressed)
	start_host_button.pressed.connect(_on_start_host_pressed)

	# Wire Join Actions
	join_submit_button.pressed.connect(_on_join_submit_pressed)

	# Wire HUD Actions
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	name_input.text_changed.connect(_on_name_changed)
	
	tab_join_btn.pressed.connect(func(): _switch_mode(Mode.JOIN))
	tab_host_btn.pressed.connect(func(): _switch_mode(Mode.HOST))
	
	# Enter key triggers action in LineEdits
	name_input.text_submitted.connect(func(_text): _trigger_primary_action())
	ip_input.text_submitted.connect(func(_text): _on_join_pressed())
	join_port_input.text_submitted.connect(func(_text): _on_join_pressed())
	host_port_input.text_submitted.connect(func(_text): _on_host_pressed())

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
	_switch_mode(Mode.JOIN, false)
	_set_status("Ready to play. Choose a mode below.", COLOR_IDLE)
	
	# Play entrance animation
	_animate_entrance()


func _switch_mode(mode: Mode, animate: bool = true) -> void:
	current_mode = mode
	var is_join = (mode == Mode.JOIN)
	
	join_section.visible = is_join
	host_section.visible = not is_join
	
	# Update tab buttons styling
	tab_join_btn.set_meta("active", is_join)
	tab_host_btn.set_meta("active", not is_join)
	_update_tab_button_style(tab_join_btn, is_join)
	_update_tab_button_style(tab_host_btn, not is_join)
	
	if animate:
		var target_section = join_section if is_join else host_section
		target_section.modulate.a = 0.0
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(target_section, "modulate:a", 1.0, 0.18)


func _update_tab_button_style(button: Button, is_active: bool) -> void:
	if is_active:
		button.theme_type_variation = "ActiveTabButton"
	else:
		button.theme_type_variation = "InactiveTabButton"


func _trigger_primary_action() -> void:
	if current_mode == Mode.JOIN:
		_on_join_pressed()
	else:
		_on_host_pressed()


func _on_name_changed(new_name: String) -> void:
	if new_name.strip_edges().is_empty():
		NetworkManager.local_player_name = "Player"
	else:
		NetworkManager.local_player_name = new_name.strip_edges()


func _on_host_pressed() -> void:
	var port = host_port_input.text.to_int()
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT

	_set_status("Starting server on port %d..." % port, COLOR_CONNECTING, true)
	var error = NetworkManager.host_game(port)
	if error != OK:
		_set_status("Error hosting server! (Code: %d)" % error, COLOR_ERROR)


func _on_join_submit_pressed() -> void:
	var ip := join_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = NetworkManager.DEFAULT_IP
	
	var port = join_port_input.text.to_int()
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT

	_set_status("Connecting to %s:%d..." % [ip, port], COLOR_CONNECTING, true)
	var error = NetworkManager.join_game(ip, port)
	if error != OK:
		_set_status("Error starting client! (Code: %d)" % error, COLOR_ERROR)


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

	voxide_voice.register_tool(host_tool)
	voxide_voice.register_tool(join_tool)
	voxide_voice.register_tool(name_tool)


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


func _on_ammo_changed(cur: int, reserve: int, is_infinite: bool) -> void:
	if hud_ammo_current:
		hud_ammo_current.text = "INF" if is_infinite else str(cur)
	if hud_ammo_reserve:
		hud_ammo_reserve.text = "" if is_infinite else "/ %d" % reserve


# --- Network Events ---
func _on_server_started() -> void:
	_set_ui_state(true)
	hud_status.text = "HOSTING SERVER"
	_update_player_count_badge(1)


func _on_connection_successful() -> void:
	_set_ui_state(true)
	hud_status.text = "CONNECTED (%s)" % NetworkManager.local_player_name
	_update_player_count_badge(NetworkManager.players.size())


func _on_connection_failed() -> void:
	_set_ui_state(false)
	_set_status("Failed to connect to host. Check IP & port.", COLOR_ERROR)


func _on_server_closed() -> void:
	_set_ui_state(false)
	_set_status("Disconnected from session.", COLOR_INFO)


func _update_player_hud(_id: int, _info: Dictionary) -> void:
	if hud_panel.visible:
		var count = NetworkManager.players.size()
		var is_host = multiplayer.is_server()
		var role = "HOST" if is_host else "CLIENT"
		hud_status.text = "%s • %s" % [role, NetworkManager.local_player_name]
		_update_player_count_badge(count)


func _update_player_count_badge(count: int) -> void:
	hud_players_badge.text = "● %d %s" % [count, "Player" if count == 1 else "Players"]


func _set_status(msg: String, dot_color: Color, pulse: bool = false) -> void:
	status_label.text = msg
	status_dot.color = dot_color
	
	if status_tween and status_tween.is_valid():
		status_tween.kill()
		
	if pulse:
		status_tween = create_tween().set_loops()
		status_tween.tween_property(status_dot, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
		status_tween.tween_property(status_dot, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		status_dot.modulate.a = 1.0


func _set_ui_state(in_game: bool) -> void:
	menu_panel.visible = not in_game
	backdrop.visible = not in_game
	hud_panel.visible = in_game


func _animate_entrance() -> void:
	menu_panel.modulate.a = 0.0
	menu_panel.scale = Vector2(0.96, 0.96)
	menu_panel.pivot_offset = menu_panel.size / 2.0
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.35)
	tween.tween_property(menu_panel, "scale", Vector2.ONE, 0.35)
