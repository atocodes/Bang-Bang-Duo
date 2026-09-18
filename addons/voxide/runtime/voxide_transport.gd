## VoxideTransport
## Abstract base class defining the transport interface.
## Concrete implementations: VoxideNativeTransport, VoxideWebTransport.
## VoxideClient selects the appropriate implementation automatically
## based on the current Godot export target.
class_name VoxideTransport
extends RefCounted


## Emitted when the transport successfully opens a connection.
signal connected

## Emitted when the transport closes (cleanly or on error).
signal disconnected

## Emitted on any transport-level error. Provides a human-readable message.
signal error_occurred(message: String)

## Emitted when a JSON message Dictionary is received from the server.
signal message_received(data: Dictionary)

## Emitted periodically with current input audio level (0.0 - 1.0).
signal input_level_changed(level: float)

## Emitted periodically with current output audio level (0.0 - 1.0).
signal output_level_changed(level: float)


## Open a connection to the Voxide live endpoint.
## Must emit [signal connected] on success or [signal error_occurred] on failure.
func connect_to_session(_ws_url: String, _public_key: String) -> void:
	push_error("VoxideTransport.connect_to_session() is abstract — use a concrete implementation.")


## Close the transport connection cleanly.
func disconnect_from_session() -> void:
	push_error("VoxideTransport.disconnect_from_session() is abstract — use a concrete implementation.")


## Send a pre-encoded JSON message Dictionary to the server.
func send_message(_data: Dictionary) -> void:
	push_error("VoxideTransport.send_message() is abstract — use a concrete implementation.")


## Send a raw audio chunk (PCM-16 base64 encoded) to the server.
func send_audio(_base64_pcm: String) -> void:
	send_message({ "type": VoxideConstants.MSG_AUDIO_INPUT, "data": _base64_pcm })


## Returns true if the transport currently has an open connection.
func is_connected_to_session() -> bool:
	return false


## Returns current microphone input level (0.0 - 1.0). Override in subclasses.
func get_input_level() -> float:
	return 0.0


## Returns current audio output level (0.0 - 1.0). Override in subclasses.
func get_output_level() -> float:
	return 0.0


## Called each process frame. Override for polling-based transports (e.g., WebSocketPeer).
func poll(_delta: float) -> void:
	pass
