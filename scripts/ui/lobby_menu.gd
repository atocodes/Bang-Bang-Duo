class_name LobbyMenu
extends Control

## LobbyMenu Controller
## Provides UI controls for hosting, joining, setting player names, and handling connection feedback.

@onready var menu_panel: PanelContainer = $MenuPanel
@onready var name_input: LineEdit = $MenuPanel/VBoxContainer/NameRow/NameInput
@onready var ip_input: LineEdit = $MenuPanel/VBoxContainer/JoinSection/IPInput
@onready var port_input: LineEdit = $MenuPanel/VBoxContainer/JoinSection/PortInput
@onready var host_button: Button = $MenuPanel/VBoxContainer/HostButton
@onready var join_button: Button = $MenuPanel/VBoxContainer/JoinSection/JoinButton
@onready var status_label: Label = $MenuPanel/VBoxContainer/StatusLabel

@onready var hud_panel: Control = $HUD
@onready var hud_status: Label = $HUD/MarginContainer/VBoxContainer/HUDStatus
@onready var disconnect_button: Button = $HUD/MarginContainer/VBoxContainer/DisconnectButton

func _ready() -> void:
	# Wire UI events
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	name_input.text_changed.connect(_on_name_changed)

	# Wire NetworkManager events
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.connection_successful.connect(_on_connection_successful)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_closed.connect(_on_server_closed)
	NetworkManager.player_connected.connect(_update_player_hud)
	NetworkManager.player_disconnected.connect(func(_id): _update_player_hud(0, {}))

	# Show menu, hide HUD initially
	_set_ui_state(false)
	status_label.text = "Enter a name and host or join a session."


func _on_name_changed(new_name: String) -> void:
	if new_name.strip_edges().is_empty():
		NetworkManager.local_player_name = "Player"
	else:
		NetworkManager.local_player_name = new_name.strip_edges()


func _on_host_pressed() -> void:
	var port = port_input.text.to_int()
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT

	status_label.text = "Starting server on port %d..." % port
	var error = NetworkManager.host_game(port)
	if error != OK:
		status_label.text = "Error hosting server! (Code: %d)" % error


func _on_join_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = NetworkManager.DEFAULT_IP
	
	var port = port_input.text.to_int()
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT

	status_label.text = "Connecting to %s:%d..." % [ip, port]
	var error = NetworkManager.join_game(ip, port)
	if error != OK:
		status_label.text = "Error starting client! (Code: %d)" % error


func _on_disconnect_pressed() -> void:
	NetworkManager.disconnect_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_server_started() -> void:
	_set_ui_state(true)
	hud_status.text = "Hosting | Players: 1"


func _on_connection_successful() -> void:
	_set_ui_state(true)
	hud_status.text = "Connected as %s (ID: %d)" % [NetworkManager.local_player_name, multiplayer.get_unique_id()]


func _on_connection_failed() -> void:
	_set_ui_state(false)
	status_label.text = "Failed to connect to host."


func _on_server_closed() -> void:
	_set_ui_state(false)
	status_label.text = "Disconnected from session."


func _update_player_hud(_id: int, _info: Dictionary) -> void:
	if hud_panel.visible:
		var count = NetworkManager.players.size()
		var is_host = multiplayer.is_server()
		var role = "Host" if is_host else "Client"
		hud_status.text = "%s | Active Players: %d" % [role, count]


func _set_ui_state(in_game: bool) -> void:
	menu_panel.visible = not in_game
	hud_panel.visible = in_game
