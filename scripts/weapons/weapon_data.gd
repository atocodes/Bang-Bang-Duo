class_name WeaponData
extends Resource

## Modular Weapon Definition
## Encapsulates stats, ammunition, visuals, and behavior for interchangeable weapons.

@export var weapon_id: String = "pulse_blaster"
@export var weapon_name: String = "PULSE BLASTER"
@export var shoot_type: String = "FULL AUTO"
@export var max_ammo: int = 30
@export var current_ammo: int = 30
@export var reserve_ammo: int = 120
@export var is_infinite: bool = false
@export var fire_rate: float = 0.16
@export var burst_count: int = 1
@export var burst_interval: float = 0.06
@export var spread_degrees: float = 0.0
@export var bullet_speed: float = 95.0
@export var damage: float = 25.0
@export var bullet_color: Color = Color(0.0, 1.0, 0.95)
@export var sfx_pitch: float = 1.3
@export var model_name: String = "Rifile"

func can_shoot() -> bool:
	return is_infinite or current_ammo > 0


func consume_ammo() -> bool:
	if is_infinite:
		return true
	if current_ammo > 0:
		current_ammo -= 1
		return true
	return false


func reload() -> bool:
	if is_infinite or current_ammo >= max_ammo or reserve_ammo <= 0:
		return false
	var needed := max_ammo - current_ammo
	var amount := mini(needed, reserve_ammo)
	current_ammo += amount
	reserve_ammo -= amount
	return true
