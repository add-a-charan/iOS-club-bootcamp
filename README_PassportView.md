# Mini README: `PassportView.swift`

## 1. Purpose of this File
`PassportView.swift` is the **home screen and visual feed** of the Coffee Passport app (similar to Beli). It:
* Automatically fetches all saved coffees from local SwiftData storage via `@Query`.
* Displays a scrollable feed where each coffee card shows the **bag photo thumbnail**, **Coffee Name**, **Roaster**, and **Overall Rating**.
* Provides the navigation entry point to view details via `NavigationLink`.
* Houses the top navigation bar with the `+` button that opens `AddCoffeeView` modally.

---

## 2. Swift Lecture Lessons Called Upon

| Lesson | Core Concept | How It Is Used Here |
| :--- | :--- | :--- |
| **SwiftUI Lesson 1** | **View Protocol & Body** | Conforms to `View` and implements `var body: some View`. |
| **SwiftUI Lesson 1** | **Stacks & Layout** | Uses `HStack` (horizontal layout for image + text + rating) and `VStack` (stacking title above roaster). |
| **SwiftUI Lesson 1** | **Spacers & SF Symbols** | Uses `Spacer()` to push the rating badge to the right margin, and SF Symbols (`star.fill`, `plus`). |
| **SwiftUI Lesson 1** | **View Modifiers** | Styles cards using `.font()`, `.foregroundStyle()`, `.frame()`, and `.clipShape()`. |
| **SwiftUI Lesson 2** | **Source of Truth (`@Query`)** | Uses SwiftData's `@Query` to observe database changes and automatically trigger reactive view redraws. |
| **SwiftUI Lesson 2** | **View State (`@State`)** | Manages local modal sheet presentation using `@State private var showingAddCoffee = false`. |
| **SwiftUI Lesson 3** | **NavigationStack & Links** | Wraps the view in `NavigationStack` and pushes `CoffeeDetailView(coffee: coffee)` via `NavigationLink`. |
| **SwiftUI Lesson 3** | **Toolbars** | Adds the `+` button to the navigation bar using `.toolbar { ToolbarItem(...) }`. |
| **SwiftUI Lesson 4** | **List Container** | Uses `List(coffees) { ... }` to provide native iOS table scrolling and cell reuse. |
| **SwiftUI Lesson 4** | **Modal Sheets** | Presents the add-coffee form using `.sheet(isPresented: $showingAddCoffee) { AddCoffeeView() }`. |
| **Swift Lesson 3** | **Optional Binding (`if let`)** | Safely converts the first photo binary into a displayable `UIImage` using `if let firstData = coffee.photosData.first, let uiImage = UIImage(data: firstData)`. |

---

## 3. Variables, Methods, and Components Needed

### Property Wrappers & View State
* `@Query(sort: \CoffeeBag.dateAdded, order: .reverse) private var coffees: [CoffeeBag]`:
  * **Role:** Reactive database listener that automatically reloads the list whenever a coffee is added, updated, or deleted.
* `@State private var showingAddCoffee: Bool = false`:
  * **Role:** Controls whether the `AddCoffeeView` modal sheet is visible.

### UI Components
* `NavigationStack`: The container for hierarchical push/pop navigation.
* `List`: Scrollable table displaying each saved coffee.
* `NavigationLink`: Connects a feed row to `CoffeeDetailView`.
* `Image(uiImage:)`: Renders the saved photo binary thumbnail.
* `ToolbarItem`: Positions the `+` button in `.topBarTrailing`.
* `.sheet`: Displays `AddCoffeeView` modally when `showingAddCoffee` is set to `true`.

---

## 4. Basic Code Structure

```swift
import SwiftUI
import SwiftData

// [SwiftUI L1]: View Protocol Conformance
struct PassportView: View {
    // [SwiftUI L2 & SwiftData]: Reactive source of truth for saved coffees
    @Query(sort: \CoffeeBag.dateAdded, order: .reverse) private var coffees: [CoffeeBag]
    
    // [SwiftUI L2]: Local view state for presenting modal sheet
    @State private var showingAddCoffee: Bool = false

    // [SwiftUI L1]: Body protocol requirement
    var body: some View {
        // [SwiftUI L3]: Top-level navigation container
        NavigationStack {
            // [SwiftUI L4]: Scrollable feed list
            List(coffees) { coffee in
                // [SwiftUI L3]: Value-based navigation link
                NavigationLink(destination: CoffeeDetailView(coffee: coffee)) {
                    
                    // Beli-style feed row: Photo Thumbnail + Title + Roaster + Rating
                    HStack(spacing: 12) {
                        
                        // [Lesson 3]: Safe unwrapping of optional photo binary
                        if let firstData = coffee.photosData.first,
                           let uiImage = UIImage(data: firstData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            // Fallback placeholder icon
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "cup.and.saucer.fill")
                                        .foregroundStyle(.secondary)
                                )
                        }

                        // Text information
                        VStack(alignment: .leading, spacing: 4) {
                            Text(coffee.coffeeName)
                                .font(.headline)
                            Text(coffee.roaster)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // [SwiftUI L1]: Spacer pushing rating badge to trailing edge
                        Spacer()

                        // Star rating display
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(coffee.formattedRating)
                                .bold()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Coffee Passport")
            // [SwiftUI L3]: Toolbar button for adding coffee
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddCoffee = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // [SwiftUI L4]: Modal sheet presentation
            .sheet(isPresented: $showingAddCoffee) {
                AddCoffeeView()
            }
        }
    }
}
```
