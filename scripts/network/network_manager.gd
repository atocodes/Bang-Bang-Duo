extends Node

## NetworkManager (Autoload / Singleton)
## Handles high-level networking, peer connection lifecycle, and player tracking.
##
## How it works:
## 1. Uses ENetMultiplayerPeer to create a server (Host) or connect to one (Join).
## 2. Emits clean signals that the UI and World scenes can listen to.
## 3. Keeps a dictionary of connected players with their metadata (id, name, etc.).

signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_started()
signal server_closed()
signal connection_successful()
signal connection_failed()

const DEFAULT_PORT: int = 8910
const DEFAULT_MAX_CLIENTS: int = 16
const DEFAULT_IP: String = "127.0.0.1"

# Dictionary storing connected player data: { peer_id: { "name": String, ... } }
var players: Dictionary = {}

# Local player's profile info
var local_player_name: String = "Player"
var local_player_character: String = "Weyzero Codes"

## Returns the resolved player display name
func get_player_name(id: int) -> String:
	if players.has(id):
		var n := str(players[id].get("name", "")).strip_edges()
		if not n.is_empty():
			return n
	if id == multiplayer.get_unique_id() or (id == 1 and multiplayer.is_server()):
		if not local_player_name.is_empty():
			return local_player_name
	return "Player %d" % id


## Returns the resolved player chosen character model
func get_player_character(id: int) -> String:
	if players.has(id):
		var c := str(players[id].get("character", "")).strip_edges()
		if not c.is_empty():
			return c
	if id == multiplayer.get_unique_id() or (id == 1 and multiplayer.is_server()):
		return local_player_character
	return "Weyzero Codes"

func _ready() -> void:
	# Connect to Godot's built-in multiplayer API signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Starts a multiplayer server on the specified port.
func host_game(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_clients)
	
	if error != OK:
		push_error("NetworkManager: Failed to create server on port %d! Error code: %d" % [port, error])
		return error
	
	multiplayer.multiplayer_peer = peer
	
	# Register host (ID = 1 in Godot multiplayer)
	players[1] = {
		"id": 1,
		"name": local_player_name,
		"character": local_player_character
	}
	
	print("NetworkManager: Server hosted on port %d (Host ID: 1)" % port)
	server_started.emit()
	player_connected.emit(1, players[1])
	return OK


## Connects to an existing multiplayer server.
func join_game(ip: String = DEFAULT_IP, port: int = DEFAULT_PORT) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	
	if error != OK:
		push_error("NetworkManager: Failed to create client connecting to %s:%d! Error code: %d" % [ip, port, error])
		return error
	
	multiplayer.multiplayer_peer = peer
	print("NetworkManager: Connecting to %s:%d..." % [ip, port])
	return OK


## Closes the network connection and resets player state.
func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	players.clear()
	print("NetworkManager: Disconnected.")
	server_closed.emit()


# ------------------------------------------------------------------------------
# Built-in Multiplayer Callbacks
# ------------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer connected with ID: %d" % id)
	# If we are the server, notify the new peer of existing players and request their info
	if multiplayer.is_server():
		# Send existing players list to the newly connected peer
		_sync_players_to_client.rpc_id(id, players)


func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer disconnected with ID: %d" % id)
	if players.has(id):
		players.erase(id)
	player_disconnected.emit(id)


func _on_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	print("NetworkManager: Successfully connected to server! My ID: %d" % my_id)
	
	# Send our info to the server
	_register_player.rpc_id(1, my_id, {
		"id": my_id,
		"name": local_player_name,
		"character": local_player_character
	})
	connection_successful.emit()


func _on_connection_failed() -> void:
	push_warning("NetworkManager: Connection to server failed!")
	disconnect_game()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	push_warning("NetworkManager: Server disconnected!")
	disconnect_game()


# ------------------------------------------------------------------------------
# RPCs for Player Registration
# ------------------------------------------------------------------------------

## Server receives player info from a newly connected client and broadcasts it.
@rpc("any_peer", "call_local", "reliable")
func _register_player(id: int, info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	
	players[id] = info
	print("NetworkManager: Registered player %s (ID: %d)" % [info.get("name", "Unknown"), id])
	
	# Broadcast new player to all connected clients
	_add_player_entry.rpc(id, info)


## Client receives single player entry to add to local cache.
@rpc("authority", "call_local", "reliable")
func _add_player_entry(id: int, info: Dictionary) -> void:
	players[id] = info
	player_connected.emit(id, info)


## Client receives full list of existing players upon initial connection.
@rpc("authority", "call_remote", "reliable")
func _sync_players_to_client(all_players: Dictionary) -> void:
	for id in all_players:
		players[id] = all_players[id]
		player_connected.emit(id, all_players[id])
