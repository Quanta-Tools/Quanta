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
