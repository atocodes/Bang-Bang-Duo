@tool
extends Node

const ENV_FILE_PATH = "res://.env"

func _ready() -> void:
	load_env()

func load_env() -> void:
	if not FileAccess.file_exists(ENV_FILE_PATH):
		# print("No .env file found at: ", ENV_FILE_PATH)
		return

	var file = FileAccess.open(ENV_FILE_PATH, FileAccess.READ)
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		# Ignore empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue
			
		# Split at the first '=' character
		var split_idx = line.find("=")
		if split_idx != -1:
			var key = line.left(split_idx).strip_edges()
			var value = line.right(-split_idx - 1).strip_edges()
			
			# Strip quotes if present around the value
			if (value.begins_with('"') and value.ends_with('"')) or (value.begins_with("'") and value.ends_with("'")):
				value = value.substr(1, value.length() - 2)
				
			OS.set_environment(key, value)

func get_env(variable: String) -> String:
	return OS.get_environment(variable)
