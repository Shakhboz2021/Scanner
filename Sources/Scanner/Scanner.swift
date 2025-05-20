// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public protocol ScanResult {
    var data: [String: String] { get }
}

public protocol ScanDelegate {
    func startScanning(completion: @escaping (ScanResult?) -> Void)
    func stopScanning()
}
