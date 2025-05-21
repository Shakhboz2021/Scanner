// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public protocol ScanResult {
    var data: [String: String] { get }
}

public struct CardScanResult: ScanResult {
    public let cardNumber: String
    public let expiryDate: String?
    public init(cardNumber: String, expiryDate: String?) {
        self.cardNumber = cardNumber
        self.expiryDate = expiryDate
    }

    public var data: [String: String] {
        var result: [String: String] = ["cardNumber": cardNumber]
        if let expiryDate = expiryDate { result["expiryDate"] = expiryDate }
        return result
    }
}

public protocol ScanDelegate: AnyObject {
    func scannerDidFinish(with result: CardScanResult?)
}
