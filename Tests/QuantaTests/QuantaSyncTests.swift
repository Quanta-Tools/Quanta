/**
 * QuantaSyncTests.swift
 * Quanta
 *
 * Created for Quanta Tools testing
 */

import XCTest

@testable import Quanta

class MockUserDefaults: UserDefaults {
    var storage: [String: Any] = [:]

    override func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }

    override func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func reset() {
        storage.removeAll()
    }
}

final class QuantaSyncTests: XCTestCase {
    var standardDefaults: MockUserDefaults!
    var groupDefaults: MockUserDefaults!

    override func setUp() {
        super.setUp()
        standardDefaults = MockUserDefaults()
        groupDefaults = MockUserDefaults()
    }

    override func tearDown() {
        standardDefaults = nil
        groupDefaults = nil
        super.tearDown()
    }

    // Test helper to sync ID with our mock defaults
    private func syncId() {
        Quanta.syncId(
            for: "test.group",
            standardDefaults: standardDefaults,
            groupDefaultsProvider: { _ in self.groupDefaults }
        )
    }

    // MARK: - Test Cases for Empty Values

    func testBothEmpty() {
        // Both standard and group defaults are empty
        syncId()

        // Verify new values were created
        XCTAssertNotNil(standardDefaults.string(forKey: "tools.quanta.id"))
        XCTAssertNotNil(groupDefaults.string(forKey: "tools.quanta.id"))
        XCTAssertEqual(
            standardDefaults.string(forKey: "tools.quanta.id"),
            groupDefaults.string(forKey: "tools.quanta.id"))
        XCTAssertNotEqual(standardDefaults.integer(forKey: "tools.quanta.install"), 0)
        XCTAssertNotEqual(groupDefaults.integer(forKey: "tools.quanta.install"), 0)
        XCTAssertEqual(
            standardDefaults.integer(forKey: "tools.quanta.install"),
            groupDefaults.integer(forKey: "tools.quanta.install"))
				print("new id:", standardDefaults.string(forKey: "tools.quanta.id")!)
    }

    func testStandardIdEmptyGroupIdExists() {
        // Setup: Group has ID, standard doesn't
        groupDefaults.set("group-id-value", forKey: "tools.quanta.id")

        syncId()

        // Standard should get group's ID
        XCTAssertEqual(standardDefaults.string(forKey: "tools.quanta.id"), "group-id-value")
        XCTAssertEqual(groupDefaults.string(forKey: "tools.quanta.id"), "group-id-value")
    }

    func testGroupIdEmptyStandardIdExists() {
        // Setup: Standard has ID, group doesn't
        standardDefaults.set("standard-id-value", forKey: "tools.quanta.id")

        syncId()

        // Group should get standard's ID
        XCTAssertEqual(standardDefaults.string(forKey: "tools.quanta.id"), "standard-id-value")
        XCTAssertEqual(groupDefaults.string(forKey: "tools.quanta.id"), "standard-id-value")
    }

    func testStandardDateEmptyGroupDateExists() {
        // Setup: Group has date, standard doesn't
        groupDefaults.set(100, forKey: "tools.quanta.install")

        syncId()

        // Standard should get group's date
        XCTAssertEqual(standardDefaults.integer(forKey: "tools.quanta.install"), 100)
        XCTAssertEqual(groupDefaults.integer(forKey: "tools.quanta.install"), 100)
    }

    func testGroupDateEmptyStandardDateExists() {
        // Setup: Standard has date, group doesn't
        standardDefaults.set(200, forKey: "tools.quanta.install")

        syncId()

        // Group should get standard's date
        XCTAssertEqual(standardDefaults.integer(forKey: "tools.quanta.install"), 200)
        XCTAssertEqual(groupDefaults.integer(forKey: "tools.quanta.install"), 200)
    }

    // MARK: - Test Cases for Date Comparison

    func testOlderDateInGroup() {
        // Setup: Group has older date (100 vs 200)
        standardDefaults.set("standard-id", forKey: "tools.quanta.id")
        groupDefaults.set("group-id", forKey: "tools.quanta.id")
        standardDefaults.set(200, forKey: "tools.quanta.install")
        groupDefaults.set(100, forKey: "tools.quanta.install")

        syncId()

        // Standard should adopt group's values because group has older date
        XCTAssertEqual(standardDefaults.string(forKey: "tools.quanta.id"), "group-id")
        XCTAssertEqual(standardDefaults.integer(forKey: "tools.quanta.install"), 100)
    }

    func testOlderDateInStandard() {
        // Setup: Standard has older date (100 vs 200)
        standardDefaults.set("standard-id", forKey: "tools.quanta.id")
        groupDefaults.set("group-id", forKey: "tools.quanta.id")
        standardDefaults.set(100, forKey: "tools.quanta.install")
        groupDefaults.set(200, forKey: "tools.quanta.install")

        syncId()

        // Group should adopt standard's values because standard has older date
        XCTAssertEqual(groupDefaults.string(forKey: "tools.quanta.id"), "standard-id")
        XCTAssertEqual(groupDefaults.integer(forKey: "tools.quanta.install"), 100)
    }

    func testEqualDates() {
        // Setup: Both have the same date but different IDs
        standardDefaults.set("standard-id", forKey: "tools.quanta.id")
        groupDefaults.set("group-id", forKey: "tools.quanta.id")
        standardDefaults.set(100, forKey: "tools.quanta.install")
        groupDefaults.set(100, forKey: "tools.quanta.install")

        syncId()

        // Group values should be preferred in a tie
        XCTAssertEqual(standardDefaults.string(forKey: "tools.quanta.id"), "group-id")
        XCTAssertEqual(standardDefaults.integer(forKey: "tools.quanta.install"), 100)
    }

    // MARK: - Test Cases for ID/Date Combinations

    func testStandardHasIdNoDateGroupHasDateNoId() {
        // Setup: Standard has ID but no date, group has date but no ID
        standardDefaults.set("standard-id", forKey: "tools.quanta.id")
        groupDefaults.set(100, forKey: "tools.quanta.install")

        syncId()

        // Check if values were properly merged
        // Standard should keep its ID
        XCTAssertEqual(standardDefaults.string(forKey: "tools.quanta.id"), "standard-id")
        // Group should get standard's ID
        XCTAssertEqual(groupDefaults.string(forKey: "tools.quanta.id"), "standard-id")
        // Standard should get group's date
        XCTAssertEqual(standardDefaults.integer(forKey: "tools.quanta.install"), 100)
        // Group should keep its date
        XCTAssertEqual(groupDefaults.integer(forKey: "tools.quanta.install"), 100)
    }

    func testGroupHasIdNoDateStandardHasDateNoId() {
        // Setup: Group has ID but no date, standard has date but no ID
        groupDefaults.set("group-id", forKey: "tools.quanta.id")
        standardDefaults.set(100, forKey: "tools.quanta.install")

        syncId()

        // Both values should be merged
        XCTAssertEqual(standardDefaults.string(forKey: "tools.quanta.id"), "group-id")
        XCTAssertEqual(groupDefaults.string(forKey: "tools.quanta.id"), "group-id")
        XCTAssertEqual(standardDefaults.integer(forKey: "tools.quanta.install"), 100)
        XCTAssertEqual(groupDefaults.integer(forKey: "tools.quanta.install"), 100)
    }

    // MARK: - Edge Cases

    func testEmptyStringsAsIds() {
        // Setup: Both have empty strings as IDs
        standardDefaults.set("", forKey: "tools.quanta.id")
        groupDefaults.set("", forKey: "tools.quanta.id")

        syncId()

        // New IDs should be generated
        XCTAssertNotEqual(standardDefaults.string(forKey: "tools.quanta.id"), "")
        XCTAssertNotEqual(groupDefaults.string(forKey: "tools.quanta.id"), "")
    }

    func testGroupEmptyStringIdStandardValidId() {
        // Setup: Group has empty string ID, standard has valid ID
        standardDefaults.set("standard-id", forKey: "tools.quanta.id")
        groupDefaults.set("", forKey: "tools.quanta.id")

        syncId()

        // Group should adopt standard's ID
        XCTAssertEqual(standardDefaults.string(forKey: "tools.quanta.id"), "standard-id")
        XCTAssertEqual(groupDefaults.string(forKey: "tools.quanta.id"), "standard-id")
    }

    func testStandardEmptyStringIdGroupValidId() {
        // Setup: Standard has empty string ID, group has valid ID
        standardDefaults.set("", forKey: "tools.quanta.id")
        groupDefaults.set("group-id", forKey: "tools.quanta.id")

        syncId()

        // Standard should adopt group's ID
        XCTAssertEqual(standardDefaults.string(forKey: "tools.quanta.id"), "group-id")
        XCTAssertEqual(groupDefaults.string(forKey: "tools.quanta.id"), "group-id")
    }

    func testCurrentIdUpdateWhenInitialized() {
        // Setup: Initialize Quanta with a specific ID
        standardDefaults.set("old-id", forKey: "tools.quanta.id")
        Quanta.id_ = "old-id"
        Quanta.initialized = true

        // Group has different ID
        groupDefaults.set("group-id", forKey: "tools.quanta.id")
        groupDefaults.set(100, forKey: "tools.quanta.install")

        syncId()

        // Current ID should be updated since Quanta is initialized
        XCTAssertEqual(Quanta.id, "group-id")
    }

    func testCurrentIdNotUpdateWhenNotInitialized() {
        // Setup: Quanta not yet initialized
        standardDefaults.set("old-id", forKey: "tools.quanta.id")
        Quanta.id_ = ""
        Quanta.initialized = false

        // Group has different ID
        groupDefaults.set("group-id", forKey: "tools.quanta.id")
        groupDefaults.set(100, forKey: "tools.quanta.install")

        syncId()

        // Current ID should not be updated since Quanta is not initialized
        XCTAssertEqual(Quanta.id, "")
    }

    // MARK: - Cleanup Tests

    override func tearDownWithError() throws {
        // Reset Quanta state after tests
        Quanta.id_ = ""
        Quanta.initialized = false
        try super.tearDownWithError()
    }
}
