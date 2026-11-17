import Foundation

/// Validates Foundation Model extractions against OCR ground-truth and canonical reference lists,
/// merging validated values into the baseline CoffeeDetails.
final class CoffeeLabelValidator {
    private let reference: CoffeeReference

    init(reference: CoffeeReference = .shared) {
        self.reference = reference
    }

    // MARK: - Merge & Validation

    func merge(
        _ baseline: CoffeeDetails,
        with x: ExtractedLabel,
        texts: [String]
    ) -> CoffeeDetails {
        var details = baseline
        let ocrLower = texts.joined(separator: " ").lowercased()
        let ocrWords = Set(CoffeeTextNormalizer.words(ocrLower))

        // Tasting notes first so notes text can be excluded from other fields
        if details.tastingNotes == nil, let rawNotes = x.tastingNotes {
            let notes = CoffeeTextNormalizer.stripHeaderPrefix(from: rawNotes)
            if !notes.isEmpty,
               !CoffeeTextNormalizer.isFieldHeader(notes),
               !CoffeeTextNormalizer.isFinePrint(notes),
               isGrounded(notes, in: ocrWords) {
                details.tastingNotes = notes
            }
        }
        let notesKey = details.tastingNotes.map(CoffeeTextNormalizer.squash) ?? ""
        let matchTexts = texts.filter { !isNotesLine($0, notesKey: notesKey) }

        // Countries: strictly validated against CoffeeReference
        let countryHits = reference.matches(in: matchTexts, for: .countries)
            + reference.matches(in: x.countries.filter { isGrounded($0, in: ocrWords) }, for: .countries)
        details.countryOfOrigin = CoffeeTextNormalizer.joined(CoffeeTextNormalizer.unique(countryHits)) ?? details.countryOfOrigin

        // Regions & Processes
        details.region = verifiedValues(x.regions, category: .regions, existing: details.region, ocrWords: ocrWords, notesKey: notesKey)
        details.processes = verifiedValues(x.processes, category: .processes, existing: details.processes, ocrWords: ocrWords, notesKey: notesKey)

        // Varieties: strictly validated against CoffeeReference
        details.varieties = verifiedValues(
            x.varieties,
            category: .varieties,
            existing: details.varieties,
            allowFallback: false,
            ocrWords: ocrWords,
            notesKey: notesKey
        )

        // Roaster: must appear in OCR and resolve to an exact reference entry
        if details.roaster.isEmpty,
           let rawRoaster = x.roaster?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawRoaster.isEmpty,
           ocrLower.contains(rawRoaster.lowercased()),
           let resolved = resolveRoaster(rawRoaster) {
            details.roaster = resolved
        }

        // Elevation: accepts model value only if its longest number is found in flat OCR
        if details.elevation == nil, let elev = x.elevation {
            let normalized = CoffeeTextNormalizer.parseElevation(from: elev) ?? elev
            let flat = ocrLower.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
            let longest = normalized.split(whereSeparator: { !$0.isNumber }).map(String.init).max(by: { $0.count < $1.count })
            if let longest, flat.contains(longest) {
                details.elevation = normalized
            }
        }

        // A region that is only words from the coffee title is the model echoing the name
        if let region = details.region {
            let nameWords = Set(CoffeeTextNormalizer.words(details.coffeeName))
            let kept = region.components(separatedBy: ", ").filter { part in
                if !reference.matches(in: [part], for: .regions).isEmpty { return true }
                let w = CoffeeTextNormalizer.words(part)
                return w.isEmpty || !w.allSatisfy { nameWords.contains($0) }
            }
            details.region = CoffeeTextNormalizer.joined(kept)
        }

        // Recompute origin type from merged places
        details.originType = CoffeeTextNormalizer.findOriginType(
            in: texts,
            countries: details.countryOfOrigin?.components(separatedBy: ", ") ?? [],
            regions: details.region?.components(separatedBy: ", ") ?? []
        )
        return details
    }

    /// Reusable model extraction validator across reference categories.
    private func verifiedValues(
        _ values: [String],
        category: CoffeeReference.Category,
        existing: String? = nil,
        allowFallback: Bool = false,
        ocrWords: Set<String>,
        notesKey: String
    ) -> String? {
        var results = (existing?.components(separatedBy: ", ") ?? [])
            .filter { !$0.isEmpty && !isPartOfNotes($0, notesKey: notesKey) }

        for raw in values {
            let cleaned = CoffeeTextNormalizer.stripHeaderPrefix(from: raw)
            for part in CoffeeTextNormalizer.splitListItems(cleaned) {
                guard !part.isEmpty,
                      !CoffeeTextNormalizer.isFieldHeader(part),
                      !CoffeeTextNormalizer.isFinePrint(part),
                      !isPartOfNotes(part, notesKey: notesKey),
                      resolveRoaster(part) == nil,
                      isGrounded(part, in: ocrWords) else {
                    continue
                }

                let canonicalHits = reference.matches(in: [part], for: category)
                if !canonicalHits.isEmpty {
                    results.append(contentsOf: canonicalHits)
                } else if allowFallback && !matchesOtherCategory(part, than: category) {
                    results.append(CoffeeTextNormalizer.displayName(part))
                }
            }
        }
        return CoffeeTextNormalizer.joined(CoffeeTextNormalizer.unique(results))
    }

    private func isGrounded(_ text: String, in ocrWords: Set<String>) -> Bool {
        let w = CoffeeTextNormalizer.words(text)
        return !w.isEmpty && w.allSatisfy { ocrWords.contains($0) }
    }

    private func isPartOfNotes(_ value: String, notesKey: String) -> Bool {
        guard !notesKey.isEmpty else { return false }
        let key = CoffeeTextNormalizer.squash(value)
        return key.count >= 3 && notesKey.contains(key)
    }

    private func isNotesLine(_ line: String, notesKey: String) -> Bool {
        let key = CoffeeTextNormalizer.squash(line)
        guard key.count >= 8, notesKey.count >= 8 else { return false }
        return notesKey.contains(key) || key.contains(notesKey)
    }

    func resolveRoaster(_ raw: String) -> String? {
        CoffeeTextNormalizer.resolveRoaster(raw, reference: reference)
    }

    private func matchesOtherCategory(_ text: String, than category: CoffeeReference.Category) -> Bool {
        CoffeeTextNormalizer.matchesOtherCategory(text, than: category, reference: reference)
    }
}
