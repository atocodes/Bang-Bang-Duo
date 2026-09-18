## VoxideWebTransport
## VoxideTransport implementation for Godot Web exports.
## Delegates all communication to VoxideWebBridge (and thus to voxide_web.js).
class_name VoxideWebTransport
extends VoxideTransport


var _bridge: VoxideWebBridge = null
var _is_connected := false
var _input_level := 0.0
var _output_level := 0.0


func _init() -> void:
	_bridge = VoxideWebBridge.new()
	_bridge.event_received.connect(_on_bridge_event)


# -- VoxideTransport overrides -------------------------------------------------

func connect_to_session(ws_url: String, public_key: String) -> void:
	# The web SDK resolves its own URL from the public key and base URL.
	# ws_url is unused here — the JS SDK handles WebSocket internally.
	_bridge.connect_session()


func disconnect_from_session() -> void:
	_bridge.disconnect_session()
	_is_connected = false


func send_message(data: Dictionary) -> void:
	# Route specific messages to appropriate bridge calls.
	var type: String = data.get("type", "")
	match type:
		VoxideConstants.MSG_TEXT_INPUT:
			_bridge.send_text(data.get("text", ""))
		VoxideConstants.MSG_INTERRUPT:
			_bridge.interrupt()
		_:
			push_warning("[VoxideWebTransport] Unhandled outbound message type: %s" % type)


func is_connected_to_session() -> bool:
	return _is_connected


func get_input_level() -> float:
	return _bridge.get_input_level()


func get_output_level() -> float:
	return _bridge.get_output_level()


func poll(_delta: float) -> void:
	pass  # JS bridge is event-driven; no polling needed.


# -- Web-specific API ----------------------------------------------------------

## Initialize the Voxide JS client. Must be called before connect_to_session().
func init_client(public_key: String, base_url: String) -> void:
	_bridge.init_client(public_key, base_url)


## Register a VoxideTool on the JavaScript side.
func register_tool(tool: VoxideTool) -> void:
	_bridge.register_tool(tool)


## Send a tool execution result back after a tool_call event.
func send_tool_result(tool_name: String, result: Dictionary) -> void:
	_bridge.send_tool_result(tool_name, result)


## Push state to the JS bridge.
func set_state(state: Dictionary) -> void:
	_bridge.set_state(state)


## Set active route scope.
func set_active_route(route: String) -> void:
	_bridge.set_active_route(route)


# -- Internal ------------------------------------------------------------------

func _on_bridge_event(type: String, payload: Dictionary) -> void:
	match type:
		"ready":
			_is_connected = true
			connected.emit()
		"status":
			# Re-map JS status string to a message_received event so VoxideClient
			# can process it uniformly alongside native transport messages.
			message_received.emit({ "type": "status_update", "status": payload.get("status", "") })
		"transcript":
			message_received.emit({
				"type": VoxideConstants.MSG_TEXT if payload.get("role") == "ai" else VoxideConstants.MSG_TEXT_USER,
				"text": payload.get("text", ""),
				"turnComplete": not payload.get("partial", false),
			})
		"message":
			message_received.emit({
				"type": "message_complete",
				"role": payload.get("role", "ai"),
				"text": payload.get("text", ""),
			})
		"action":
			# Tool calls routed through the unified message pipeline.
			message_received.emit({
				"type": VoxideConstants.MSG_TOOL_CALL,
				"name": payload.get("name", ""),
				"args": payload.get("args", {}),
				"id": payload.get("id", ""),
			})
		"tool_call":
			message_received.emit({
				"type": VoxideConstants.MSG_TOOL_CALL,
				"name": payload.get("name", ""),
				"args": payload.get("args", {}),
				"id": "",
			})
		"error":
			error_occurred.emit(payload.get("message", "Unknown error"))
		_:
			message_received.emit(payload)
