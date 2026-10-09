import Foundation
import ImageIO
import PDFKit
import UIKit

actor CoverCache {
    static let shared = CoverCache()
    private let images = NSCache<NSURL, NSData>()

    init() {
        images.totalCostLimit = 20 * 1_024 * 1_024
        images.countLimit = 128
    }

    func thumbnail(for url: URL, kind: BookKind) async -> Data? {
        let key = url as NSURL
        if let cached = images.object(forKey: key) { return cached as Data }
        let data = await Task.detached(priority: .utility) {
            Self.makeThumbnail(url: url, kind: kind)
        }.value
        if let data { images.setObject(data as NSData, forKey: key, cost: data.count) }
        return data
    }

    private nonisolated static func makeThumbnail(url: URL, kind: BookKind) -> Data? {
        autoreleasepool {
            if kind == .pdf {
                return PDFDocument(url: url)?.page(at: 0)?
                    .thumbnail(of: CGSize(width: 300, height: 440), for: .mediaBox)
                    .jpegData(compressionQuality: 0.85)
            }
            guard kind == .images,
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 440
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
        }
    }
}
