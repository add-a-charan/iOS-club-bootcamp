import SwiftUI
import SwiftData

extension Color {
    static let mugShotBackground = Color(red: 0.95, green: 0.85, blue: 0.80)
}

struct WelcomeView: View {
    @Query private var coffees: [CoffeeBag]
    @State private var showingPassport = false
    @State private var showingAddCoffee = false
    @State private var didSave = false

    var body: some View {
        if showingPassport {
            PassportView { showingPassport = false }
        } else {
            ZStack {
                Color.mugShotBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "mug")
                        .font(.system(size: 44))
                    Text("MugShot")
                        .font(.largeTitle.bold())
                        .padding(.top, 40)
                    Text("Never forget the coffee you love")
                        .font(.subheadline)
                    Button("Add Coffee") { showingAddCoffee = true }
                        .font(.title2)
                        .padding(.top, 100)
                    if !coffees.isEmpty {
                        Button("View passport") { showingPassport = true }
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(.black)
            }
            .fullScreenCover(isPresented: $showingAddCoffee, onDismiss: {
                if didSave {
                    didSave = false
                    showingPassport = true
                }
            }) {
                AddCoffeeView { didSave = true }
            }
        }
    }
}
