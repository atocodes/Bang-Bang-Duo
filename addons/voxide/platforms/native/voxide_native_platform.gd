## VoxideNativePlatform
## Platform capability detection for native Godot targets.
class_name VoxideNativePlatform
extends RefCounted


## Returns true if the current runtime is a web export.
static func is_web() -> bool:
	return OS.has_feature("web")


## Returns true if the current platform can support microphone input.
static func has_microphone() -> bool:
	# On web, the JS SDK manages the mic — report false here.
	if is_web():
		return false
	# Android/iOS require runtime permissions; assume hardware present.
	return true


## Returns a Dictionary of capabilities available on the current platform.
static func get_capabilities() -> Dictionary:
	return {
		"voice": true,
		"text": true,
		"microphone": has_microphone(),
		"web": is_web(),
		"platform": OS.get_name(),
	}


## Returns true if the named feature is supported on this platform.
static func is_feature_supported(feature: String) -> bool:
	return get_capabilities().get(feature, false)


## Build the Voxide live WebSocket URL from base URL, public key, and anonymous ID.
static func build_ws_url(base_url: String, public_key: String, anon_id: String) -> String:
	var cleaned := base_url.strip_edges().rstrip("/")
	var protocol := "wss"
	if cleaned.begins_with("http://"):
		protocol = "ws"
		cleaned = cleaned.substr(7)
	elif cleaned.begins_with("https://"):
		cleaned = cleaned.substr(8)
	elif cleaned.begins_with("wss://") or cleaned.begins_with("ws://"):
		var split_idx := cleaned.find("://")
		cleaned = cleaned.substr(split_idx + 3)
	var anon_param := "&anon=%s" % anon_id if not anon_id.is_empty() else ""
	return "%s://%s%s?key=%s%s" % [protocol, cleaned, VoxideConstants.WS_LIVE_PATH, public_key, anon_param]
