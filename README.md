# 💥 Bang Bang Duo — 3D Multiplayer Arena Shooter (Godot 4)

[![Version](https://img.shields.io/badge/Version-0.5.0-blue.svg)](CHANGELOG.md)
[![Godot Engine](https://img.shields.io/badge/Godot-4.7+-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Physics](https://img.shields.io/badge/Physics-Jolt_3D-FF6B6B)](https://github.com/godot-jolt/godot-jolt)
[![Networking](https://img.shields.io/badge/Multiplayer-ENet_RPC-2EA44F)](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
[![Voice AI](https://img.shields.io/badge/AI-Voxide_Voice-8A2BE2)](https://github.com/atocodes/voxide)
[![Changelog](https://img.shields.io/badge/Changelog-Keep_a_Changelog-orange.svg)](CHANGELOG.md)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Bang Bang Duo** is a fast-paced, modular 3D multiplayer arena shooter built with **Godot 4**, **GDScript**, **Jolt 3D Physics**, and Godot's **High-Level Multiplayer API**. Featuring responsive third-person combat, selectable animated 3D characters, tactical in-world weapon pickups, timed reloads, synchronized player health & damage physics, server-authoritative replication, an educational live **Code Logic Visualizer Dock**, and an integrated **Voxide Voice AI Assistant** directly in the lobby.

---

## 🎮 Game Overview

In **Bang Bang Duo**, players jump into a sci-fi arena for fast-paced, tactical combat. The game combines responsive movement mechanics with a scavenger weapon pickup system, physical damage feedback, and seamless networking:

- **Third-Person Tactical Perspective**: Smooth over-the-shoulder camera with mouse look, pitch clamping, and collision-aware spring arm.
- **Selectable 3D Characters & Animations**: Play as **Weyzero Codes** or **Ato Codes** with full locomotion and combat animations (Idle, Walk, Sprint, Jump, Aim, Fire, Death) and procedural `SkeletonIK3D` left-hand grip alignment.
- **Unarmed Spawns & Scavenging Loop**: Players spawn unarmed and must scavenge the arena to pick up weapons from floating, glowing pickup stations.
- **Networked Health, Damage & Knockback**: Replicated damage system with physical impact knockback impulses, red-flash visual feedback, spark particle bursts, overhead 3D health meters, and instant server-authoritative arena respawns.
- **Dynamic 3D Crosshair Aiming**: Weapons automatically orient toward the exact world point targeted by your crosshair with responsive weapon recoil.
- **Kenney Blaster Kit Arsenal**: 5 distinct modular weapons with unique ballistic behaviors, fire rates, spread, damage, plasma FX, and timed reload cycles.
- **Interactive 3D Weapon Pickups**: Rotating 3D blaster models with sinusoidal bobbing, glowing omni-lights matching weapon plasma, 3D billboard labels, and network-synchronized respawn timers.
- **Tactical Timed Reloading**: Configurable reload durations, automatic reload triggers on magazine depletion, and intelligent reload cancellation on weapon switching.
- **Educational Code Logic Visualizer**: Live GDScript engine deconstructor dock (`F1`) displaying real-time kinematics, raycast ballistics, condition checks, and netcode breakdown.
- **Voice AI Enabled Lobby**: Hands-free lobby management, matchmaking commands, and player configuration powered by the **Voxide Voice Assistant**.
- **Server-Authoritative Networking**: Clean multiplayer replication using `MultiplayerSpawner` and `MultiplayerSynchronizer`.

---

## 🥋 Character Models & Animation System

Players can select their preferred operative directly from the main lobby menu. Both models feature synchronized networked appearances and complete animation sets:

| Character Model | Visual Profile | Animation Features |
| :--- | :--- | :--- |
| **Weyzero Codes** | Sleek Cyber Operative | Full State Machine (Idle, Walk, Run, Jump, Aiming, Firing, Gunplay, Death) |
| **Ato Codes** | Heavy Tactical Enforcer | Full State Machine with synchronized animations and custom skin textures |

### Procedural Left-Hand Inverse Kinematics (IK)
To ensure realistic weapon handling across different blaster geometries, characters utilize a procedural `SkeletonIK3D` (`LeftHandIK`) that dynamically solves the left hand's target position to match each weapon's custom forward grip offset.

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
- **Smart Text Focus Protection**: When clicking into any `LineEdit` input field (e.g. typing an IP or nickname), voice capture automatically pauses to prevent typing sounds from triggering unintended voice commands.
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

## 🔫 Weapon Arsenal & Pickups

### 1. Modular Blaster Arsenal
The game features 5 distinct weapons built on the extensible `WeaponData` resource architecture:

| Weapon | Shoot Type | Clip / Reserve | Fire Rate | Reload | Speed | Damage | Plasma Visual |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Assault Rifle** *(Slot 1)* | Full Auto | `30 / 120` | `0.14s` | `1.6s` | `115 m/s` | `25` | ⚡ Cyan Core Glow |
| **Machine Gun** *(Slot 2)* | Full Auto | `60 / 240` | `0.08s` | `2.2s` | `105 m/s` | `14` | 🔶 Amber Plasma |
| **Burst Rifle** *(Slot 3)* | 3-Round Burst | `30 / 90` | `0.38s` | `1.8s` | `125 m/s` | `22` | 🟢 Emerald Plasma |
| **Sniper Rifle** *(Slot 4)* | Semi-Auto | `10 / 40` | `0.55s` | `2.0s` | `180 m/s` | `60` | 🟣 Magenta Plasma |
| **Heavy Sniper** *(Slot 5)* | Bolt Action | `5 / 20` | `1.15s` | `2.5s` | `220 m/s` | `95` | 🔴 Crimson Blast |

### 2. In-World Weapon Pickups
- **Interactive Visuals**: Floating 3D weapon models rotate slowly with sinusoidal bobbing.
- **Dynamic Lighting**: Omni-lights match the bullet plasma color of the weapon with high-visibility billboard text labels displaying weapon name and firing mode.
- **Multiplayer Respawn Sync**: Server-authoritative pickup collection hides the pickup, plays audio SFX, displays an in-game HUD toast, and triggers a synced respawn timer (default: `12.0s`).
- **Inventory Refill**: Walking over a pickup for a weapon you already possess tops up its magazine and replenishes reserve ammunition.

### 3. Tactical Timed Reload Mechanics
- **Timed Delays**: Reloading requires a realistic delay (`reload_time`), displayed on the HUD (`RELOADING... [Xs]`).
- **Automatic Reload**: Depleting a magazine automatically triggers a reload if reserve ammunition is available.
- **Switch Interruption**: Switching weapons while reloading cancels the reload immediately without refilling ammo. Switching back to an empty magazine weapon cleanly restarts the reload timer.

---

## ❤️ Health, Damage & Arena Respawn System

The combat loop features fully replicated vitality management and physical impact responses:

- **100 HP Health Pool**: Both local and remote peers track current and maximum health.
- **Overhead 3D Billboard (`HealthTag`)**: Dynamically floats above each character, displaying real-time HP values with dynamic color coding:
  - 🟢 **Healthy** (>55% HP): `#34d399` Emerald
  - 🟡 **Wounded** (25%–55% HP): `#fbbf24` Amber
  - 🔴 **Critical** (<=25% HP): `#f87171` Crimson
- **Damage & Physical Knockback**:
  - Direct raycast hits invoke `take_damage(amount, attacker_id, dir, pos)` with weapon-calibrated damage values.
  - Generates directional velocity impulses upon impact to push targets back.
  - Mesh flash red feedback and dynamic 3D spark particle bursts at the contact point.
- **Server-Authoritative Respawn (`respawn_rpc`)**:
  - Depleting health to 0 triggers instant network-synchronized respawn at arena spawn points with full health restoration.

---

## 🔬 Live Code Logic Visualizer & Engine Deconstructor

Press **`F1`** at any time during gameplay to toggle the **Live Code Logic Dock**. This transparent overlay streams real-time execution events, physics formulas, and condition evaluations under the hood:

```
[00:14.280] ⟨MATH:LERP:KINEMATICS⟩ v = move_toward(dir*spd, a*dt) ➜ vel:(4.2, 0.0, -5.8)
[00:14.340] ⟨EXEC:BALLISTICS⟩ _spawn_bullet() ➜ speed:115.0m/s | dmg:25.0 | aim:(12.4, 1.2, -8.0)
[00:14.352] ⟨COLLISION:RAYCAST⟩ INTERSECT QUERY ➜ hit:Player(2) ➜ dmg:25
[00:14.354] ⟨EXEC:PHYSICS⟩ apply_knockback() ➜ impulse:(0.0, 1.8, 8.8) | vel:(0.0, 1.8, 8.8)
[00:14.355] ⟨COND:COMBAT⟩ take_damage(25.0, attacker:1) [TRUE] ➜ hp:100->75 [ALIVE]
```

- **Ring-Buffer Event Bus (`CodeLogicBus`)**: High-throughput memory-safe ring buffer storing formatted entries with timestamp and color-coded tags.
- **Under-the-Hood Educational Tracing**: Deconstructs math, kinematics, and networking state transitions in real time.
- **Zero Runtime Overhead**: Toggling the visualizer off completely short-circuits tracing to guarantee 0 FPS loss in performance-critical gameplay.

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
| **Select Weapon Slot 1–5** | `1`, `2`, `3`, `4`, `5` | — |
| **Cycle Weapon Up/Down** | `Mouse Wheel Up / Down` | — |
| **Toggle Code Logic Dock** | `F1` | — |
| **Toggle Mouse Capture** | `Escape` | — |

---

## 📂 Project Structure

```text
bang-bang-duo/
├── CHANGELOG.md                      # Detailed version history and release notes
├── project.godot                     # Project configuration, inputs & autoloads
├── README.md                         # Game documentation & architecture breakdown
│
├── scenes/
│   ├── main.tscn                     # Root scene managing World and UI lifecycle
│   ├── player/
│   │   └── player.tscn               # CharacterBody3D with animations, IK & weapons
│   ├── projectile/
│   │   └── bullet.tscn               # High-speed projectile with light & impact FX
│   ├── weapons/
│   │   └── weapon_pickup.tscn        # Interactive floating 3D weapon pickup
│   ├── world/
│   │   ├── map_geometry.tscn         # Modular arena geometry (corridors, rooms, gates)
│   │   └── world.tscn                # 3D Arena with Spawner, lighting & weapon stations
│   └── ui/
│       ├── code_logic_dock.tscn      # Live Code Logic Visualizer developer dock
│       ├── lobby_menu.tscn           # Host / Join menu, Voice UI & In-game HUD
│       └── lobby_theme.tres          # Polished UI theme resources
│
├── scripts/
│   ├── debug/
│   │   └── code_logic_bus.gd         # Autoload: High-speed ring-buffer event stream
│   ├── helper/
│   │   └── ip_helper.gd              # Local IP detection & clipboard utility
│   ├── network/
│   │   └── network_manager.gd        # Autoload: Peer lifecycle, connections & RPCs
│   ├── player/
│   │   ├── player.gd                 # Root controller, model selection & authority
│   │   ├── player_input.gd           # Local-only input gatherer (WASD, sprint, fire)
│   │   ├── player_movement.gd        # Physics, velocity, friction & jump math
│   │   ├── player_camera.gd          # Mouse look, spring arm & 3D aim projection
│   │   ├── player_weapon_manager.gd  # Inventory, ammo, pickups, cooldowns & reload
│   │   └── bullet.gd                 # Projectile trajectory & collision spark FX
│   ├── weapons/
│   │   ├── weapon_data.gd            # Resource definition for custom weapons
│   │   └── weapon_pickup.gd          # Pickup bobbing, lighting, interaction & respawn
│   ├── world/
│   │   └── world.gd                  # Server-side player spawning & despawning
│   └── ui/
│       ├── code_logic_dock.gd        # Developer dock UI & fading modulate animations
│       └── lobby_menu.gd             # Menu logic, Voxide integration & HUD updates
│
├── tests/
│   ├── test_code_logic_visualizer.gd # Headless unit tests for CodeLogicBus and Dock
│   ├── test_runner.gd                # Automated test runner for game systems
│   └── test_runner.tscn              # Test harness scene
│
├── addons/
│   ├── dotenv/                       # Environment variable loader (.env)
│   └── voxide/                       # Voxide Voice AI Assistant runtime & nodes
│
└── assets/
    ├── font/                         # PhantomGuardiansCoolGamingBold arcade typography
    ├── kenney_blaster_kit/           # 3D weapon models (Blasters, Rifles, Snipers)
    ├── kenney_ui/                    # Audio SFX and graphical assets
    ├── map/                          # Modular corridor, room, and gate 3D models
    └── player_models/                # Weyzero Codes & Ato Codes 3D models and anims
```

---

## 🧠 System Architecture

### 1. Multiplayer Networking Flow
- **Autoload Singleton (`NetworkManager`)**: Manages `ENetMultiplayerPeer` instances, host registration on port `8910`, and peer synchronization.
- **Replication**:
  - `MultiplayerSpawner` automatically instantiates `player.tscn` on all connected clients when spawned by the server.
  - `MultiplayerSynchronizer` syncs `position`, `rotation`, and `velocity` across peers in real-time.
- **Dynamic Identity**: Players are assigned distinct procedural HSV avatar colors, character model selections, and 3D billboard nametags synced from the lobby.

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
[Player] Authority assigned -> Local player handles inputs, camera & weapon scavenging
```

### 2. Modular Player Component Hierarchy
```
Player (CharacterBody3D)
├── Visuals
│   ├── WeyzeroCodes (Mesh + Skeleton3D + LeftHandIK + AnimationTree)
│   ├── AtoCodes (Mesh + Skeleton3D + LeftHandIK + AnimationTree)
│   └── WeaponMount (Hand-aligned socket for active Blaster model)
├── Nametag (Label3D - Billboard)
├── CameraPivot (PlayerCamera)
│   └── SpringArm3D -> Camera3D
├── PlayerInput (PlayerInput)
├── PlayerMovement (PlayerMovement)
├── WeaponManager (PlayerWeaponManager - Ammo, Inventory, Reload FSM)
└── MultiplayerSynchronizer
```

---

## 🚀 How to Play & Test Multiplayer

### Option 1: Multi-Instance Testing in Godot Editor
1. Open the project in the **Godot 4 Editor**.
2. Go to **Debug** in the top menu bar.
3. Select **Customize Run Instances...** and set the count to **2** (or more).
4. Press **F5** to start.
5. In **Window 1**: Select your character model, enter a nickname, and click **Host Game** (Port `8910`) or speak *"Host game on port 8910"*.
6. In **Window 2**: Select your character model, enter a nickname, and click **Join Game** (IP: `127.0.0.1`, Port: `8910`) or speak *"Join server at 127.0.0.1"*.
7. Both players will spawn unarmed in the arena with unique player colors and nametags! Run toward the glowing weapon stations to equip your arsenal.

### Option 2: Running via Terminal / CLI
```bash
# Terminal 1: Launch Host Instance
godot --path .

# Terminal 2: Launch Client Instance
godot --path .
```

### Option 3: Automated Test Runner
You can verify the game systems headlessly using the integrated test runner:
```bash
godot --headless --path . scenes/test_runner.tscn
```

---

## 🛠️ Extending the Game

### Adding a New Weapon Pickup to the Arena
Instantiate a `WeaponPickup` in `world.tscn` or `map_geometry.tscn` and configure its `weapon_id` export property:
```gdscript
var pickup := preload("res://scenes/weapons/weapon_pickup.tscn").instantiate()
pickup.weapon_id = "heavy_sniper"
pickup.position = Vector3(5.0, 0.0, -12.0)
pickup.respawn_time = 15.0
add_child(pickup)
```

### Registering New Voice AI Tools
You can expand the voice assistant by adding new `VoxideTool` instances in `lobby_menu.gd`:
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

## 📜 Changelog

See the full history of changes in [CHANGELOG.md](CHANGELOG.md).

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
