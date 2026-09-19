class_name PlayerInput
extends Node

## PlayerInput Component
## Gathers keyboard & mouse input exclusively for the local player authority.
##
## Separating input from movement allows:
## 1. Easy addition of AI bots (just feed simulated inputs).
## 2. Rebinding inputs without touching movement physics.
## 3. Strict authority isolation (peers don't run input checks for other peers).

# Raw input states
var move_direction: Vector2 = Vector2.ZERO
var is_jumping: bool = false
var is_sprinting: bool = false
var is_firing: bool = false

# Reference to the root player
@onready var player: CharacterBody3D = get_parent()

func _ready() -> void:
	_ensure_default_actions()
	# Disable processing if this node belongs to a remote peer
	if multiplayer.has_multiplayer_peer() and not player.is_multiplayer_authority():
		set_process_unhandled_input(false)
		set_physics_process(false)


## Registers default keybindings if they are not already set in Project Settings
static func _ensure_default_actions() -> void:
	var default_bindings = {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT]
	}
	
	for action_name in default_bindings:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			for keycode in default_bindings[action_name]:
				var event = InputEventKey.new()
				event.physical_keycode = keycode
				InputMap.action_add_event(action_name, event)

	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", event)


func _physics_process(_delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not player.is_multiplayer_authority():
		return
	
	# Gather directional movement (X = Left/Right, Y = Forward/Backward)
	move_direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	
	# Gather action inputs
	is_jumping = Input.is_action_just_pressed("jump")
	is_sprinting = Input.is_action_pressed("sprint")
	is_firing = Input.is_action_just_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
