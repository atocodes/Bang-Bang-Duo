@icon("../icon.png")
## VoxideStatus
## A label that automatically displays the current VoxideClient state.
## Bind to a VoxideClient via the client property.
class_name VoxideStatus
extends Control


# -- Inspector: Client ---------------------------------------------------------

@export_group("Client")
@export var client: NodePath = NodePath("")


# -- Inspector: Appearance -----------------------------------------------------

@export_group("Appearance")

@export var show_label: bool = true
@export var font_size: int = 13

@export var idle_color: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var armed_color: Color = Color(0.4, 0.7, 0.9, 1.0)
@export var listening_color: Color = Color(0.3, 0.7, 1.0, 1.0)
@export var thinking_color: Color = Color(0.9, 0.7, 0.2, 1.0)
@export var speaking_color: Color = Color(0.3, 1.0, 0.6, 1.0)
@export var executing_color: Color = Color(1.0, 0.6, 0.2, 1.0)
@export var error_color: Color = Color(1.0, 0.3, 0.3, 1.0)


# -- Inspector: Labels ---------------------------------------------------------

@export_group("Labels")

@export var label_idle: String = "Idle"
@export var label_armed: String = "Ready (Hold to Talk)"
@export var label_connecting: String = "Connecting"
@export var label_listening: String = "Listening"
@export var label_thinking: String = "Thinking"
@export var label_speaking: String = "Speaking"
@export var label_executing: String = "Executing"
@export var label_error: String = "Error"


# -- Signals -------------------------------------------------------------------

signal state_display_changed(label: String, color: Color)


# -- Internal ------------------------------------------------------------------

var _label_node: Label = null
var _client_ref: VoxideClient = null


func _ready() -> void:
	_label_node = Label.new()
	_label_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_node.add_theme_font_size_override("font_size", font_size)
	add_child(_label_node)
	_bind_client()
	_update_display(VoxideConstants.State.IDLE)


# -- Public API ----------------------------------------------------------------

func set_display_state(new_state: VoxideConstants.State) -> void:
	_update_display(new_state)


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
	_update_display(new_state)


func _update_display(s: VoxideConstants.State) -> void:
	var lbl := _label_for_state(s)
	var col := _color_for_state(s)
	if _label_node:
		_label_node.visible = show_label
		_label_node.text = lbl
		_label_node.add_theme_color_override("font_color", col)
	state_display_changed.emit(lbl, col)


func _label_for_state(s: VoxideConstants.State) -> String:
	match s:
		VoxideConstants.State.IDLE: return label_idle
		VoxideConstants.State.ARMED: return label_armed
		VoxideConstants.State.CONNECTING: return label_connecting
		VoxideConstants.State.LISTENING: return label_listening
		VoxideConstants.State.THINKING: return label_thinking
		VoxideConstants.State.SPEAKING: return label_speaking
		VoxideConstants.State.EXECUTING: return label_executing
		VoxideConstants.State.ERROR: return label_error
	return label_idle


func _color_for_state(s: VoxideConstants.State) -> Color:
	match s:
		VoxideConstants.State.IDLE: return idle_color
		VoxideConstants.State.ARMED: return armed_color
		VoxideConstants.State.CONNECTING: return thinking_color
		VoxideConstants.State.LISTENING: return listening_color
		VoxideConstants.State.THINKING: return thinking_color
		VoxideConstants.State.SPEAKING: return speaking_color
		VoxideConstants.State.EXECUTING: return executing_color
		VoxideConstants.State.ERROR: return error_color
	return idle_color
