@tool
extends EditorPlugin


const DOCK_SCRIPT := preload("res://addons/voxide/editor/voxide_dock.gd")

# DotEnv dependency paths and settings
const DOTENV_PLUGIN_NAME := "dotenv"
const DOTENV_DIR := "res://addons/dotenv"
const DOTENV_ENTRY_SCRIPT := "res://addons/dotenv/env.gd"
const DOTENV_PLUGIN_CFG := "res://addons/dotenv/plugin.cfg"
const DOTENV_BUNDLED_DIR := "res://addons/voxide/bundled/dotenv"
const DOTENV_AUTOLOAD_NAME := "DotEnv"
const GITIGNORE_PATH := "res://.gitignore"
const ENV_ENTRY := ".env"

# Custom node registration paths.
const NODES := {
	"VoxideClient": "res://addons/voxide/runtime/voxide_client.gd",
	"VoxideVoice": "res://addons/voxide/nodes/voxide_voice.gd",
	"VoxideChat": "res://addons/voxide/nodes/voxide_chat.gd",
	"VoxideOrb": "res://addons/voxide/nodes/voxide_orb.gd",
	"VoxideStatus": "res://addons/voxide/nodes/voxide_status.gd",
	"VoxideTranscript": "res://addons/voxide/nodes/voxide_transcript.gd",
	"VoxideAudioMeter": "res://addons/voxide/nodes/voxide_audio_meter.gd",
}

var _dock: Control = null


func _enable_plugin() -> void:
	_install_and_enable_dotenv()


func _disable_plugin() -> void:
	# Note: DotEnv is intentionally left enabled so any other project systems
	# or plugins that rely on DotEnv continue to work without interruption.
	pass


func _enter_tree() -> void:
	# Ensure DotEnv dependency is installed and configured.
	_install_and_enable_dotenv()

	# Register all custom node types under the "Voxide" category.
	for node_name in NODES:
		add_custom_type(
			node_name,
			_base_type(node_name),
			load(NODES[node_name]),
			_get_icon()
		)

	# Add the editor dock.
	_dock = DOCK_SCRIPT.new()
	_dock.name = "Voxide"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)


func _exit_tree() -> void:
	# Remove custom node types.
	for node_name in NODES:
		remove_custom_type(node_name)

	# Remove editor dock.
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _base_type(node_name: String) -> String:
	match node_name:
		"VoxideClient":
			return "Node"
	return "Control"


func _get_icon() -> Texture2D:
	return preload("res://addons/voxide/icon.png")


# -- Dependency Management: DotEnv ---------------------------------------------

func _install_and_enable_dotenv() -> void:
	var needs_install := not FileAccess.file_exists(DOTENV_ENTRY_SCRIPT) or not FileAccess.file_exists(DOTENV_PLUGIN_CFG)

	if needs_install:
		if DirAccess.dir_exists_absolute(DOTENV_BUNDLED_DIR):
			_copy_dir_recursive(DOTENV_BUNDLED_DIR, DOTENV_DIR)
			print("[Voxide] Installed DotEnv dependency to '%s'." % DOTENV_DIR)
			var fs = EditorInterface.get_resource_filesystem()
			if fs and not fs.is_scanning():
				fs.scan()
		else:
			push_error("[Voxide] Bundled DotEnv not found at '%s'. Cannot auto-install dependency." % DOTENV_BUNDLED_DIR)

	# Enable the DotEnv editor plugin if installed and not already enabled.
	if FileAccess.file_exists(DOTENV_PLUGIN_CFG):
		if not _is_dotenv_plugin_enabled():
			EditorInterface.set_plugin_enabled(DOTENV_PLUGIN_NAME, true)
			print("[Voxide] Enabled DotEnv plugin.")

	# Register the DotEnv autoload singleton if not already present.
	if FileAccess.file_exists(DOTENV_ENTRY_SCRIPT):
		if not ProjectSettings.has_setting("autoload/" + DOTENV_AUTOLOAD_NAME):
			add_autoload_singleton(DOTENV_AUTOLOAD_NAME, DOTENV_ENTRY_SCRIPT)
			print("[Voxide] Registered '%s' autoload singleton." % DOTENV_AUTOLOAD_NAME)

	# Ensure .env is added to .gitignore.
	_add_env_to_gitignore()


func _is_dotenv_plugin_enabled() -> bool:
	var enabled_plugins: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	return enabled_plugins.has(DOTENV_PLUGIN_CFG)


func _copy_dir_recursive(src: String, dst: String) -> void:
	if not DirAccess.dir_exists_absolute(dst):
		DirAccess.make_dir_recursive_absolute(dst)

	var dir := DirAccess.open(src)
	if not dir:
		push_error("[Voxide] Failed to open source directory: %s" % src)
		return

	dir.list_dir_begin()
	var item := dir.get_next()
	while not item.is_empty():
		if item != "." and item != "..":
			var src_path := src.path_join(item)
			var dst_path := dst.path_join(item)
			if dir.current_is_dir():
				_copy_dir_recursive(src_path, dst_path)
			else:
				DirAccess.copy_absolute(src_path, dst_path)
		item = dir.get_next()
	dir.list_dir_end()


func _add_env_to_gitignore() -> void:
	var path := ProjectSettings.globalize_path(GITIGNORE_PATH)
	var lines: PackedStringArray = []

	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			while not file.eof_reached():
				lines.append(file.get_line())
			file.close()

	if not lines.has(ENV_ENTRY):
		if lines.size() > 0 and lines[-1] != "":
			lines.append("")
		lines.append(ENV_ENTRY)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
		file.close()
