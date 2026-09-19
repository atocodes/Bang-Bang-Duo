# 💥 Bang Bang Duo — 3D Multiplayer Arena Shooter (Godot 4)

[![Godot Engine](https://img.shields.io/badge/Godot-4.7+-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Physics](https://img.shields.io/badge/Physics-Jolt_3D-FF6B6B)](https://github.com/godot-jolt/godot-jolt)
[![Networking](https://img.shields.io/badge/Multiplayer-ENet_RPC-2EA44F)](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
[![Voice AI](https://img.shields.io/badge/AI-Voxide_Voice-8A2BE2)](https://github.com/atocodes/voxide)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Bang Bang Duo** is a fast-paced, modular 3D multiplayer arena shooter built with **Godot 4**, **GDScript**, **Jolt 3D Physics**, and Godot's **High-Level Multiplayer API**. Featuring responsive third-person combat, multi-weapon arsenals, server-authoritative replication, and integrated **Voxide Voice AI Assistant** support.

---

## 🎮 Game Overview

In **Bang Bang Duo**, players jump into a vibrant 3D arena for fast-paced combat. The game combines responsive movement mechanics with a modular weapon system and seamless networking:

- **Third-Person Tactical Perspective**: Smooth over-the-shoulder camera with mouse look, pitch clamping, and collision-aware spring arm.
- **Dynamic 3D Crosshair Aiming**: Weapons automatically orient toward the exact world point targeted by your crosshair with responsive weapon recoil.
- **Modular Weapon Arsenal**: Switch between different weapons on the fly, each with custom fire rates, velocities, damage, color profiles, and audio signatures.
- **Glowing Projectiles & FX**: Real-time high-speed projectiles with dynamic lighting, trajectory collision detection, and glowing impact spark effects.
- **Voice AI Enabled Lobby**: Hands-free lobby management and server operations powered by Voxide AI.
- **Server-Authoritative Networking**: Clean multiplayer replication using `MultiplayerSpawner` and `MultiplayerSynchronizer`.

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
[Client] Click 'Host' or 'Join' 
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

### 3. Voice AI Assistant Integration (Voxide)
- Integrated voice tools enable players to interact with the game via natural voice commands:
  - `"Host game on port 8910"`
  - `"Join server at 192.168.1.5"`
  - `"Change my name to CyberKnight"`
- Focus-safety handling ensures push-to-talk does not trigger accidentally when editing text fields.

---

## 🚀 How to Play & Test Multiplayer

### Option 1: Multi-Instance Testing in Godot Editor
1. Open the project in the **Godot 4 Editor**.
2. Go to **Debug** in the top menu bar.
3. Select **Customize Run Instances...** and set the count to **2** (or more).
4. Press **F5** to start.
5. In **Window 1**: Enter a nickname and click **Host Game** (Port `8910`).
6. In **Window 2**: Enter a nickname and click **Join Game** (IP: `127.0.0.1`, Port: `8910`).
7. Both players will spawn in the arena with unique player colors and nametags!

### Option 2: Running via Terminal / CLI
```bash
# Terminal 1: Launch Host Instance
godot --path .

# Terminal 2: Launch Client Instance
godot --path .
```

### Option 3: Headless Syntax & Codebase Validation
```bash
godot --headless --quit
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

### Adding Player Health & Combat Damage
1. Add `@export var health: float = 100.0` to `player.gd`.
2. Add `health` to the `MultiplayerSynchronizer` replication properties.
3. In `bullet.gd`, detect when collision hits a `Player` node and call a server-side damage handler:
   ```gdscript
   if hit_collider is Player:
       hit_collider.take_damage.rpc_id(1, damage, shooter_id)
   ```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
