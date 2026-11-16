import Foundation

// =============================================================
// HOW NAME MATCHING WORKS (overview)
// =============================================================
// Goal: turn messy OCR text from a coffee bag into clean, canonical names.
//   OCR text:  ["ONYX COFFEE LAB", "Ethiopia Guji", "Geisha", "Natural"]
//   Result:    roaster "Onyx Coffee Lab", country "Ethiopia",
//              variety "Gesha", process "Natural"
//
// Steps:
//   1. LOAD     CoffeeReference.json is decoded once into lists of entries.
//   2. COMPILE  Every name and alias becomes a whole-word regex that points
//               back to its canonical name (done once, at startup).
//   3. NORMALIZE The OCR text and the search terms are both lowercased and
//               stripped of accents so they compare fairly.
//   4. MATCH    Each regex is run against the text, collecting every hit.
//   5. PRUNE    Hits that sit inside a longer hit are discarded
//               ("Bourbon" inside "Pink Bourbon").
//   6. RETURN   Surviving canonical names, ordered by position in the text.
//
// If nothing matches, the result is an empty array. It never throws or
// crashes, and the caller decides on a fallback (for example, the scanner
// falls back to the first OCR line for the roaster).
// =============================================================

// -------------------------------------------------------------
// [Swift Lesson 2]: STRUCTS + CODABLE (JSON entry model)
// -------------------------------------------------------------
/// One row in CoffeeReference.json, e.g. { "name": "Gesha", "aliases": ["Geisha"] }
struct ReferenceEntry: Codable {
    /// The canonical spelling we store in the app and show to the user
    let name: String

    /// Alternate spellings found on bags. Optional because most entries have none.
    /// [Swift Lesson 3]: Optionals. A missing "aliases" key in the JSON decodes to nil.
    let aliases: [String]?

    /// Canonical name first, then any alternate spellings.
    /// Every one of these becomes a search term, but all of them report back
    /// the same canonical `name` (so "Geisha" on a bag is recorded as "Gesha").
    var searchTerms: [String] { [name] + (aliases ?? []) }
}

/// Top-level shape of CoffeeReference.json. The property names must match
/// the JSON keys exactly so Codable can decode the file automatically.
private struct ReferenceData: Codable {
    let roasters: [ReferenceEntry]
    let countries: [ReferenceEntry]
    let regions: [ReferenceEntry]
    let processes: [ReferenceEntry]
    let varieties: [ReferenceEntry]

    /// Used when the file is missing or broken, so the app keeps working
    /// with no matches instead of crashing.
    static let empty = ReferenceData(
        roasters: [],
        countries: [],
        regions: [],
        processes: [],
        varieties: [])
}

// -------------------------------------------------------------
// [Swift Lesson 2]: CLASS (loaded once, shared by the scanner)
// -------------------------------------------------------------
final class CoffeeReference {

    /// The four lookup lists in the JSON file. The scanner picks which list
    /// to search by passing one of these.
    enum Category {
        case roasters, countries, processes, varieties, regions
    }

    /// One compiled search pattern. A single entry can produce several of these
    /// (one for its name, one per alias), and all of them point back to the same
    /// `canonicalName`.
    private struct Matcher {
        let canonicalName: String
        let regex: NSRegularExpression
    }

    // [Swift Lesson 2]: `static let` singleton. Initialized lazily, exactly once,
    // the first time anything touches `CoffeeReference.shared`.
    static let shared = CoffeeReference()

    /// All compiled patterns, grouped by category. Built once in `init` because
    /// compiling ~500 regexes on every scan would be wasteful.
    private let matchers: [Category: [Matcher]]

    init(bundle: Bundle = .main, resourceName: String = "CoffeeReference") {
        // Step 1 (LOAD): read and decode the JSON file
        let data = Self.loadData(bundle: bundle, resourceName: resourceName)

        // Step 2 (COMPILE): turn every name and alias into a regex
        matchers = [
            .roasters:  Self.buildMatchers(from: data.roasters),
            .countries: Self.buildMatchers(from: data.countries),
            .regions:   Self.buildMatchers(from: data.regions),
            .processes: Self.buildMatchers(from: data.processes),
            .varieties: Self.buildMatchers(from: data.varieties)
        ]
    }

    // MARK: - Public API

    /// Returns the canonical names found in the OCR lines for one category,
    /// ordered by where they appear in the text.
    ///
    /// - Whole-word only: "NATIVE" won't match inside "alternative".
    /// - Longest match wins: "Pink Bourbon" returns only "Pink Bourbon", not also "Bourbon".
    /// - Ignores case, accents, and curly vs. straight apostrophes.
    /// - Returns [] when nothing matches. The caller supplies any fallback.
    func matches(in lines: [String], for category: Category) -> [String] {

        // Step 3 (NORMALIZE): combine all OCR lines into one lowercase,
        // accent-free string. Lines are joined with a space (not a newline)
        // so a name that wraps across two lines, like "Counter Culture" /
        // "Coffee", can still match as one phrase.
        let text = Self.normalize(lines.joined(separator: " "))

        // NSRegularExpression works with NSRange (UTF-16 offsets), so we
        // build a range covering the whole string.
        let fullRange = NSRange(text.startIndex..., in: text)

        /// A single regex match: which canonical name, and where in the text.
        struct Hit {
            let name: String
            let range: NSRange
        }

        // Step 4 (MATCH): run every pattern for this category against the text
        // and record every place it hits. A term can hit more than once.
        var hits: [Hit] = []
        for matcher in matchers[category] ?? [] {
            for result in matcher.regex.matches(in: text, range: fullRange) {
                hits.append(Hit(name: matcher.canonicalName, range: result.range))
            }
        }

        // Step 5 (PRUNE): throw away any hit that sits entirely inside a longer one.
        // Example text: "pink bourbon"
        //   "Bourbon"      hits characters 5-11   (length 7)
        //   "Pink Bourbon" hits characters 0-11   (length 12)
        // The shorter range is fully contained in the longer one, so "Bourbon" is
        // dropped and only "Pink Bourbon" survives.
        // NSIntersectionRange gives the overlap of two ranges. If the overlap is
        // as long as the short hit itself, the short hit is fully inside.
        let kept = hits.filter { hit in
            !hits.contains { other in
                other.range.length > hit.range.length &&
                NSIntersectionRange(other.range, hit.range).length == hit.range.length
            }
        }

        // Step 6 (RETURN): sort by position so results read in the order they
        // appear on the bag, and drop duplicate names (a term that appears twice,
        // or a name and its alias both present). `Set.insert` returns
        // `.inserted == false` if the name was already seen.
        var seen = Set<String>()
        var results: [String] = []
        for hit in kept.sorted(by: { $0.range.location < $1.range.location }) {
            if seen.insert(hit.name).inserted {
                results.append(hit.name)
            }
        }
        return results
    }

    // MARK: - Loading

    /// Reads and decodes the JSON from the app bundle. On any failure it returns
    /// empty data (no matches) so the app keeps running. In debug builds the
    /// assertion stops with a message so you notice the problem right away.
    private static func loadData(bundle: Bundle, resourceName: String) -> ReferenceData {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            // Usually means the JSON isn't checked for the app target in Xcode
            assertionFailure("\(resourceName).json not found. Check that it is added to the app target.")
            return .empty
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ReferenceData.self, from: data)
        } catch {
            // Usually means a JSON typo (missing comma, bad quote) or a key mismatch
            assertionFailure("Could not decode \(resourceName).json: \(error)")
            return .empty
        }
    }

    // MARK: - Matching helpers

    /// Turns each entry's name and aliases into compiled whole-word regexes.
    private static func buildMatchers(from entries: [ReferenceEntry]) -> [Matcher] {
        var result: [Matcher] = []
        for entry in entries {
            for term in entry.searchTerms {

                // Normalize the term the same way the OCR text is normalized,
                // otherwise "Café Bustelo" (with accent) could never match
                // OCR text that was stripped of accents.
                // escapedPattern makes characters like "." or "&" literal so
                // they aren't read as regex commands.
                let escaped = NSRegularExpression.escapedPattern(for: normalize(term))
                    // Let one space in the term match any run of whitespace,
                    // since OCR sometimes produces double or odd spacing.
                    .replacingOccurrences(of: " ", with: "\\s+")

                // WHOLE-WORD RULE:
                //   (?<![\p{L}\p{N}])  means "not preceded by a letter or digit"
                //   (?![\p{L}\p{N}])   means "not followed by a letter or digit"
                // This stops "NATIVE" from matching inside "alternative" and
                // "SL28" from matching inside "SL289". We use these lookarounds
                // instead of the usual \b because \b breaks on terms that end
                // in punctuation, like "Dunkin'".
                let pattern = "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"

                // try? skips any term whose pattern fails to compile
                // instead of crashing the whole app.
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    result.append(Matcher(canonicalName: entry.name, regex: regex))
                }
            }
        }
        return result
    }

    /// Makes text comparable: lowercase, no accents, straight apostrophes.
    /// Applied to BOTH the OCR text and every search term, so both sides
    /// are in the same form before matching.
    ///   "Café Bustelo" -> "cafe bustelo"
    ///   "Peet’s"       -> "peet's"
    private static func normalize(_ string: String) -> String {
        string
            // OCR and typed JSON often disagree on curly vs. straight apostrophes
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            // Case and accent insensitive. locale: nil keeps the result the same
            // on every device, regardless of the user's language settings.
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
