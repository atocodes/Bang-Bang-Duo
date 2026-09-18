@icon("../icon.png")
## VoxideTranscript
## Scrollable conversation transcript display.
## Automatically discovers and listens to VoxideClient for incoming messages.
class_name VoxideTranscript
extends Control


# -- Inspector: Client ---------------------------------------------------------

@export_group("Client")
@export var client: NodePath = NodePath("")


# -- Inspector: Layout ---------------------------------------------------------

@export_group("Layout")

@export var background_color: Color = Color(0.05, 0.05, 0.08, 0.85)
@export var border_radius: float = 8.0
@export var padding: float = 10.0


# -- Inspector: Messages -------------------------------------------------------

@export_group("Messages")

@export var max_messages: int = 100
@export var auto_scroll: bool = true
@export var show_timestamps: bool = false
@export var show_speaker: bool = true
@export var message_spacing: float = 6.0

@export var user_color: Color = Color(0.85, 0.85, 1.0, 1.0)
@export var ai_color: Color = Color(0.85, 1.0, 0.9, 1.0)
@export var system_color: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var partial_opacity: float = 0.6

@export var font_size: int = 13
@export var user_prefix: String = "You"
@export var ai_prefix: String = "Assistant"


# -- Signals -------------------------------------------------------------------

signal message_added(message: VoxideMessage)
signal cleared


# -- Internal ------------------------------------------------------------------

var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _client_ref: VoxideClient = null
var _partial_label: RichTextLabel = null
var _partial_role: VoxideMessage.Role = VoxideMessage.Role.AI


func _ready() -> void:
	_build_ui()
	_bind_client()


# -- Public API ----------------------------------------------------------------

## Append a message directly.
func add_message(msg: VoxideMessage) -> void:
	if _partial_label and msg.partial:
		_update_partial(msg)
		return
	if _partial_label and not msg.partial:
		_commit_partial(msg)
		return
	if msg.partial:
		_create_partial(msg)
	else:
		_create_committed(msg)
	_trim_messages()
	_scroll_to_bottom()


## Clear all displayed messages.
func clear() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_partial_label = null
	cleared.emit()


## Returns all current messages from the bound client (if any).
func get_messages() -> Array[VoxideMessage]:
	if _client_ref:
		return _client_ref.get_messages()
	return []


# -- Internal ------------------------------------------------------------------

func _build_ui() -> void:
	set_clip_contents(true)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", int(message_spacing))
	_scroll.add_child(_vbox)


func _bind_client() -> void:
	_client_ref = _find_client()
	if _client_ref:
		if not _client_ref.transcript_received.is_connected(_on_transcript):
			_client_ref.transcript_received.connect(_on_transcript)
		if not _client_ref.message_received.is_connected(_on_message_received):
			_client_ref.message_received.connect(_on_message_received)


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


func _on_transcript(text: String, is_final: bool) -> void:
	var partial_msg := VoxideMessage.create(VoxideMessage.Role.AI, text, not is_final)
	add_message(partial_msg)


func _on_message_received(msg: VoxideMessage) -> void:
	if msg.role == VoxideMessage.Role.AI and _partial_label:
		_commit_partial(msg)
	else:
		add_message(msg)


func _create_partial(msg: VoxideMessage) -> void:
	_partial_role = msg.role
	_partial_label = _make_label(msg)
	_partial_label.modulate.a = partial_opacity
	_vbox.add_child(_partial_label)


func _update_partial(msg: VoxideMessage) -> void:
	if _partial_label and msg.role == _partial_role:
		_partial_label.text = _format_text(msg)
		_partial_label.modulate.a = partial_opacity
	else:
		_commit_partial(null)
		_create_partial(msg)


func _commit_partial(msg: VoxideMessage) -> void:
	if _partial_label:
		if msg:
			_partial_label.text = _format_text(msg)
		_partial_label.modulate.a = 1.0
		_partial_label = null
		_scroll_to_bottom()


func _create_committed(msg: VoxideMessage) -> void:
	var lbl := _make_label(msg)
	_vbox.add_child(lbl)
	message_added.emit(msg)
	_scroll_to_bottom()


func _scroll_to_bottom() -> void:
	if auto_scroll and _scroll:
		await get_tree().process_frame
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _make_label(msg: VoxideMessage) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.fit_content = true
	rtl.bbcode_enabled = false
	rtl.add_theme_font_size_override("normal_font_size", font_size)
	rtl.add_theme_color_override("default_color", _color_for_role(msg.role))
	rtl.text = _format_text(msg)
	return rtl


func _format_text(msg: VoxideMessage) -> String:
	var parts: PackedStringArray = []
	if show_speaker:
		var prefix := ai_prefix if msg.role == VoxideMessage.Role.AI else user_prefix
		if msg.role == VoxideMessage.Role.SYSTEM:
			prefix = "System"
		parts.append("[%s]" % prefix)
	if show_timestamps:
		parts.append("[%s]" % Time.get_time_string_from_unix_time(int(msg.timestamp)))
	parts.append(msg.text)
	return " ".join(parts)


func _color_for_role(role: VoxideMessage.Role) -> Color:
	match role:
		VoxideMessage.Role.USER: return user_color
		VoxideMessage.Role.AI: return ai_color
		VoxideMessage.Role.SYSTEM: return system_color
	return system_color


func _trim_messages() -> void:
	var children := _vbox.get_children()
	while children.size() > max_messages:
		children[0].queue_free()
		children.remove_at(0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true, -1.0)
