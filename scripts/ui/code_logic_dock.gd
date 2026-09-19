class_name CodeLogicDock
extends Control

## CodeLogicDock
## Floating, 100% transparent live GDScript logic flow visualizer.
## High-performance implementation using pre-allocated label pooling,
## zero GC node instantiations during runtime, and auto-fading lines.

const MAX_VISIBLE_LINES: int = 7
const LINE_LIFETIME: float = 3.5

@onready var lines_container: VBoxContainer = $MarginContainer/LinesContainer
@onready var status_header: Label = $MarginContainer/HeaderRow/StatusHeader
@onready var toggle_hint: Label = $MarginContainer/HeaderRow/ToggleHint

class TraceEntry:
	var tag: String = ""
	var code: String = ""
	var category: String = ""
	var color_hex: String = "#38bdf8"
	var timestamp_str: String = ""
	var life_timer: float = 0.0
	var is_active: bool = false

var _pool_labels: Array[RichTextLabel] = []
var _entries: Array[TraceEntry] = []
var _is_dock_visible: bool = true


func _ready() -> void:
	# Pre-allocate pooled labels for high performance (0 new/free allocations per frame)
	_entries.resize(MAX_VISIBLE_LINES)
	for i in range(MAX_VISIBLE_LINES):
		_entries[i] = TraceEntry.new()
		
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.add_theme_font_size_override("normal_font_size", 12)
		rtl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		rtl.add_theme_constant_override("shadow_offset_x", 1)
		rtl.add_theme_constant_override("shadow_offset_y", 1)
		rtl.modulate.a = 0.0
		lines_container.add_child(rtl)
		_pool_labels.append(rtl)

	if CodeLogicBus:
		CodeLogicBus.logic_traced.connect(_on_logic_traced)
		CodeLogicBus.is_enabled = true

	# Initial banner trace
	CodeLogicBus.trace("ENGINE", "Godot 4.7 GDScript Deconstructor [color=#34d399]READY[/color] • Live Math, Physics & Netcode breakdown", "SYS", "#38bdf8")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_QUOTELEFT:
			toggle_dock()


func toggle_dock() -> void:
	_is_dock_visible = not _is_dock_visible
	visible = _is_dock_visible
	if CodeLogicBus:
		CodeLogicBus.is_enabled = _is_dock_visible


func _on_logic_traced(tag: String, code_line: String, category: String, color_hex: String) -> void:
	if not _is_dock_visible:
		return

	# Shift entries up
	for i in range(MAX_VISIBLE_LINES - 1):
		var prev := _entries[i + 1]
		var cur := _entries[i]
		cur.tag = prev.tag
		cur.code = prev.code
		cur.category = prev.category
		cur.color_hex = prev.color_hex
		cur.timestamp_str = prev.timestamp_str
		cur.life_timer = prev.life_timer
		cur.is_active = prev.is_active

	# Add newest entry at bottom
	var latest := _entries[MAX_VISIBLE_LINES - 1]
	latest.tag = tag
	latest.code = code_line
	latest.category = category
	latest.color_hex = color_hex
	latest.life_timer = LINE_LIFETIME
	latest.is_active = true

	# Format current time m:s:ms
	var msec := Time.get_ticks_msec()
	var secs := (msec / 1000) % 60
	var mins := (msec / 60000) % 60
	var ms := msec % 1000
	latest.timestamp_str = "%02d:%02d.%03d" % [mins, secs, ms]

	_update_labels()


func _process(delta: float) -> void:
	if not _is_dock_visible:
		return

	for i in range(MAX_VISIBLE_LINES):
		var entry := _entries[i]
		if entry.is_active:
			entry.life_timer -= delta
			var lbl := _pool_labels[i]
			if entry.life_timer <= 0.0:
				entry.is_active = false
				lbl.modulate.a = 0.0
			elif entry.life_timer < 0.8:
				# Smooth fade out
				lbl.modulate.a = entry.life_timer / 0.8
			else:
				lbl.modulate.a = 0.95


func _update_labels() -> void:
	for i in range(MAX_VISIBLE_LINES):
		var entry := _entries[i]
		var lbl := _pool_labels[i]
		if entry.is_active:
			var formatted := "[color=#475569]%s[/color] [color=%s][b]⟨%s⟩[/b][/color] %s" % [
				entry.timestamp_str,
				entry.color_hex,
				entry.tag,
				entry.code
			]
			lbl.text = formatted
			lbl.modulate.a = 0.95
		else:
			lbl.text = ""
			lbl.modulate.a = 0.0
