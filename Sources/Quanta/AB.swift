/**
 * AB.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 1/5/25.
 * 
 */

import Foundation

extension Quanta {
	nonisolated(unsafe) static var abLetters_: String = ""

	static var abLetters: String {
		get {
			queue.sync { abLetters_ }
		}
		set {
			queue.sync { abLetters_ = newValue }
		}
	}

	nonisolated(unsafe) static var abNames_: [[String]] = []

	static var abNames: [[String]] {
		get {
			queue.sync { abNames_ }
		}
		set {
			queue.sync { abNames_ = newValue }
		}
	}

	static func set(abJson: String) {
		abLetters = getAbLetters(for: abJson)
		abNames = getAbNames(for: abJson)
	}
}

struct ABExperiment: Decodable {
	let name: [String]
	let variants: [Int]
}

func getAbLetters(for abJson: String) -> String {
	guard let experiments = try? JSONDecoder().decode([ABExperiment].self, from: abJson.data(using: .utf8)!) else {
		return ""
	}

	var abLetters: String = ""
	for exp in experiments {
		let key = "\(Quanta.id).\(exp.name.last ?? "")"
		let int = stringToNumber(key)
		var limit = 0
		for (idx, variant) in exp.variants.enumerated() {
			limit += variant
			if limit > int {
				abLetters += "\("ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { $0 }[idx])"
				break
			}
		}
	}

	return abLetters
}

func getAbNames(for abJson: String) -> [[String]] {
	guard let experiments = try? JSONDecoder().decode([ABExperiment].self, from: abJson.data(using: .utf8) ?? .init()) else {
		return []
	}
	return experiments.map { $0.name.map { $0.lowercased() } }
}
