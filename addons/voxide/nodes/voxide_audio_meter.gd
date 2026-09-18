@icon("../icon.png")
## VoxideAudioMeter
## Lightweight audio level visualizer for microphone input and AI output.
## Supports Bar, Wave, and Circle visualization modes.
## Bound to a VoxideClient via the client property.
class_name VoxideAudioMeter
extends Control


enum Mode {
	BAR,
	WAVE,
	CIRCLE,
	MINIMAL,
}

# -- Inspector: Client ---------------------------------------------------------

@export_group("Client")
@export var client: NodePath = NodePath("")


# -- Inspector: Display --------------------------------------------------------

@export_group("Display")

@export var mode: Mode = Mode.BAR
@export var show_input: bool = true
@export var show_output: bool = true
@export var bar_count: int = 12
@export_range(1.0, 20.0, 0.5) var bar_width: float = 6.0
@export_range(1.0, 20.0, 0.5) var bar_gap: float = 3.0


# -- Inspector: Appearance -----------------------------------------------------

@export_group("Appearance")

@export var input_color: Color = Color(0.3, 0.7, 1.0, 0.9)
@export var output_color: Color = Color(0.3, 1.0, 0.6, 0.9)
@export var background_color: Color = Color(0.05, 0.05, 0.08, 0.6)
@export var border_radius: float = 4.0


# -- Internal ------------------------------------------------------------------

var _client_ref: VoxideClient = null
var _input_level := 0.0
var _output_level := 0.0
var _time := 0.0
var _input_history: Array[float] = []
var _output_history: Array[float] = []


func _ready() -> void:
	_input_history.resize(bar_count)
	_input_history.fill(0.0)
	_output_history.resize(bar_count)
	_output_history.fill(0.0)
	_bind_client()


func _process(delta: float) -> void:
	_time += delta
	if _client_ref:
		_input_level = _client_ref.get_input_level()
		_output_level = _client_ref.get_output_level()
	# Shift history buffers.
	_input_history.pop_front()
	_input_history.append(_input_level)
	_output_history.pop_front()
	_output_history.append(_output_level)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true, -1.0)
	match mode:
		Mode.BAR: _draw_bars()
		Mode.WAVE: _draw_wave()
		Mode.CIRCLE: _draw_circle()
		Mode.MINIMAL: _draw_minimal()


# -- Public API ----------------------------------------------------------------

## Manually set levels when not using a client binding.
func set_levels(input: float, output: float) -> void:
	_input_level = clampf(input, 0.0, 1.0)
	_output_level = clampf(output, 0.0, 1.0)


# -- Internal: Draw modes -------------------------------------------------------

func _draw_bars() -> void:
	var h := size.y
	var total_w := bar_count * (bar_width + bar_gap) - bar_gap
	var start_x := (size.x - total_w) * 0.5
	for i in bar_count:
		var t := float(i) / float(bar_count)
		var level := _input_history[i] if show_input else _output_history[i]
		if show_output and not show_input:
			level = _output_history[i]
		elif show_input and show_output:
			level = maxf(_input_history[i], _output_history[i])
		var bar_h := maxf(2.0, level * h)
		var x := start_x + i * (bar_width + bar_gap)
		var col := input_color.lerp(output_color, t)
		draw_rect(Rect2(x, h - bar_h, bar_width, bar_h), col, true, -1.0)


func _draw_wave() -> void:
	var pts: PackedVector2Array = []
	var count := bar_count
	for i in count:
		var x := size.x * float(i) / float(count - 1)
		var level: float
		if show_input and show_output:
			level = maxf(_input_history[i % _input_history.size()],
						 _output_history[i % _output_history.size()])
		elif show_input:
			level = _input_history[i % _input_history.size()]
		else:
			level = _output_history[i % _output_history.size()]
		var y := size.y * (1.0 - level) * 0.5 + size.y * 0.25
		pts.append(Vector2(x, y))
	if pts.size() >= 2:
		draw_polyline(pts, input_color, 2.0, true)


func _draw_circle() -> void:
	var center := size * 0.5
	var max_r := minf(size.x, size.y) * 0.5 - 4.0
	var in_r := _input_level * max_r
	var out_r := _output_level * max_r
	if show_output:
		draw_arc(center, out_r, 0.0, TAU, 48, output_color, 3.0, true)
	if show_input:
		draw_arc(center, in_r, 0.0, TAU, 48, input_color, 2.0, true)


func _draw_minimal() -> void:
	var h := size.y
	if show_input:
		var in_h := _input_level * h
		draw_rect(Rect2(0.0, h - in_h, size.x * 0.5 - 1.0, in_h), input_color, true, -1.0)
	if show_output:
		var out_h := _output_level * h
		draw_rect(Rect2(size.x * 0.5 + 1.0, h - out_h, size.x * 0.5 - 1.0, out_h), output_color, true, -1.0)


func _bind_client() -> void:
	_client_ref = _find_client()


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
