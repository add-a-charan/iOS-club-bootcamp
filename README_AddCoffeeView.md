# Mini README: `AddCoffeeView.swift`

## 1. Purpose of this File
`AddCoffeeView.swift` is the **modal creation and editing screen**. It orchestrates the user review pipeline:
1. **Photo Acquisition:** Accepts 1–2 photos of the coffee bag (front and back) via `PhotosPicker`.
2. **Scan & Parse Trigger:** Automatically runs `CoffeeScanner` to extract text via Apple Vision OCR.
3. **Pre-fill & Verify:** Pre-populates form fields (`roaster`, `coffeeName`, `countryOfOrigin`, `varieties`, `processes`, `originType`, `elevation`, `tastingNotes`) for user verification.
4. **Rating & Sensories:** Allows the user to set the overall rating (0.0–5.0 slider), select the brew method from a dropdown menu, add personal notes, and adjust 4 sensory sliders (Bitterness–Sweetness, Acidity, Body, Funkiness).
5. **Persistence:** Commits the record (with preserved photos) into **SwiftData** and dismisses the modal.

---

## 2. Swift Lecture Lessons Called Upon

| Lesson | Core Concept | How It Is Used Here |
| :--- | :--- | :--- |
| **Swift Basics 1** | **Comparison & Logical Operators** | Disables the save button using `roaster.isEmpty || coffeeName.isEmpty`. |
| **Swift Basics 1** | **String Interpolation** | Formats slider values: `"Overall Rating: \(String(format: "%.1f", overallRating)) / 5.0"`. |
| **Swift Lesson 2** | **Enums in Pickers** | Iterates over `BrewMethod.allCases` and `OriginType.allCases` in SwiftUI Pickers. |
| **Swift Lesson 3** | **Optional Wrapping & Unwrapping** | Converts empty optional strings to `nil` before saving (`origin.isEmpty ? nil : origin`). |
| **SwiftUI Lesson 1** | **Forms & Controls** | Uses `Form`, `Section`, `TextField`, `Slider`, and `Button`. |
| **SwiftUI Lesson 2** | **Two-Way Data Binding (`@State` & `$`)** | Uses `@State` for all form inputs and passes bindings (`$roaster`, `$coffeeName`, `$overallRating`) into controls. |
| **SwiftUI Lesson 2** | **Environment Context** | Uses `@Environment(\.modelContext)` to obtain the SwiftData database session. |
| **SwiftUI Lesson 3** | **Programmatic Dismissal** | Obtains `@Environment(\.dismiss) private var dismiss` and calls `dismiss()` when cancel or save is tapped. |
| **SwiftUI Lesson 3** | **Toolbars** | Uses `.cancellationAction` and `.confirmationAction` toolbar placements. |
| **SwiftUI Lesson 4** | **PhotosPicker & Concurrency** | Ingests up to 2 photos using `PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 2)` and reacts via `.onChange`. |
| **SwiftUI Lesson 4** | **Dropdown Menu Styling** | Styles the brew method picker with `.pickerStyle(.menu)`. |

---

## 3. Variables, Methods, and Components Needed

### Environment Values
* `@Environment(\.modelContext) private var modelContext`: SwiftData database access.
* `@Environment(\.dismiss) private var dismiss`: Closure to pop/dismiss the modal.

### View State Properties (`@State`)
* Photo Selection:
  * `selectedPhotoItems: [PhotosPickerItem]`: Selection handles from the photo picker.
  * `savedPhotosData: [Data]`: Binary payloads preserved for saving into SwiftData.
  * `isScanning: Bool`: Shows `ProgressView` while Vision OCR runs.
* Extracted & Verified Fields:
  * `roaster: String`, `coffeeName: String`
  * `countryOfOrigin: String`, `varieties: String`, `processes: String`
  * `selectedOriginType: OriginType` (Default: `.singleOrigin`)
  * `elevation: String`, `tastingNotes: String`
* Ratings & Personal Notes:
  * `overallRating: Double` (0.0 to 5.0 slider)
  * `selectedBrewMethod: BrewMethod` (Default: `.filter`)
  * `personalNotes: String`
* Sensory Sliders (0.0 to 5.0):
  * `sweetnessBitterness: Double`, `acidity: Double`, `bodyRating: Double`, `funkiness: Double`

### Methods
* `private func saveCoffee()`: Instantiates a `CoffeeBag` class from the verified `@State` variables, calls `modelContext.insert(record)`, and dismisses the view.

---

## 4. Basic Code Structure

```swift
import SwiftUI
import PhotosUI
import SwiftData

struct AddCoffeeView: View {
    // [SwiftUI L2 & L3]: Environment properties
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 1. Photo input state (2 photos max)
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var savedPhotosData: [Data] = []
    @State private var isScanning: Bool = false
    private let scanner = CoffeeScanner()

    // 2. Extracted & Verified Fields
    @State private var roaster: String = ""
    @State private var coffeeName: String = ""
    @State private var countryOfOrigin: String = ""
    @State private var varieties: String = ""
    @State private var processes: String = ""
    @State private var selectedOriginType: OriginType = .singleOrigin
    @State private var elevation: String = ""
    @State private var tastingNotes: String = ""

    // 3. Review & Rate Fields
    @State private var overallRating: Double = 4.0
    @State private var selectedBrewMethod: BrewMethod = .filter
    @State private var personalNotes: String = ""

    // 4. Sensory Sliders (0.0 - 5.0)
    @State private var sweetnessBitterness: Double = 2.5
    @State private var acidity: Double = 2.5
    @State private var bodyRating: Double = 2.5
    @State private var funkiness: Double = 1.0

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Photo selection & thumbnails
                Section("Photos (Front & Back — 2 Max)") {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 2,
                        matching: .images
                    ) {
                        Label("Select Photos from Library", systemImage: "photo.on.rectangle")
                    }

                    // Previews preserved photos
                    if !savedPhotosData.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(savedPhotosData, id: \.self) { data in
                                if let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if isScanning {
                        HStack {
                            ProgressView()
                            Text("Scanning bag with Vision OCR...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Section 2: Verified Details
                Section("Verified Details") {
                    TextField("Roaster *", text: $roaster)
                    TextField("Coffee Name *", text: $coffeeName)
                    TextField("Country of Origin", text: $countryOfOrigin)
                    TextField("Variety(s)", text: $varieties)
                    TextField("Process(s)", text: $processes)
                    
                    Picker("Origin Type", selection: $selectedOriginType) {
                        ForEach(OriginType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Elevation (e.g. 1800m)", text: $elevation)
                    TextField("Bag Tasting Notes", text: $tastingNotes)
                }

                // Section 3: Rating & Brew Method
                Section("Rating & Brew Method") {
                    VStack(alignment: .leading) {
                        Text("Overall Rating: \(String(format: "%.1f", overallRating)) / 5.0")
                        Slider(value: $overallRating, in: 0.0...5.0, step: 0.1)
                    }

                    // Dropdown menu select for brew method
                    Picker("Brew Method", selection: $selectedBrewMethod) {
                        ForEach(BrewMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Section 4: Sensory Profiles (0 - 5 Sliders)
                Section("Sensory Attributes (0 - 5)") {
                    VStack(alignment: .leading) {
                        Text("Bitterness — Sweetness: \(String(format: "%.1f", sweetnessBitterness))")
                        Slider(value: $sweetnessBitterness, in: 0.0...5.0, step: 0.5)
                    }
                    VStack(alignment: .leading) {
                        Text("Acidity: \(String(format: "%.1f", acidity))")
                        Slider(value: $acidity, in: 0.0...5.0, step: 0.5)
                    }
                    VStack(alignment: .leading) {
                        Text("Body: \(String(format: "%.1f", bodyRating))")
                        Slider(value: $bodyRating, in: 0.0...5.0, step: 0.5)
                    }
                    VStack(alignment: .leading) {
                        Text("Funkiness: \(String(format: "%.1f", funkiness))")
                        Slider(value: $funkiness, in: 0.0...5.0, step: 0.5)
                    }
                }

                // Section 5: Personal Notes
                Section("Personal Notes") {
                    TextField("Add your notes...", text: $personalNotes, axis: .vertical)
                }
            }
            .navigationTitle("Add Coffee")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCoffee() }
                        .disabled(roaster.isEmpty || coffeeName.isEmpty)
                }
            }
            // Ingests photos, retains data, and executes OCR
            .onChange(of: selectedPhotoItems) { _, items in
                Task {
                    var loadedImages: [UIImage] = []
                    var loadedData: [Data] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            loadedData.append(data)
                            loadedImages.append(image)
                        }
                    }
                    guard !loadedImages.isEmpty else { return }
                    
                    self.savedPhotosData = loadedData
                    isScanning = true
                    if let details = try? await scanner.scanAndExtract(from: loadedImages) {
                        self.roaster = details.roaster
                        self.coffeeName = details.coffeeName
                        if let country = details.countryOfOrigin { self.countryOfOrigin = country }
                        if let v = details.varieties { self.varieties = v }
                        if let p = details.processes { self.processes = p }
                        if let type = details.originType { self.selectedOriginType = type }
                        if let elev = details.elevation { self.elevation = elev }
                        if let notes = details.tastingNotes { self.tastingNotes = notes }
                    }
                    isScanning = false
                }
            }
        }
    }

    private func saveCoffee() {
        let record = CoffeeBag(
            photosData: savedPhotosData,
            roaster: roaster,
            coffeeName: coffeeName,
            countryOfOrigin: countryOfOrigin.isEmpty ? nil : countryOfOrigin,
            varieties: varieties.isEmpty ? nil : varieties,
            processes: processes.isEmpty ? nil : processes,
            originType: selectedOriginType,
            elevation: elevation.isEmpty ? nil : elevation,
            tastingNotes: tastingNotes.isEmpty ? nil : tastingNotes,
            overallRating: overallRating,
            brewMethod: selectedBrewMethod,
            personalNotes: personalNotes,
            sweetnessBitterness: sweetnessBitterness,
            acidity: acidity,
            body: bodyRating,
            funkiness: funkiness
        )
        modelContext.insert(record)
        dismiss()
    }
}
```
