## VoxideDock
## Editor dock that provides connection testing, key validation,
## and debug information for the Voxide plugin.
## Only active in the Godot editor — never included in exported games.
@tool
class_name VoxideDock
extends Control


const BASE_URL := "https://voxide.onrender.com"

var _key_edit: LineEdit = null
var _test_btn: Button = null
var _result_label: RichTextLabel = null
var _http: HTTPRequest = null
var _status_indicator: ColorRect = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "Voxide Plugin"
	header.add_theme_font_size_override("font_size", 15)
	vbox.add_child(header)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Key section
	var key_lbl := Label.new()
	key_lbl.text = "Public Key"
	vbox.add_child(key_lbl)

	var key_row := HBoxContainer.new()
	vbox.add_child(key_row)

	_key_edit = LineEdit.new()
	_key_edit.placeholder_text = "vox_pub_..."
	_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_edit.secret = true
	key_row.add_child(_key_edit)

	_status_indicator = ColorRect.new()
	_status_indicator.custom_minimum_size = Vector2(10, 10)
	_status_indicator.color = Color(0.4, 0.4, 0.4)
	key_row.add_child(_status_indicator)

	var hint_lbl := Label.new()
	hint_lbl.text = "Read from .env VOXIDE_API_KEY at runtime."
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint_lbl)

	_test_btn = Button.new()
	_test_btn.text = "Test Connection"
	_test_btn.pressed.connect(_on_test_pressed)
	vbox.add_child(_test_btn)

	_result_label = RichTextLabel.new()
	_result_label.custom_minimum_size = Vector2(0, 80)
	_result_label.fit_content = false
	_result_label.bbcode_enabled = true
	_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_result_label)

	# Platform info
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var platform_lbl := Label.new()
	platform_lbl.text = "Platform: %s" % OS.get_name()
	platform_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(platform_lbl)

	var godot_lbl := Label.new()
	godot_lbl.text = "Godot: %s" % Engine.get_version_info().get("string", "unknown")
	godot_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(godot_lbl)

	# Load key from env file for convenience.
	_load_env_key()


func _load_env_key() -> void:
	var val := ""
	# 1. Try reading from the DotEnv autoload singleton if present in the tree.
	if Engine.has_singleton("DotEnv") or get_node_or_null("/root/DotEnv") != null:
		var dot_env = get_node("/root/DotEnv")
		if dot_env.has_method("get_env"):
			val = dot_env.get_env("VOXIDE_API_KEY")

	# 2. In editor context, instantiate the DotEnv script directly.
	if val.is_empty() and ResourceLoader.exists("res://addons/dotenv/env.gd"):
		var dotenv_script: GDScript = load("res://addons/dotenv/env.gd")
		if dotenv_script:
			var env_instance: Node = dotenv_script.new()
			if env_instance.has_method("load_env"):
				env_instance.load_env()
			if env_instance.has_method("get_env"):
				val = env_instance.get_env("VOXIDE_API_KEY")
			env_instance.free()

	# 3. Direct environment variable fallback.
	if val.is_empty():
		val = OS.get_environment("VOXIDE_API_KEY")

	if not val.is_empty():
		_key_edit.text = val
		_status_indicator.color = Color(0.2, 0.8, 0.4)



func _on_test_pressed() -> void:
	var key := _key_edit.text.strip_edges()
	if key.is_empty():
		_set_result("[color=red]Enter a public key first.[/color]")
		return
	_test_btn.disabled = true
	_set_result("[color=gray]Testing connection...[/color]")
	_status_indicator.color = Color(0.9, 0.7, 0.1)

	if _http:
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	var url := "%s%s" % [BASE_URL, "/api/sdk/init"]
	var err := _http.request(url, ["Authorization: Bearer %s" % key], HTTPClient.METHOD_GET)
	if err != OK:
		_set_result("[color=red]HTTP request failed: %s[/color]" % error_string(err))
		_test_btn.disabled = false


func _on_http_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_test_btn.disabled = false
	if _http:
		_http.queue_free()
		_http = null

	if result != HTTPRequest.RESULT_SUCCESS:
		_status_indicator.color = Color(0.9, 0.2, 0.2)
		_set_result("[color=red]Network error. Check your internet connection.[/color]")
		return

	if code == 200:
		_status_indicator.color = Color(0.2, 0.9, 0.4)
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		var agent_name := ""
		if parsed is Dictionary:
			agent_name = (parsed as Dictionary).get("config", {}).get("agent", {}).get("name", "")
		var agent_str := " — Agent: %s" % agent_name if not agent_name.is_empty() else ""
		_set_result("[color=green]Connection successful.%s[/color]" % agent_str)
	else:
		_status_indicator.color = Color(0.9, 0.2, 0.2)
		_set_result("[color=red]HTTP %d: Check your public key.[/color]" % code)


func _set_result(bbcode: String) -> void:
	if _result_label:
		_result_label.text = bbcode
