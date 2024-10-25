/**
 * QuantaQueue.swift
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 10/25/24.
 *
 */

import Foundation

protocol QuantaTask: Codable, Sendable {
	func run() async -> Bool
}

actor QuantaQueue {
	static var shared = QuantaQueue()

	// MARK: - Properties
	private var tasks: [any QuantaTask] = []
	private var isProcessing = false
	private let defaults = UserDefaults.standard
	private let queueKey = "tools.quanta.queue.tasks"
	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()

	// MARK: - Initialization
	init() {
		Task(priority: .background) {
			await loadTasks()
			await processQueue()
		}
	}

	// MARK: - Public Methods
	func enqueue(_ task: any QuantaTask) {
		tasks.append(task)
		saveTasks()

		if !isProcessing {
			Task(priority: .background) {
				await processQueue()
			}
		}
	}

	// MARK: - Private Methods
	private func loadTasks() {
		guard
			let data = defaults.data(forKey: queueKey),
			let taskDictionaries = try? decoder.decode([[String: Data]].self, from: data) else {
			return
		}

		tasks = taskDictionaries.compactMap { dictionary in
			guard
				let typeStringData = dictionary["type"],
				let typeString = String(data: typeStringData, encoding: .utf8),
				let taskData = dictionary["data"],
				let taskType = NSClassFromString("Quanta.\(typeString)") as? QuantaTask.Type
			else {
				return nil
			}
			return try? decoder.decode(taskType, from: taskData) as QuantaTask
		}
	}

	private func saveTasks() {
		let taskDictionaries = tasks.map { task -> [String: Data] in
			let typeString = String(describing: type(of: task))
			let taskData = try? encoder.encode(task)
			return [
				"type": typeString.data(using: .utf8) ?? Data(),
				"data": taskData ?? Data()
			]
		}

		if let data = try? encoder.encode(taskDictionaries) {
			defaults.set(data, forKey: queueKey)
		}
	}

	private func processQueue() async {
		guard !isProcessing else { return }
		isProcessing = true
		var failures = 0

		while !tasks.isEmpty {
			// Handle exponential backoff if we've had failures
			if failures > 0 {
				let delay = pow(2.0, Double(failures - 1))
				try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			}

			// Always try the first task
			let success = await tasks[0].run()

			if success {
				tasks.removeFirst()
				failures = 0
				saveTasks()
			} else {
				failures += 1
			}

			try? await Task.sleep(nanoseconds: 100_000_000)
		}

		isProcessing = false
	}
}
