@icon("../icon.png")
## VoxideOrb
## An animated visual indicator that reacts to VoxideClient session states.
## Drawn entirely with Godot's CanvasItem draw API — no external assets required.
##
## Bind to a VoxideClient node via the client property or by drag-and-drop in the Inspector.
## The developer can hide this node entirely and build their own orb visualization.
class_name VoxideOrb
extends Control


# -- Inspector: Client ---------------------------------------------------------

@export_group("Client")

## The VoxideClient node to observe. If null, searches for a sibling VoxideClient.
@export var client: NodePath = NodePath("")


# -- Inspector: Appearance -----------------------------------------------------

@export_group("Appearance")

@export var background_color: Color = Color(0.08, 0.08, 0.12, 0.9)
@export var idle_color: Color = Color(0.4, 0.4, 0.5, 1.0)
@export var listening_color: Color = Color(0.3, 0.7, 1.0, 1.0)
@export var thinking_color: Color = Color(0.9, 0.7, 0.2, 1.0)
@export var speaking_color: Color = Color(0.3, 1.0, 0.6, 1.0)
@export var executing_color: Color = Color(1.0, 0.6, 0.2, 1.0)
@export var error_color: Color = Color(1.0, 0.3, 0.3, 1.0)

@export_range(8.0, 256.0, 1.0) var orb_radius: float = 40.0
@export_range(0.0, 1.0, 0.01) var inner_radius_ratio: float = 0.55
@export_range(0.0, 1.0, 0.01) var glow_strength: float = 0.5
@export_range(0.0, 4.0, 0.01) var pulse_amount: float = 0.12
@export_range(0.1, 8.0, 0.01) var pulse_speed: float = 2.0
@export_range(0.0, 4.0, 0.01) var rotation_speed: float = 0.8


# -- Inspector: Animation ------------------------------------------------------

@export_group("Animation")

@export_range(0.1, 10.0, 0.1) var animation_speed: float = 1.0


# -- Internal ------------------------------------------------------------------

var _client_ref: VoxideClient = null
var _state: VoxideConstants.State = VoxideConstants.State.IDLE
var _time := 0.0
var _current_color := Color.WHITE
var _target_color := Color.WHITE
var _current_radius := 40.0


func _ready() -> void:
	_current_color = idle_color
	_target_color = idle_color
	_current_radius = orb_radius
	custom_minimum_size = Vector2(orb_radius * 2.0 + 20.0, orb_radius * 2.0 + 20.0)
	_bind_client()


func _process(delta: float) -> void:
	_time += delta * animation_speed
	_current_color = _current_color.lerp(_target_color, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var pulse := 1.0 + sin(_time * pulse_speed) * pulse_amount * _state_pulse_factor()
	var radius := _current_radius * pulse

	# Glow ring.
	if glow_strength > 0.0:
		var glow_col := _current_color
		glow_col.a *= glow_strength * 0.4
		for i in 6:
			var glow_r := radius + float(i) * 3.0
			draw_circle(center, glow_r, glow_col)

	# Background circle.
	draw_circle(center, radius, background_color)

	# Outer ring — state color.
	draw_arc(center, radius, 0.0, TAU, 64, _current_color, 2.5, true)

	# Inner animated fill.
	var inner_r := radius * inner_radius_ratio
	var fill_col := _current_color
	fill_col.a *= 0.25
	draw_circle(center, inner_r, fill_col)

	# Rotating accent arc (hidden when idle or armed standby).
	if _state != VoxideConstants.State.IDLE and _state != VoxideConstants.State.ARMED and _state != VoxideConstants.State.ERROR:
		var arc_angle := _time * rotation_speed * TAU
		var arc_span := 1.2 + sin(_time * 1.5) * 0.4
		draw_arc(center, inner_r * 0.8, arc_angle, arc_angle + arc_span, 32, _current_color, 2.0, true)


# -- Public API ----------------------------------------------------------------

## Manually set the displayed state without a client binding.
func set_display_state(new_state: VoxideConstants.State) -> void:
	_state = new_state
	_target_color = _color_for_state(new_state)


# -- Internal ------------------------------------------------------------------

func _bind_client() -> void:
	_client_ref = _find_client()
	if _client_ref and not _client_ref.state_changed.is_connected(_on_state_changed):
		_client_ref.state_changed.connect(_on_state_changed)


func _find_client() -> VoxideClient:
	if not client.is_empty():
		var node := get_node_or_null(client)
		if node is VoxideClient:
			return node
	if owner:
		for child in owner.get_children():
			if child is VoxideClient:
				return child
	var curr: Node = get_parent()
	while curr:
		if curr is VoxideClient:
			return curr
		for child in curr.get_children():
			if child is VoxideClient:
				return child
		curr = curr.get_parent()
	return null


func _on_state_changed(new_state: VoxideConstants.State) -> void:
	_state = new_state
	_target_color = _color_for_state(new_state)


func _color_for_state(s: VoxideConstants.State) -> Color:
	match s:
		VoxideConstants.State.IDLE: return idle_color
		VoxideConstants.State.ARMED: return Color(0.3, 0.65, 0.85, 0.85)
		VoxideConstants.State.CONNECTING: return thinking_color
		VoxideConstants.State.LISTENING: return listening_color
		VoxideConstants.State.THINKING: return thinking_color
		VoxideConstants.State.SPEAKING: return speaking_color
		VoxideConstants.State.EXECUTING: return executing_color
		VoxideConstants.State.ERROR: return error_color
	return idle_color


func _state_pulse_factor() -> float:
	match _state:
		VoxideConstants.State.LISTENING: return 1.5
		VoxideConstants.State.SPEAKING: return 2.0
		VoxideConstants.State.THINKING: return 0.8
		VoxideConstants.State.EXECUTING: return 1.2
		VoxideConstants.State.ARMED: return 0.4
	return 0.3
