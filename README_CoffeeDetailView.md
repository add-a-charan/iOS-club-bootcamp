# Mini README: `CoffeeDetailView.swift`

## 1. Purpose of this File
`CoffeeDetailView.swift` is the **cupping card and inspection screen** for a single saved coffee. It:
* Displays the preserved coffee bag photos in a horizontal gallery header.
* Shows all extracted and verified coffee parameters (Roaster, Name, Origin, Variety, Process, Elevation, Bag Notes).
* Shows the user's cupping review (Overall Rating, Brew Method, Personal Notes).
* Renders the 4 sensory profile values (Bitterness–Sweetness, Acidity, Body, Funkiness).
* Provides a destructive **Delete** action with confirmation dialog, removing the record from SwiftData and popping back to the passport feed.

---

## 2. Swift Lecture Lessons Called Upon

| Lesson | Core Concept | How It Is Used Here |
| :--- | :--- | :--- |
| **Swift Basics 1** | **String Interpolation & Formatting** | Formats ratings: `"\(coffee.formattedRating) / 5.0"` and `String(format: "%.1f / 5.0", sb)`. |
| **Swift Lesson 2** | **Reference Semantics** | Accepts `let coffee: CoffeeBag` as a reference type; changes to the model reflect immediately. |
| **Swift Lesson 3** | **Optional Unwrapping in UI (`if let`)** | Only displays sections/rows if the optional property is non-nil (e.g. `if let country = coffee.countryOfOrigin`). |
| **SwiftUI Lesson 1** | **Form, Section & LabeledContent** | Uses `LabeledContent("Label", value: "Value")` inside `Form` sections for clean iOS system styling. |
| **SwiftUI Lesson 2** | **Environment Model Context** | Uses `@Environment(\.modelContext)` to delete records. |
| **SwiftUI Lesson 3** | **Programmatic Pop (`dismiss`)** | Calls `dismiss()` after deletion to pop back to `PassportView`. |
| **SwiftUI Lesson 4** | **Horizontal ScrollView** | Implements `ScrollView(.horizontal)` for the photo gallery header. |
| **SwiftUI Lesson 4** | **Confirmation Alert** | Attaches `.alert("Delete this coffee?", isPresented: $showDeleteAlert)` to prevent accidental deletions. |

---

## 3. Variables, Methods, and Components Needed

### Stored Properties
* `let coffee: CoffeeBag`: The persistent record passed in from the parent feed.

### Environment & View State Properties
* `@Environment(\.modelContext) private var modelContext`: Persistent database access.
* `@Environment(\.dismiss) private var dismiss`: Closes the detail screen and pops back to the root feed.
* `@State private var showDeleteAlert: Bool = false`: Controls presentation of the deletion confirmation alert.

### UI Components
* `Form`: Grouped table layout.
* `ScrollView(.horizontal)`: Carousel for viewing the 1–2 bag photos.
* `LabeledContent`: Native SwiftUI view for key-value row display.
* `Button(role: .destructive)`: Red trash button to initiate deletion.
* `.alert`: Two-button confirmation dialog ("Delete" vs. "Cancel").

---

## 4. Basic Code Structure

```swift
import SwiftUI
import SwiftData

// [SwiftUI L1]: View Protocol Conformance
struct CoffeeDetailView: View {
    // [Lesson 2]: Reference type passed from parent feed
    let coffee: CoffeeBag

    // [SwiftUI L2 & L3]: Environment access
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // [SwiftUI L2]: State toggle for deletion alert
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        Form {
            // [SwiftUI L4]: Photo Gallery Header (if photos exist)
            if !coffee.photosData.isEmpty {
                Section("Bag Photos") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(coffee.photosData, id: \.self) { data in
                                if let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 140, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Coffee Information Section
            Section("Coffee Information") {
                LabeledContent("Roaster", value: coffee.roaster)
                LabeledContent("Coffee Name", value: coffee.coffeeName)
                
                // [Lesson 3]: Conditionally display optional fields
                if let country = coffee.countryOfOrigin {
                    LabeledContent("Country of Origin", value: country)
                }
                if let varieties = coffee.varieties {
                    LabeledContent("Variety(s)", value: varieties)
                }
                if let processes = coffee.processes {
                    LabeledContent("Process(s)", value: processes)
                }
                if let originType = coffee.originType {
                    LabeledContent("Origin Type", value: originType.rawValue)
                }
                if let elevation = coffee.elevation {
                    LabeledContent("Elevation", value: elevation)
                }
                if let tastingNotes = coffee.tastingNotes {
                    LabeledContent("Tasting Notes", value: tastingNotes)
                }
            }

            // Rating & Brew Section
            Section("Rating & Brew") {
                LabeledContent("Overall Rating", value: "\(coffee.formattedRating) / 5.0")
                if let brew = coffee.brewMethod {
                    LabeledContent("Brew Method", value: brew.rawValue)
                }
                if !coffee.personalNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Personal Notes").font(.caption).foregroundStyle(.secondary)
                        Text(coffee.personalNotes)
                    }
                }
            }

            // Sensory Sliders Section (Lesson 3 Optionals)
            Section("Sensory Profile") {
                if let sb = coffee.sweetnessBitterness {
                    LabeledContent("Bitterness — Sweetness", value: String(format: "%.1f / 5.0", sb))
                }
                if let acidity = coffee.acidity {
                    LabeledContent("Acidity", value: String(format: "%.1f / 5.0", acidity))
                }
                if let body = coffee.body {
                    LabeledContent("Body", value: String(format: "%.1f / 5.0", body))
                }
                if let funk = coffee.funkiness {
                    LabeledContent("Funkiness", value: String(format: "%.1f / 5.0", funk))
                }
            }

            // Destructive Delete Action
            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Coffee", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(coffee.coffeeName)
        // [SwiftUI L4]: Deletion confirmation alert
        .alert("Delete this coffee?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(coffee)
                dismiss() // [SwiftUI L3]: Pop back to PassportView
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}
```
