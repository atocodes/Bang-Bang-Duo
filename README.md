# 💥 Bang Bang Duo — 3D Multiplayer Arena Shooter (Godot 4)

[![Godot Engine](https://img.shields.io/badge/Godot-4.7+-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Physics](https://img.shields.io/badge/Physics-Jolt_3D-FF6B6B)](https://github.com/godot-jolt/godot-jolt)
[![Networking](https://img.shields.io/badge/Multiplayer-ENet_RPC-2EA44F)](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
[![Voice AI](https://img.shields.io/badge/AI-Voxide_Voice-8A2BE2)](https://github.com/atocodes/voxide)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Bang Bang Duo** is a fast-paced, modular 3D multiplayer arena shooter built with **Godot 4**, **GDScript**, **Jolt 3D Physics**, and Godot's **High-Level Multiplayer API**. Featuring responsive third-person combat, multi-weapon arsenals, server-authoritative replication, and an integrated **Voxide Voice AI Assistant** directly in the lobby.

---

## 🎮 Game Overview

In **Bang Bang Duo**, players jump into a vibrant 3D arena for fast-paced combat. The game combines responsive movement mechanics with a modular weapon system and seamless networking:

- **Third-Person Tactical Perspective**: Smooth over-the-shoulder camera with mouse look, pitch clamping, and collision-aware spring arm.
- **Dynamic 3D Crosshair Aiming**: Weapons automatically orient toward the exact world point targeted by your crosshair with responsive weapon recoil.
- **Modular Weapon Arsenal**: Switch between different weapons on the fly, each with custom fire rates, velocities, damage, color profiles, and audio signatures.
- **Glowing Projectiles & VFX**: Real-time high-speed projectiles with dynamic lighting, trajectory collision detection, and glowing impact spark effects.
- **Voice AI Enabled Lobby**: Hands-free lobby management, matchmaking commands, and player configuration powered by the **Voxide Voice Assistant**.
- **Server-Authoritative Networking**: Clean multiplayer replication using `MultiplayerSpawner` and `MultiplayerSynchronizer`.

---

## 🎙️ Voxide Voice Assistant (Lobby AI)

The lobby features a full-fledged, real-time conversational **Voice AI Assistant** powered by [Voxide](https://github.com/atocodes/voxide). Players can configure their profile, host servers, and join games entirely hands-free using natural spoken commands.

```
       ┌───────────────────────────────┐
       │   Player Speaks into Mic      │
       └──────────────┬────────────────┘
                      ▼
       ┌───────────────────────────────┐
       │     Voxide Voice Runtime      │
       └──────────────┬────────────────┘
                      ▼
         ┌────────────────────────────┐
         │ Tool Dispatch & Execution  │
         ├────────────────────────────┤
         │ • host_game(port)          │
         │ • join_game(ip, port)      │
         │ • set_player_name(name)    │
         └────────────┬───────────────┘
                      ▼
       ┌───────────────────────────────┐
       │   Lobby Menu & NetworkManager │
       └───────────────────────────────┘
```

### 🗣️ Supported Voice Commands & Tools

| Voice Tool | Spoken Example | Action Executed |
| :--- | :--- | :--- |
| `host_game` | *"Host a game on port 8910"* | Starts server hosting on specified port and transitions into arena. |
| `join_game` | *"Join server at 127.0.0.1 on port 8910"* | Connects client to target server IP/port. |
| `set_player_name` | *"Change my name to CyberViper"* | Updates local nickname, UI input, and synced 3D billboard nametag. |
| **Context Q&A** | *"What is my name?"* / *"Who is connected?"* | State provider inspects live lobby/network status and responds via voice. |

### 🛡️ Smart Focus Safety & Push-to-Talk
- **Smart Text Focus Protection**: When the user clicks into any `LineEdit` input field (e.g. typing an IP or nickname), voice capture automatically pauses to prevent background speech or typing noises from firing unintended voice commands.
- **Push-to-Talk Mode**: Configurable Push-to-Talk integration with visual audio pulse indicators and connection status badges in the lobby menu.

### 🔑 Environment Setup
The Voice AI uses your API key configured in `.env` via the `DotEnv` autoload:
```ini
# .env file in project root
VOXIDE_API_KEY="your-voxide-api-key"
# or
GEMINI_API_KEY="your-gemini-api-key"
```

---

## 🔫 Weapon Arsenal

The game features an extensible, resource-driven weapon architecture (`WeaponData`):

| Weapon | Type | Clip / Reserve | Fire Rate | Speed | Damage | Plasma Visual |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Pulse Blaster** *(Slot 1)* | Balanced Energy Pistol | `30 / 120` | `0.15s` | `95 m/s` | `25` | ⚡ Cyan Core Glow |
| **Heavy Cannon** *(Slot 2)* | High-Impact Energy Slug | `8 / 32` | `0.45s` | `120 m/s` | `65` | 🔥 Amber Blast |
| **Plasma Rifle** *(Slot 3)* | Rapid Auto-Fire Rifle | `45 / 180` | `0.09s` | `110 m/s` | `18` | 🟢 Emerald Plasma |

---

## ⌨️ Controls & Keybindings

| Action | Primary Input | Secondary / Alternative |
| :--- | :--- | :--- |
| **Move Forward** | `W` | `Up Arrow` |
| **Move Backward** | `S` | `Down Arrow` |
| **Move Left** | `A` | `Left Arrow` |
| **Move Right** | `D` | `Right Arrow` |
| **Sprint** | `Shift` *(Hold)* | — |
| **Jump** | `Space` | — |
| **Aim & Look** | `Mouse Motion` | — |
| **Fire Weapon** | `Left Mouse Button` | — |
| **Reload Weapon** | `R` | — |
| **Select Pulse Blaster** | `1` | — |
| **Select Heavy Cannon** | `2` | — |
| **Select Plasma Rifle** | `3` | — |
| **Cycle Weapon Up/Down** | `Mouse Wheel Up / Down` | — |
| **Toggle Mouse Capture** | `Escape` | — |

---

## 📂 Project Structure

```text
bang-bang-duo/
├── project.godot                     # Project configuration, inputs & autoloads
├── README.md                         # Game documentation & architecture breakdown
│
├── scenes/
│   ├── main.tscn                     # Root scene managing World and UI lifecycle
│   ├── player/
│   │   └── player.tscn               # CharacterBody3D with modular components
│   ├── projectile/
│   │   └── bullet.tscn               # High-speed projectile with light & impact FX
│   ├── world/
│   │   └── world.tscn                # 3D Arena with Spawner, lighting & spawn points
│   └── ui/
│       ├── lobby_menu.tscn           # Host / Join menu, Voice UI & In-game HUD
│       └── lobby_theme.tres          # Polished UI theme resources
│
├── scripts/
│   ├── network/
│   │   └── network_manager.gd        # Autoload: Peer lifecycle, connections & RPCs
│   ├── player/
│   │   ├── player.gd                 # Root controller & authority distributor
│   │   ├── player_input.gd           # Local-only input gatherer (WASD, sprint, fire)
│   │   ├── player_movement.gd        # Physics, velocity, friction & jump math
│   │   ├── player_camera.gd          # Mouse look, spring arm & 3D aim projection
│   │   ├── player_weapon_manager.gd  # Weapon inventory, ammo, cooldowns & reload
│   │   └── bullet.gd                 # Projectile trajectory & collision spark FX
│   ├── weapons/
│   │   └── weapon_data.gd            # Resource definition for custom weapons
│   ├── world/
│   │   └── world.gd                  # Server-side player spawning & despawning
│   └── ui/
│       └── lobby_menu.gd             # Menu logic, Voxide integration & HUD updates
│
├── addons/
│   ├── dotenv/                       # Environment variable loader (.env)
│   └── voxide/                       # Voxide Voice AI Assistant runtime & nodes
│
└── assets/
    └── kenney_ui/                    # Audio SFX and graphical assets
```

---

## 🧠 System Architecture

### 1. Multiplayer Networking Flow
- **Autoload Singleton (`NetworkManager`)**: Manages `ENetMultiplayerPeer` instances, host registration on port `8910`, and peer synchronization.
- **Replication**:
  - `MultiplayerSpawner` automatically instantiates `player.tscn` on all connected clients when spawned by the server.
  - `MultiplayerSynchronizer` syncs `position`, `rotation`, and `velocity` across peers in real-time.
- **Dynamic Identity**: Players are assigned distinct procedural HSV avatar colors and 3D billboard nametags synced from the lobby.

```
[Client] Click 'Host' or 'Join' (or Speak Command)
       │
       ▼
[NetworkManager] Sets ENetMultiplayerPeer
       │
       ▼
[World] Server instantiates 'player.tscn' under $Players
       │
       ▼
[MultiplayerSpawner] Replicates character across all connected peers
       │
       ▼
[Player] Authority assigned -> Local player handles inputs & camera
```

### 2. Modular Player Component Hierarchy
```
Player (CharacterBody3D)
├── Visuals (BodyMesh + FaceIndicator)
│   └── WeaponMount (GunBody + Barrel + EnergyCore + Muzzle)
├── Nametag (Label3D - Billboard)
├── CameraPivot (PlayerCamera)
│   └── SpringArm3D -> Camera3D
├── PlayerInput (PlayerInput)
├── PlayerMovement (PlayerMovement)
├── WeaponManager (PlayerWeaponManager)
└── MultiplayerSynchronizer
```

---

## 🚀 How to Play & Test Multiplayer

### Option 1: Multi-Instance Testing in Godot Editor
1. Open the project in the **Godot 4 Editor**.
2. Go to **Debug** in the top menu bar.
3. Select **Customize Run Instances...** and set the count to **2** (or more).
4. Press **F5** to start.
5. In **Window 1**: Enter a nickname and click **Host Game** (Port `8910`) or speak *"Host game on port 8910"*.
6. In **Window 2**: Enter a nickname and click **Join Game** (IP: `127.0.0.1`, Port: `8910`) or speak *"Join server at 127.0.0.1"*.
7. Both players will spawn in the arena with unique player colors and nametags!

### Option 2: Running via Terminal / CLI
```bash
# Terminal 1: Launch Host Instance
godot --path .

# Terminal 2: Launch Client Instance
godot --path .
```

---

## 🛠️ Extending the Game

### Adding a New Weapon
Create a new `WeaponData` resource or instantiate one programmatically:
```gdscript
var sniper := WeaponData.new()
sniper.weapon_id = "sniper_rifle"
sniper.weapon_name = "HEAVY SNIPER"
sniper.max_ammo = 5
sniper.reserve_ammo = 20
sniper.fire_rate = 0.9
sniper.bullet_speed = 220.0
sniper.damage = 100.0
sniper.bullet_color = Color(1.0, 0.2, 0.2) # Red Plasma
sniper.sfx_pitch = 0.7

weapon_manager.weapons.append(sniper)
```

### Registering New Voice AI Tools
You can easily expand the voice assistant by adding new `VoxideTool` instances in `lobby_menu.gd`:
```gdscript
var map_tool := VoxideTool.new("change_map", "Change the active arena map.")
map_tool.parameters = {
    "map_name": { "type": "string", "description": "Name of the arena.", "required": true }
}
map_tool.handler = func(args: Dictionary) -> Dictionary:
    var map: String = args.get("map_name", "cyber_arena")
    # Execute map change logic...
    return { "status": "success", "map": map }

voxide_voice.register_tool(map_tool)
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
