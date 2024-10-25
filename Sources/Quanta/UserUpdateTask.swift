/**
 * UserUpdateTask.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 10/25/24.
 * 
 */

import Foundation

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
		urlString += "/\(device)"
		urlString += "/\(os)"
		urlString += "/\(bundleId)"
		urlString += "/\(debugFlags)"
		urlString += "/\(version)"
		urlString += "/\(language)"

		print(urlString)

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
