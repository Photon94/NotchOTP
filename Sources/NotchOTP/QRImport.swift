import AppKit
import Vision
import ImageIO
import UniformTypeIdentifiers
import OTPCore

struct QRImport {
    static func choose(completion: @escaping (Result<OTPAccount?, Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Выберите изображение с QR-кодом"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .bmp]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { completion(.success(nil)); return }
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<OTPAccount?, Error> = Result {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 3000,
                        kCGImageSourceCreateThumbnailWithTransform: true
                      ] as CFDictionary) else {
                    throw OTPError.invalid("Не удалось открыть изображение. Выберите PNG или JPEG с QR-кодом.")
                }
                return try decode(image)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    static func decode(_ image: CGImage) throws -> OTPAccount {
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]
    try VNImageRequestHandler(cgImage: image).perform([request])
    let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
    let otpPayloads = payloads.filter { $0.lowercased().hasPrefix("otpauth://") }
    guard otpPayloads.count == 1, let payload = otpPayloads.first else {
        if otpPayloads.count > 1 { throw OTPError.invalid("На изображении несколько аккаунтов. Обрежьте его до одного QR-кода.") }
        throw OTPError.invalid("QR-код TOTP не найден. Выберите более чёткое изображение кода из настроек безопасности сервиса. Пакетный перенос Google не поддерживается.")
    }
    return try OTPAccount.parse(payload)
    }
}
