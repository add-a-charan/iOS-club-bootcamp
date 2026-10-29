# Mini README: `CoffeeBag.swift`

## 1. Purpose of this File
`CoffeeBag.swift` is the **single persistent data model** for the entire application. It defines the structure of a saved coffee record stored locally on the user's iPhone using **SwiftData**. It stores:
* Permanent photo binaries (`[Data]`) for the home feed.
* Extracted bag details (Roaster, Name, Origin, Process, Elevation, Bag Tasting Notes).
* User review ratings (Overall 0.0–5.0 slider, Brew Method dropdown, Personal Notes).
* Four sensory sliding scales (Bitterness–Sweetness, Acidity, Body, Funkiness).

It also defines the domain **Enums** (`BrewMethod` and `OriginType`) to prevent typos and enforce type safety.

---

## 2. Swift Lecture Lessons Called Upon

| Lesson | Core Concept | How It Is Used Here |
| :--- | :--- | :--- |
| **Swift Basics 1** | **Constants vs. Variables** | Uses `let id: UUID` for immutable identity and `var` for editable coffee attributes. |
| **Swift Basics 1** | **Explicit Types & Collections** | Uses explicit types: `String`, `Double`, `UUID`, `Date`, and `[Data]`. |
| **Swift Lesson 2** | **Classes vs. Structs** | `CoffeeBag` is declared as a `class` (Reference Type) because SwiftData requires class identity to track and persist database records. |
| **Swift Lesson 2** | **Enums with Raw Values** | `enum BrewMethod: String` and `enum OriginType: String` restrict selections and eliminate typo bugs. |
| **Swift Lesson 2** | **Protocols** | Conforms to `CaseIterable` (providing `.allCases` for pickers) and `Codable`. |
| **Swift Lesson 2** | **Required Initializers** | Implements an explicit `init(...)` since Swift classes do not automatically receive memberwise initializers like structs do. |
| **Swift Lesson 3** | **Optionals (`nil`, `?`)** | Nullable cupping fields are declared as optional (`String?`, `Double?`) with default `nil` values. |
| **Swift Lesson 3** | **Computed Properties** | Implements getters and setters to bridge raw database strings to type-safe enums (`brewMethod`, `originType`), and `formattedRating`. |
| **Swift Lesson 3** | **Optional Binding & Guard** | Safely converts raw strings back to enum cases using `guard let raw = ... else { return nil }`. |

---

## 3. Variables, Methods, and Components Needed

### Supporting Domain Enums
1. **`BrewMethod: String, CaseIterable, Codable`**:
   * Cases: `.filter = "Filter"`, `.espresso = "Espresso"`, `.immersion = "Immersion"`.
2. **`OriginType: String, CaseIterable, Codable`**:
   * Cases: `.singleOrigin = "Single Origin"`, `.fieldBlend = "Field Blend"`, `.blend = "Blend"`.

### Stored Properties in `@Model class CoffeeBag`
* `@Attribute(.unique) var id: UUID`: Unique primary key for fast indexing and SwiftUI list identity.
* `@Attribute(.externalStorage) var photosData: [Data]`: 1–2 photos stored as binary data, offloaded to external disk storage by SwiftData to keep queries fast.
* `var roaster: String`: Coffee roasting company.
* `var coffeeName: String`: Name of roast/blend.
* `var countryOfOrigin: String?`: Country (e.g. "Colombia", "Ethiopia").
* `var varieties: String?`: Bean variety (e.g. "Caturra, Heirloom").
* `var processes: String?`: Processing method (e.g. "Washed", "Natural").
* `var originTypeRaw: String?`: Stored raw string for origin type.
* `var elevation: String?`: Growing elevation (e.g. "1800m").
* `var tastingNotes: String?`: Printed notes on bag (e.g. "Chocolate, berries").
* `var overallRating: Double`: Rating from 0.0 to 5.0.
* `var brewMethodRaw: String?`: Stored raw string for brew method.
* `var personalNotes: String`: User's custom tasting impressions.
* `var sweetnessBitterness: Double?`: 0.0–5.0 sensory scale.
* `var acidity: Double?`: 0.0–5.0 sensory scale.
* `var body: Double?`: 0.0–5.0 sensory scale.
* `var funkiness: Double?`: 0.0–5.0 sensory scale.
* `var dateAdded: Date`: Creation timestamp.

### Methods & Computed Properties
* `init(...)`: Explicit designated initializer with default values.
* `var brewMethod: BrewMethod? { get set }`: Type-safe computed property wrapping `brewMethodRaw`.
* `var originType: OriginType? { get set }`: Type-safe computed property wrapping `originTypeRaw`.
* `var formattedRating: String`: Read-only computed property returning 1-decimal rating string.

---

## 4. Basic Code Structure

```swift
import Foundation
import SwiftData

// -------------------------------------------------------------
// [Lesson 2]: ENUMS (Prevent typos and constrain options)
// -------------------------------------------------------------
enum BrewMethod: String, CaseIterable, Codable {
    case filter = "Filter"
    case espresso = "Espresso"
    case immersion = "Immersion"
}

enum OriginType: String, CaseIterable, Codable {
    case singleOrigin = "Single Origin"
    case fieldBlend = "Field Blend"
    case blend = "Blend"
}

// -------------------------------------------------------------
// [Lesson 2]: CLASS (Reference type required by SwiftData)
// -------------------------------------------------------------
@Model
final class CoffeeBag {
    // [Swift Basics 1 & SwiftData]: Primary unique indexed key
    @Attribute(.unique) var id: UUID
    
    // Preserved Photos (Stored as binary Data with external storage optimization)
    @Attribute(.externalStorage) var photosData: [Data]

    // Core Extracted Fields
    var roaster: String
    var coffeeName: String
    var countryOfOrigin: String?
    var varieties: String?
    var processes: String?
    var originTypeRaw: String?
    var elevation: String?
    var tastingNotes: String?

    // User Review & Rating
    var overallRating: Double
    var brewMethodRaw: String?
    var personalNotes: String

    // Sensory Sliding Scales (0.0 - 5.0)
    var sweetnessBitterness: Double?
    var acidity: Double?
    var body: Double?
    var funkiness: Double?

    // Timestamp
    var dateAdded: Date

    // [Lesson 2]: Explicit required initializer for classes
    init(
        id: UUID = UUID(),
        photosData: [Data] = [],
        roaster: String,
        coffeeName: String,
        countryOfOrigin: String? = nil,
        varieties: String? = nil,
        processes: String? = nil,
        originType: OriginType? = nil,
        elevation: String? = nil,
        tastingNotes: String? = nil,
        overallRating: Double = 0.0,
        brewMethod: BrewMethod? = nil,
        personalNotes: String = "",
        sweetnessBitterness: Double? = nil,
        acidity: Double? = nil,
        body: Double? = nil,
        funkiness: Double? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.photosData = photosData
        self.roaster = roaster
        self.coffeeName = coffeeName
        self.countryOfOrigin = countryOfOrigin
        self.varieties = varieties
        self.processes = processes
        self.originTypeRaw = originType?.rawValue
        self.elevation = elevation
        self.tastingNotes = tastingNotes
        self.overallRating = overallRating
        self.brewMethodRaw = brewMethod?.rawValue
        self.personalNotes = personalNotes
        self.sweetnessBitterness = sweetnessBitterness
        self.acidity = acidity
        self.body = body
        self.funkiness = funkiness
        self.dateAdded = dateAdded
    }

    // [Lesson 3]: Computed property wrapping raw brew method string into enum
    var brewMethod: BrewMethod? {
        get {
            guard let raw = brewMethodRaw else { return nil }
            return BrewMethod(rawValue: raw)
        }
        set { brewMethodRaw = newValue?.rawValue }
    }

    // [Lesson 3]: Computed property wrapping raw origin string into enum
    var originType: OriginType? {
        get {
            guard let raw = originTypeRaw else { return nil }
            return OriginType(rawValue: raw)
        }
        set { originTypeRaw = newValue?.rawValue }
    }

    // [Lesson 3]: Computed property for UI rating badge
    var formattedRating: String {
        String(format: "%.1f", overallRating)
    }
}
```
