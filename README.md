# Bang Bang Duo - 3D Modular Multiplayer Starter (Godot 4)

A clean, modular, and beginner-friendly 3D multiplayer starter template built for Godot 4 (using GDScript, Jolt Physics, and Godot's High-Level Multiplayer API).

---

## 🚀 Key Features

- **Decoupled Component Architecture**: Input, movement physics, camera, and network synchronization are split into isolated, single-responsibility components.
- **Authority-First Logic**: Local prediction for responsiveness, synchronized via `MultiplayerSynchronizer`.
- **Automatic Entity Replication**: Server-driven spawning using `MultiplayerSpawner`.
- **Plug-and-Play Lobby UI**: Ready-to-use UI supporting custom nicknames, hosting (port 8910), and joining via IP address.
- **Dynamic Player Distinction**: Automatic unique colors and billboard nametags generated per peer ID.
- **3D Test Arena**: Pre-built arena with floor, border walls, jumpable platforms, ramps, and multiple spawn points.

---

## 📂 Project Structure

```text
bang-bang-duo/
├── project.godot                     # Project configuration & input mappings
├── README.md                         # Architecture and usage documentation
│
├── scenes/
│   ├── main.tscn                     # Root scene orchestrating World and UI
│   ├── player/
│   │   └── player.tscn               # CharacterBody3D with modular components
│   ├── world/
│   │   └── world.tscn                # 3D Arena with Spawner and SpawnPoints
│   └── ui/
│       └── lobby_menu.tscn           # Host/Join Menu & In-game HUD
│
└── scripts/
    ├── network/
    │   └── network_manager.gd        # Autoload: Peer lifecycle, connections, RPCs
    ├── player/
    │   ├── player.gd                 # Root controller & authority distributor
    │   ├── player_input.gd           # Local-only input gatherer
    │   ├── player_movement.gd        # Physics, velocity, sprint, jump calculations
    │   └── player_camera.gd          # Mouse capture, pitch/yaw look & camera mount
    ├── world/
    │   └── world.gd                  # Spawns & despawns players upon connection
    └── ui/
        └── lobby_menu.gd             # UI bindings & NetworkManager signal handlers
```

---

## 🧠 Architectural Overview

### 1. Networking Lifecycle (`NetworkManager`)
- Registered as an **Autoload** (`NetworkManager`).
- Uses `ENetMultiplayerPeer` to start a server or connect as a client.
- Exposes signals for state transitions:
  - `server_started`, `server_closed`
  - `connection_successful`, `connection_failed`
  - `player_connected(peer_id, info)`, `player_disconnected(peer_id)`

```
[User clicks 'Host'] ---> NetworkManager.host_game()
                                |
                                v
                       multiplayer.peer = server
                                |
                                v
                     Emits `server_started`
```

### 2. Player Component Breakdown

```
Player (CharacterBody3D)
├── Visuals (BodyMesh + FaceIndicator)
├── Nametag (Label3D - Billboard)
├── CameraPivot (PlayerCamera)
│   └── Camera3D
├── PlayerInput (PlayerInput)
├── PlayerMovement (PlayerMovement)
└── MultiplayerSynchronizer
```

| Component | Responsibility | Authority Rule |
| :--- | :--- | :--- |
| `player.gd` | Sets up multiplayer authority from node name, applies visuals/materials, coordinates tick. | Both Host & Client |
| `player_input.gd` | Reads WASD, Jump (Space), Sprint (Shift). Disabled for non-local peers. | Local Authority Only |
| `player_movement.gd` | Pure physics calculations: acceleration, friction, gravity, jump. | Local Authority Only |
| `player_camera.gd` | Captures mouse cursor, handles vertical pitch and horizontal yaw look. | Local Authority Only |
| `MultiplayerSynchronizer` | Automatically syncs `position`, `rotation`, and `velocity` across all peers. | Synchronized |

### 3. Server-Authoritative Spawning (`World` & `MultiplayerSpawner`)
- When a peer connects, `NetworkManager` alerts `World`.
- The server instantiates `player.tscn`, sets the node name to `str(peer_id)`, and adds it to `$Players`.
- `MultiplayerSpawner` detects the child addition and automatically replicates the node across all peers.
- When `player.tscn` enters the scene tree, `player.gd` reads its own node name (`str(name).to_int()`) and assigns `set_multiplayer_authority(peer_id)`.

---

## 🎮 How to Test Multiplayer in Godot

### Method 1: Godot Editor (Run Multiple Instances)
1. Open the project in the Godot Editor.
2. At the top right of the editor, click **Debug** in the menu bar.
3. Select **Customize Run Instances...** (or **Run Multiple Instances**).
4. Set the instance count to **2** (or more).
5. Press **F5** (Run Project).
6. In Window 1: Click **Host Server**.
7. In Window 2: Click **Join Game** (IP: `127.0.0.1`, Port: `8910`).
8. Both windows will enter the 3D world with separate controlled characters!

### Method 2: Command Line (CLI)
You can launch two instances directly from your terminal:
```bash
# Terminal 1 (Host)
godot --path .

# Terminal 2 (Client)
godot --path .
```

---

## ⌨️ Default Controls

| Action | Keybinding |
| :--- | :--- |
| **Move Forward** | `W` or `Up Arrow` |
| **Move Backward** | `S` or `Down Arrow` |
| **Move Left** | `A` or `Left Arrow` |
| **Move Right** | `D` or `Right Arrow` |
| **Jump** | `Space` |
| **Sprint** | `Shift` (Hold) |
| **Look Around** | `Mouse Motion` |
| **Toggle Mouse Capture** | `Escape` |

---

## 🛠️ How to Extend this Framework

### Adding Weapons / Projectiles
1. Create a `PlayerCombat` component and add it to `player.tscn`.
2. When the local player clicks left mouse button (`Input.is_action_just_pressed("fire")`), call an `@rpc("any_peer", "call_local", "reliable")` function to notify the server.
3. The server validates the shot and spawns the projectile in the world via a `MultiplayerSpawner`.

### Adding Player Health & Respawn
1. In `player.gd`, add `@export var health: int = 100`.
2. Add `health` to the `MultiplayerSynchronizer` properties list.
3. When health reaches `0`, the server resets the player's position to `_get_spawn_position(peer_id)`.

### Adding Animations
1. Attach an `AnimationPlayer` or `AnimationTree` under `Visuals`.
2. Synchronize `velocity` or animation state enum via `MultiplayerSynchronizer`.
3. In `_process()` on remote instances, blend animations according to `velocity.length()`.
