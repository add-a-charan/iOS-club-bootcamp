import UIKit
import Vision

// A small container that holds one line of text Vision reads from a photo
struct OCRLine {
	let text: String
	// boundingBox is a rectangle describing where the text sits in the photo
	// Normalized 0-1 coordinates
	let boundingBox: CGRect
}

// Optional fields stay nil when nothing was found
struct CoffeeDetails {
	var roaster: String = ""
	var coffeeName: String = ""
	var countryOfOrigin: String?
	var varieties: String?
	var processes: String?
	var originType: OriginType?
	var elevation: String?
	var tastingNotes: String?
}

// A dedicated object responsible for scanning text from photos
final class CoffeeScanner {

	// Scans 1-2 photos and returns the parsed details
	// AddCoffeeView calls this one method
	func scanAndExtract(from photos: [UIImage]) async -> CoffeeDetails {
		guard !photos.isEmpty else { return CoffeeDetails() }

		// Read every photo and pool the lines together
		var allLines: [OCRLine] = []
		for photo in photos {
			allLines.append(contentsOf: try await recognizeLines(in: photo))
		}
		return parse(allLines)
	}

	// Runs Vision OCR on one photo and returns every recognized line
	func recognizeLines(in image: UIImage) async throws -> [OCRLine] {
		// tries to extract raw data from the UIImage; returns empty array if fails
		guard let cgImage = image.cgImage else {
			return []
		}
		// ensures OCR reads the text the right side up
		let orientation = CGImagePropertyOrientation(image.imageOrientation)

		// Moving the OCR work off the main thread; app could freeze
		return try await Task.detached(priority: .userInitiated) {
			// Creating the OCR request; priority is accuracy
			let request = VNRecognizeTextRequest()
			request.recognitionLevel = .accurate
			// Autocorrect is turned off
			request.usesLanguageCorrection = false

			// Creating the image handler; passes image to Vision framework
			let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
			// OCR performs processing
			try handler.perform([request])

			// Gets OCR results
			let observations = request.results ?? []
			// Extracting the best text candidate
			return observations.compactMap { observation in
				guard let best = observation.topCandidates(1).first else { return nil }
				return OCRLine(text: best.string, boundingBox: observation.boundingBox)
			}.value
			// Vision's origin is the bottom-left, so a LARGER maxY means HIGHER on
			// the photo. Sorting descending puts lines in top-to-bottom reading order.
			return lines.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
		}
	}
}

/// Turns raw OCR lines into form fields. Lines must be in reading order.
/// Accepts any array of OCRLine objects from the scanner
/// Returns a CoffeeDetails object with the information
func parse(_ lines: [OCRLine]) -> CoffeeDetails {
	// Tells swift to go thru every object and get its text property
	let texts = lines.map(\.text)
	// creates a new empty coffee info object
	var details = CoffeeDetails()

	// --- List-based fields (CoffeeReference does the matching) ---
	// No match leaves these empty/nil so the user fills them in.
	// (We deliberately do NOT guess the roaster from the first line anymore:
	// a wrong guess could be saved without the user noticing. An empty
	// roaster also keeps the Save button disabled until they check it.)
	details.roaster = reference.matches(in: texts, for: .roasters).first ?? ""
	details.countryOfOrigin = reference.matches(in: texts, for: .countries).first
	details.processes = joined(reference.matches(in: texts, for: .processes))
	details.varieties = joined(reference.matches(in: texts, for: .varieties))

	// --- Keyword and regex fields ---
	details.originType = findOriginType(in: texts)
	details.elevation = texts.compactMap { parseElevation(from: $0) }.first

	// "Claimed" lines have already been explained by something else, so
	// they can't be the coffee name. We track them by index.
	var claimed = Set<Int>()

	// Tasting notes: the keyword line (and the line below it, if that's
	// where the notes are) become notes, not a name.
	if let found = findTastingNotes(in: texts) {
		details.tastingNotes = found.notes
		claimed.formUnion(found.indices)
	}

	// Lines that matched any reference list or look like fine print
	// (website, dates, elevation, weights) are also not the name.
	for (index, text) in texts.enumerated() {
		if isKnownTerm(text) || isFinePrint(text) {
			claimed.insert(index)
		}
	}

	// --- Coffee name: biggest remaining text ---
	// On a typical label the name is the largest lettering ("Raro",
	// "Erica Tellez"). boundingBox.height measures how tall each line is.
	// Strict ">" means a tie goes to the line that's higher up the photo.
	var best: OCRLine?
	for (index, line) in lines.enumerated() where !claimed.contains(index) {
		// Skip scraps like "•" or "&" that have fewer than 2 letters
		guard line.text.filter(\.isLetter).count >= 2 else { continue }
		if let current = best, line.boundingBox.height <= current.boundingBox.height {
			continue
		}
		best = line
	}
	details.coffeeName = best?.text ?? ""

	return details
}

// MARK: - Parsing helpers

/// "Washed, Natural" style string, or nil when the list is empty
private func joined(_ items: [String]) -> String? {
	items.isEmpty ? nil : items.joined(separator: ", ")
}

/// True if the line contains any roaster, country, process or variety
private func isKnownTerm(_ text: String) -> Bool {
	let categories: [CoffeeReference.Category] = [.roasters, .countries, .processes, .varieties]
	// Checks if any OCR lines match something in the predefined list
	return categories.contains { !reference.matches(in: [text], for: $0).isEmpty }
}

/// True for lines that are never a coffee name: websites, harvest or roast
/// dates, weights, elevation, or anything with 3+ digits.
private func isFinePrint(_ text: String) -> Bool {
	let lower = text.lowercased()
	let keywords = [".com", "www", "@", "harvest", "roasted", "roast date", "net wt", "whole bean"]
	if keywords.contains(where: { lower.contains($0) }) { return true }
	if text.filter(\.isNumber).count >= 3 { return true }
	return parseElevation(from: text) != nil
}

/// Looks for the words "field blend", "single origin" or "blend".
/// Returns nil if none appear, so the form keeps its default.
/// Order matters: "field blend" must be checked before plain "blend".
private func findOriginType(in texts: [String]) -> OriginType? {
	let all = texts.joined(separator: " ")
	if containsWord("field blend", in: all) { return .fieldBlend }
	if containsWord("single origin", in: all) { return .singleOrigin }
	if containsWord("blend", in: all) { return .blend }
	return nil
}

/// Whole-word, case-insensitive check ("blend" won't match "blended")
private func containsWord(_ word: String, in text: String) -> Bool {
	text.range(of: "\\b\(word)\\b", options: [.regularExpression, .caseInsensitive]) != nil
}

// --- Elevation ---
// Matches a 4-digit number (optionally with a comma or period) followed by
// a unit, with an optional range:
//   "2,050 m."   "1800m"   "2300 MASL"   "1900-2300 masl"   "1800 meters"
// Group 1 = first number, group 2 = optional range end, group 3 = unit.
// (?<!\d) stops it starting mid-number; (?![A-Za-z]) stops "2026 More"
// from matching as "2026 m".
private static let elevationRegex = try! NSRegularExpression(
	pattern: #"(?<!\d)(\d{1,2}[,.]?\d{3})\s*(?:[-–—]\s*(\d{1,2}[,.]?\d{3}))?\s*(masl|m\.a\.s\.l\.?|meters|metres|mts|m)(?![A-Za-z])"#,
	options: [.caseInsensitive]
)

/// Returns a clean string like "2300 masl" or "2050 m", or nil if the line
/// has no elevation.
private func parseElevation(from text: String) -> String? {
	let range = NSRange(text.startIndex..., in: text)
	guard let match = Self.elevationRegex.firstMatch(in: text, range: range) else { return nil }

	// Reads one capture group and strips "," and "." so "2,050" -> "2050"
	func group(_ index: Int) -> String? {
		let r = match.range(at: index)
		guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { return nil }
		return String(text[swiftRange])
				.replacingOccurrences(of: ",", with: "")
				.replacingOccurrences(of: ".", with: "")
	}

	guard let low = group(1) else { return nil }
	let numbers = [low, group(2)].compactMap { $0 }.joined(separator: "-")

	// "masl" and "m.a.s.l." both become "masl"; meters/metres/mts/m become "m"
	let unit = (group(3) ?? "m").lowercased().hasPrefix("mas") ? "masl" : "m"
	return "\(numbers) \(unit)"
}

// --- Tasting notes ---
// A line that STARTS with a notes keyword:
//   "Notes: peach, jasmine"  "Tasting notes - cocoa"  "Notes of blueberry"
//   "Tastes like honey"      "Flavors: citrus"
// Group 1 = whatever follows the keyword on the same line.
private static let notesRegex = try! NSRegularExpression(
	pattern: #"^\s*(?:tasting\s+notes?|notes?\s+of|notes?|tastes?\s+like|flavou?rs?)\b\s*[:\-–]?\s*(.*)$"#,
	options: [.caseInsensitive]
)

/// Returns the notes text plus the line indices it used, or nil if there's
/// no notes keyword. If the keyword stands alone ("NOTES"), the notes are
/// taken from the line below it.
private func findTastingNotes(in texts: [String]) -> (notes: String, indices: [Int])? {
	for (index, text) in texts.enumerated() {
		let range = NSRange(text.startIndex..., in: text)
		guard let match = Self.notesRegex.firstMatch(in: text, range: range),
			  let restRange = Range(match.range(at: 1), in: text) else { continue }

		let rest = String(text[restRange]).trimmingCharacters(in: .whitespaces)
		if !rest.isEmpty {
			return (rest, [index])
		}
		if index + 1 < texts.count {
			return (texts[index + 1], [index, index + 1])
		}
	}
	return nil
}


// UIImage and Vision describe rotation with two different enums
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