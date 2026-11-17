import CoreGraphics
import Foundation

/// Handles line classification, table extraction, deterministic reference parsing, and title selection.
final class CoffeeLabelParser {
    private let reference: CoffeeReference

    init(reference: CoffeeReference = .shared) {
        self.reference = reference
    }

    // MARK: - Classification

    /// Classifies OCR lines once to eliminate duplicated filtering across parsing and title candidate generation.
    func classify(_ lines: [OCRLine]) -> ClassifiedLines {
        let texts = lines.map(\.text)
        let table = parseTablePairs(in: lines)
        var claimed = table.claimedIndices

        var notesIndices = Set<Int>()
        var tastingNotes: String?
        if let found = CoffeeTextNormalizer.findTastingNotes(in: texts, excluding: claimed, reference: reference) {
            tastingNotes = found.notes
            notesIndices.formUnion(found.indices)
            claimed.formUnion(found.indices)
        }

        // Claim vertical lines, fine print, standalone headers, and known roasters/countries/processes
        for (index, line) in lines.enumerated() {
            let text = line.text
            if line.boundingBox.height > line.boundingBox.width * 1.5
                || CoffeeTextNormalizer.isFinePrint(text)
                || CoffeeTextNormalizer.isFieldHeader(text)
                || isStrictlyKnown(text, in: [.roasters, .countries, .processes])
                || resolveRoaster(text) != nil {
                claimed.insert(index)
            }
        }

        let candidates = lines.enumerated()
            .filter { index, line in
                !claimed.contains(index)
                    && line.boundingBox.height <= line.boundingBox.width * 1.5
                    && line.text.filter(\.isLetter).count >= 2
            }
            .map { (index: $0.offset, line: $0.element) }
            .sorted {
                if $0.line.boundingBox.height != $1.line.boundingBox.height {
                    return $0.line.boundingBox.height > $1.line.boundingBox.height
                }
                return $0.line.boundingBox.maxY > $1.line.boundingBox.maxY
            }

        return ClassifiedLines(
            lines: lines,
            texts: texts,
            tableVarieties: table.varieties,
            tastingNotes: tastingNotes,
            notesIndices: notesIndices,
            claimedIndices: claimed,
            titleCandidates: candidates
        )
    }

    func topCandidateTitles(from classified: ClassifiedLines) -> [String] {
        classified.titleCandidates.prefix(5).map {
            $0.line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Deterministic Parsing

    /// Turns recognized OCR lines into coffee details using reference matching and rule-based extractors.
    func parse(_ lines: [OCRLine]) -> CoffeeDetails {
        parse(classify(lines))
    }

    func parse(_ c: ClassifiedLines) -> CoffeeDetails {
        var details = CoffeeDetails()
        details.tastingNotes = c.tastingNotes

        // List-based fields, matched against lines excluding tasting notes
        let matchTexts = c.texts.enumerated()
            .filter { !c.notesIndices.contains($0.offset) }
            .map(\.element)

        let matchedCountries = reference.matches(in: matchTexts, for: .countries)
        let matchedRegions = reference.matches(in: matchTexts, for: .regions)
        let matchedProcesses = reference.matches(in: matchTexts, for: .processes)
        var matchedVarieties = reference.matches(in: matchTexts, for: .varieties)

        for v in c.tableVarieties {
            let canonicalHits = reference.matches(in: [v], for: .varieties)

            for hit in canonicalHits where !matchedVarieties.contains(hit) {
                matchedVarieties.append(hit)
            }
        }

        details.roaster = reference.matches(in: matchTexts, for: .roasters).first
            ?? findRoasterBrand(in: matchTexts)
            ?? ""
        details.countryOfOrigin = CoffeeTextNormalizer.joined(matchedCountries)
        details.region = CoffeeTextNormalizer.joined(matchedRegions) ?? regionFromLocationLine(in: matchTexts)
        details.processes = CoffeeTextNormalizer.joined(matchedProcesses)
        details.varieties = CoffeeTextNormalizer.joined(matchedVarieties)

        details.originType = CoffeeTextNormalizer.findOriginType(in: c.texts, countries: matchedCountries, regions: matchedRegions)
        details.elevation = c.texts.compactMap { CoffeeTextNormalizer.parseElevation(from: $0) }.first

        // Select coffee name from classified candidate titles
        details.coffeeName = selectCoffeeName(from: c, roaster: details.roaster)

        // Zero-anchor fallback: if coffeeName is still empty, check prominent variety/region/country
        if details.coffeeName.isEmpty {
            details.coffeeName = details.varieties ?? details.region ?? details.countryOfOrigin ?? ""
        }

        return details
    }

    // MARK: - Title Selection

    private func selectCoffeeName(
        from c: ClassifiedLines,
        roaster: String = ""
    ) -> String {
        guard let primary = c.titleCandidates.first else {
            return ""
        }

        let title = primary.line.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let withoutRoaster = stripRoasterPrefix(
            from: title,
            roaster: roaster
        )

        return stripCountryPrefixIfAnchorRemains(
            from: withoutRoaster
        )
    }

    // MARK: - Table Extraction

    private func parseTablePairs(in lines: [OCRLine]) -> (varieties: [String], claimedIndices: Set<Int>) {
        var extraVarieties: [String] = []
        var claimed = Set<Int>()

        for (index, line) in lines.enumerated() {
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()

            // 1. Inline "VARIETY: Wolisho & Dega"
            if let value = CoffeeTextNormalizer.extractInlineValue(from: trimmed, prefixes: CoffeeTextNormalizer.varietyHeaders) {
                claimed.insert(index)
                extraVarieties.append(contentsOf: CoffeeTextNormalizer.splitListItems(value))
                continue
            }

            // 2. Standalone "VARIETY" header in two-column table or stacked
            if CoffeeTextNormalizer.varietyHeaders.contains(upper) {
                claimed.insert(index)

                if let rightIndex = lines.indices.first(where: { otherIdx in
                    guard otherIdx != index, !claimed.contains(otherIdx) else { return false }
                    let other = lines[otherIdx]
                    let otherText = other.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let sameRow = abs(other.boundingBox.midY - line.boundingBox.midY) <= max(line.boundingBox.height * 1.5, 0.02)
                    return sameRow
                        && other.boundingBox.minX > line.boundingBox.minX
                        && !CoffeeTextNormalizer.isFieldHeader(otherText)
                        && !CoffeeTextNormalizer.isFinePrint(otherText)
                }) {
                    claimed.insert(rightIndex)
                    extraVarieties.append(contentsOf: CoffeeTextNormalizer.splitListItems(lines[rightIndex].text))
                } else if index + 1 < lines.count {
                    let nextText = lines[index + 1].text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !CoffeeTextNormalizer.isFieldHeader(nextText), !CoffeeTextNormalizer.isFinePrint(nextText) {
                        claimed.insert(index + 1)
                        extraVarieties.append(contentsOf: CoffeeTextNormalizer.splitListItems(nextText))
                    }
                }
                continue
            }

            if CoffeeTextNormalizer.isFieldHeader(trimmed) {
                claimed.insert(index)
            }
        }
        return (extraVarieties, claimed)
    }

    // MARK: - Helpers

    private func regionFromLocationLine(in texts: [String]) -> String? {
        for text in texts {
            let parts = text
                .split(whereSeparator: { ",•·|".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let countryIndex = parts.firstIndex(where: {
                !reference.matches(in: [$0], for: .countries).isEmpty
            }), countryIndex > 0 else {
                continue
            }
            let candidate = parts[countryIndex - 1]
            if let hit = reference.matches(in: [candidate], for: .regions).first {
                return hit
            }
        }
        return nil
    }

    func resolveRoaster(_ raw: String) -> String? {
        CoffeeTextNormalizer.resolveRoaster(raw, reference: reference)
    }

    func findRoasterBrand(in texts: [String]) -> String? {
        CoffeeTextNormalizer.findRoasterBrand(in: texts, reference: reference)
    }

    private func isStrictlyKnown(_ text: String, in categories: [CoffeeReference.Category]) -> Bool {
        CoffeeTextNormalizer.isStrictlyKnown(text, in: categories, reference: reference)
    }

    private func matchesOtherCategory(_ text: String, than category: CoffeeReference.Category) -> Bool {
        CoffeeTextNormalizer.matchesOtherCategory(text, than: category, reference: reference)
    }

    private func stripRoasterPrefix(from text: String, roaster: String) -> String {
        CoffeeTextNormalizer.stripRoasterPrefix(from: text, roaster: roaster)
    }

    private func stripCountryPrefixIfAnchorRemains(from text: String) -> String {
        CoffeeTextNormalizer.stripCountryPrefixIfAnchorRemains(from: text, reference: reference)
    }
}
