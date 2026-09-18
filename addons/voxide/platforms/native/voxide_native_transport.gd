## VoxideNativeTransport
## WebSocketPeer-based Voxide transport for native Godot export targets
## (Windows, Linux, macOS, Android, iOS).
##
## Protocol is derived from the official Voxide browser SDK source:
##   https://unpkg.com/@voxide/react@0.8.0/dist/voxide.browser.js
##
## WebSocket endpoint: wss://<host>/api/sdk/live?key=<publicKey>&anon=<anonId>
## Audio in:  JSON { type: "audio_input", data: "<base64 PCM-16 16kHz>" }
## Audio out: JSON { type: "audio",       data: "<base64 PCM-24 24kHz>" }
## Text in:   JSON { type: "text_input",  text: "...", state: {} }
## Interrupt: JSON { type: "interrupt" }
## Tool result: JSON { type: "tool_result", id, name, result, state }
class_name VoxideNativeTransport
extends VoxideTransport


## 4 MB buffer sizes to accommodate streaming PCM audio without WebSocket buffer overflows.
const WS_BUFFER_SIZE := 4 * 1024 * 1024
const WS_MAX_PACKETS := 4096
const MAX_SEND_QUEUE := 64

var _ws := WebSocketPeer.new()
var _connected := false
var _ws_url := ""
var _audio: VoxideAudio = null
var _send_queue: Array[String] = []


func _init(audio_node: VoxideAudio) -> void:
	_audio = audio_node
	if _audio:
		_audio.audio_chunk_ready.connect(_on_audio_chunk_ready)


# -- VoxideTransport overrides -------------------------------------------------

func connect_to_session(ws_url: String, _public_key: String) -> void:
	_ws_url = ws_url
	_send_queue.clear()
	_ws = WebSocketPeer.new()
	# Set buffer sizes BEFORE connect_to_url to avoid default 64KB ERR_OUT_OF_MEMORY overflows.
	_ws.inbound_buffer_size = WS_BUFFER_SIZE
	_ws.outbound_buffer_size = WS_BUFFER_SIZE
	_ws.max_queued_packets = WS_MAX_PACKETS

	var err := _ws.connect_to_url(ws_url)
	if err != OK:
		error_occurred.emit("WebSocket connect_to_url failed: %s" % error_string(err))
		return


func disconnect_from_session() -> void:
	_send_queue.clear()
	if _audio:
		_audio.stop_capture()
		_audio.stop_playback()
	if _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close(1000, "Client disconnect")
	_connected = false


func send_message(data: Dictionary) -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var json_str := JSON.stringify(data)
	_enqueue_or_send(json_str, data.get("type", "") == VoxideConstants.MSG_AUDIO_INPUT)


func is_connected_to_session() -> bool:
	return _connected and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func get_input_level() -> float:
	return _audio.get_input_level() if _audio else 0.0


func get_output_level() -> float:
	return _audio.get_output_level() if _audio else 0.0


func poll(_delta: float) -> void:
	# Flush queued outbound messages first.
	_flush_send_queue()

	_ws.poll()
	var state := _ws.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				connected.emit()
				if _audio:
					_audio.start_capture()
			_drain_packets()
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				_send_queue.clear()
				if _audio:
					_audio.stop_capture()
				var code := _ws.get_close_code()
				var reason := _ws.get_close_reason()
				if code != 1000 and not reason.is_empty():
					error_occurred.emit("WebSocket closed (%d): %s" % [code, reason])
				disconnected.emit()
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CONNECTING:
			pass


# -- Internal ------------------------------------------------------------------

func _enqueue_or_send(json_str: String, is_audio: bool) -> void:
	# If queue is empty, attempt immediate transmission.
	if _send_queue.is_empty():
		var err := _ws.send_text(json_str)
		if err == OK:
			return

	# If socket buffer was full or busy, queue the message.
	if _send_queue.size() >= MAX_SEND_QUEUE:
		if is_audio:
			# Real-time audio policy: drop oldest audio packet to prevent latency buildup.
			for i in _send_queue.size():
				if _send_queue[i].contains('"audio_input"'):
					_send_queue.remove_at(i)
					break
		else:
			# Critical control packets (tools/interrupts/text) must not be dropped.
			pass

	if _send_queue.size() < MAX_SEND_QUEUE:
		_send_queue.append(json_str)


func _flush_send_queue() -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	while not _send_queue.is_empty():
		var msg := _send_queue[0]
		var err := _ws.send_text(msg)
		if err == OK:
			_send_queue.remove_at(0)
		else:
			# Socket is congested, will retry on next poll.
			break


func _drain_packets() -> void:
	while _ws.get_available_packet_count() > 0:
		var packet := _ws.get_packet()
		var text := packet.get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			var data := parsed as Dictionary
			# Delegate audio playback to the audio node.
			if data.get("type") == VoxideConstants.MSG_AUDIO and _audio:
				_audio.play_audio_chunk(data.get("data", ""))
			message_received.emit(data)


func _on_audio_chunk_ready(base64_pcm: String) -> void:
	send_message({ "type": VoxideConstants.MSG_AUDIO_INPUT, "data": base64_pcm })
