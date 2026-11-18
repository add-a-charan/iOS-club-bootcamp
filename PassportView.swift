import SwiftUI
import SwiftData

struct PassportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CoffeeBag.dateAdded, order: .reverse) private var coffees: [CoffeeBag]
    @State private var showingAddCoffee = false
    @State private var isDeleting = false

    var onHome: () -> Void = {}

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)

    private var slotCount: Int {
        max(9, (coffees.count + 2) / 3 * 3)
    }

    var body: some View {
        ZStack {
            Color.mugShotBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: onHome) {
                        Image(systemName: "house.fill")
                    }
                    Spacer()
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 72))
                    Spacer()
                    Button {
                        isDeleting.toggle()
                    } label: {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(isDeleting ? .red : .black)
                    }
                }
                .font(.largeTitle)
                .padding(.horizontal, 24)

                HStack {
                    Spacer()
                    Button {
                        showingAddCoffee = true
                    } label: {
                        Label("Add coffee", systemImage: "plus.circle")
                    }
                    .font(.title3)
                }
                .padding()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(0..<slotCount, id: \.self) { index in
                            cell(at: index)
                        }
                    }
                }
            }
            .foregroundStyle(.black)
        }
        .fullScreenCover(isPresented: $showingAddCoffee) {
            AddCoffeeView()
        }
    }

    private func cell(at index: Int) -> some View {
        Color.clear
            .aspectRatio(0.9, contentMode: .fit)
            .overlay {
                if index < coffees.count {
                    tile(for: coffees[index])
                }
            }
            .clipped()
            .border(.black, width: 0.5)
    }

    private func tile(for coffee: CoffeeBag) -> some View {
        ZStack(alignment: .topTrailing) {
            if let data = coffee.photosData.first, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(coffee.coffeeName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if isDeleting {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white, .red)
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isDeleting {
                modelContext.delete(coffee)
            }
        }
    }
}
