import SwiftUI
import SwiftData

@main
struct CoffeeOCRProjectApp: App {
    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
        .modelContainer(for: CoffeeBag.self)
    }
}
