// xcode: set sdk=iOS

import Foundation
import UIKit
import Vision

/// One line of text recognized by Vision, with its normalized position in the image.
struct OCRLine {
	let text: String
	let boundingBox: CGRect
}

enum OriginType: String {
    case fieldBlend = "Field Blend"
    case singleOrigin = "Single Origin"
    case blend = "Blend"
    case mixedOrigin = "Mixed Origin"
}

/// Parsed coffee-label information. Fields remain empty/nil when OCR finds no reliable value.
struct CoffeeDetails {
	var roaster: String = ""
	var coffeeName: String = ""
	var countryOfOrigin: String?
    var region: String?
	var varieties: String?
	var processes: String?
	var originType: OriginType?
	var elevation: String?
	var tastingNotes: String?
}

/// Scans coffee-label photos and parses the recognized text.
///
/// `CoffeeReference` and `OriginType` are app-level types and must be defined elsewhere
/// in the project. `CoffeeReference.matches(in:for:)` is expected to return matching
/// names for the requested category.
final class CoffeeScanner {
	private let reference: CoffeeReference

	init(reference: CoffeeReference) {
		self.reference = reference
	}

	/// Scans the supplied photos and returns the parsed details.
	/// Throws if Vision fails to process any photo.
	func scanAndExtract(from photos: [UIImage]) async throws -> CoffeeDetails {
		guard !photos.isEmpty else { return CoffeeDetails() }

		var allLines: [OCRLine] = []
		for photo in photos {
			allLines.append(contentsOf: try await recognizeLines(in: photo))
		}

		return parse(allLines)
	}

	/// Runs Vision OCR on one image and returns recognized lines in top-to-bottom, left-to-right order.
	func recognizeLines(in image: UIImage) async throws -> [OCRLine] {
		guard let cgImage = image.cgImage else {
			return []
		}

		let orientation = CGImagePropertyOrientation(image.imageOrientation)

		return try await Task.detached(priority: .userInitiated) {
			let request = VNRecognizeTextRequest()
			request.recognitionLevel = .accurate
			request.usesLanguageCorrection = true

			let handler = VNImageRequestHandler(
				cgImage: cgImage,
				orientation: orientation,
				options: [:]
			)
			try handler.perform([request])

			let observations = request.results ?? []
			let lines: [OCRLine] = observations.compactMap { observation in
				guard let candidate = observation.topCandidates(1).first else {
					return nil
				}

				return OCRLine(
					text: candidate.string,
					boundingBox: observation.boundingBox
				)
			}

			// Vision's normalized coordinate origin is at the bottom-left.
			// Larger maxY values therefore appear nearer the top of the image.
			let verticallySorted = lines.sorted {
				$0.boundingBox.maxY > $1.boundingBox.maxY
			}

			var rows: [[OCRLine]] = []
			var currentRow: [OCRLine] = []
			var currentMaxY = verticallySorted.first?.boundingBox.maxY ?? 0

			let rowThreshold: CGFloat = 0.02

			for line in verticallySorted {
				if abs(currentMaxY - line.boundingBox.maxY) <= rowThreshold {
					currentRow.append(line)
				} else {
					rows.append(currentRow)
					currentRow = [line]
					currentMaxY = line.boundingBox.maxY
				}
			}
			if !currentRow.isEmpty {
				rows.append(currentRow)
			}

			return rows.flatMap { row in
				row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
			}
		}.value
	}

	// MARK: - Parsing

	/// Turns recognized OCR lines into coffee form fields.
	private func parse(_ lines: [OCRLine]) -> CoffeeDetails {
		let texts = lines.map(\.text)
		var details = CoffeeDetails()

        // List-based fields. No match leaves the field empty/nil.
        let matchedCountries = reference.matches(in: texts, for: .countries)
        let matchedRegions = reference.matches(in: texts, for: .regions)

        details.roaster = reference.matches(in: texts, for: .roasters).first ?? ""
        details.countryOfOrigin = joined(matchedCountries)
        details.region = joined(matchedRegions)
        details.processes = joined(reference.matches(in: texts, for: .processes))
        details.varieties = joined(reference.matches(in: texts, for: .varieties))

        // Keyword- and regex-based fields.
        details.originType = findOriginType(in: texts, countries: matchedCountries, regions: matchedRegions)
        details.elevation = texts.compactMap { parseElevation(from: $0) }.first

		// Track lines already explained by other fields so they are not selected as
		// the coffee name.
		var claimed = Set<Int>()

		if let found = findTastingNotes(in: texts) {
			details.tastingNotes = found.notes
			claimed.formUnion(found.indices)
		}

		// We want lines containing processes/varieties to remain eligible for the Name.
		for (index, text) in texts.enumerated() {
			if isFinePrint(text) {
				claimed.insert(index)
			}
		}

		// The coffee name is heuristically selected as the tallest remaining line.
		var best: OCRLine?
		for (index, line) in lines.enumerated() where !claimed.contains(index) {
			guard line.text.filter(\.isLetter).count >= 2 else {
				continue
			}

			if let current = best,
			   line.boundingBox.height <= current.boundingBox.height {
				continue
			}
			best = line
		}

		details.coffeeName = best?.text ?? ""
		return details
	}

	// MARK: - Parsing helpers

	private func joined(_ items: [String]) -> String? {
		items.isEmpty ? nil : items.joined(separator: ", ")
	}

	private func isKnownTerm(_ text: String) -> Bool {
		let categories: [CoffeeReference.Category] = [
			.roasters, .countries, .processes, .varieties
		]
		return categories.contains {
			!reference.matches(in: [text], for: $0).isEmpty
		}
	}

	/// filters out websites, dates, weights, elevation, and other fine print.
	private func isFinePrint(_ text: String) -> Bool {
		let lower = text.lowercased()
		let keywords = [
			".com", "www", "@", "harvest", "roasted",
			"roast date", "net wt", "whole bean"
		]

		if keywords.contains(where: { lower.contains($0) }) {
			return true
		}
		if text.filter(\.isNumber).count >= 3 {
			return true
		}
		return parseElevation(from: text) != nil
	}

    private func findOriginType(
        in texts: [String],
        countries: [String],
        regions: [String]
    ) -> OriginType? {
        let all = texts.joined(separator: " ")
        
        let placeCount = max(countries.count, regions.count)
        let hasMultiplePlaces = placeCount > 1
        
        // 1. Field Blend: explicitly stated by the farmer/roaster
        if containsWord("field blend", in: all) {
            return .fieldBlend
        }
        
        // 2. Mixed Origin: explicitly stated, OR we detected 2+ countries/regions
        if containsWord("mixed origin", in: all) || hasMultiplePlaces {
            return .mixedOrigin
        }
        
        // 3. Blend: explicitly stated (and implicitly 1 or 0 places found, otherwise caught above)
        if containsWord("blend", in: all) {
            return .blend
        }
        
        // 4. Single Origin: explicitly stated, uses "origin" label, OR exactly 1 place found
        if containsWord("single origin", in: all) || containsWord("origin", in: all) || placeCount == 1 {
            return .singleOrigin
        }
        
        return nil
    }

	private func containsWord(_ word: String, in text: String) -> Bool {
		text.range(
			of: #"\b\#(NSRegularExpression.escapedPattern(for: word))\b"#,
			options: [.regularExpression, .caseInsensitive]
		) != nil
	}

	// MARK: Elevation

	// Examples: "2,050 m", "1800m", "2300 MASL", "1900-2300 masl".
	// Capture groups: first number, optional range end, unit.
	private static let elevationRegex = try! NSRegularExpression(
		pattern: #"(?<!\d)(\d{1,2}[,.]?\d{3})\s*(?:[-–—]\s*(\d{1,2}[,.]?\d{3}))?\s*(masl|m\.a\.s\.l\.?|meters|metres|mts|m)(?![A-Za-z])"#,
		options: [.caseInsensitive]
	)

	private func parseElevation(from text: String) -> String? {
		let range = NSRange(text.startIndex..., in: text)
		guard let match = Self.elevationRegex.firstMatch(in: text, range: range) else {
			return nil
		}

		func group(_ index: Int) -> String? {
			let nsRange = match.range(at: index)
			guard nsRange.location != NSNotFound,
				  let swiftRange = Range(nsRange, in: text) else {
				return nil
			}

			return String(text[swiftRange])
					.replacingOccurrences(of: ",", with: "")
					.replacingOccurrences(of: ".", with: "")
		}

		guard let low = group(1) else {
			return nil
		}

		let numbers = [low, group(2)].compactMap { $0 }.joined(separator: "-")
		let unit = (group(3) ?? "m").lowercased().hasPrefix("mas") ? "masl" : "m"
		return "\(numbers) \(unit)"
	}

	// MARK: Tasting notes

	// Examples: "Notes: peach", "Tasting notes - cocoa", "Notes of blueberry".
	private static let notesRegex = try! NSRegularExpression(
		pattern: #"^\s*(?:tasting\s+notes?|notes?\s+of|notes?|tastes?\s+like|flavou?rs?)\b\s*[:\-–]?\s*(.*)$"#,
		options: [.caseInsensitive]
	)

	private func findTastingNotes(
		in texts: [String]
	) -> (notes: String, indices: [Int])? {
		for (index, text) in texts.enumerated() {
			let range = NSRange(text.startIndex..., in: text)
			guard let match = Self.notesRegex.firstMatch(in: text, range: range),
				  let restRange = Range(match.range(at: 1), in: text) else {
				continue
			}

			let rest = String(text[restRange])
			.trimmingCharacters(in: .whitespacesAndNewlines)

			if !rest.isEmpty {
				return (rest, [index])
			}

			if index + 1 < texts.count {
				return (texts[index + 1], [index, index + 1])
			}
		}
		return nil
	}
}

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
