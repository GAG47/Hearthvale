class_name UuidGenerator
extends RefCounted


static func generate_v4() -> StringName:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		push_error("UUID v4 generation requires 16 cryptographically random bytes.")
		return &""

	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80

	var hexadecimal := ""
	for byte in bytes:
		hexadecimal += "%02x" % byte
	return StringName(
		"%s-%s-%s-%s-%s"
		% [
			hexadecimal.substr(0, 8),
			hexadecimal.substr(8, 4),
			hexadecimal.substr(12, 4),
			hexadecimal.substr(16, 4),
			hexadecimal.substr(20, 12),
		]
	)
