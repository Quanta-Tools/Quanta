// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "Quanta",
	platforms: [
		.iOS(.v13),
		.macOS(.v10_15),
		.tvOS(.v13),
		.watchOS(.v6),
		.visionOS(.v1),
	],
	products: [
		.library(
			name: "Quanta",
			targets: ["Quanta"]),
	],
	targets: [
		.target(
			name: "QuantaObjC",
			publicHeadersPath: "include"
		),
		.target(
			name: "Quanta",
			dependencies: ["QuantaObjC"]
		)
	]
)
