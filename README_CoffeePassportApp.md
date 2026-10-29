# Mini README: `CoffeePassportApp.swift`

## 1. Purpose of this File
`CoffeePassportApp.swift` is the **application entry point**. It establishes the app lifecycle, sets up the initial window hierarchy (`WindowGroup`), and initializes the local **SwiftData** container (`.modelContainer(for: CoffeeBag.self)`), injecting database capabilities into the entire view hierarchy without needing manual instance passing.

---

## 2. Swift Lecture Lessons Called Upon

| Lesson | Core Concept | How It Is Used Here |
| :--- | :--- | :--- |
| **Swift Lesson 2** | **Structs & Protocols** | `struct CoffeePassportApp: App` conforms to Apple's `App` protocol. |
| **SwiftUI Lesson 1** | **View & Scene Hierarchy** | Implements the required `var body: some Scene` computed property returning a `WindowGroup`. |
| **SwiftUI Lesson 2** | **Environment Values & Data Flow** | Uses `.modelContainer(for: CoffeeBag.self)` to inject the SwiftData persistent context down to all descendant views. |
| **SwiftUI Lesson 3** | **Root View Navigation** | Places `PassportView()` as the root screen of the application window. |

---

## 3. Variables, Methods, and Components Needed

### Property Wrappers & Attributes
* `@main`: Compiler directive that identifies `CoffeePassportApp` as the starting point of the iOS app execution.

### Stored & Computed Properties
* `var body: some Scene`:
  * **Type:** `some Scene` (Opaque return type conforming to `Scene`).
  * **Role:** Constructs the window scene containing the initial visual interface.

### SwiftUI & SwiftData Components
* `WindowGroup`: Container managing the presentation of the main app window.
* `PassportView`: The top-level root view loaded on app launch.
* `.modelContainer(for: CoffeeBag.self)`: Configures the SQLite database schema and manages persistent transactions for `CoffeeBag` entities.

---

## 4. Basic Code Structure

```swift
import SwiftUI
import SwiftData

// [Lesson 2]: Struct conforming to the App protocol
@main
struct CoffeePassportApp: App {

    // [SwiftUI L1]: Scene protocol requirement
    var body: some Scene {
        WindowGroup {
            // [SwiftUI L3]: Root view of the app
            PassportView()
        }
        // [SwiftUI L2 & SwiftData]: Single container setup injecting 
        // persistence down to all child views automatically
        .modelContainer(for: CoffeeBag.self)
    }
}
```
