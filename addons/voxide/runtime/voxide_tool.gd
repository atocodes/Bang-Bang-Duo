## VoxideTool
## A Resource representing a callable Voxide action/tool.
## Create instances in the Inspector or through code and register
## them with VoxideClient.register_tool().
class_name VoxideTool
extends Resource


## The unique name used to identify this tool with Voxide.
@export var tool_name: String = ""

## Human-readable description shown to the AI so it knows when to invoke this tool.
@export_multiline var description: String = ""

## JSON-schema-style parameter definitions. Each entry should be a Dictionary
## with keys: "type", "description", and optionally "required" (bool).
## Example: { "item_id": { "type": "string", "description": "ID of the item", "required": true } }
@export var parameters: Dictionary = {}

## If true, the tool_confirmation_requested signal is emitted before execution.
@export var requires_confirmation: bool = false

## Marks this tool as potentially destructive. Implies requires_confirmation.
@export var dangerous: bool = false

## Optional: restrict this tool to a specific route scope (e.g. "inventory/*").
## Leave empty for global scope.
@export var scope: String = "global"

## The callable invoked when the AI triggers this tool.
## Signature: func(args: Dictionary) -> Dictionary
var handler: Callable


func _init(p_name: String = "", p_description: String = "") -> void:
	tool_name = p_name
	description = p_description


## Returns true if this tool is valid for registration.
func is_valid() -> bool:
	return not tool_name.is_empty() and not description.is_empty()


## Converts this tool to the manifest format expected by the Voxide API.
func to_manifest() -> Dictionary:
	return {
		"name": tool_name,
		"description": description,
		"params": parameters,
		"scope": scope,
		"dangerous": dangerous or requires_confirmation,
	}
