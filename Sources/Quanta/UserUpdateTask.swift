/**
 * UserUpdateTask.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 10/25/24.
 * 
 */

import Foundation

func safe(_ value: String, keepUnitSeparator: Bool = false) -> String {
	if keepUnitSeparator {
		return value.replacingOccurrences(of: recordSeparator, with: "")
	}
	return value.replacingOccurrences(of: recordSeparator, with: "").replacingOccurrences(of: unitSeparator, with: "")
}

struct UserData {
	let id: String
	let appId: String
	let device: String
	let os: String
	let bundleId: String
	let debugFlags: Int
	let version: String
	let language: String

	var string: String {
		var urlString = ""

		var bundleId = self.bundleId
		if bundleId.count > 50 {
			Quanta.warn("You bundle id is too long. It should be 50 characters or less. It will be truncated to \(bundleId.prefix(50)).")
			Quanta.warn("Set Quanta.bundleId inside your app delegate to override the default and prevent this error.")
		}
		bundleId = "\(bundleId.prefix(50))"
		var version = self.version
		if version.count > 50 {
			Quanta.warn("You app version is too long. It should be 50 characters or less. It will be truncated to \(version.prefix(50)).")
			Quanta.warn("Set Quanta.appVersion inside your app delegate to override the default and prevent this error.")
		}
		version = "\(version.prefix(50))"

		urlString += "\(id)"
		urlString += "\(recordSeparator)\(appId)"
		urlString += "\(recordSeparator)\(safe(device))"
		urlString += "\(recordSeparator)\(safe(os))"
		urlString += "\(recordSeparator)\(safe(bundleId))"
		urlString += "\(recordSeparator)\(debugFlags)"
		urlString += "\(recordSeparator)\(safe(version))"
		urlString += "\(recordSeparator)\(language)"

		return urlString
	}
}

/// deprecated
@objc final class UserUpdateTask: NSObject, QuantaTask {
	let time: Date
	let id: String
	let appId: String
	let device: String
	let os: String
	let bundleId: String
	let debugFlags: Int
	let version: String
	let language: String

	init(time: Date, id: String, appId: String, device: String, os: String, bundleId: String, debugFlags: Int, version: String, language: String) {
		self.time = time
		self.id = id
		self.appId = appId
		self.device = device
		self.os = os
		self.bundleId = bundleId
		self.debugFlags = debugFlags
		self.version = version
		self.language = language
	}

	func encode(_ string: String) -> String {
		string.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
	}

	func run() async -> Bool {
		var urlString = "https://analytics-ingress.quanta.tools/u/"

		let formatter = DateFormatter()
		formatter.locale = .init(identifier: "en_US_POSIX")
		formatter.timeZone = .init(secondsFromGMT: 0)
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"

		urlString += formatter.string(from: time)
		urlString += "/\(id)"
		urlString += "/\(appId)"
		urlString += "/\(encode(device))"
		urlString += "/\(encode(os))"
		urlString += "/\(encode(bundleId))"
		urlString += "/\(debugFlags)"
		urlString += "/\(encode(version))"
		urlString += "/\(language)"

		guard let url = URL(string: urlString) else { return false }
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		var result: URLResponse
		do {
			result = try await URLSession.shared.data(for: req).1
		} catch {
			return false
		}
		guard let result = result as? HTTPURLResponse else {
			return false
		}
		return result.statusCode == 200
	}
}
