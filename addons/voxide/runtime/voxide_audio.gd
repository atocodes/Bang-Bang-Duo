## VoxideAudio
## Handles microphone capture, linear downsampling to 16 kHz PCM-16,
## echo suppression, push-to-talk, and 24 kHz audio playback for native Godot targets.
## On Web exports this node is bypassed — the Voxide JS SDK handles WebRTC audio directly.
class_name VoxideAudio
extends Node


## Emitted with base64-encoded 16 kHz PCM-16 audio chunks ready for transmission.
signal audio_chunk_ready(base64_pcm: String)

## Emitted each frame with the current microphone input level (RMS, 0.0-1.0).
signal input_level_changed(level: float)

## Emitted each frame with the current playback output level (RMS, 0.0-1.0).
signal output_level_changed(level: float)

## Emitted when playback of all queued audio chunks has completed.
signal playback_finished()


const CAPTURE_BUS_NAME := "VoxideCapture"
const PLAYBACK_BUS_NAME := "VoxidePlayback"
## Target sample rate required by Voxide (PCM-16 mono at 16 kHz).
const TARGET_SAMPLE_RATE := 16000
## Output playback rate expected from Voxide audio chunks (24 kHz).
const OUTPUT_SAMPLE_RATE := 24000
## 1024 samples at 16 kHz = 64 ms per chunk for ultra-low latency response.
const TARGET_CHUNK_SAMPLES := 1024
const TARGET_CHUNK_BYTES := TARGET_CHUNK_SAMPLES * 2

## If true, suppresses microphone transmission while the assistant audio is actively playing
## through the speakers. Prevents acoustic feedback loops on native desktop/mobile targets.
@export var mute_mic_while_speaking: bool = true

## When enabled, microphone audio is only sent when set_ptt_active(true) is called.
@export var ptt_enabled: bool = true

var _capture_bus_idx := -1
var _playback_bus_idx := -1
var _mic_player: AudioStreamPlayer = null
var _capture_effect: AudioEffectCapture = null
var _out_player: AudioStreamPlayer = null
var _output_generator: AudioStreamGeneratorPlayback = null

var _recording := false
var _input_level := 0.0
var _output_level := 0.0
var _pcm16_accumulator: PackedByteArray = PackedByteArray()
var _playback_queue: PackedVector2Array = PackedVector2Array()
var _is_playing_audio := false
var _playback_seconds_remaining := 0.0
var _ptt_active := false
var _silence_tail_chunks_remaining: int = 0
var _silence_timer: float = 0.0


func _ready() -> void:
	_setup_audio_buses()
	_ensure_capture_player()
	start_capture()


func _process(delta: float) -> void:
	if _recording:
		_process_capture(delta)
	_process_playback(delta)


# -- Public API ----------------------------------------------------------------

## Set Push-To-Talk active state.
func set_ptt_active(active: bool) -> void:
	if _ptt_active and not active:
		# User released PTT: stream ~900ms of clean silence (14 chunks of 64ms)
		# so the server-side Voice Activity Detector reliably detects end of speech.
		_silence_tail_chunks_remaining = 14
		_silence_timer = 0.0
	elif active:
		_silence_tail_chunks_remaining = 0
		_silence_timer = 0.0

	_ptt_active = active
	if not active:
		_pcm16_accumulator.clear()
		if _input_level != 0.0:
			_input_level = 0.0
			input_level_changed.emit(0.0)


## Returns true if Push-To-Talk is currently pressed/active.
func is_ptt_active() -> bool:
	return _ptt_active


## Begin microphone capture.
func start_capture() -> void:
	if _recording:
		return
	_ensure_capture_player()
	if _capture_effect == null:
		push_error("[VoxideAudio] AudioEffectCapture not available — cannot start microphone.")
		return
	_pcm16_accumulator.clear()
	_mic_player.play()
	_recording = true


## Stop microphone capture.
func stop_capture() -> void:
	if not _recording:
		return
	_recording = false
	_silence_tail_chunks_remaining = 0
	_silence_timer = 0.0
	_pcm16_accumulator.clear()
	if _mic_player:
		_mic_player.stop()
	_input_level = 0.0
	input_level_changed.emit(0.0)


## Decode and queue a base64 PCM-16 24 kHz chunk for playback.
func play_audio_chunk(base64_pcm: String) -> void:
	if base64_pcm.is_empty():
		return
	var raw := Marshalls.base64_to_raw(base64_pcm)
	var sample_count := raw.size() / 2
	if sample_count <= 0:
		return

	var float_samples := PackedVector2Array()
	float_samples.resize(sample_count)

	var sum_sq := 0.0
	for i in sample_count:
		var lo := raw[i * 2]
		var hi := raw[i * 2 + 1]
		var sample_i16 := (hi << 8) | lo
		if sample_i16 > 32767:
			sample_i16 -= 65536
		var f := clampf(float(sample_i16) / 32768.0, -1.0, 1.0)
		sum_sq += f * f
		float_samples[i] = Vector2(f, f)

	_output_level = clampf(sqrt(sum_sq / float(sample_count)) * 2.0, 0.1, 1.0)
	output_level_changed.emit(_output_level)

	_ensure_output_player()
	_playback_queue.append_array(float_samples)

	# Accurately increment playback time by chunk duration.
	var chunk_duration := float(sample_count) / float(OUTPUT_SAMPLE_RATE)
	_playback_seconds_remaining += chunk_duration
	_is_playing_audio = true


## Stop in-progress audio playback immediately.
func stop_playback() -> void:
	_playback_queue.clear()
	_playback_seconds_remaining = 0.0
	if _out_player and _out_player.playing:
		_out_player.stop()
	if _output_generator:
		_output_generator.clear_buffer()
	_output_level = 0.0
	output_level_changed.emit(0.0)
	if _is_playing_audio:
		_is_playing_audio = false
		playback_finished.emit()


func is_playing_audio() -> bool:
	return _is_playing_audio


func get_input_level() -> float:
	return _input_level


func get_output_level() -> float:
	return _output_level


# -- Internal: Buses and Players -----------------------------------------------

func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index(CAPTURE_BUS_NAME) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, CAPTURE_BUS_NAME)
		AudioServer.set_bus_mute(idx, true)
		var effect := AudioEffectCapture.new()
		effect.buffer_length = 0.5
		AudioServer.add_bus_effect(idx, effect)
	_capture_bus_idx = AudioServer.get_bus_index(CAPTURE_BUS_NAME)

	if AudioServer.get_bus_index(PLAYBACK_BUS_NAME) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, PLAYBACK_BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
	_playback_bus_idx = AudioServer.get_bus_index(PLAYBACK_BUS_NAME)


func _ensure_capture_player() -> void:
	if _mic_player:
		return
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = CAPTURE_BUS_NAME
	add_child(_mic_player)
	if _capture_bus_idx >= 0 and AudioServer.get_bus_effect_count(_capture_bus_idx) > 0:
		_capture_effect = AudioServer.get_bus_effect(_capture_bus_idx, 0) as AudioEffectCapture


func _ensure_output_player() -> void:
	if not _out_player:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = OUTPUT_SAMPLE_RATE
		gen.buffer_length = 2.0  # 2 seconds of buffer to prevent dropouts.
		_out_player = AudioStreamPlayer.new()
		_out_player.stream = gen
		_out_player.bus = PLAYBACK_BUS_NAME
		add_child(_out_player)
	if not _out_player.playing:
		_out_player.play()
	_output_generator = _out_player.get_stream_playback() as AudioStreamGeneratorPlayback


# -- Internal: Capture & Resampling --------------------------------------------

func _process_capture(delta: float) -> void:
	if _capture_effect == null:
		return
	var frames_available := _capture_effect.get_frames_available()

	if ptt_enabled and not _ptt_active:
		# Discard live mic audio while unkeyed so ambient room noise is not buffered.
		if frames_available > 0:
			_capture_effect.get_buffer(frames_available)
		_pcm16_accumulator.clear()
		if _input_level != 0.0:
			_input_level = 0.0
			input_level_changed.emit(0.0)

		# Send timed silence tail at 64ms pace to trigger server-side VAD turn completion.
		if _silence_tail_chunks_remaining > 0:
			_silence_timer += delta
			var chunk_duration := float(TARGET_CHUNK_SAMPLES) / float(TARGET_SAMPLE_RATE)
			while _silence_timer >= chunk_duration and _silence_tail_chunks_remaining > 0:
				_silence_timer -= chunk_duration
				_silence_tail_chunks_remaining -= 1
				var silence := PackedByteArray()
				silence.resize(TARGET_CHUNK_BYTES)
				silence.fill(0)
				audio_chunk_ready.emit(Marshalls.raw_to_base64(silence))
		return

	if frames_available <= 0:
		return

	var raw_frames: PackedVector2Array = _capture_effect.get_buffer(frames_available)
	var godot_rate := float(AudioServer.get_mix_rate())
	var ratio := godot_rate / float(TARGET_SAMPLE_RATE)
	var out_count := int(float(raw_frames.size()) / ratio)
	if out_count <= 0:
		return

	# High quality linear interpolation downsampling to 16 kHz.
	var new_pcm := PackedByteArray()
	new_pcm.resize(out_count * 2)

	var rms_sum := 0.0
	for i in out_count:
		var src_pos := float(i) * ratio
		var idx0 := clampi(int(src_pos), 0, raw_frames.size() - 1)
		var idx1 := clampi(idx0 + 1, 0, raw_frames.size() - 1)
		var frac := src_pos - float(idx0)

		var s0 := (raw_frames[idx0].x + raw_frames[idx0].y) * 0.5
		var s1 := (raw_frames[idx1].x + raw_frames[idx1].y) * 0.5
		var mono := clampf(lerpf(s0, s1, frac), -1.0, 1.0)
		rms_sum += mono * mono

		var i16 := clampi(int(mono * (32767.0 if mono >= 0.0 else 32768.0)), -32768, 32767)
		new_pcm[i * 2]     = i16 & 0xFF
		new_pcm[i * 2 + 1] = (i16 >> 8) & 0xFF

	_input_level = clampf(sqrt(rms_sum / float(out_count)) * 6.0, 0.0, 1.0)
	input_level_changed.emit(_input_level)

	_pcm16_accumulator.append_array(new_pcm)

	# Emit standard chunks of 1024 samples (2048 bytes = 64 ms).
	while _pcm16_accumulator.size() >= TARGET_CHUNK_BYTES:
		var chunk := _pcm16_accumulator.slice(0, TARGET_CHUNK_BYTES)
		_pcm16_accumulator = _pcm16_accumulator.slice(TARGET_CHUNK_BYTES)

		# Push-to-talk check: if PTT mode is enabled, only stream when PTT is active.
		if ptt_enabled and not _ptt_active:
			continue

		# Echo suppression: in continuous mode, suppress mic loopback if assistant is speaking.
		# In Push-To-Talk mode, user explicitly holds to talk, so never suppress.
		if not ptt_enabled and mute_mic_while_speaking and _is_playing_audio:
			continue

		# Energy gate: in continuous mode, skip ambient room silence (< 0.008 RMS) to prevent VAD lag.
		if not ptt_enabled and _input_level < 0.008:
			continue

		audio_chunk_ready.emit(Marshalls.raw_to_base64(chunk))


# -- Internal: Playback --------------------------------------------------------

func _process_playback(delta: float) -> void:
	if not _is_playing_audio:
		_output_level = lerpf(_output_level, 0.0, 0.2)
		output_level_changed.emit(_output_level)
		return

	# Deterministic timer-based playback completion.
	if _playback_seconds_remaining > 0.0:
		_playback_seconds_remaining -= delta
		if _playback_seconds_remaining <= 0.0:
			_playback_seconds_remaining = 0.0
			_is_playing_audio = false
			_output_level = 0.0
			output_level_changed.emit(0.0)
			playback_finished.emit()
	else:
		_playback_seconds_remaining = 0.0
		_is_playing_audio = false
		_output_level = 0.0
		output_level_changed.emit(0.0)
		playback_finished.emit()

	if _output_generator == null or _out_player == null:
		return

	var frames_free := _output_generator.get_frames_available()
	if frames_free > 0 and _playback_queue.size() > 0:
		var count := mini(frames_free, _playback_queue.size())
		var slice := _playback_queue.slice(0, count)
		_output_generator.push_buffer(slice)
		_playback_queue = _playback_queue.slice(count)


func _exit_tree() -> void:
	stop_capture()
	stop_playback()
	var cap := AudioServer.get_bus_index(CAPTURE_BUS_NAME)
	if cap >= 0:
		AudioServer.remove_bus(cap)
	var play := AudioServer.get_bus_index(PLAYBACK_BUS_NAME)
	if play >= 0:
		AudioServer.remove_bus(play)
