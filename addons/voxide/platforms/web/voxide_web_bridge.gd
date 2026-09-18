## VoxideWebBridge
## GDScript wrapper that communicates with the Voxide JavaScript bridge
## (voxide_web.js) through Godot's JavaScript singleton.
## Only instantiated on Web exports. All JavaScript is isolated here.
class_name VoxideWebBridge
extends RefCounted


## Emitted when any event JSON is received from the JavaScript bridge.
signal event_received(type: String, payload: Dictionary)


var _js_callback: JavaScriptObject = null
var _bridge_available := false


func _init() -> void:
	if not OS.has_feature("web"):
		return
	if not ClassDB.class_exists("JavaScriptBridge"):
		push_warning("[VoxideWebBridge] JavaScriptBridge not available.")
		return
	_bridge_available = true
	# Create a persistent JS callback that the bridge will call.
	_js_callback = JavaScriptBridge.create_callback(_on_js_event)
	JavaScriptBridge.eval("if(window._VoxideBridge) window._VoxideBridge.setCallback(arguments[0]);", true)


## Initialize the Voxide JS client with the given public key and base URL.
func init_client(public_key: String, base_url: String) -> void:
	if not _bridge_available:
		return
	_js_call("window._VoxideBridge.init('%s', '%s');" % [public_key, base_url])


## Open a live session.
func connect_session() -> void:
	_js_call("window._VoxideBridge.connect();")


## Close the live session.
func disconnect_session() -> void:
	_js_call("window._VoxideBridge.disconnect();")


## Send a text message to the AI.
func send_text(text: String) -> void:
	var escaped := text.replace("'", "\\'")
	_js_call("window._VoxideBridge.sendText('%s');" % escaped)


## Interrupt the current AI speech.
func interrupt() -> void:
	_js_call("window._VoxideBridge.interrupt();")


## Register a tool on the JS side.
func register_tool(tool: VoxideTool) -> void:
	var json := JSON.stringify(tool.to_manifest())
	_js_call("window._VoxideBridge.registerTool(%s);" % json)


## Return a tool result to the JS bridge after GDScript handles a tool_call event.
func send_tool_result(tool_name: String, result: Dictionary) -> void:
	var escaped_result := JSON.stringify(result).replace("'", "\\'")
	_js_call("window._VoxideBridge.sendToolResult('%s', '%s');" % [tool_name, escaped_result])


## Push current state to the JS bridge.
func set_state(state: Dictionary) -> void:
	var escaped := JSON.stringify(state).replace("'", "\\'")
	_js_call("window._VoxideBridge.setState('%s');" % escaped)


## Set the active route for scoped tools.
func set_active_route(route: String) -> void:
	_js_call("window._VoxideBridge.setActiveRoute('%s');" % route)


## Returns the current input audio level from the JS bridge (0.0 - 1.0).
func get_input_level() -> float:
	if not _bridge_available:
		return 0.0
	var result = JavaScriptBridge.eval("window._VoxideBridge ? window._VoxideBridge.getInputLevel() : 0;")
	return float(result) if result != null else 0.0


## Returns the current output audio level from the JS bridge (0.0 - 1.0).
func get_output_level() -> float:
	if not _bridge_available:
		return 0.0
	var result = JavaScriptBridge.eval("window._VoxideBridge ? window._VoxideBridge.getOutputLevel() : 0;")
	return float(result) if result != null else 0.0


## Returns true if the JavaScript bridge is ready.
func is_available() -> bool:
	return _bridge_available


# -- Internal ------------------------------------------------------------------

func _js_call(code: String) -> void:
	if not _bridge_available:
		return
	JavaScriptBridge.eval(code)


func _on_js_event(args: Array) -> void:
	if args.is_empty():
		return
	var json_str: String = str(args[0])
	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Dictionary:
		var data := parsed as Dictionary
		event_received.emit(data.get("type", ""), data.get("payload", {}))
