## VoxideMessage
## Immutable data class representing a single conversation message.
class_name VoxideMessage
extends RefCounted


enum Role {
	USER,
	AI,
	SYSTEM,
	TOOL,
}

const ROLE_NAMES := {
	Role.USER: "user",
	Role.AI: "ai",
	Role.SYSTEM: "system",
	Role.TOOL: "tool",
}

var role: Role = Role.USER
var text: String = ""
var partial: bool = false
var timestamp: float = 0.0
var tool_name: String = ""


static func create(p_role: Role, p_text: String, p_partial: bool = false) -> VoxideMessage:
	var msg := VoxideMessage.new()
	msg.role = p_role
	msg.text = p_text
	msg.partial = p_partial
	msg.timestamp = Time.get_unix_time_from_system()
	return msg


static func role_from_string(s: String) -> Role:
	match s:
		"user":
			return Role.USER
		"ai":
			return Role.AI
		"system":
			return Role.SYSTEM
		"tool":
			return Role.TOOL
	return Role.USER


func to_dict() -> Dictionary:
	return {
		"role": ROLE_NAMES.get(role, "user"),
		"text": text,
		"partial": partial,
		"timestamp": timestamp,
	}
