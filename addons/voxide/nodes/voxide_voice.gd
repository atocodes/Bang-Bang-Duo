@icon("../icon.png")
## VoxideVoice
## The primary high-level voice interaction component and drop-in widget.
## Combines VoxideClient, VoxideOrb, VoxideStatus, VoxideTranscript,
## VoxideAudioMeter, and customizable Push-To-Talk controls into one drop-in node.
##
## Basic usage:
##   1. Add VoxideVoice to your scene.
##   2. The public key is read from VOXIDE_API_KEY in your .env file automatically.
##   3. Press Play. The node initializes and can begin a voice session immediately.
class_name VoxideVoice
extends Control


enum WidgetMode {
	BAR,   # Compact floating launcher pill (Orb + Status + PTT / Connect)
	PANEL  # Full panel with Orb, Status, Transcript, Meter, and Controls
}

# -- Inspector: Widget ---------------------------------------------------------

@export_group("Widget")

@export var widget_mode: WidgetMode = WidgetMode.PANEL


# -- Inspector: Connection -----------------------------------------------------

@export_group("Connection")

## Voxide public key override. Leave empty to use VOXIDE_API_KEY from .env.
@export var public_key: String = ""

## Voxide base URL override. Leave empty for the default.
@export var base_url: String = ""

## Automatically initialize the client when this node enters the scene tree.
@export var auto_initialize: bool = true

## Automatically connect to Voxide after initialization.
@export var auto_connect: bool = true

## Automatically reconnect after unexpected disconnection.
@export var auto_reconnect: bool = false


# -- Inspector: Voice ----------------------------------------------------------

@export_group("Voice")

## Enable push-to-talk mode. When true, voice is only streamed while the
## Hold to Talk button is pressed or Spacebar / push_to_talk_action key is held.
@export var push_to_talk: bool = true:
	set(val):
		push_to_talk = val
		if client:
			client.set_ptt_enabled(val)
		_update_ui_controls()

## InputMap action name for push-to-talk key.
@export var push_to_talk_action: String = "ui_accept"

## Interrupt AI speech when the user begins speaking.
@export var interrupt_on_input: bool = true


# -- Inspector: UI -------------------------------------------------------------

@export_group("UI")

@export var show_orb: bool = true
@export var show_status: bool = true
@export var show_transcript: bool = true
@export var show_audio_meter: bool = true
@export var show_controls: bool = true


# -- Inspector: Appearance -----------------------------------------------------

@export_group("Appearance")

@export var background_color: Color = Color(0.06, 0.06, 0.10, 0.95)
@export var border_color: Color = Color(0.2, 0.25, 0.35, 0.8)
@export var border_radius: float = 12.0
@export var opacity: float = 1.0
@export_range(0.1, 10.0, 0.1) var animation_speed: float = 1.0


# -- Signals (forwarded from VoxideClient) -------------------------------------

signal initialized
signal connected
signal disconnected
signal transcript_received(text: String, is_final: bool)
signal message_received(message: VoxideMessage)
signal tool_called(tool_name: String, arguments: Dictionary, call_id: String)
signal tool_confirmation_requested(tool: VoxideTool, arguments: Dictionary)
signal state_changed(new_state: VoxideConstants.State)
signal error_occurred(error: String)


# -- Sub-nodes -----------------------------------------------------------------

var client: VoxideClient = null
var orb: VoxideOrb = null
var status: VoxideStatus = null
var transcript: VoxideTranscript = null
var audio_meter: VoxideAudioMeter = null


# -- Internal ------------------------------------------------------------------

var _container: BoxContainer = null
var _controls_row: HBoxContainer = null
var _connect_btn: Button = null
var _ptt_btn: Button = null
var _interrupt_btn: Button = null
var _ptt_key_held := false
var _ptt_btn_held := false


func _ready() -> void:
	modulate.a = opacity
	_build_client()
	_build_layout()
	_bind_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _ptt_key_held or _ptt_btn_held:
			_ptt_key_held = false
			_ptt_btn_held = false
			_sync_ptt_state()


func _process(_delta: float) -> void:
	if push_to_talk:
		var held := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_pressed(push_to_talk_action)
		if held != _ptt_key_held:
			_ptt_key_held = held
			_sync_ptt_state()


# -- Public API ----------------------------------------------------------------

## Forward: register a tool with the embedded VoxideClient.
func register_tool(tool: VoxideTool) -> void:
	if client:
		client.register_tool(tool)


## Forward: send text to the AI.
func send_text(text: String) -> void:
	if client:
		client.send_text(text)


## Forward: interrupt the AI.
func interrupt() -> void:
	if client:
		client.interrupt()


## Forward: confirm or deny a pending tool call.
func confirm_tool(tool_name: String, allow: bool) -> void:
	if client:
		client.confirm_tool(tool_name, allow)


## Connect to live session.
func connect_session() -> void:
	if client:
		client.connect_to_voxide()


## Disconnect from live session.
func disconnect_session() -> void:
	if client:
		client.disconnect_from_voxide()


## Access the state manager for game state injection.
var state: VoxideState:
	get:
		return client.state if client else null


# -- Internal: Build -----------------------------------------------------------

func _build_client() -> void:
	client = VoxideClient.new()
	client.name = "VoxideClient"
	client.public_key = public_key
	client.base_url = base_url
	client.auto_initialize = auto_initialize
	client.auto_connect = auto_connect
	client.auto_reconnect = auto_reconnect
	add_child(client)


func _build_layout() -> void:
	set_clip_contents(true)
	if widget_mode == WidgetMode.BAR:
		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 10)
		add_child(hbox)
		_container = hbox
	else:
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 8)
		add_child(vbox)
		_container = vbox


func _bind_ui() -> void:
	if widget_mode == WidgetMode.BAR:
		_bind_ui_bar()
	else:
		_bind_ui_panel()

	client.set_ptt_enabled(push_to_talk)

	# Forward client signals.
	client.initialized.connect(func(): initialized.emit())
	client.connected.connect(_on_client_connected)
	client.disconnected.connect(_on_client_disconnected)
	client.transcript_received.connect(func(t, f): transcript_received.emit(t, f))
	client.message_received.connect(func(m): message_received.emit(m))
	client.tool_called.connect(func(n, a, i): tool_called.emit(n, a, i))
	client.tool_confirmation_requested.connect(func(t, a): tool_confirmation_requested.emit(t, a))
	client.state_changed.connect(_on_state_changed)
	client.error_occurred.connect(func(e): error_occurred.emit(e))


func _bind_ui_bar() -> void:
	# Compact Bar Widget Mode.
	if show_orb:
		orb = VoxideOrb.new()
		orb.client = client.get_path()
		orb.custom_minimum_size = Vector2(40.0, 40.0)
		orb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_container.add_child(orb)

	if show_status:
		status = VoxideStatus.new()
		status.client = client.get_path()
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_container.add_child(status)

	if show_controls:
		_build_controls_row()
		_container.add_child(_controls_row)


func _bind_ui_panel() -> void:
	# Full Panel Widget Mode.
	if show_orb:
		orb = VoxideOrb.new()
		orb.client = client.get_path()
		orb.custom_minimum_size = Vector2(90.0, 90.0)
		orb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_container.add_child(orb)

	if show_status:
		status = VoxideStatus.new()
		status.client = client.get_path()
		status.custom_minimum_size = Vector2(0.0, 22.0)
		_container.add_child(status)

	if show_audio_meter:
		audio_meter = VoxideAudioMeter.new()
		audio_meter.client = client.get_path()
		audio_meter.custom_minimum_size = Vector2(0.0, 24.0)
		_container.add_child(audio_meter)

	if show_transcript:
		transcript = VoxideTranscript.new()
		transcript.client = client.get_path()
		transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
		transcript.custom_minimum_size = Vector2(0.0, 80.0)
		_container.add_child(transcript)

	if show_controls:
		_build_controls_row()
		_container.add_child(_controls_row)


func _build_controls_row() -> void:
	_controls_row = HBoxContainer.new()
	_controls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls_row.add_theme_constant_override("separation", 8)

	_connect_btn = Button.new()
	_connect_btn.text = "Connect"
	_connect_btn.custom_minimum_size = Vector2(90, 32)
	_connect_btn.pressed.connect(_on_connect_pressed)
	_controls_row.add_child(_connect_btn)

	_ptt_btn = Button.new()
	_ptt_btn.text = "Hold to Talk"
	_ptt_btn.custom_minimum_size = Vector2(110, 32)
	_ptt_btn.button_down.connect(func():
		_ptt_btn_held = true
		_sync_ptt_state()
	)
	_ptt_btn.button_up.connect(func():
		_ptt_btn_held = false
		_sync_ptt_state()
	)
	_controls_row.add_child(_ptt_btn)

	_interrupt_btn = Button.new()
	_interrupt_btn.text = "Interrupt"
	_interrupt_btn.custom_minimum_size = Vector2(80, 32)
	_interrupt_btn.visible = false
	_interrupt_btn.pressed.connect(func(): interrupt())
	_controls_row.add_child(_interrupt_btn)

	_update_ui_controls()


func _update_ui_controls() -> void:
	if _ptt_btn:
		_ptt_btn.visible = push_to_talk


func _sync_ptt_state() -> void:
	if not push_to_talk:
		return
	var active := _ptt_key_held or _ptt_btn_held
	if client:
		var current_state := client.get_state()
		if active and current_state in [VoxideConstants.State.SPEAKING, VoxideConstants.State.THINKING, VoxideConstants.State.EXECUTING]:
			client.interrupt()

		if active and current_state in [VoxideConstants.State.IDLE, VoxideConstants.State.ERROR]:
			client.connect_to_voxide()

		client.set_ptt_active(active)

	_update_ptt_button_for_state(client.get_state() if client else VoxideConstants.State.IDLE)


func _update_ptt_button_for_state(s: VoxideConstants.State) -> void:
	if not _ptt_btn or not push_to_talk:
		return
	var is_active := _ptt_key_held or _ptt_btn_held
	match s:
		VoxideConstants.State.IDLE:
			_ptt_btn.disabled = false
			_ptt_btn.text = "Listening..." if is_active else "Hold to Talk"
		VoxideConstants.State.CONNECTING:
			_ptt_btn.disabled = true
			_ptt_btn.text = "Connecting..."
		VoxideConstants.State.ARMED:
			_ptt_btn.disabled = false
			_ptt_btn.text = "Listening..." if is_active else "Hold to Talk"
		VoxideConstants.State.LISTENING:
			_ptt_btn.disabled = false
			_ptt_btn.text = "Listening..."
		VoxideConstants.State.THINKING, VoxideConstants.State.EXECUTING:
			_ptt_btn.disabled = false
			_ptt_btn.text = "Listening..." if is_active else "Processing..."
		VoxideConstants.State.SPEAKING:
			_ptt_btn.disabled = false
			_ptt_btn.text = "Listening..." if is_active else "Hold to Interrupt"
		VoxideConstants.State.ERROR:
			_ptt_btn.disabled = false
			_ptt_btn.text = "Hold to Talk"


func _on_connect_pressed() -> void:
	if client.get_state() in [VoxideConstants.State.IDLE, VoxideConstants.State.ERROR]:
		client.connect_to_voxide()
	else:
		client.disconnect_from_voxide()


func _on_client_connected() -> void:
	if _connect_btn:
		_connect_btn.text = "Disconnect"
	_update_ptt_button_for_state(client.get_state() if client else VoxideConstants.State.ARMED)
	connected.emit()


func _on_client_disconnected() -> void:
	if _connect_btn:
		_connect_btn.text = "Connect"
	if _interrupt_btn:
		_interrupt_btn.visible = false
	_ptt_key_held = false
	_ptt_btn_held = false
	_update_ptt_button_for_state(VoxideConstants.State.IDLE)
	disconnected.emit()


func _on_state_changed(new_state: VoxideConstants.State) -> void:
	_update_ptt_button_for_state(new_state)
	if _interrupt_btn:
		_interrupt_btn.visible = (new_state == VoxideConstants.State.SPEAKING)
	state_changed.emit(new_state)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = background_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(border_radius))
	sb.draw(get_canvas_item(), r)
