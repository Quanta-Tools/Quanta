/**
 * View+track.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 3/30/25.
 *
 */

import Foundation

func shortString(from value: Double) -> String {
	if abs(value) > 9_999 {
		// Use scientific notation for large numbers
		let formatter = NumberFormatter()
		formatter.numberStyle = .scientific
		formatter.maximumFractionDigits = 2
		formatter.exponentSymbol = "e"
		return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
	} else if value == 0 || abs(value) < 0.001 {
		// Return "0" for very small values
		return "0"
	} else {
		// Format with up to 2 decimal places
		let formatter = NumberFormatter()
		formatter.locale = .init(identifier: "en_US")
		formatter.numberStyle = .decimal
		formatter.maximumFractionDigits = 2

		// Check if integer part + fraction ≤ 4 digits
		let intPart = Int(value)
		let intLength = String(abs(intPart)).count

		// If too many digits before the period, round to an integer
		if intLength >= 4 {
			formatter.maximumFractionDigits = 0
		} else {
			// Limit total length to 4 digits
			let remainingDigits = 4 - intLength
			formatter.maximumFractionDigits = min(remainingDigits, 2)
		}

		return formatter.string(from: NSNumber(value: value))?.replacingOccurrences(
			of: ",", with: "") ?? "\(value)"
	}
}

#if canImport(UIKit) && canImport(SwiftUI)
typealias Application = UIApplication
#elseif canImport(AppKit) && canImport(SwiftUI)
typealias Application = NSApplication
#endif

#if canImport(SwiftUI)
	import SwiftUI
	import Combine

	// MARK: - ScreenTimeTracker

	/// Singleton responsible for managing screen view time tracking
	class ScreenTimeTracker {
		@MainActor static let shared = ScreenTimeTracker()

		private var activeScreens: [String: ScreenSession] = [:]
		private var cancellables = Set<AnyCancellable>()
		private let persistenceKey = "tools.quanta.sessions"
		private var persistenceTimer: Timer?
		private let timerInterval: TimeInterval = 10.0
		private var minimumEstimatedDuration: TimeInterval { timerInterval / 2 }  // Minimum estimated duration for new sessions
		private let minimumTrackableDuration: TimeInterval = 0.5  // Minimum duration to consider tracking

		private init() {
			setupNotifications()
			startPersistenceTimer()
			processRestoredSessions()
		}

		deinit {
			persistenceTimer?.invalidate()
		}

		private func setupNotifications() {
			// Monitor app going to background
			NotificationCenter.default.publisher(for: Application.willResignActiveNotification)
				.sink { [weak self] _ in
					self?.handleAppBackground()
				}
				.store(in: &cancellables)

			// Monitor app coming to foreground
			NotificationCenter.default.publisher(for: Application.didBecomeActiveNotification)
				.sink { [weak self] _ in
					self?.handleAppForeground()
				}
				.store(in: &cancellables)

			// We don't rely on termination notification as it may not be called during crashes
		}

		/// Start a timer to periodically persist screen time data to handle crashes
		private func startPersistenceTimer() {
			persistenceTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true)
			{ _ in
				Task { @MainActor in
					Self.shared.periodicPersistence()
				}
			}
			persistenceTimer?.tolerance = 2.0  // Add some tolerance to be battery-friendly
		}

		/// Called every 10 seconds to update persisted session data
		private func periodicPersistence() {
			guard !activeScreens.isEmpty else { return }
			persistAllSessions()
		}

		private func handleAppBackground() {
			// Pause all active sessions
			for (screenId, _) in activeScreens {
				pauseScreenView(screenId: screenId)
			}

			// Persist active sessions with their actual durations when backgrounding
			// This ensures we have accurate data if the app is terminated while backgrounded
			persistAllSessions(useActualDurationOnly: true)
		}

		private func handleAppForeground() {
			// Resume active sessions (if any)
			for (screenId, _) in activeScreens {
				resumeScreenView(screenId: screenId)
			}
		}

		// Process any restored sessions from a previous app run
		private func processRestoredSessions() {
			guard
				let sessionsData = UserDefaults.standard.array(forKey: persistenceKey)
					as? [[String: Any]]
			else {
				return
			}

			// Clear the stored data immediately to prevent duplicate restores
			UserDefaults.standard.removeObject(forKey: persistenceKey)
			UserDefaults.standard.synchronize()

			// Process each saved session as a completed event
			for sessionDict in sessionsData {
				guard let screenId = sessionDict["screenId"] as? String,
					let accumulatedTime = sessionDict["accumulatedTime"] as? TimeInterval,
					let argumentsDict = sessionDict["arguments"] as? [String: String]
				else {
					continue
				}

				// Get the start time if available
				let startTime = sessionDict["startTime"] as? TimeInterval

				// Only send analytics if the duration is significant
				if accumulatedTime >= minimumTrackableDuration {
					sendAnalytics(
						screenId: screenId,
						duration: accumulatedTime,
						arguments: argumentsDict,
						startTime: startTime
					)
				}
			}
		}

		// Start tracking a screen view
		func startScreenView(screenId: String, arguments: [String: String]? = nil) {
			// Check if we already have an active session for this screen
			if let existingSession = activeScreens[screenId] {
				// If session already exists, update arguments but don't create a new timer
				existingSession.updateArguments(arguments)
				return
			}

			// Create new session
			let session = ScreenSession(screenId: screenId, arguments: arguments)
			activeScreens[screenId] = session

			// Immediately persist with a minimum estimated duration
			// This ensures that even if the app crashes before our timer fires,
			// we'll have at least captured this minimum duration
			persistSessionWithEstimatedDuration(session)
		}

		// End tracking a screen view
		func endScreenView(screenId: String) {
			guard let session = activeScreens[screenId] else { return }

			// Calculate final duration
			let duration = session.calculateDuration()

			// Send analytics for completed session
			if duration >= minimumTrackableDuration {
				sendAnalytics(
					screenId: screenId, duration: duration,
					arguments: session.arguments, startTime: session.sessionStartTime)
			}

			// Remove from active screens
			activeScreens.removeValue(forKey: screenId)

			// After removing, persist the current state
			persistAllSessions(onDisappear: true)
		}

		// Pause tracking (when app goes to background)
		private func pauseScreenView(screenId: String) {
			guard let session = activeScreens[screenId] else { return }
			session.pause()
		}

		// Resume tracking (when app comes to foreground)
		private func resumeScreenView(screenId: String) {
			guard let session = activeScreens[screenId] else { return }
			session.resume()

			// Persist after resume
			persistAllSessions()
		}

		// Immediately persist a session with a minimum estimated duration
		private func persistSessionWithEstimatedDuration(_ session: ScreenSession) {
			var sessionsData =
				UserDefaults.standard.array(forKey: persistenceKey) as? [[String: Any]] ?? []

			// Remove any existing entry for this screen ID
			sessionsData = sessionsData.filter { dict in
				guard let existingId = dict["screenId"] as? String else { return true }
				return existingId != session.screenId
			}

			// Add the session data with minimum estimated duration and start time
			let sessionDict: [String: Any] = [
				"screenId": session.screenId,
				"arguments": session.arguments ?? [:],
				"accumulatedTime": minimumEstimatedDuration,  // Use estimated duration for new sessions
				"lastUpdateTime": Date().timeIntervalSince1970,
				"startTime": session.sessionStartTime,
				"isEstimated": true,  // Mark this as an estimated duration
			]
			sessionsData.append(sessionDict)

			// Save to UserDefaults
			UserDefaults.standard.set(sessionsData, forKey: persistenceKey)
			UserDefaults.standard.synchronize()
		}

		// Persist all active sessions to UserDefaults
		private func persistAllSessions(
			useActualDurationOnly: Bool = false, onDisappear: Bool = false
		) {
			guard !activeScreens.isEmpty || onDisappear else { return }

			// Get existing data first to preserve any estimated durations for screens
			// that might not be active anymore
			var sessionsData = [[String: Any]]()

			// Now add updated data for all active screens
			for (_, session) in activeScreens {
				// Calculate current duration for accurate persistence
				let currentDuration = session.calculateDuration()

				// If useActualDurationOnly is true (like when backgrounding), we store the actual duration
				// Otherwise we use our minimum estimated duration as a floor
				let durationToStore =
					useActualDurationOnly
					? currentDuration : max(currentDuration, minimumEstimatedDuration)

				// Add the session data for persistence with current accurate values
				let sessionDict: [String: Any] = [
					"screenId": session.screenId,
					"arguments": session.arguments ?? [:],
					"accumulatedTime": durationToStore,
					"lastUpdateTime": Date().timeIntervalSince1970,
					"startTime": session.sessionStartTime,
					"isEstimated": !useActualDurationOnly
						&& currentDuration < minimumEstimatedDuration,
				]
				sessionsData.append(sessionDict)
			}

			// Save to UserDefaults
			UserDefaults.standard.set(sessionsData, forKey: persistenceKey)
			UserDefaults.standard.synchronize()
		}

		// Send analytics to your analytics service
		private func sendAnalytics(
			screenId: String, duration: TimeInterval, arguments: [String: String]?,
			startTime: TimeInterval? = nil
		) {
			// Skip extremely short sessions (likely view lifecycle issues)
			guard duration >= minimumTrackableDuration else { return }

			var arguments = arguments ?? [:]
			arguments["screen"] = screenId
			arguments["seconds"] = shortString(from: duration)

			// Use provided start time if available, otherwise calculate it from now - duration
			let eventStartTime: TimeInterval
			if let startTime {
				eventStartTime = startTime
			} else {
				eventStartTime = Date(timeIntervalSinceNow: -duration).timeIntervalSince1970
			}

			Quanta.log(event: "view", at: Date(timeIntervalSince1970: eventStartTime), addedArguments: arguments)
		}
	}

	// MARK: - ScreenSession

	/// Represents a single viewing session of a screen
	class ScreenSession {
		let screenId: String
		private(set) var arguments: [String: String]?
		private(set) var startTime: Date
		private(set) var pauseTime: Date?
		private(set) var accumulatedTime: TimeInterval = 0
		private(set) var sessionStartTime: TimeInterval  // Store start time as TimeInterval for analytics

		var isPaused: Bool {
			return pauseTime != nil
		}

		init(
			screenId: String,
			arguments: [String: String]? = nil,
			startTime: Date = Date(),
			accumulatedTime: TimeInterval = 0,
			paused: Bool = false
		) {
			self.screenId = screenId
			self.arguments = arguments
			self.startTime = startTime
			self.sessionStartTime = startTime.timeIntervalSince1970
			self.accumulatedTime = accumulatedTime
			if paused {
				self.pauseTime = Date()
			}
		}

		func updateArguments(_ newArguments: [String: String]?) {
			guard let newArguments = newArguments else { return }
			if arguments == nil {
				arguments = newArguments
			} else {
				// Merge new arguments with existing ones
				for (key, value) in newArguments {
					arguments?[key] = value
				}
			}
		}

		func pause() {
			guard pauseTime == nil else { return }
			pauseTime = Date()

			// Calculate accumulated time up to this point
			accumulatedTime += pauseTime!.timeIntervalSince(startTime)
		}

		func resume() {
			guard pauseTime != nil else { return }

			// Reset start time to current time
			startTime = Date()
			pauseTime = nil
		}

		func calculateDuration() -> TimeInterval {
			if pauseTime != nil {
				// If paused, just return accumulated time
				return accumulatedTime
			} else {
				// If active, return accumulated time plus time since last start/resume
				return accumulatedTime + Date().timeIntervalSince(startTime)
			}
		}
	}

	// MARK: - View Extension

	extension View {
		/// Track the screen time for this view
		/// - Parameter screen: Optional custom name for the screen. If nil, the view type name will be used.
		/// - Parameter addedArguments: Optional dictionary of additional arguments to track with the screen view
		/// - Returns: A modified view that tracks screen time
		public func track(screen: String? = nil, addedArguments: [String: String]? = nil)
			-> some View
		{
			let actualScreenName = screen ?? String(describing: type(of: self))

			return self.modifier(
				ScreenTimeTrackingModifier(screenName: actualScreenName, arguments: addedArguments))
		}
	}

	// MARK: - ScreenTimeTrackingModifier

	/// ViewModifier that handles the tracking logic
	struct ScreenTimeTrackingModifier: ViewModifier {
		let screenName: String
		let arguments: [String: String]?
		@State private var hasAppeared = false

		func body(content: Content) -> some View {
			content
				.onAppear {
					// Only track once to prevent duplicate events
					if !hasAppeared {
						ScreenTimeTracker.shared.startScreenView(
							screenId: screenName, arguments: arguments)
						hasAppeared = true
					}
				}
				.onDisappear {
					// Only end tracking if we've started it
					if hasAppeared {
						ScreenTimeTracker.shared.endScreenView(screenId: screenName)
						// Reset so we can track again if the view reappears
						hasAppeared = false
					}
				}
		}
	}

//// MARK: - NavigationLink Extension
//
//extension NavigationLink {
//	/// Creates a navigation link that tracks screen time on the destination view
//	/// - Parameters:
//	///   - destination: The destination view
//	///   - screen: Optional custom name for the destination screen
//	///   - addedArguments: Optional dictionary of additional arguments
//	///   - label: The label view
//	/// - Returns: A navigation link with tracked destination
//	static func tracking<D: View, L: View>(
//		destination: D,
//		screen: String? = nil,
//		addedArguments: [String: String]? = nil,
//		@ViewBuilder label: () -> L
//	) -> some View {
//		let trackedDestination = destination.track(screen: screen, addedArguments: addedArguments)
//		return NavigationLink(destination: trackedDestination, label: label)
//	}
//}
//
//// MARK: - List Item Extension
//
//extension ForEach where Content: View {
//	/// Creates a ForEach that applies screen time tracking to each item
//	/// - Parameters:
//	///   - data: The data to create views for
//	///   - id: The key path to the ID
//	///   - screenPrefix: Prefix for the screen name, item ID will be appended
//	///   - addedArguments: Optional dictionary of additional arguments
//	///   - content: The view builder
//	/// - Returns: A ForEach with tracked items
//	static func tracking<Data, ID, ItemContent>(
//		_ data: Data,
//		id: KeyPath<Data.Element, ID>,
//		screenPrefix: String,
//		addedArguments: [String: String]? = nil,
//		@ViewBuilder content: @escaping (Data.Element) -> ItemContent
//	) -> some View where Data: RandomAccessCollection, ID: Hashable, ItemContent: View {
//		ForEach(data, id: id) { item in
//			let itemId = String(describing: item[keyPath: id])
//			let screenName = "\(screenPrefix)_\(itemId)"
//			content(item).track(screen: screenName, addedArguments: addedArguments)
//		}
//	}
//}
#endif
