class_name IPHelper
extends RefCounted

## Helper class for retrieving local LAN IPv4 address.

static func get_local_ipv4() -> String:
	var addresses: PackedStringArray = IP.get_local_addresses()
	var candidates: Array[String] = []

	for addr in addresses:
		if is_valid_lan_ipv4(addr):
			if addr.begins_with("192.168."):
				return addr
			elif addr.begins_with("10."):
				candidates.insert(0, addr)
			elif is_class_b_private(addr):
				candidates.insert(0, addr)
			else:
				candidates.append(addr)

	if not candidates.is_empty():
		return candidates[0]

	return "127.0.0.1"


static func is_valid_lan_ipv4(addr: String) -> bool:
	if ":" in addr:
		return false
	if addr.begins_with("127."):
		return false
	if addr.begins_with("169.254."):
		return false
	var parts: PackedStringArray = addr.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
		var val: int = part.to_int()
		if val < 0 or val > 255:
			return false
	return true


static func is_class_b_private(addr: String) -> bool:
	if addr.begins_with("172."):
		var parts: PackedStringArray = addr.split(".")
		if parts.size() >= 2 and parts[1].is_valid_int():
			var second_octet: int = parts[1].to_int()
			return second_octet >= 16 and second_octet <= 31
	return false
