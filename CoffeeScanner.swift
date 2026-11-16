import UIKit
import Vision

// A small container that holds one line of text Vision reads from a photo
struct OCRLine {
	let text: String
	// boundingBox is a rectangle discribing where the text sits in the photo
	// Normalized 0-1 coordinates
	let boundingBox: CGRect
}

// A dedicated object responsible for scanning text from photos
final class CoffeeScanner {
	// Runs Vision OCR on one photo and returns every recognized line
	func recognizeLines(in image: UIImage) async throws -> [OCRline] {
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
				gaurd let best = observation.topCandidates(1).first else { return nil }
				return OCRLine(text: best.string, boundingBox: observation.boundingBox)
			}.value
		}
	}
}

// UIImage and Vision describe rotation with two different enums
extension CGImagePropertyOrientation {
	init(_orientation: UIImage.Orientation) {
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