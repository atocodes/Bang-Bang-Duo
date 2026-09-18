## VoxideConstants
## Global constants for the Voxide plugin.
class_name VoxideConstants


const PLUGIN_VERSION := "1.0.0"
const PLUGIN_NAME := "Voxide"

const DEFAULT_BASE_URL := "https://voxide.onrender.com"
const WS_LIVE_PATH := "/api/sdk/live"
const HTTP_INIT_PATH := "/api/sdk/init"
const HTTP_MANIFEST_PATH := "/api/sdk/manifest"
const HTTP_FEEDBACK_PATH := "/api/sdk/feedback"

const AUDIO_INPUT_SAMPLE_RATE := 16000
const AUDIO_OUTPUT_SAMPLE_RATE := 24000
const AUDIO_CHUNK_SIZE := 2048
const AUDIO_ANALYSER_FFT := 512

## VoxideClient connection / session state strings.
enum State {
	IDLE,
	ARMED,
	CONNECTING,
	LISTENING,
	THINKING,
	SPEAKING,
	EXECUTING,
	ERROR,
}

const STATE_NAMES := {
	State.IDLE: "Idle",
	State.ARMED: "Armed",
	State.CONNECTING: "Connecting",
	State.LISTENING: "Listening",
	State.THINKING: "Thinking",
	State.SPEAKING: "Speaking",
	State.EXECUTING: "Executing",
	State.ERROR: "Error",
}

## WebSocket message types (client -> server).
const MSG_AUDIO_INPUT := "audio_input"
const MSG_TEXT_INPUT := "text_input"
const MSG_INTERRUPT := "interrupt"
const MSG_TOOL_RESULT := "tool_result"

## WebSocket message types (server -> client).
const MSG_READY := "ready"
const MSG_TEXT := "text"
const MSG_TEXT_USER := "text_user"
const MSG_AUDIO := "audio"
const MSG_TOOL_CALL := "tool_call"
const MSG_INTERRUPTED := "interrupted"
const MSG_ERROR := "error"
const MSG_TURN_COMPLETE := "turn_complete"
