## VoxideClient
## The primary runtime API node for the Voxide Godot plugin.
##
## Usage:
##   extends Control
##   @onready var ai: VoxideClient = $VoxideClient
##
##   func _ready() -> void:
##       ai.connected.connect(_on_connected)
##       ai.transcript_received.connect(_on_transcript)
##       ai.initialize()
##
## The public_key is read from the DotEnv autoload (VOXIDE_API_KEY) by default.
## You may also set it explicitly via the Inspector or code.
##
## VoxideClient automatically selects the appropriate transport:
##   - Native platforms: VoxideNativeTransport (WebSocketPeer + GodotAudio)
##   - Web exports:      VoxideWebTransport    (official Voxide browser SDK)
class_name VoxideClient
extends Node


# -- Signals -------------------------------------------------------------------

## Emitted once initialize() completes successfully.
signal initialized

## Emitted when a connection attempt begins.
signal connecting

## Emitted when the live session is fully established.
signal connected

## Emitted when the session is closed (cleanly or on error).
signal disconnected

## Emitted on any error. Provides a human-readable description.
signal connection_error(error: String)

## Emitted each time a transcript update is received.
## final is true when the turn is complete.
signal transcript_received(text: String, is_final: bool)

## Emitted when a complete message (user or AI) is finalized.
signal message_received(message: VoxideMessage)

## Emitted when the AI requests a tool execution.
signal tool_called(tool_name: String, arguments: Dictionary, call_id: String)

## Emitted after a tool execution result has been sent back to Voxide.
signal tool_completed(tool_name: String, result: Dictionary)

## Emitted when a tool requires confirmation before execution.
signal tool_confirmation_requested(tool: VoxideTool, arguments: Dictionary)

## Emitted when the AI speaking state changes.
signal speaking_changed(is_speaking: bool)

## Emitted each process frame with the microphone input level (0.0 - 1.0).
signal input_level_changed(level: float)

## Emitted each process frame with the audio output level (0.0 - 1.0).
signal output_level_changed(level: float)

## Emitted whenever the connection/session state changes.
signal state_changed(new_state: VoxideConstants.State)

## Emitted on any runtime error.
signal error_occurred(error: String)


# -- Inspector: Connection -----------------------------------------------------

@export_group("Connection")

## Voxide public key (vox_pub_...).
## Leave empty to read VOXIDE_API_KEY from the DotEnv autoload (.env file).
@export var public_key: String = ""

## Override the Voxide API base URL. Leave empty for the default.
@export var base_url: String = ""

## Automatically call initialize() when this node enters the scene tree.
@export var auto_initialize: bool = true

## Automatically call connect_to_voxide() after initialization completes.
@export var auto_connect: bool = true

## Automatically reconnect after an unexpected disconnection.
@export var auto_reconnect: bool = false

## Delay in seconds between auto-reconnect attempts.
@export_range(1.0, 30.0, 0.5) var reconnect_delay: float = 3.0


# -- Inspector: Identity -------------------------------------------------------

@export_group("Identity")

## Optional user data Dictionary sent with each session for personalization.
@export var user_data: Dictionary = {}


# -- Internal state ------------------------------------------------------------

var _state: VoxideConstants.State = VoxideConstants.State.IDLE
var _transport: VoxideTransport = null
var _audio: VoxideAudio = null
var _tools: Dictionary = {}            # tool_name -> VoxideTool
var _state_mgr: VoxideState = VoxideState.new()
var _messages: Array[VoxideMessage] = []
var _session_id: String = ""
var _anon_id: String = ""
var _is_initialized := false
var _pending_ai_text := ""
var _pending_user_text := ""
var _reconnect_timer := 0.0
var _wants_reconnect := false
var _resolved_key := ""
var _resolved_base_url := ""
var _pending_text_sends: Array[String] = []
var _ptt_enabled: bool = true
var _ptt_active: bool = false
var _thinking_timer: float = 0.0


# -- State accessor ------------------------------------------------------------

## The VoxideState manager. Use this to inject dynamic game state.
## Example: ai.state.provider = func(): return { "health": player.health }
var state: VoxideState:
	get:
		return _state_mgr


# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	_anon_id = _generate_anon_id()
	if auto_initialize:
		initialize()


func _process(delta: float) -> void:
	if _transport:
		_transport.poll(delta)
		input_level_changed.emit(_transport.get_input_level())
		output_level_changed.emit(_transport.get_output_level())

	if _state == VoxideConstants.State.THINKING:
		_thinking_timer += delta
		if _thinking_timer > 10.0:
			_thinking_timer = 0.0
			_set_state(VoxideConstants.State.ARMED if _ptt_enabled else VoxideConstants.State.LISTENING)
	else:
		_thinking_timer = 0.0

	if _wants_reconnect and auto_reconnect:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_wants_reconnect = false
			connect_to_voxide()


# -- Public API ----------------------------------------------------------------

## Resolve the public key, fetch agent config, and sync the manifest.
## Must complete before connect_to_voxide() is called.
func initialize() -> void:
	if _is_initialized:
		return
	_resolved_key = _resolve_public_key()
	if _resolved_key.is_empty():
		push_error("[VoxideClient] No public key set. Set public_key in the Inspector or add VOXIDE_API_KEY to your .env file.")
		error_occurred.emit("No public key configured.")
		return
	_resolved_base_url = base_url.strip_edges().rstrip("/")
	if _resolved_base_url.is_empty():
		_resolved_base_url = VoxideConstants.DEFAULT_BASE_URL

	_set_state(VoxideConstants.State.CONNECTING)
	_http_init()


## Open a live voice session with Voxide.
func connect_to_voxide() -> void:
	if not _is_initialized:
		auto_connect = true
		if _state != VoxideConstants.State.CONNECTING:
			initialize()
		return
	if _transport and _transport.is_connected_to_session():
		return
	_setup_transport()
	connecting.emit()
	_set_state(VoxideConstants.State.CONNECTING)
	var ws_url := VoxideNativePlatform.build_ws_url(_resolved_base_url, _resolved_key, _anon_id)
	_transport.connect_to_session(ws_url, _resolved_key)


## Close the active live session.
func disconnect_from_voxide() -> void:
	_wants_reconnect = false
	if _transport:
		_transport.disconnect_from_session()


## Send a text message to the AI without using voice.
## If not yet connected, queues the message and connects automatically.
func send_text(text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return

	# Record and emit user message locally immediately so UI displays it without delay.
	var user_msg := VoxideMessage.create(VoxideMessage.Role.USER, clean)
	_messages.append(user_msg)
	message_received.emit(user_msg)

	if _transport and _transport.is_connected_to_session():
		var state_snap := _state_mgr.get_snapshot()
		_transport.send_message({
			"type": VoxideConstants.MSG_TEXT_INPUT,
			"text": clean,
			"state": state_snap,
		})
		_set_state(VoxideConstants.State.THINKING)
	else:
		_pending_text_sends.append(clean)
		connect_to_voxide()


## Enable or disable Push-To-Talk mode on the audio subsystem.
func set_ptt_enabled(enabled: bool) -> void:
	_ptt_enabled = enabled
	if _audio:
		_audio.ptt_enabled = enabled
	if _state in [VoxideConstants.State.ARMED, VoxideConstants.State.LISTENING]:
		_set_state(VoxideConstants.State.ARMED if (_ptt_enabled and not _ptt_active) else VoxideConstants.State.LISTENING)


## Activate or deactivate Push-To-Talk microphone streaming.
func set_ptt_active(active: bool) -> void:
	_ptt_active = active
	if _audio:
		_audio.set_ptt_active(active)
	if active:
		if _state in [VoxideConstants.State.SPEAKING, VoxideConstants.State.THINKING, VoxideConstants.State.EXECUTING]:
			interrupt()
		elif _state in [VoxideConstants.State.ARMED, VoxideConstants.State.IDLE, VoxideConstants.State.ERROR]:
			_set_state(VoxideConstants.State.LISTENING)
	else:
		if _state == VoxideConstants.State.LISTENING:
			_set_state(VoxideConstants.State.THINKING if _ptt_enabled else VoxideConstants.State.LISTENING)


## Returns true if Push-To-Talk is currently pressed/active.
func is_ptt_active() -> bool:
	return _ptt_active


## Interrupt the current AI speech.
func interrupt() -> void:
	if _transport:
		_transport.send_message({ "type": VoxideConstants.MSG_INTERRUPT })
	if _audio:
		_audio.stop_playback()
	_set_state(VoxideConstants.State.LISTENING)
	speaking_changed.emit(false)


## Register a VoxideTool so the AI can call it.
func register_tool(tool: VoxideTool) -> void:
	if not tool.is_valid():
		push_warning("[VoxideClient] Tool '%s' is invalid (missing name or description)." % tool.tool_name)
		return
	_tools[tool.tool_name] = tool
	# If already connected via web transport, register on the JS side immediately.
	if _transport is VoxideWebTransport:
		(_transport as VoxideWebTransport).register_tool(tool)


## Unregister a previously registered tool.
func unregister_tool(tool_name: String) -> void:
	_tools.erase(tool_name)


## Set user identity data sent with the session.
func set_user(data: Dictionary) -> void:
	user_data = data


## Set the active route scope for scoped tools.
func set_active_route(route: String) -> void:
	if _transport is VoxideWebTransport:
		(_transport as VoxideWebTransport).set_active_route(route)


## Returns a snapshot Dictionary with current session information.
func get_snapshot() -> Dictionary:
	return {
		"state": VoxideConstants.STATE_NAMES.get(_state, "idle"),
		"session_id": _session_id,
		"message_count": _messages.size(),
		"initialized": _is_initialized,
		"platform": OS.get_name(),
	}


## Returns the current microphone input level (0.0 - 1.0).
func get_input_level() -> float:
	return _transport.get_input_level() if _transport else 0.0


## Returns the current audio output level (0.0 - 1.0).
func get_output_level() -> float:
	return _transport.get_output_level() if _transport else 0.0


## Returns all messages in the current session.
func get_messages() -> Array[VoxideMessage]:
	return _messages.duplicate()


## Returns true if the named feature is supported on this platform.
func is_feature_supported(feature: String) -> bool:
	return VoxideNativePlatform.is_feature_supported(feature)


## Returns a Dictionary of capabilities for the current platform.
func get_platform_capabilities() -> Dictionary:
	return VoxideNativePlatform.get_capabilities()


## Returns the current connection/session state.
func get_state() -> VoxideConstants.State:
	return _state


## Provide confirmation for a pending tool call (tool_confirmation_requested signal).
## Call with allow=true to proceed, allow=false to cancel.
func confirm_tool(tool_name: String, allow: bool) -> void:
	if allow:
		_execute_tool_call(tool_name, _pending_confirmations.get(tool_name, {}), "")
	else:
		var result := { "status": "cancelled", "message": "User cancelled." }
		_send_tool_result(tool_name, result, _pending_confirmation_ids.get(tool_name, ""))
	_pending_confirmations.erase(tool_name)
	_pending_confirmation_ids.erase(tool_name)

var _pending_confirmations: Dictionary = {}
var _pending_confirmation_ids: Dictionary = {}


# -- Internal: Initialization --------------------------------------------------

func _resolve_public_key() -> String:
	if not public_key.is_empty():
		return public_key
	# Read from DotEnv autoload dependency.
	if Engine.has_singleton("DotEnv") or get_node_or_null("/root/DotEnv") != null:
		var dot_env = get_node("/root/DotEnv")
		if dot_env.has_method("get_env"):
			var key: String = dot_env.get_env("VOXIDE_API_KEY")
			if not key.is_empty():
				return key
	# Check OS environment directly.
	var env_key := OS.get_environment("VOXIDE_API_KEY")
	if not env_key.is_empty():
		return env_key
	# Direct fallback: parse res://.env directly.
	if FileAccess.file_exists("res://.env"):
		var f := FileAccess.open("res://.env", FileAccess.READ)
		if f:
			while not f.eof_reached():
				var line := f.get_line().strip_edges()
				if line.begins_with("VOXIDE_API_KEY=") or line.begins_with("VOXIDE_PUBLIC_KEY="):
					var parts := line.split("=", false, 1)
					if parts.size() == 2:
						var val := parts[1].strip_edges().trim_prefix('"').trim_suffix('"').trim_prefix("'").trim_suffix("'")
						if not val.is_empty():
							return val
	return ""


func _http_init() -> void:
	var url := "%s%s" % [_resolved_base_url, VoxideConstants.HTTP_INIT_PATH]
	var headers := ["Authorization: Bearer %s" % _resolved_key]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, _hdrs, body):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			push_error("[VoxideClient] Init request failed (HTTP %d)." % code)
			error_occurred.emit("Initialization failed (HTTP %d)." % code)
			_set_state(VoxideConstants.State.ERROR)
			return
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			var config: Dictionary = (parsed as Dictionary).get("config", {})
			_on_init_success(config)
		else:
			_on_init_success({})
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


func _on_init_success(config: Dictionary) -> void:
	_is_initialized = true
	_set_state(VoxideConstants.State.IDLE)
	initialized.emit()
	_sync_manifest()
	if auto_connect:
		connect_to_voxide()


func _sync_manifest() -> void:
	var url := "%s%s" % [_resolved_base_url, VoxideConstants.HTTP_MANIFEST_PATH]
	var headers := [
		"Authorization: Bearer %s" % _resolved_key,
		"Content-Type: application/json",
	]
	var tool_list: Array = []
	for tool in _tools.values():
		tool_list.append(tool.to_manifest())
	var body := JSON.stringify({
		"actions": tool_list,
		"stateSchema": _state_mgr.get_snapshot().keys(),
		"environment": "development" if OS.is_debug_build() else "production",
	})
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, _code, _hdrs, _body): http.queue_free())
	http.request(url, headers, HTTPClient.METHOD_POST, body)


# -- Internal: Transport -------------------------------------------------------

func _setup_transport() -> void:
	if _transport:
		_transport.connected.disconnect(_on_transport_connected)
		_transport.disconnected.disconnect(_on_transport_disconnected)
		_transport.error_occurred.disconnect(_on_transport_error)
		_transport.message_received.disconnect(_on_message)
		_transport = null

	if OS.has_feature("web"):
		var web_t := VoxideWebTransport.new()
		web_t.init_client(_resolved_key, _resolved_base_url)
		# Register all tools on JS side.
		for tool in _tools.values():
			web_t.register_tool(tool)
		_transport = web_t
	else:
		if not _audio:
			_audio = VoxideAudio.new()
			_audio.ptt_enabled = _ptt_enabled
			_audio.set_ptt_active(_ptt_active)
			add_child(_audio)
			_audio.playback_finished.connect(_on_audio_playback_finished)
		_transport = VoxideNativeTransport.new(_audio)

	_transport.connected.connect(_on_transport_connected)
	_transport.disconnected.connect(_on_transport_disconnected)
	_transport.error_occurred.connect(_on_transport_error)
	_transport.message_received.connect(_on_message)


# -- Internal: Transport callbacks ---------------------------------------------

func _on_transport_connected() -> void:
	_session_id = ""
	_pending_ai_text = ""
	_pending_user_text = ""
	_set_state(VoxideConstants.State.LISTENING if (not _ptt_enabled or _ptt_active) else VoxideConstants.State.ARMED)
	connected.emit()

	# Flush queued text messages that were submitted prior to connection opening.
	while not _pending_text_sends.is_empty():
		var queued_text := _pending_text_sends.pop_front()
		var state_snap := _state_mgr.get_snapshot()
		_transport.send_message({
			"type": VoxideConstants.MSG_TEXT_INPUT,
			"text": queued_text,
			"state": state_snap,
		})
		_set_state(VoxideConstants.State.THINKING)


func _on_transport_disconnected() -> void:
	_set_state(VoxideConstants.State.IDLE)
	disconnected.emit()
	if auto_reconnect and not _wants_reconnect:
		_wants_reconnect = true
		_reconnect_timer = reconnect_delay


func _on_audio_playback_finished() -> void:
	if _state == VoxideConstants.State.SPEAKING:
		_set_state(VoxideConstants.State.LISTENING if (not _ptt_enabled or _ptt_active) else VoxideConstants.State.ARMED)
		speaking_changed.emit(false)


func _on_transport_error(msg: String) -> void:
	push_error("[VoxideClient] Transport error: %s" % msg)
	var sys_msg := VoxideMessage.create(VoxideMessage.Role.SYSTEM, "Connection error: %s" % msg)
	_messages.append(sys_msg)
	message_received.emit(sys_msg)
	_set_state(VoxideConstants.State.ERROR)
	connection_error.emit(msg)
	error_occurred.emit(msg)


func _on_message(data: Dictionary) -> void:
	var type: String = data.get("type", "")
	match type:
		VoxideConstants.MSG_READY:
			var sid: String = data.get("sessionId", "")
			if not sid.is_empty():
				_session_id = sid
			if _state == VoxideConstants.State.CONNECTING:
				_set_state(VoxideConstants.State.LISTENING if (not _ptt_enabled or _ptt_active) else VoxideConstants.State.ARMED)

		VoxideConstants.MSG_TEXT:
			_thinking_timer = 0.0
			var chunk: String = data.get("text", "")
			_pending_ai_text += chunk
			var is_final: bool = data.get("turnComplete", false)
			transcript_received.emit(_pending_ai_text, is_final)
			_upsert_partial_message(VoxideMessage.Role.AI, _pending_ai_text)
			if is_final:
				_finalize_message(VoxideMessage.Role.AI, _pending_ai_text)
				_pending_ai_text = ""

		VoxideConstants.MSG_TEXT_USER:
			_thinking_timer = 0.0
			var chunk: String = data.get("text", "")
			_pending_user_text += chunk
			var is_final: bool = data.get("turnComplete", false)
			_upsert_partial_message(VoxideMessage.Role.USER, _pending_user_text)
			message_received.emit(_messages[-1])
			if is_final:
				_finalize_message(VoxideMessage.Role.USER, _pending_user_text)
				_pending_user_text = ""

		VoxideConstants.MSG_AUDIO:
			_thinking_timer = 0.0
			_set_state(VoxideConstants.State.SPEAKING)
			speaking_changed.emit(true)

		VoxideConstants.MSG_TOOL_CALL:
			_thinking_timer = 0.0
			_flush_pending_ai_text()
			_set_state(VoxideConstants.State.EXECUTING)
			var tool_name: String = data.get("name", "")
			var args: Dictionary = data.get("args", {})
			var call_id: String = data.get("id", "")
			tool_called.emit(tool_name, args, call_id)
			await _handle_tool_call(tool_name, args, call_id)

		VoxideConstants.MSG_INTERRUPTED:
			_thinking_timer = 0.0
			_set_state(VoxideConstants.State.LISTENING if (not _ptt_enabled or _ptt_active) else VoxideConstants.State.ARMED)
			speaking_changed.emit(false)

		VoxideConstants.MSG_TURN_COMPLETE:
			_thinking_timer = 0.0
			_flush_pending_user_text()
			_flush_pending_ai_text()
			if not (_audio and _audio.is_playing_audio()) and _state != VoxideConstants.State.EXECUTING:
				_set_state(VoxideConstants.State.LISTENING if (not _ptt_enabled or _ptt_active) else VoxideConstants.State.ARMED)

		VoxideConstants.MSG_ERROR:
			_thinking_timer = 0.0
			var err_msg: String = data.get("message", "Server error")
			push_error("[VoxideClient] Server error: %s" % err_msg)
			var display_msg: String = "Server error: %s" % err_msg
			if err_msg == "usage_limit":
				display_msg = "API usage limit reached for this key. Please check your key in .env"
				push_error("[VoxideClient] API usage limit reached for this key or account. Stopping session.")
			var sys_msg := VoxideMessage.create(VoxideMessage.Role.SYSTEM, display_msg)
			_messages.append(sys_msg)
			message_received.emit(sys_msg)
			_wants_reconnect = false
			_set_state(VoxideConstants.State.ERROR)
			error_occurred.emit(err_msg)
			if _transport:
				_transport.disconnect_from_session()

		"status_update":
			# Emitted by VoxideWebTransport — map JS status strings to our state enum.
			_apply_js_status(data.get("status", ""))


# -- Internal: Tool execution --------------------------------------------------

func _handle_tool_call(tool_name: String, args: Dictionary, call_id: String) -> void:
	var tool: VoxideTool = _tools.get(tool_name)
	if tool == null:
		_send_tool_result(tool_name, { "status": "error", "message": "Tool '%s' not registered." % tool_name }, call_id)
		return

	if tool.dangerous or tool.requires_confirmation:
		_pending_confirmations[tool_name] = args
		_pending_confirmation_ids[tool_name] = call_id
		tool_confirmation_requested.emit(tool, args)
		return

	_execute_tool_call(tool_name, args, call_id)


func _execute_tool_call(tool_name: String, args: Dictionary, call_id: String) -> void:
	var tool: VoxideTool = _tools.get(tool_name)
	if tool == null or not tool.handler.is_valid():
		_send_tool_result(tool_name, { "status": "error", "message": "No handler bound." }, call_id)
		return
	var result: Variant = tool.handler.call(args)
	var result_dict: Dictionary
	if result is Dictionary:
		result_dict = result
	else:
		result_dict = { "status": "success", "result": str(result) }
	_send_tool_result(tool_name, result_dict, call_id)
	tool_completed.emit(tool_name, result_dict)


func _send_tool_result(tool_name: String, result: Dictionary, call_id: String) -> void:
	var state_snap := _state_mgr.get_snapshot()
	if _transport is VoxideWebTransport:
		(_transport as VoxideWebTransport).send_tool_result(tool_name, result)
	else:
		_transport.send_message({
			"type": VoxideConstants.MSG_TOOL_RESULT,
			"id": call_id,
			"name": tool_name,
			"result": result,
			"state": state_snap,
		})
	_set_state(VoxideConstants.State.THINKING)


# -- Internal: Message management ----------------------------------------------

func _upsert_partial_message(role: VoxideMessage.Role, text: String) -> void:
	if _messages.size() > 0 and _messages[-1].role == role and _messages[-1].partial:
		_messages[-1].text = text
	else:
		_messages.append(VoxideMessage.create(role, text, true))


func _finalize_message(role: VoxideMessage.Role, text: String) -> void:
	if _messages.size() > 0 and _messages[-1].role == role and _messages[-1].partial:
		_messages[-1].text = text
		_messages[-1].partial = false
	else:
		var msg := VoxideMessage.create(role, text)
		_messages.append(msg)
	var final_msg := _messages[-1]
	message_received.emit(final_msg)


func _flush_pending_ai_text() -> void:
	if not _pending_ai_text.is_empty():
		_finalize_message(VoxideMessage.Role.AI, _pending_ai_text)
		_pending_ai_text = ""


func _flush_pending_user_text() -> void:
	if not _pending_user_text.is_empty():
		_finalize_message(VoxideMessage.Role.USER, _pending_user_text)
		_pending_user_text = ""


# -- Internal: State -----------------------------------------------------------

func _set_state(new_state: VoxideConstants.State) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(new_state)
	if new_state != VoxideConstants.State.SPEAKING:
		speaking_changed.emit(false)


func _apply_js_status(js_status: String) -> void:
	match js_status:
		"idle":      _set_state(VoxideConstants.State.IDLE)
		"armed":     _set_state(VoxideConstants.State.ARMED)
		"connecting":_set_state(VoxideConstants.State.CONNECTING)
		"listening": _set_state(VoxideConstants.State.LISTENING)
		"thinking":  _set_state(VoxideConstants.State.THINKING)
		"speaking":
			_set_state(VoxideConstants.State.SPEAKING)
			speaking_changed.emit(true)
		"executing": _set_state(VoxideConstants.State.EXECUTING)
		"error":     _set_state(VoxideConstants.State.ERROR)


# -- Internal: Utilities -------------------------------------------------------

func _generate_anon_id() -> String:
	return "anon_%s%s" % [
		str(randi()).substr(0, 6),
		str(int(Time.get_unix_time_from_system())).substr(-6),
	]
