/**
 * Quanta.swift
 * Quanta Tools (www.quanta.tools)
 *
 * Created by Nick Spreen (www.spreen.co) on 10/25/24.
 *
 */

import Foundation
import QuantaObjC

public enum Quanta {
	static var isSimulator: Bool {
#if targetEnvironment(simulator)
		return true
#else
		return false
#endif
	}

	static var isDebug: Bool {
#if DEBUG
		return true
#else
		return false
#endif
	}

	static var debugFlags: Int {
		var flags: Int = 0
		if isDebug {
			flags |= 1
		}
		if isSimulator {
			flags |= 2
		}
		return flags
	}

	static var language: String {
		if let deviceLanguage = Locale.preferredLanguages.first?.split(separator: "@").first {
			return "\(deviceLanguage)".replacingOccurrences(of: "-", with: "_")
		}
		if let appLocale = Locale.current.identifier.split(separator: "@").first {
			return "\(appLocale)".replacingOccurrences(of: "-", with: "_")
		}
		return Locale.current.identifier.replacingOccurrences(of: "-", with: "_")
	}

	public static var id: String {
		get {
			id_
		}
		set {
			if id_ == "" {
				id_ = newValue
			}
		}
	}

	nonisolated(unsafe) fileprivate static var id_: String = ""
	nonisolated(unsafe) fileprivate static var initialized = false

	static func initialize() {
		if initialized { return }
		initialized = true

		print("Quanta loaded.")

		if let previousId = UserDefaults.standard.string(forKey: "tools.quanta.id") {
			id = previousId
		} else {
			id = shorten(uuid: UUID())
			UserDefaults.standard.set(id, forKey: "too.quanta.id")
		}

		sendUserUpdate()
		log_(event: "launch")
	}

	static func sendUserUpdate() {
		initialize()

		return
	}

	private static func stringFor(double value: Double) -> String {
		// Handle upper bound
		if value > 999999.99 {
			warn("Value \(value) exceeds maximum allowed revenue of 999,999.99. Will be capped.")
			return stringFor(double: 999999.99)
		}

		// Handle lower bound
		if value < -999999.99 {
			warn("Value \(value) is below minimum allowed revenue of -999,999.99. Will be capped.")
			return stringFor(double: -999999.99)
		}

		// Check for any decimal components smaller than 0.01
		if (value * 100).truncatingRemainder(dividingBy: 1) > 0 {
			warn("Value \(value) contains decimal components smaller than 0.01 which will be truncated.")
		}

		return String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
	}

	private static func warn(_ message: String) {
		print("[Quanta] WARNING: \(message)")
	}

	public static func log(event: String, revenue: Double = 0, addedArguments: String = "") {
		if event == "launch" {
			warn("The launch event is used for internal system events. It's automatically sent on app launch and should not be sent manually.")
		}
		log_(event: event, revenue: revenue, addedArguments: addedArguments)
	}

	private static func log_(event: String, revenue: Double = 0, addedArguments: String = "") {
		initialize()

		if event.count > 100 {
			warn("Event name is too long. It should be less than 100 characters. It will be truncated.")
		}
		let event = "\(event.prefix(100))"
		if addedArguments.count > 100 {
			warn("Added arguments are too long. They should be less than 100 characters. They will be truncated.")
		}
		let addedArguments = "\(addedArguments.prefix(100))"
		let revenue = stringFor(double: revenue)

		Task {
			await QuantaQueue.shared.enqueue(LogTask(
				userId: id,
				event: event,
				revenue: revenue,
				addedArguments: addedArguments,
				time: Date()
			))
		}
	}

	static var appId: String {
		if
			let url = Bundle.main.url(forResource: "Quanta", withExtension: "plist"),
			let data = try? Data(contentsOf: url),
			let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
		{
			if let value = plist["AppId"] as? String {
				return value
			}
			warn("Quanta.plist is missing AppId value.")
		} else {
			warn("Failed to load Quanta.plist")
		}

		return ""
	}

	static func initializeAfterDelay() {
		if #available(iOS 13.0, *) {
			Task.detached(priority: .background) {
				try? await Task.sleep(nanoseconds: 3_000_000_000)
				initialize()
			}
		} else {
			DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3) {
				initialize()
			}
		}
	}

}

@objc public class QuantaLoader: NSObject {
	@objc public static func initializeLibrary() {
		Quanta.initializeAfterDelay()
	}
}
