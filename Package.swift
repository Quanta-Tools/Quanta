// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "Quanta",
	platforms: [
		.iOS(.v13)
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
