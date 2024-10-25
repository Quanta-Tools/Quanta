/**
 * File.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 10/25/24.
 * 
 */

import Foundation

struct LogTask: QuantaTask {
	let userId: String
	let event: String
	let revenue: String
	let addedArguments: String
	var time: Date = .now

	func run() async -> Bool {
		var urlString = "https://analytics-ingress.quanta.tools/e/"

		urlString += Quanta.appId.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
		urlString += "/"
		urlString += Quanta.id
		urlString += "/"
		// {app}/{user}/{time}/{event}/{revenue}/{args}

		guard let url = URL(string: urlString) else { return false }
		let req = URLRequest(url: url)
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
