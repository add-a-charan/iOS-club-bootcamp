import Foundation

/// Centralized text normalization, cleaning, regex evaluation, and packaging details detection.
enum CoffeeTextNormalizer {

    // MARK: - Constants & Descriptors

    static let titleDescriptors: Set<String> = [
        "FINCA", "HACIENDA", "ESTATE", "WASHING STATION", "STATION",
        "LOT", "COOPERATIVE", "COOP", "MICROLOT", "MICRO-LOT",
        "SELECTION", "RESERVE", "PROJECT", "DON", "DOÑA", "BENEFICIO"
    ]

    static let fieldHeaders: Set<String> = [
        "VARIETY", "VARIETIES", "VARIETAL", "CULTIVAR",
        "PROCESS", "PROCESSING", "ELEVATION", "ALTITUDE",
        "REGION", "ORIGIN", "COUNTRY", "PRODUCER", "FARM",
        "WASHING STATION", "STATION", "LOT", "HARVEST",
        "ROASTED", "ROAST DATE", "ROASTED ON", "ROAST LEVEL",
        "TASTING NOTES", "NOTES", "FLAVOR NOTES", "FLAVORS", "FLAVOURS"
    ]

    static let varietyHeaders: Set<String> = [
        "VARIETY", "VARIETIES", "VARIETAL", "CULTIVAR"
    ]

    static let finePrintKeywords = [
        ".com", "www.", "http://", "https://", "@",
        "net wt", "net weight", "peso neto", "whole bean", "ground coffee",
        "keep in a cool", "store in a cool", "cool, dry place", "airtight container",
        "roasted by", "packaged by", "distributed by", "roasted in",
        "certified organic", "fair trade", "all rights reserved",
        "brew ratio", "pour over", "degassing valve"
    ]

    static let roasterSuffixes = [
        "", "Coffee", "Coffee Roasters", "Coffee Co.", "Coffee Company",
        "Coffee Lab", "Roasters", "Roastery", "Coffee Roasting"
    ]

    static let allCategories: [CoffeeReference.Category] = [
        .roasters, .countries, .regions, .processes, .varieties
    ]

    static let noteSeparators = [" - ", " – ", " — ", " • ", " · ", " | ", " / "]

    // MARK: - Compiled Regular Expressions

    static let fieldHeaderPrefixRegex = try! NSRegularExpression(
        pattern: #"^\s*(?:producer|farm|farmer|grower|origin|country|region|department|state|station|washing\s+station|variety|varieties|varietal|cultivar|process|processing|elevation|altitude|height|masl|harvest|lot(?:\s*(?:#|no\.?|number))?|roast(?:ed)?(?:\s*on|\s*date|\s*level)?|tasting\s+notes?|notes?\s+of|notes?|flavou?rs?)\s*[:\-–—|/]\s*"#,
        options: [.caseInsensitive]
    )

    static let headerPrefixRegex = try! NSRegularExpression(
        pattern: #"^\s*(?:tasting\s+notes?|notes?\s+of|notes?|flavou?rs?|variety|varieties|varietal|cultivar|process|processing|region|origin|roasted\s*(?:on|date)?)\s*[:\-–]\s*"#,
        options: [.caseInsensitive]
    )

    static let weightRegex = try! NSRegularExpression(
        pattern: #"(?i)(?:\bnet\s*wt\.?|\bpeso\s*neto|\b\d+(?:[.,]\d+)?\s*(?:oz|ounces?|lbs?|pounds?|g|grams?|kg|kilos?|kilograms?|fl\s*oz)\b)"#,
        options: []
    )

    static let dateRegex = try! NSRegularExpression(
        pattern: #"(?i)(?:\b(?:roasted(?:\s*on|\s*date)?|roast\s*date|best\s*(?:by|before)|bb|exp(?:iry|\.|\s*date)?|packed(?:\s*on)?|batch(?:\s*#|\s*no\.?)?|harvest(?:\s*date|\s*season|\s*year)?)\s*[:\-–]?\s*\S+|\b\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}\b|\b\d{4}[/.\-]\d{1,2}[/.\-]\d{1,2}\b|\b\d{1,2}/\d{4}\b|\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+\d{1,2},?\s+\d{2,4}\b|\b\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?,?\s+\d{2,4}\b|\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:am|pm)?\b)"#,
        options: []
    )

    static let contactRegex = try! NSRegularExpression(
        pattern: #"(?i)(?:\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b|\(\d{3}\)\s*\d{3}[-.\s]\d{4}\b|\b(?:tel|phone|call)\s*[:\-–]\s*\S+|\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b|\b@[A-Za-z0-9_]{3,}\b|\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b|\bp\.?o\.?\s*box\s+\d+\b)"#,
        options: []
    )

    static let barcodeRegex = try! NSRegularExpression(
        pattern: #"(?i)(?:\b(?:upc|sku|barcode|item\s*#)\b\s*[:\-–]?\s*\d+|\b\d{8,14}\b)"#,
        options: []
    )

    static let elevationRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,2}[,.]?\d{3})\s*(?:[-–—]\s*(\d{1,2}[,.]?\d{3}))?\s*(masl|m\.a\.s\.l\.?|meters|metres|mts|m|ft|feet)(?![A-Za-z])"#,
        options: [.caseInsensitive]
    )

    static let notesRegex = try! NSRegularExpression(
        pattern: #"^\s*(?:tasting\s+notes?|notes?\s+of|notes?|tastes?\s+like|flavou?rs?)\b\s*[:\-–]?\s*(.*)$"#,
        options: [.caseInsensitive]
    )

    // MARK: - Basic String Transformations

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    static func squash(_ text: String) -> String {
        fold(text).filter(\.isLetter)
    }

    static func words(_ s: String) -> [String] {
        fold(s).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    static func displayName(_ text: String) -> String {
        text.split(separator: " ")
            .map { $0.contains(where: \.isNumber) ? $0.uppercased() : $0.capitalized }
            .joined(separator: " ")
    }

    static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.lowercased()).inserted }
    }

    static func joined(_ items: [String]) -> String? {
        items.isEmpty ? nil : items.joined(separator: ", ")
    }

    static func splitListItems(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "&/,+"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).localizedCapitalized }
            .filter { !$0.isEmpty }
    }

    static func containsWord(_ word: String, in text: String) -> Bool {
        text.range(
            of: #"\b\#(NSRegularExpression.escapedPattern(for: word))\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    // MARK: - Headers & Inline Extraction

    static func isFieldHeader(_ text: String) -> Bool {
        let cleaned = text
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-–")))
            .uppercased()
        return fieldHeaders.contains(cleaned)
    }

    static func hasFieldHeaderPrefix(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return fieldHeaderPrefixRegex.firstMatch(in: text, range: range) != nil
    }

    static func stripHeaderPrefix(from text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let stripped = headerPrefixRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractInlineValue(from text: String, prefixes: Set<String>) -> String? {
        let upper = text.uppercased()
        for prefix in prefixes where upper.hasPrefix(prefix) {
            let remainder = text.dropFirst(prefix.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: ":-– \t"))
            if !remainder.isEmpty { return remainder }
        }
        return nil
    }

    static func isTitleDescriptor(_ text: String) -> Bool {
        let upper = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if titleDescriptors.contains(upper) { return true }
        let words = upper.split(separator: " ").map(String.init)
        if let first = words.first, titleDescriptors.contains(first) {
            return true
        }
        return false
    }

    // MARK: - Fine Print & Packaging Details

    static func isFinePrint(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let lower = trimmed.lowercased()
        if finePrintKeywords.contains(where: { lower.contains($0) }) {
            return true
        }

        let range = NSRange(trimmed.startIndex..., in: trimmed)

        // 1. Weights and volumes (e.g. 12 oz, 340g, 2 lbs, 1 kg, Net Wt)
        if weightRegex.firstMatch(in: trimmed, range: range) != nil {
            return true
        }

        // 2. Dates, roast info, or timestamps (e.g. 11/15/2024, Roast Date: ..., Best By: ...)
        if dateRegex.firstMatch(in: trimmed, range: range) != nil {
            return true
        }

        // 3. Contact information: phones, emails, social handles, postal codes
        if contactRegex.firstMatch(in: trimmed, range: range) != nil {
            return true
        }

        // 4. Barcodes and inventory serial numbers (8+ digits, UPC/SKU labels)
        if barcodeRegex.firstMatch(in: trimmed, range: range) != nil {
            return true
        }

        // 5. Elevations (e.g. 1800 MASL, 1900m)
        return parseElevation(from: trimmed) != nil
    }

    // MARK: - Elevation & Tasting Notes

    static func parseElevation(from text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = elevationRegex.firstMatch(in: text, range: range) else {
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

        guard let low = group(1) else { return nil }
        let numbers = [low, group(2)].compactMap { $0 }.joined(separator: "-")
        let rawUnit = (group(3) ?? "m").lowercased()
        let unit = rawUnit.hasPrefix("mas") ? "masl" : rawUnit.hasPrefix("f") ? "ft" : "m"
        return "\(numbers) \(unit)"
    }

    static func findTastingNotes(
        in texts: [String],
        excluding claimed: Set<Int>,
        reference: CoffeeReference? = nil
    ) -> (notes: String, indices: [Int])? {
        // 1. Explicit header match ("Tasting Notes: ...")
        for (index, text) in texts.enumerated() where !claimed.contains(index) {
            let range = NSRange(text.startIndex..., in: text)
            guard let match = notesRegex.firstMatch(in: text, range: range),
                  let restRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            let rest = String(text[restRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rest.isEmpty, !isFieldHeader(rest), !isFinePrint(rest) {
                return (rest, [index])
            }

            if index + 1 < texts.count {
                let nextLine = texts[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !nextLine.isEmpty, !isFieldHeader(nextLine), !isFinePrint(nextLine) {
                    return (nextLine, [index, index + 1])
                }
            }
        }

        // 2. Unlabeled delimited flavor line ("Peach • Jasmine • Honey")
        for (index, text) in texts.enumerated() where !claimed.contains(index) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !isFinePrint(trimmed),
                  !isFieldHeader(trimmed),
                  !trimmed.contains(where: \.isNumber) else {
                continue
            }

            for sep in noteSeparators where trimmed.contains(sep) {
                let parts = trimmed.components(separatedBy: sep)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if (2...5).contains(parts.count),
                   parts.allSatisfy({ $0.count >= 3 && !isFieldHeader($0) }) {
                    let passesReferenceCheck: Bool
                    if let ref = reference {
                        let hasLocationOrRoaster = parts.contains { isStrictlyKnown($0, in: [.roasters, .countries, .regions], reference: ref) }
                        let allProcessesOrVarieties = parts.allSatisfy { isStrictlyKnown($0, in: [.processes, .varieties], reference: ref) }
                        passesReferenceCheck = !hasLocationOrRoaster && !allProcessesOrVarieties
                    } else {
                        passesReferenceCheck = true
                    }
                    if passesReferenceCheck {
                        return (trimmed.localizedCapitalized, [index])
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Origin Type Detection

    static func findOriginType(
        in texts: [String],
        countries: [String],
        regions: [String]
    ) -> OriginType? {
        let all = texts.joined(separator: " ")
        let placeCount = max(countries.count, regions.count)
        let hasMultiplePlaces = placeCount > 1

        if containsWord("field blend", in: all) {
            return .fieldBlend
        }
        if containsWord("mixed origin", in: all) || hasMultiplePlaces {
            return .mixedOrigin
        }
        if containsWord("blend", in: all) {
            return .blend
        }
        if containsWord("single origin", in: all) || containsWord("origin", in: all) || placeCount == 1 {
            return .singleOrigin
        }
        return nil
    }

    // MARK: - Prefix Stripping

    static func stripRoasterPrefix(from text: String, roaster: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roaster.isEmpty, !trimmed.isEmpty else { return trimmed }

        let roasterWords = words(roaster)
        guard !roasterWords.isEmpty else { return trimmed }

        var candidates: [String] = [roaster]
        if roasterWords.count >= 2 {
            candidates.append(roasterWords.prefix(2).joined(separator: " "))
        }
        if let first = roasterWords.first, first.count >= 3 {
            candidates.append(first)
        }

        var result = trimmed
        for brand in candidates {
            let pattern = #"^\s*\#(NSRegularExpression.escapedPattern(for: brand))\b\s*[:\-–—|]?\s*"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
               match.range.location == 0 {
                let remainder = (result as NSString).substring(from: match.range.length)
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-–—|")))
                if remainder.filter(\.isLetter).count >= 2 {
                    result = remainder
                    break
                }
            }
        }
        return result
    }

    static func stripCountryPrefixIfAnchorRemains(from text: String, reference: CoffeeReference) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let tokens = trimmed.split(separator: " ").map(String.init)
        guard tokens.count >= 2 else { return trimmed }

        let firstTwo = tokens.prefix(2).joined(separator: " ")
        let firstOne = tokens[0]

        let prefixLength = reference.exactMatch(firstTwo, for: .countries) != nil ? firstTwo.count
            : (reference.exactMatch(firstOne, for: .countries) != nil ? firstOne.count : 0)

        if prefixLength > 0 {
            let remainder = trimmed.dropFirst(prefixLength)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-–—|")))
            if remainder.filter(\.isLetter).count >= 3,
               remainder.count > 2,
               !isStrictlyKnown(remainder, in: [.roasters, .countries, .processes], reference: reference) {
                return remainder
            }
        }
        return trimmed
    }

    // MARK: - Reference Lookups

    static func resolveRoaster(_ raw: String, reference: CoffeeReference) -> String? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        for suffix in roasterSuffixes {
            let candidate = suffix.isEmpty ? cleaned : "\(cleaned) \(suffix)"
            if let hit = reference.exactMatch(candidate, for: .roasters) {
                return hit
            }
        }
        return nil
    }

    static func findRoasterBrand(in texts: [String], reference: CoffeeReference) -> String? {
        for raw in texts {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if (1...4).contains(text.split(separator: " ").count),
               !text.contains(where: \.isNumber),
               !isFieldHeader(text),
               !isFinePrint(text),
               let hit = resolveRoaster(text, reference: reference) {
                return hit
            }
        }
        return nil
    }

    static func isStrictlyKnown(_ text: String, in categories: [CoffeeReference.Category], reference: CoffeeReference) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return categories.contains { reference.exactMatch(trimmed, for: $0) != nil }
    }

    static func matchesOtherCategory(_ text: String, than category: CoffeeReference.Category, reference: CoffeeReference) -> Bool {
        if category != .roasters && resolveRoaster(text, reference: reference) != nil {
            return true
        }
        return allCategories
            .filter { $0 != category }
            .contains { !reference.matches(in: [text], for: $0).isEmpty }
    }
}
