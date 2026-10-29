# Mini README: `CoffeeScanner.swift`

## 1. Purpose of this File
`CoffeeScanner.swift` is the **Optical Character Recognition (OCR) and text parsing service**. It receives the 1–2 temporary photos of the coffee bag (front and back), invokes Apple's native **Vision framework** (`VNRecognizeTextRequest`) to extract printed text characters, runs field extraction heuristics to detect coffee attributes (Roaster, Name, Origin, Process, Elevation, etc.), and returns a clean, structured `CoffeeDetails` value struct.

---

## 2. Swift Lecture Lessons Called Upon

| Lesson | Core Concept | How It Is Used Here |
| :--- | :--- | :--- |
| **Swift Basics 1** | **Control Flow & Guard** | Uses `guard !photos.isEmpty else { return CoffeeDetails() }` to exit early if no photos are passed. |
| **Swift Basics 1** | **Loops & String Operations** | Iterates through recognized lines using `for line in cleaned` and checks for substring presence via `localizedCaseInsensitiveContains`. |
| **Swift Lesson 2** | **Structs (Value Types)** | `CoffeeDetails` is a `struct` that holds the intermediate extracted text before user review, ensuring immutability and thread safety. |
| **Swift Lesson 2** | **Classes (Service Types)** | `CoffeeScanner` is declared as a `final class` that encapsulates OCR services. |
| **Swift Lesson 3** | **Optionals & Safe Unwrapping** | Returns nullable parsed fields (`String?`, `OriginType?`) so absent data defaults to `nil` rather than crashing. |
| **Swift Lesson 3** | **Optional Chaining** | Extracts top recognition candidate safely with `observation.topCandidates(1).first?.string`. |
| **Swift Lesson 4** | **Closures & Callbacks** | Passes a trailing completion handler closure to `VNRecognizeTextRequest { req, err in ... }`. |
| **Swift Lesson 4** | **Async Continuations** | Wraps the legacy delegate/closure-based Vision API inside modern Swift concurrency via `withCheckedThrowingContinuation`. |
| **Swift Lesson 4** | **Higher-Order Functions & `$0`** | Cleans lines and extracts text using `.compactMap`, `.map`, and `.filter` with shorthand argument names (`$0`). |

---

## 3. Variables, Methods, and Components Needed

### Data Structure: `struct CoffeeDetails`
* `var roaster: String`: Parsed roaster candidate.
* `var coffeeName: String`: Parsed blend/single-origin name.
* `var countryOfOrigin: String?`: Matched country (e.g., "Ethiopia", "Colombia").
* `var varieties: String?`: Matched varieties.
* `var processes: String?`: Matched processes ("Washed", "Natural").
* `var originType: OriginType?`: Enum match for `.singleOrigin`, `.fieldBlend`, or `.blend`.
* `var elevation: String?`: Matched altitude text (e.g. "1800m").
* `var tastingNotes: String?`: Printed flavor notes on bag.

### Service: `final class CoffeeScanner`
* **Method:** `func scanAndExtract(from photos: [UIImage]) async throws -> CoffeeDetails`
  * **Input:** Array of 1–2 `UIImage` instances.
  * **Output:** Populated `CoffeeDetails` value struct.
  * **Throws:** Vision processing or image conversion errors.

### Apple Vision Components
* `VNRecognizeTextRequest`: Apple Vision request for high-accuracy optical character recognition.
* `VNImageRequestHandler`: Executes the Vision request against a `CGImage`.
* `VNRecognizedTextObservation`: Vision result objects containing candidate string matches.

---

## 4. Basic Code Structure

```swift
import UIKit
import Vision

// -------------------------------------------------------------
// [Lesson 2]: STRUCT (Value type for intermediate parsed output)
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// [Lesson 2]: CLASS (Service object encapsulating OCR logic)
// -------------------------------------------------------------
final class CoffeeScanner {

    // [Swift Basics 1 & Lesson 4]: Async throwing method
    func scanAndExtract(from photos: [UIImage]) async throws -> CoffeeDetails {
        // [Lesson 3]: Early guard against empty arrays
        guard !photos.isEmpty else { return CoffeeDetails() }

        var recognizedLines: [String] = []

        // [Swift Basics 1]: For-in loop over 1-2 photos
        for image in photos {
            guard let cgImage = image.cgImage else { continue }

            // [Lesson 4]: Converting closure-based Vision API to async/await
            let lines: [String] = try await withCheckedThrowingContinuation { continuation in
                let request = VNRecognizeTextRequest { req, err in
                    if let err = err {
                        continuation.resume(throwing: err)
                        return
                    }
                    let observations = req.results as? [VNRecognizedTextObservation] ?? []
                    
                    // [Lesson 4]: compactMap with shorthand $0
                    let text = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: text)
                }
                
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                
                let handler = VNImageRequestHandler(cgImage: cgImage)
                try? handler.perform([request])
            }
            recognizedLines.append(contentsOf: lines)
        }

        // [Lesson 4]: Functional map and filter with $0
        let cleaned = recognizedLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var details = CoffeeDetails()
        details.roaster = cleaned.first ?? ""
        details.coffeeName = cleaned.count > 1 ? cleaned[1] : ""

        // Field Extraction Heuristics (Lesson 1 & 2)
        for line in cleaned {
            if line.localizedCaseInsensitiveContains("Single Origin") { details.originType = .singleOrigin }
            else if line.localizedCaseInsensitiveContains("Field Blend") { details.originType = .fieldBlend }
            else if line.localizedCaseInsensitiveContains("Blend") { details.originType = .blend }

            if line.localizedCaseInsensitiveContains("Washed") { details.processes = "Washed" }
            if line.localizedCaseInsensitiveContains("Natural") { details.processes = "Natural" }

            let countries = ["Ethiopia", "Colombia", "Guatemala", "Kenya", "Costa Rica", "Honduras", "Brazil", "Rwanda"]
            for country in countries where line.localizedCaseInsensitiveContains(country) {
                details.countryOfOrigin = country
            }

            if line.localizedCaseInsensitiveContains("masl") || (line.localizedCaseInsensitiveContains("1") && line.contains("m")) {
                details.elevation = line
            }
        }

        return details
    }
}
```
