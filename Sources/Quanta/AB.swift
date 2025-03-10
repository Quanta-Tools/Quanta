/**
 * AB.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 1/5/25.
 * 
 */

import Foundation

extension Quanta {
	public static func abTest(for experimentName: String) -> String {
		Self.initialize()
		return abDict[experimentName.lowercased()] ?? "A"
	}

	nonisolated(unsafe) static var abLetters_: String = ""

	static var abLetters: String {
		get {
			queue.sync { abLetters_ }
		}
		set {
			queue.sync { abLetters_ = newValue }
		}
	}

	nonisolated(unsafe) static var abDict_: [String: String] = [:]

	static var abDict: [String: String] {
		get {
			queue.sync { abDict_ }
		}
		set {
			queue.sync { abDict_ = newValue }
		}
	}

	static func set(abJson: String) {
		abLetters = getAbLetters(for: abJson)
		abDict = getAbDict(for: abJson)
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

func getAbDict(for abJson: String) -> [String: String] {
	var dict = [String: String]()
	guard let experiments = try? JSONDecoder().decode([ABExperiment].self, from: abJson.data(using: .utf8) ?? .init()) else {
		return dict
	}
	let letters = Quanta.abLetters
	for (idx, experiment) in experiments.enumerated() {
		guard letters.count > idx else { break }
		for name in experiment.name {
			dict[name.lowercased()] = "\(letters.prefix(idx + 1).suffix(1))"
		}
	}
	return dict
}
