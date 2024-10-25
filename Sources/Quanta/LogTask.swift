/**
 * File.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 10/25/24.
 * 
 */

import Foundation

@objc final class LogTask: NSObject, QuantaTask {
	let userId: String
	let event: String
	let revenue: String
	let addedArguments: String
	let time: Date

	init(userId: String, event: String, revenue: String, addedArguments: String, time: Date) {
		self.userId = userId
		self.event = event
		self.revenue = revenue
		self.addedArguments = addedArguments
		self.time = time
	}

	func run() async -> Bool {
		var urlString = "https://analytics-ingress.quanta.tools/e/"

		let formatter = DateFormatter()
		formatter.locale = .init(identifier: "en_US_POSIX")
		formatter.timeZone = .init(secondsFromGMT: 0)
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"

		urlString += Quanta.appId
		urlString += "/"
		urlString += Quanta.id
		urlString += "/"
		urlString += formatter.string(from: time)
		urlString += "/"
		urlString += event.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
		if revenue != "0" || addedArguments != "" {
			urlString += "/"
			urlString += revenue.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
		}
		if addedArguments != "" {
			urlString += "/"
			urlString += addedArguments.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
		}

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
