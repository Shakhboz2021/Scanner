//
//  File.swift
//  Scanner
//
//  Created by Muhammad on 22/01/26.
//

import Foundation

/// Localization helper that supports both iOS 14 (NSLocalizedString) and iOS 15+ (String(localized:))
/// Usage: L10n.scanCardInfo, L10n.cancel, etc.
public enum L10n {

    // MARK: - Bundle
    private static let bundle: Bundle = .module

    // MARK: - Private Helper
    private static func localized(_ key: String) -> String {
        if #available(iOS 15, *) {
            return String(
                localized: String.LocalizationValue(key),
                bundle: bundle
            )
        } else {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
    }

    // MARK: - Common

    /// "Settings" / "Sozlamalar" / "Настройки"
    public static var settings: String {
        localized("settings")
    }

    /// "Cancel" / "Bekor qilish" / "Отмена"
    public static var cancel: String {
        localized("cancel")
    }

    /// "OK"
    public static var ok: String {
        localized("ok")
    }

    // MARK: - Card Scanner

    /// "Scan a card or handwritten one" / "Kartani yoki qo'lda yozilganini skanerlang"
    public static var scanCardInfo: String {
        localized("scan_card_info")
    }

    /// "Unable to Read Card" / "Kartani o'qib bo'lmadi"
    public static var unableToReadTitle: String {
        localized("unable_to_read_title")
    }

    /// "We couldn't detect card details..." / "Tanlangan rasmdan karta ma'lumotlarini aniqlab bo'lmadi..."
    public static var unableToReadSubtitle: String {
        localized("unable_to_read_subtitle")
    }

    // MARK: - Camera Permission

    /// "Camera Access Required" / "Kamera ruxsati kerak"
    public static var cameraAccessRequired: String {
        localized("camera_access_required")
    }

    /// "Please enable camera access in Settings to scan cards."
    public static var cameraAccessMessage: String {
        localized("camera_access_message")
    }

    // MARK: - Photo Library Permission

    /// "Photo Library Access Required" / "Foto kutubxona ruxsati kerak"
    public static var photoLibraryRequired: String {
        localized("photo_library_access_required")
    }

    /// "Please enable photo library access in Settings to select photos."
    public static var photoLibraryMessage: String {
        localized("photo_library_access_message")
    }

    // MARK: - QR Scanner

    /// "Point camera at QR code" / "Kamerani QR kodga qarating"
    public static var scanQRInfo: String {
        localized("scan_qr_info")
    }

    // MARK: - Barcode Scanner

    /// "Point camera at barcode" / "Kamerani shtrix kodga qarating"
    public static var scanBarcodeInfo: String {
        localized("scan_barcode_info")
    }
}
