## VoxideState
## Manages dynamic game/application state injection for Voxide.
## Assign state_provider to a Callable that returns a Dictionary
## snapshot of relevant game state at query time.
class_name VoxideState
extends RefCounted


## A Callable returning a Dictionary of current game state.
## Called immediately before each Voxide transmission.
## Keep the payload small — do not continuously stream the full game state.
## Example:
##   ai.state.provider = func():
##       return { "player_health": player.health, "location": str(player.position) }
var provider: Callable

## Static key-value state set directly (merged with provider output).
var _static_state: Dictionary = {}

## Named getters registered individually.
var _getters: Dictionary = {}


## Set or update static state values.
func set_values(data: Dictionary) -> void:
	_static_state.merge(data, true)


## Register a named getter callable.
## Example: state.register_getter("score", func(): return score_node.value)
func register_getter(key: String, getter: Callable) -> void:
	_getters[key] = getter


## Collect and return the current state snapshot.
## Called by VoxideClient immediately before transmitting to Voxide.
func get_snapshot() -> Dictionary:
	var snapshot := _static_state.duplicate()

	# Run the primary provider callable if set.
	if provider.is_valid():
		var result = provider.call()
		if result is Dictionary:
			snapshot.merge(result, true)

	# Run individual named getters.
	for key in _getters:
		var getter: Callable = _getters[key]
		if getter.is_valid():
			snapshot[key] = getter.call()

	return snapshot


## Clear all static state (does not affect provider or getters).
func clear() -> void:
	_static_state.clear()
