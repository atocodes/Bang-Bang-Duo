@icon("../icon.png")
## VoxideChat
## Full text chat UI: input field, send button, and embedded transcript.
## Fully self-contained Control widget: automatically manages its own VoxideClient
## if none is present in the scene, or binds to an existing one.
class_name VoxideChat
extends Control


# -- Inspector: Connection -----------------------------------------------------

@export_group("Connection")

## Optional path to an external VoxideClient. If empty, VoxideChat automatically
## discovers one in the scene or creates its own internal client.
@export var client: NodePath = NodePath("")

## Voxide public key override. Leave empty to use VOXIDE_API_KEY from .env.
@export var public_key: String = ""

## Voxide base URL override. Leave empty for default.
@export var base_url: String = ""

## Automatically initialize the client when this node enters the scene tree.
@export var auto_initialize: bool = true

## Automatically connect to Voxide after initialization.
@export var auto_connect: bool = false

## Automatically reconnect after unexpected disconnection.
@export var auto_reconnect: bool = false


# -- Inspector: Layout ---------------------------------------------------------

@export_group("Layout")

@export var show_input: bool = true
@export var show_send_button: bool = true
@export var show_transcript: bool = true

@export var background_color: Color = Color(0.06, 0.06, 0.10, 0.95)
@export var input_background_color: Color = Color(0.12, 0.12, 0.18, 1.0)
@export var send_button_color: Color = Color(0.25, 0.55, 0.95, 1.0)
@export var send_button_text: String = "Send"
@export var placeholder_text: String = "Type a message and press Enter..."

@export var border_radius: float = 8.0
@export var padding: float = 8.0


# -- Inspector: Messages -------------------------------------------------------

@export_group("Messages")

@export var font_size: int = 13
@export var max_messages: int = 100
@export var auto_scroll: bool = true
@export var show_timestamps: bool = false
@export var show_speaker: bool = true


# -- Signals (forwarded from client & UI) --------------------------------------

signal initialized
signal connected
signal disconnected
signal state_changed(new_state: VoxideConstants.State)
signal message_received(message: VoxideMessage)
signal message_sent(text: String)
signal send_failed(reason: String)
signal error_occurred(error: String)


# -- Internal ------------------------------------------------------------------

var _client_ref: VoxideClient = null
var _vbox: VBoxContainer = null
var _transcript: VoxideTranscript = null
var _input_row: HBoxContainer = null
var _line_edit: LineEdit = null
var _send_btn: Button = null
var _status_label: Label = null


func _ready() -> void:
	_ensure_client()
	_build_ui()
	_bind_ui()


# -- Public API ----------------------------------------------------------------

## Send a message programmatically or from UI.
func send_message(text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	var c := _ensure_client()
	if c == null:
		send_failed.emit("No VoxideClient available.")
		return
	c.send_text(clean)
	message_sent.emit(clean)


## Clear the transcript.
func clear_transcript() -> void:
	if _transcript:
		_transcript.clear()


## Connect to live session.
func connect_to_voxide() -> void:
	var c := _ensure_client()
	if c:
		c.connect_to_voxide()


## Disconnect from live session.
func disconnect_from_voxide() -> void:
	if _client_ref:
		_client_ref.disconnect_from_voxide()


## Returns the current session state.
func get_state() -> VoxideConstants.State:
	return _client_ref.get_state() if _client_ref else VoxideConstants.State.IDLE


## Register a tool on the bound client.
func register_tool(tool: VoxideTool) -> void:
	var c := _ensure_client()
	if c:
		c.register_tool(tool)


## Access the state manager for game state injection.
var state: VoxideState:
	get:
		var c := _ensure_client()
		return c.state if c else null


## Reference to the underlying client.
var voxide_client: VoxideClient:
	get:
		return _ensure_client()


# -- Internal: Setup -----------------------------------------------------------

func _ensure_client() -> VoxideClient:
	if _client_ref:
		return _client_ref

	_client_ref = _find_client()
	if _client_ref == null:
		# Auto-create internal client so VoxideChat works independently as a pure Control node.
		var new_client := VoxideClient.new()
		new_client.name = "VoxideClient"
		new_client.public_key = public_key
		new_client.base_url = base_url
		new_client.auto_initialize = auto_initialize
		new_client.auto_connect = auto_connect
		new_client.auto_reconnect = auto_reconnect
		add_child(new_client)
		_client_ref = new_client

	# Connect client signals.
	_client_ref.initialized.connect(func(): initialized.emit())
	_client_ref.connected.connect(func(): connected.emit())
	_client_ref.disconnected.connect(func(): disconnected.emit())
	_client_ref.state_changed.connect(_on_state_changed)
	_client_ref.message_received.connect(func(m): message_received.emit(m))
	_client_ref.error_occurred.connect(func(e): error_occurred.emit(e))

	return _client_ref


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


func _build_ui() -> void:
	set_clip_contents(true)
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", int(padding))
	add_child(_vbox)

	# Transcript area.
	if show_transcript:
		_transcript = VoxideTranscript.new()
		_transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_transcript.font_size = font_size
		_transcript.max_messages = max_messages
		_transcript.auto_scroll = auto_scroll
		_transcript.show_timestamps = show_timestamps
		_transcript.show_speaker = show_speaker
		_vbox.add_child(_transcript)

	# Status label.
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.visible = false
	_vbox.add_child(_status_label)

	# Input row.
	if show_input:
		_input_row = HBoxContainer.new()
		_input_row.add_theme_constant_override("separation", int(padding * 0.5))
		_vbox.add_child(_input_row)

		_line_edit = LineEdit.new()
		_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_line_edit.placeholder_text = placeholder_text
		_line_edit.add_theme_font_size_override("font_size", font_size)
		_line_edit.text_submitted.connect(_on_submit)
		_input_row.add_child(_line_edit)

		if show_send_button:
			_send_btn = Button.new()
			_send_btn.text = send_button_text
			_send_btn.custom_minimum_size = Vector2(70, 0)
			_send_btn.pressed.connect(_on_send_pressed)
			_input_row.add_child(_send_btn)


func _bind_ui() -> void:
	if _client_ref and _transcript:
		_transcript.client = _client_ref.get_path()
		_transcript._bind_client()


func _on_send_pressed() -> void:
	if _line_edit:
		var text := _line_edit.text.strip_edges()
		if not text.is_empty():
			send_message(text)
			_line_edit.clear()


func _on_submit(text: String) -> void:
	var stripped := text.strip_edges()
	if not stripped.is_empty():
		send_message(stripped)
		if _line_edit:
			_line_edit.clear()


func _on_state_changed(new_state: VoxideConstants.State) -> void:
	state_changed.emit(new_state)
	if _status_label == null:
		return
	match new_state:
		VoxideConstants.State.CONNECTING:
			_status_label.text = "Connecting..."
			_status_label.visible = true
		VoxideConstants.State.THINKING:
			_status_label.text = "Thinking..."
			_status_label.visible = true
		VoxideConstants.State.SPEAKING:
			_status_label.text = "Speaking..."
			_status_label.visible = true
		VoxideConstants.State.EXECUTING:
			_status_label.text = "Executing..."
			_status_label.visible = true
		_:
			_status_label.visible = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true, -1.0)
