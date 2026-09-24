# Changelog

All notable changes to **Bang Bang Duo** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.5.0] - 2026-09-24

### Added
- **Player Health System & Combat Damage Replication**:
  - Full networked player health (`100 HP`) synchronized across peers.
  - Overhead 3D billboard `HealthTag` with dynamic traffic light color coding (Green > 55%, Yellow > 25%, Red <= 25%).
  - Replicated bullet raycast hit registration, weapon-specific damage application, and physical impact knockback impulses.
  - Visual damage feedback: red flash material overlay and localized spark impact particle burst.
  - Server-authoritative death and respawn loop (`respawn_rpc`) with full health restoration and repositioning to arena spawn points.
- **HUD Combat & Vitality Overhaul**:
  - Top-left vitality status display featuring an animated in-game Health Bar and precise numerical HP readout.
  - Dynamic Duo Target Radar (`hud_opponent_radar`) displaying live vitals and combat readiness of opponents.
- **Educational Code Logic Visualizer & GDScript Deconstructor Dock**:
  - Built-in real-time developer visualizer dock (`CodeLogicDock` / `CodeLogicBus`) providing live GDScript execution tracing for physics kinematics, condition evaluations, netcode RPCs, weapon state transitions, and ballistics math.
  - Ring-buffer based high-performance entry logging with fading modulate transitions and zero runtime overhead when toggled off.
  - Keybinding toggle (`F1`) to inspect under-the-hood engine math, physics impulses, and formulas in real time.
- **Custom Arcade Typography & Enhanced Lobby Layout**:
  - Integrated custom arcade font `PhantomGuardiansCoolGamingBold` (`PhantomGuardiansCoolGamingBold-q2Rlx.otf`).
  - Redesigned lobby layout with responsive hero selection buttons (`Weyzero Codes` / `Ato Codes`), firing mode badges, and pickup notification toasts.

### Changed
- Updated `project.godot` configuration to version `0.5.0`.
- Refactored projectile collision raycast handling to trigger `take_damage` on hit actors with sender peer attribution.
- Hooked up local player health events to automatically drive the HUD health bar, overhead nametags, and respawn cycles.

---

## [0.4.0] - 2026-09-19

### Added
- **Unarmed Player Spawns**: Players now spawn completely unarmed and must scavenge the arena to acquire weapons.
- **Interactive 3D Weapon Pickups**:
  - In-world pickups featuring rotating 3D blaster models with smooth sinusoidal floating/bobbing animations.
  - Glowing colored omni-lights matching weapon plasma energy cores.
  - 3D billboard labels indicating weapon name and firing mode (Full Auto, 3-Round Burst, Semi-Auto, Bolt Action).
  - Server-authoritative pickup collection and networked respawn timers with RPC synchronization.
  - Arcade pickup audio SFX and animated HUD toast notifications upon collecting a weapon.
- **Kenney Blaster Kit Arsenal (5 Modular Weapons)**:
  - **Assault Rifle**: Balanced full-auto rifle (30/120 ammo, 0.14s rate, Cyan plasma).
  - **Machine Gun**: High-capacity suppressive fire weapon (60/240 ammo, 0.08s rate, Amber plasma).
  - **Burst Rifle**: Precise 3-round burst firearm (30/90 ammo, 0.38s rate, Emerald plasma).
  - **Sniper Rifle**: High-speed precision semi-automatic sniper (10/40 ammo, 0.55s rate, Magenta plasma).
  - **Heavy Sniper**: Devastating high-caliber bolt-action rifle (5/20 ammo, 1.15s rate, Crimson blast).
- **Timed Reload Mechanics**:
  - Configurable reload duration per weapon (`reload_time`).
  - Automatic reload trigger when emptying a magazine with reserves available.
  - Reload interruption and cancellation on weapon switching; switching back to an empty magazine weapon cleanly restarts the reload cycle.
  - Real-time in-game HUD indicators displaying active reload timers (`RELOADING... [Xs]`).
- **Sci-Fi Map Geometry**:
  - Modular arena layout with interconnected corridors, wide junctions, large & small chambers, security gates, and elevated platforms (`scenes/world/map_geometry.tscn`).
  - Strategic world placement of weapon pickups across the facility.
- **Automated Integration Test Suite**:
  - Headless-ready test runner (`tests/test_runner.gd` / `test_runner.tscn`) covering unarmed spawn states, weapon pickups, timed reloads, ammo replenishment, and character switching.

### Changed
- Refactored `PlayerWeaponManager` to support dynamic inventory expansion, duplicate resource instantiation on pickup, and reload state machine.
- Updated `Player` controller to hide weapon meshes when unarmed and sync active weapon state to remote peers.
- Updated HUD to reflect current weapon shoot modes, dynamic ammo counts, reserve ammunition, and pickup toast animations.

---

## [0.3.0] - 2026-09-19

### Added
- **Selectable 3D Character Models**:
  - Integrated custom player models: **Weyzero Codes** and **Ato Codes**.
  - Synchronized character selection across multiplayer peers.
- **Full 3D Character Locomotion & Combat Animations**:
  - Animation state machine playback: Idle, Walk with Rifle, Rifle Run / Sprint, Rifle Jump, Rifle Aiming, Firing, Gunplay, and Death animations.
- **Procedural LeftHandIK**:
  - SkeletonIK3D setup on character models for accurate left-hand grip alignment across various weapon models and grip offsets.
- **Lobby Character Selection UI**:
  - Interactive model toggle buttons on the main menu with selected state indicators.

---

## [0.2.0] - 2026-09-19

### Added
- **Voxide Voice AI Assistant**:
  - Real-time hands-free voice assistant integration directly in the lobby menu powered by Voxide and Gemini.
  - Spoken voice commands: `host_game`, `join_game`, `set_player_name`, and network state Q&A.
  - Smart text input focus detection to suspend voice capture while typing in `LineEdit` fields.
- **Polished Lobby UI & Arcade Theme**:
  - Modular menu panels: Host, Join, Voice Assistant, Settings, and active Status badges.
  - Automatic LAN IP detection with one-click clipboard copy helper (`ip_helper.gd`).
  - Custom UI theme (`lobby_theme.tres` and `ui_theme.tres`) with Kenney UI assets.

---

## [0.1.0] - 2026-09-17

### Added
- **Core Multiplayer Networking**:
  - Server-authoritative high-level multiplayer using ENet and Godot 4 RPCs.
  - Real-time entity replication with `MultiplayerSpawner` and `MultiplayerSynchronizer`.
- **Third-Person Combat Controller**:
  - Over-the-shoulder spring arm camera with mouse look, pitch clamping, and 3D crosshair raycasting.
  - Responsive character movement with sprinting, jump kinematics, and Jolt 3D physics integration.
- **Projectile & Ballistics System**:
  - Dynamic high-speed projectiles with trail lighting, collision hit detection, and particle sparks.
- **3D Nametags & Identity**:
  - Synced 3D billboard nametags and procedural HSV avatar coloring per peer.
