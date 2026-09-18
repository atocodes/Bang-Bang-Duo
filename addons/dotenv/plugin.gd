@tool
extends EditorPlugin

const AUTOLOAD_NAME := "DotEnv"
const AUTOLOAD_PATH := "res://addons/dotenv/env.gd"

const GITIGNORE_PATH := "res://.gitignore"
const ENV_ENTRY := ".env"

func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	_add_env_to_gitignore()

func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	_remove_env_from_gitignore()


func _add_env_to_gitignore() -> void:
	var path := ProjectSettings.globalize_path(GITIGNORE_PATH)

	var lines: PackedStringArray = []

	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		while not file.eof_reached():
			lines.append(file.get_line())
		file.close()

	if not lines.has(ENV_ENTRY):
		if lines.size() > 0 and lines[-1] != "":
			lines.append("")
		lines.append(ENV_ENTRY)

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


func _remove_env_from_gitignore() -> void:
	var path := ProjectSettings.globalize_path(GITIGNORE_PATH)

	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var lines: PackedStringArray = []

	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges() != ENV_ENTRY:
			lines.append(line)

	file.close()

	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
