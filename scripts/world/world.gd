class_name World
extends Node3D

## World Arena Controller
## Responsible for spawning and despawning player entities in the 3D world.
##
## Spawning Workflow:
## 1. NetworkManager emits 'player_connected'.
## 2. If this instance is the server, it creates a Player scene instance.
## 3. The instance's name is set to the peer ID string (e.g. "1" or "482910").
## 4. When added to the '$Players' container, the MultiplayerSpawner automatically
##    replicates the player to all other connected clients!

@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")

@onready var players_container: Node3D = $Players
@onready var spawn_points: Node3D = $SpawnPoints
@onready var menu_camera: Camera3D = get_node_or_null("MenuCamera")

func _ready() -> void:
	if menu_camera:
		menu_camera.current = true

	# Connect to NetworkManager signals
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_closed.connect(_on_server_closed)

	# If server already had players registered (like host), spawn them
	if multiplayer.is_server():
		for peer_id in NetworkManager.players:
			_spawn_player(peer_id)


func _on_server_started() -> void:
	_clear_all_players()


func _on_server_closed() -> void:
	_clear_all_players()
	if menu_camera:
		menu_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _clear_all_players() -> void:
	for child in players_container.get_children():
		players_container.remove_child(child)
		child.queue_free()


func _on_player_connected(peer_id: int, _info: Dictionary) -> void:
	if multiplayer.is_server():
		_spawn_player(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_despawn_player(peer_id)


## Instantiates and spawns a player node on the server.
func _spawn_player(peer_id: int) -> void:
	var node_name = str(peer_id)
	
	# If any existing node with this name exists, clean it up immediately
	if players_container.has_node(node_name):
		var old_player = players_container.get_node(node_name)
		players_container.remove_child(old_player)
		old_player.queue_free()

	var player_instance = player_scene.instantiate()
	player_instance.name = node_name
	
	# Determine spawn position
	var spawn_pos = _get_spawn_position(peer_id)
	player_instance.position = spawn_pos
	
	# Determine character model chosen by player
	var char_choice: String = NetworkManager.get_player_character(peer_id)
	player_instance.character_model = char_choice
	
	players_container.add_child(player_instance, true)
	print("World: Spawned player %d at %s" % [peer_id, str(spawn_pos)])
	
	if menu_camera:
		menu_camera.current = false


## Removes and frees a player node on the server.
func _despawn_player(peer_id: int) -> void:
	var node_name = str(peer_id)
	var player_node = players_container.get_node_or_null(node_name)
	if player_node:
		players_container.remove_child(player_node)
		player_node.queue_free()
		print("World: Despawned player %d" % peer_id)
		if peer_id == multiplayer.get_unique_id() and menu_camera:
			menu_camera.current = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Picks a spawn point or calculates an offset position
func _get_spawn_position(peer_id: int) -> Vector3:
	if spawn_points and spawn_points.get_child_count() > 0:
		var count = spawn_points.get_child_count()
		var index = (peer_id - 1) % count
		if index < 0:
			index = 0
		var sp = spawn_points.get_child(index) as Node3D
		if sp:
			return sp.global_position
	
	# Fallback spawn position spread in a circle
	var angle = float(peer_id) * 1.5
	return Vector3(cos(angle) * 4.0, 1.0, sin(angle) * 4.0)
