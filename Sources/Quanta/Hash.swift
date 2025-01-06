/**
 * Hash.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 1/5/25.
 * 
 */

import CryptoKit
import Foundation

func stringToNumber(_ input: String) -> Int {
	let inputData = Data(input.utf8)
	let hash = Insecure.MD5.hash(data: inputData)
	let hashString = hash.prefix(4).map { String(format: "%02x", $0) }
	return (Int(hashString.joined(), radix: 16) ?? 0) % 100
}
