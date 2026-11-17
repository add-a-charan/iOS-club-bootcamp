// xcode: set sdk=iOS

import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Vision

/// Handles Vision OCR text recognition, line ordering, and photo rotation.
final class CoffeeOCR {
    private let reference: CoffeeReference

    init(reference: CoffeeReference = .shared) {
        self.reference = reference
    }

    #if canImport(UIKit)
    /// Runs Vision OCR on one image and returns recognized lines in top-to-bottom, left-to-right order.
    func recognizeLines(in image: UIImage) async throws -> [OCRLine] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Language correction disabled to avoid altering proper nouns (Guji, Gesha).
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])

            let lines = (request.results ?? []).compactMap { obs in
                obs.topCandidates(1).first.map { OCRLine(text: $0.string, boundingBox: obs.boundingBox) }
            }
            return Self.orderLines(lines)
        }.value
    }

    /// Re-runs OCR on copies of each photo rotated 90 degrees each way and looks for
    /// the roaster there (vertical wordmarks).
    func roasterFromRotatedPhotos(_ photos: [UIImage]) async -> String? {
        for photo in photos {
            for degrees in [CGFloat(90), CGFloat(-90)] {
                guard let turned = Self.rotated(photo, degrees: degrees),
                      let turnedLines = try? await recognizeLines(in: turned) else {
                    continue
                }
                let texts = turnedLines.map(\.text)
                if let hit = reference.matches(in: texts, for: .roasters).first
                    ?? CoffeeTextNormalizer.findRoasterBrand(in: texts, reference: reference) {
                    return hit
                }
            }
        }
        return nil
    }

    static func rotated(_ image: UIImage, degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        let bounds = CGRect(origin: .zero, size: image.size).applying(CGAffineTransform(rotationAngle: radians))
        let newSize = CGSize(width: abs(bounds.width).rounded(), height: abs(bounds.height).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: newSize, format: format).image { context in
            context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.rotate(by: radians)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
        }
    }
    #endif

    /// Sorts OCR lines top-to-bottom and groups vertically aligned elements into horizontal rows (left-to-right).
    /// Pure static helper to prevent capturing self in Task.detached.
    static func orderLines(_ lines: [OCRLine]) -> [OCRLine] {
        let verticallySorted = lines.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }

        var rows: [[OCRLine]] = []
        var currentRow: [OCRLine] = []
        var rowMidY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowIsVertical = false

        for line in verticallySorted {
            let box = line.boundingBox
            let isVertical = box.height > box.width * 1.5
            // Use 0.85 of line height so slightly tilted two-column rows stay paired in the same row.
            let joinsRow = !currentRow.isEmpty
                && !isVertical
                && !rowIsVertical
                && abs(rowMidY - box.midY) <= max(min(rowHeight, box.height) * 0.85, 0.012)

            if joinsRow {
                currentRow.append(line)
            } else {
                if !currentRow.isEmpty { rows.append(currentRow) }
                currentRow = [line]
                rowMidY = box.midY
                rowHeight = box.height
                rowIsVertical = isVertical
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        return rows.flatMap { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        }
    }
}

#if canImport(UIKit)
// UIImage and Vision use different orientation enums.
extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
#endif
