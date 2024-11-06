/**
 * Id.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 10/25/24.
 *
 */


import Foundation

func shorten(uuid: UUID) -> String {
	// Convert UUID to 16-byte array
	let uuidBytes = withUnsafeBytes(of: uuid.uuid) { Data($0) }

	// Encode the byte array to Base64, URL-safe without padding
	let base64String = uuidBytes.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
	let urlSafeBase64String = base64String
		.replacingOccurrences(of: "+", with: "-")
		.replacingOccurrences(of: "/", with: "_")
		.replacingOccurrences(of: "=", with: "") // Remove padding

	return urlSafeBase64String
}

#if DEBUG
func uuid(fromQuantaId base64Str: String) throws -> UUID {
	// Add back padding if needed
	let paddingLength = base64Str.count % 4
	let paddedString: String
	if paddingLength > 0 {
		paddedString = base64Str + String(repeating: "=", count: 4 - paddingLength)
	} else {
		paddedString = base64Str
	}

	// Convert URL-safe characters back to standard Base64
	let standardBase64 = paddedString
		.replacingOccurrences(of: "-", with: "+")
		.replacingOccurrences(of: "_", with: "/")

	// Decode Base64 to bytes
	guard let decodedData = Data(base64Encoded: standardBase64) else {
		throw NSError(domain: "UUID.Lengthen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode base64 string"])
	}

	// Convert bytes back to UUID
	guard decodedData.count == 16 else {
		throw NSError(domain: "UUID.Lengthen", code: -2, userInfo: [NSLocalizedDescriptionKey: "Decoded data is not 16 bytes"])
	}

	let uuid = decodedData.withUnsafeBytes { bytes in
		return UUID(uuid: bytes.load(as: uuid_t.self))
	}

	return uuid
}
#endif
