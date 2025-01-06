/**
 * Quanta.swift
 * Quanta Tools (www.quanta.tools)
 *
 * Created by Nick Spreen (www.spreen.co) on 10/25/24.
 *
 */

import Foundation
import QuantaObjC

let unitSeparator: String = "\u{1F}"
let recordSeparator: String = "\u{1E}"

/// Default: load 3s after app start. Set this variable to false/f/no/n and load will be skipped.
let loadEnvironmentVariable: String = "QUANTA_LOAD"

public enum Quanta {
	/// Override the bundle id to avoid 50 char truncation.
	nonisolated(unsafe) public static var bundleId_: String?

	/// Override the bundle id to avoid 50 char truncation.
	static var bundleId: String? {
		get {
			queue.sync { bundleId_ }
		}
		set {
			queue.sync { bundleId_ = newValue }
		}
	}

	/// Override the app version number to avoid 50 char truncation.
	nonisolated(unsafe) public static var appVersion_: String?

	/// Override the app version number to avoid 50 char truncation.
	static var appVersion: String? {
		get {
			queue.sync { appVersion_ }
		}
		set {
			queue.sync { appVersion_ = newValue }
		}
	}

	nonisolated(unsafe) public static var sendLaunchEvent_ = true

	static var sendLaunchEvent: Bool {
		get {
			queue.sync { sendLaunchEvent_ }
		}
		set {
			queue.sync { sendLaunchEvent_ = newValue }
		}
	}

	/// Override this user's app installation date.
	nonisolated(unsafe) public static var installDate__: Date?

	/// Override this user's app installation date.
	static var installDate: Date? {
		get {
			queue.sync { installDate__ }
		}
		set {
			queue.sync { installDate__ = newValue }
		}
	}

	/// Manually set the appId to avoid auto-detection from Quanta.plist.
	public static var appId: String {
		get {
			#if DEBUG
			if overrideAppId ?? plistAppId == "" {
				warn("Quanta App ID is empty. Please check the instructions at www.quanta.tools")
			}
			#endif
			return overrideAppId ?? plistAppId
		}
		set { overrideAppId = newValue }
	}

	static var isTestFlight: Bool {
		Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
	}

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
		if isTestFlight {
			flags |= 4
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
				if let uuid = UUID(uuidString: newValue) {
					id_ = shorten(uuid: uuid)
				} else {
					id_ = newValue
					if id_.count != 22 {
						warn("The ID \(id_) does not look like a valid UUID or Quanta ID. Only use UUIDs or shortened Quanta IDs as user IDs.")
					}
				}
			}
		}
	}

	static let queue = DispatchQueue(label: "tools.quanta.queue")

	nonisolated(unsafe) fileprivate static var id__: String = ""

	static var id_: String {
		get {
			queue.sync { id__ }
		}
		set {
			queue.sync { id__ = newValue }
		}
	}

	nonisolated(unsafe) fileprivate static var initialized_ = false

	static var initialized: Bool {
		get {
			queue.sync { initialized_ }
		}
		set {
			queue.sync { initialized_ = newValue }
		}
	}

	static var installDate_: Int {
		if let override = installDate {
			return Int(override.timeIntervalSince1970)
		}
		let int = UserDefaults.standard.integer(forKey: "tools.quanta.install")
		if int > 0 {
			return int
		}
		let now = Int(Date().timeIntervalSince1970)
		UserDefaults.standard.set(now, forKey: "tools.quanta.install")
		return now
	}

	static func initialize() {
		if initialized { return }
		initialized = true

		print("Quanta loaded.")
#if DEBUG
		Task { await checkClaimed() }
#endif

		if let previousId = UserDefaults.standard.string(forKey: "tools.quanta.id") {
			id = previousId
		} else {
			id = shorten(uuid: UUID())
			UserDefaults.standard.set(id, forKey: "tools.quanta.id")
		}

		let abJson = UserDefaults.standard.string(forKey: "tools.quanta.ab") ?? ""
		abNames = getAbNames(for: abJson)
		abLetters = getAbLetters(for: abJson)

		if sendLaunchEvent {
			log_(event: "launch")
		}
	}

	static var device: String {
#if os(macOS)
		var modelIdentifier = [CChar](repeating: 0, count: 256)
		var size = modelIdentifier.count
		let result = sysctlbyname("hw.model", &modelIdentifier, &size, nil, 0)
		if result == 0 {
			let identifier = modelIdentifier.prefix(while: { $0 != 0 }).map { UInt8($0) }
			return String(decoding: identifier, as: UTF8.self)
		} else {
			return "unknown-mac"
		}
#elseif targetEnvironment(simulator)
		return "iOS-Simulator"
#else
		var systemInfo = utsname()
		uname(&systemInfo)

		let machineMirror = Mirror(reflecting: systemInfo.machine)
		let identifier = machineMirror.children.reduce("") { identifier, element in
			guard let value = element.value as? Int8, value != 0 else { return identifier }
			return identifier + String(UnicodeScalar(UInt8(value)))
		}

		return identifier
#endif
	}


	static var os: String {
		let os = ProcessInfo.processInfo.operatingSystemVersion
		let major = os.majorVersion
		let minor = os.minorVersion
		let patch = os.patchVersion

#if targetEnvironment(macCatalyst)
		return "macOS\(major).\(minor).\(patch)"
#elseif os(iOS)
		return "iOS\(major).\(minor).\(patch)"
#elseif os(macOS)
		return "macOS\(major).\(minor).\(patch)"
#elseif os(visionOS)
		return "visionOS\(major).\(minor).\(patch)"
#elseif os(watchOS)
		return "watchOS\(major).\(minor).\(patch)"
#elseif os(tvOS)
		return "tvOS\(major).\(minor).\(patch)"
#else
		return "appleOS\(major).\(minor).\(patch)"
#endif
	}

	private static var systemBundleId: String {
		Bundle.main.bundleIdentifier ?? "?"
	}

	private static var systemAppVersion: String {
		guard
			let infoDictionary = Bundle.main.infoDictionary,
			let version = infoDictionary["CFBundleShortVersionString"] as? String,
			let build = infoDictionary["CFBundleVersion"] as? String
		else {
			return "?"
		}
		return "\(version)+\(build)"
	}

	public static var isPreview: Bool {
		ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
	}

	/// Call this before sending any events. Will be called on launch unless env QUANTA\_LOAD is set to false.
	public static func sendUserUpdate() {
		print("sendUserUpdate is deprecated.")
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

	static func warn(_ message: String) {
		print("[Quanta] WARNING: \(message)")
	}

	public static func log(event: String, addedArguments: [String: String]) {
		log(event: event, revenue: 0, addedArguments: addedArguments)
	}

	public static func log(event: String, revenue: Double = 0, addedArguments: String = "") {
		if event == "launch", sendLaunchEvent {
			warn("The launch event is used for internal system events. It's automatically sent on app launch and should not be sent manually.")
		}
		log_(event: event, revenue: revenue, addedArguments: addedArguments)
	}

	public static func log(event: String, revenue: Double, addedArguments: [String: String]) {
		var argString = ""
		let delim = unitSeparator

		for key in addedArguments.keys.sorted() {
			if key.contains(delim) || addedArguments[key]!.contains(delim) {
				warn("Added arguments contain unit separator chars. They will be removed.")
			}
			argString += "\(key.replacingOccurrences(of: delim, with: ""))\(delim)\(addedArguments[key]!.replacingOccurrences(of: delim, with: ""))\(delim)"
		}
		if argString.count > 0 {
			argString.removeLast(delim.count)
		}

		log(event: event, revenue: revenue, addedArguments: argString)
	}

	private static func log_(event: String, revenue: Double = 0, addedArguments: String = "") {
		initialize()

		if event.count > 200 {
			warn("Event name is too long. Event name + args should be 200 characters or less. It will be truncated.")
		}
		let event = "\(event.prefix(200))"
		if event.contains(recordSeparator) {
			warn("Event name contains record separator characters. They will be removed.")
		}
		if event.contains("\n") {
			warn("Event name contains new line characters. They will be replaced with spaces.")
		}
		if event.contains("\r") {
			warn("Event name contains new line (return) characters. They will be removed.")
		}
		let addedArguments = {
			if event.count >= 200 {
				if addedArguments.count > 0 {
					warn("Added arguments are ignored. Event name is 200 characters long.")
				}
				return ""
			} else {
				if event.count + addedArguments.count > 200 {
					warn("Added arguments are too long. Event name + args should be 200 characters or less. They will be truncated.")
				}
				return "\(addedArguments.prefix(200 - event.count))"
			}
		}()
		if addedArguments.contains(recordSeparator) {
			warn("Added arguments contain record separator characters. They will be removed.")
		}
		if addedArguments.contains("\n") {
			warn("Added arguments contain new line characters. They will be replaced with spaces.")
		}
		if addedArguments.contains("\r") {
			warn("Added arguments contain new line (return) characters. They will be removed.")
		}
		let revenue = stringFor(double: revenue)

		if isPreview { return }
		if appId.isEmpty { return }

		let userData = UserData(
			id: id,
			device: device,
			os: os,
			bundleId: bundleId ?? systemBundleId,
			debugFlags: debugFlags,
			version: appVersion ?? systemAppVersion,
			language: language,
			installDate: installDate_
		)

		Task {
			await QuantaQueue.shared.enqueue(UserLogTask(
				appId: appId,
				userData: userData.string,
				event: event,
				revenue: revenue,
				addedArguments: addedArguments,
				time: Date()
			))
		}
	}

	nonisolated(unsafe) private static var overrideAppId__: String?

	static var overrideAppId_: String? {
		get {
			queue.sync { overrideAppId__ }
		}
		set {
			queue.sync { overrideAppId__ = newValue }
		}
	}

	private static var overrideAppId: String? {
		get {
			overrideAppId_
		}
		set {
			if let uuid = UUID(uuidString: newValue ?? "") {
				overrideAppId_ = shorten(uuid: uuid)
			} else {
				overrideAppId_ = newValue
			}
		}
	}

	static var plistAppId: String {
		if
			let url = Bundle.main.url(forResource: "Quanta", withExtension: "plist"),
			let data = try? Data(contentsOf: url),
			let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
		{
			if let value = plist["AppId"] as? String {
				if let uuid = UUID(uuidString: value) {
					return shorten(uuid: uuid)
				}
				return value
			}
			warn("Quanta.plist is missing AppId value.")
		} else {
			warn("No Quanta.plist in bundle.")
		}

		return ""
	}

	static func initializeAfterDelay() {
		Task.detached(priority: .background) {
			try? await Task.sleep(nanoseconds: 3_000_000_000)
			if
				let loadOnStart = ProcessInfo.processInfo.environment[loadEnvironmentVariable],
				loadOnStart.lowercased().starts(with: "f") || loadOnStart.lowercased().starts(with: "n")
			{
				return
			}
			initialize()
		}
	}

#if DEBUG
	static func checkClaimed() async {
		struct Response: Decodable {
			let unClaimed: Bool
		}

		guard
			let url = URL(string: "https://quanta.tools/api/claimed/\(appId)"),
			appId != ""
		else {
			return
		}
		let request = URLRequest(url: url)
		guard
			let request = try? await URLSession.shared.data(for: request),
			let response = try? JSONDecoder().decode(Response.self, from: request.0),
			response.unClaimed
		else {
			return
		}

		var appId = Self.appId
		if let uuid = UUID(uuidString: appId) {
			appId = shorten(uuid: uuid)
		}

		print("""

       :@@@               +@@+    @@@             
      @@  @:             @@  @   @  @@            
      @@ @@             @@  @@  @@  @             
      @ @@        =     @@  @   @  @@      =     +
     @@@@:@@    @@ @@   @  @=  @@ @@    @@@ @@=@@ 
    :@@    @   @@  @@   @@@    @@@@    @@    @@   
 @@@@@@   @@   @@@@    @@@     @@     @@@    @@   
     @     \\@@@@ \\@@@@@  \\@@@@@ \\@@@@@  \\@@@@     

""")
		print("Welcome to Quanta! 🥳")
		print("Your analytics are fully set up.")
		print("See your first events coming in and attach this app to your Quanta account at")
		print("https://quanta.tools/setup/\(appId)")
		print()

		if let longId = try? uuid(fromQuantaId: appId) {
			print("ℹ️ Your app has the id \(appId) which is a shorter base 64 representation of the UUID \(longId). Both ids can be used interchangeably. Quanta will always refer to your app by the shorter id.")
			print()
		}

		print("Once your app is attached to an account, this welcome message won't show up anymore. 🚮")
	}
#endif
}

@objc public class QuantaLoader: NSObject {
	@objc public static func initializeLibrary() {
		Quanta.initializeAfterDelay()
	}
}
