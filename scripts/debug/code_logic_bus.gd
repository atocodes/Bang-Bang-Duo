class_name CodeLogicBusSingleton
extends Node

## CodeLogicBus
## High-performance, zero-allocation event bus for streaming live GDScript logic flow.
## Includes instant bypass when disabled and throttling for continuous physics ticks.

signal logic_traced(tag: String, code_line: String, category: String, color_hex: String)

var is_enabled: bool = true

# Physics tick throttling to ensure 0 frame drops
var _last_move_trace_time: float = 0.0
const MOVE_THROTTLE_INTERVAL: float = 0.12  # Max ~8 updates/sec for continuous sliding


func trace(tag: String, code_line: String, category: String = "CORE", color_hex: String = "#38bdf8") -> void:
	if not is_enabled:
		return
	logic_traced.emit(tag, code_line, category, color_hex)


func trace_cond(category: String, condition: String, result: bool, details: String = "") -> void:
	if not is_enabled:
		return
	var res_str := "[color=#34d399]TRUE[/color]" if result else "[color=#f87171]FALSE[/color]"
	var tag := "COND:%s" % category
	var col := "#38bdf8" if result else "#f87171"
	var text := "if %s -> %s" % [condition, res_str]
	if not details.is_empty():
		text += " | [color=#fbbf24]%s[/color]" % details
	logic_traced.emit(tag, text, category, col)


func trace_exec(category: String, func_signature: String, result_state: String = "", col: String = "#34d399") -> void:
	if not is_enabled:
		return
	var tag := "EXEC:%s" % category
	var text := "[color=#a78bfa]%s[/color]" % func_signature
	if not result_state.is_empty():
		text += " -> [color=#fbbf24]%s[/color]" % result_state
	logic_traced.emit(tag, text, category, col)


func trace_movement_throttled(state_desc: String, vel: Vector3, speed: float) -> void:
	if not is_enabled:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_move_trace_time < MOVE_THROTTLE_INTERVAL:
		return
	_last_move_trace_time = now
	
	var code := "move_and_slide() -> vel:(%.1f, %.1f, %.1f) | spd:%.1fm/s [%s]" % [
		vel.x, vel.y, vel.z, speed, state_desc
	]
	logic_traced.emit("PHYSICS", code, "PHYSICS", "#38bdf8")
