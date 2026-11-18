import Foundation

/// Plain result type so `CoffeeScanner` doesn't depend on FoundationModels.
/// Values are exactly what the model read off the label; the scanner validates
/// them against `CoffeeReference` before using them.
struct ExtractedLabel {
    var coffeeName: String?
    var roaster: String?
    var countries: [String] = []
    var regions: [String] = []
    var varieties: [String] = []
    var processes: [String] = []
    var elevation: String?
    var tastingNotes: String?
}

/// Wraps the on-device Foundation Model. Returns nil whenever the model can't be
/// used (older OS, Apple Intelligence off or unsupported, generation error), in
/// which case the caller keeps the regex-based result.
enum LabelExtractor {
    static func extract(from texts: [String]) async -> ExtractedLabel? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await extractWithModel(texts)
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct GeneratedLabel {
    @Guide(description: "The coffee's product title (lot, farm, or producer name). Not the roaster.")
    var coffeeName: String?

    @Guide(description: "The roaster or brand name, as printed. Not the coffee's name.")
    var roaster: String?

    @Guide(description: "Countries of origin, as printed on the label.")
    var countries: [String]

    @Guide(description: "Regions or districts, as printed on the label.")
    var regions: [String]

    @Guide(description: "Coffee varieties or cultivars, as printed on the label.")
    var varieties: [String]

    @Guide(description: "Processing methods, as printed on the label.")
    var processes: [String]

    @Guide(description: "Elevation as printed, e.g. '1900-2300 masl'.")
    var elevation: String?

    @Guide(description: "Flavor descriptors ONLY if the label prints them. Otherwise nil. Never invent.")
    var tastingNotes: String?
}

@available(iOS 26.0, *)
extension LabelExtractor {
    static func extractWithModel(_ texts: [String]) async -> ExtractedLabel? {
        guard case .available = SystemLanguageModel.default.availability else {
            return nil
        }

        let session = LanguageModelSession(instructions: """
            You extract fields from OCR text of a coffee bag label. \
            Copy values as printed. Never guess or invent. \
            If a field is not on the label, leave it empty or nil. \
            Ignore websites, dates, and weights.
            """)

        // The on-device model has a small context window; labels are short,
        // but cap the input so a noisy scan can't overflow it.
        let ocr = String(texts.joined(separator: "\n").prefix(3000))

        do {
            let response = try await session.respond(
                to: "OCR text:\n" + ocr,
                generating: GeneratedLabel.self
            )
            let g = response.content
            return ExtractedLabel(
                coffeeName: g.coffeeName,
                roaster: g.roaster,
                countries: g.countries,
                regions: g.regions,
                varieties: g.varieties,
                processes: g.processes,
                elevation: g.elevation,
                tastingNotes: g.tastingNotes
            )
        } catch {
            // Guardrail trip, context overflow, model busy, etc.: fall back.
            return nil
        }
    }
}
#endif
