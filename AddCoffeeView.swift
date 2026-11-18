import SwiftUI
import SwiftData
import PhotosUI

struct AddCoffeeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onSave: () -> Void = {}

    @State private var savedPhotosData: [Data] = []
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingReview = false
    @State private var hasScanned = false
    @State private var isScanning = false

    @State private var roaster = ""
    @State private var coffeeName = ""
    @State private var countryOfOrigin = ""
    @State private var region = ""
    @State private var varieties = ""
    @State private var processes = ""
    @State private var elevation = ""
    @State private var tastingNotes = ""
    @State private var originType: OriginType?

    @State private var bitterness = 3.0
    @State private var acidity = 3.0
    @State private var bodyLevel = 3.0
    @State private var funkiness = 3.0
    @State private var overallRating = 2.5

    var body: some View {
        NavigationStack {
            captureStep
                .navigationDestination(isPresented: $showingReview) { reviewStep }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }

    private var captureStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        if let data = savedPhotosData.last, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 120))
                                .foregroundStyle(.black)
                        }
                    }
                    .clipped()
            }
            .disabled(savedPhotosData.count >= 2)
            .frame(maxHeight: 560)

            Text(savedPhotosData.count == 1 ? "Tap to add the back of the bag" : "Upload a picture of your coffee")
                .font(.title2)

            if !savedPhotosData.isEmpty {
                HStack {
                    Button("Retake") {
                        savedPhotosData = []
                        hasScanned = false
                    }
                    Spacer()
                    Button("Next") {
                        showingReview = true
                        if !hasScanned {
                            hasScanned = true
                            Task { await scan() }
                        }
                    }
                    .bold()
                }
                .font(.title3)
            }
            Spacer()
        }
        .padding()
        .onChange(of: pickerItem) {
            Task {
                if let data = try? await pickerItem?.loadTransferable(type: Data.self) {
                    savedPhotosData.append(data)
                    hasScanned = false
                }
                pickerItem = nil
            }
        }
    }

    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    reviewField("Brand", text: $coffeeName)
                    Divider()
                    reviewField("Roaster", text: $roaster)
                    Divider()
                    reviewField("Country", text: $countryOfOrigin)
                    Divider()
                    reviewField("Varieties", text: $varieties)
                    Divider()
                    reviewField("Region", text: $region)
                    Divider()
                    reviewField("Processes", text: $processes)
                    Divider()
                    reviewField("Elevation", text: $elevation)
                    Divider()
                    HStack {
                        Text("Origin Type:")
                        Spacer()
                        Picker("Origin Type", selection: $originType) {
                            Text("—").tag(OriginType?.none)
                            ForEach(OriginType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(Optional(type))
                            }
                        }
                        .labelsHidden()
                    }
                    .padding(.vertical, 6)
                    Divider()
                    reviewField("Tasting Notes", text: $tastingNotes)
                }
                .padding(.horizontal)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))

                if isScanning {
                    ProgressView("Scanning label...")
                }

                Text("Sensory Sliders").font(.headline)
                VStack(spacing: 8) {
                    sensorySlider("Bitterness", value: $bitterness)
                    sensorySlider("Acidity", value: $acidity)
                    sensorySlider("Body", value: $bodyLevel)
                    sensorySlider("Funkiness", value: $funkiness)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Overall Rating:")
                        Spacer()
                        Text(String(format: "%.1f", overallRating))
                    }
                    Slider(value: $overallRating, in: 0...5, step: 0.5)
                }
                .padding()
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding()
        }
        .background(Color.mugShotBackground)
        .navigationTitle("Text Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(roaster.isEmpty || coffeeName.isEmpty)
            }
        }
    }

    private func reviewField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text("\(label):")
            TextField("", text: text)
        }
        .padding(.vertical, 12)
    }

    private func sensorySlider(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 70, alignment: .leading)
            Slider(value: value, in: 1...5, step: 1)
        }
    }

    private func scan() async {
        isScanning = true
        defer { isScanning = false }
        let images = savedPhotosData.compactMap { UIImage(data: $0) }
        guard let details = try? await CoffeeScanner(reference: CoffeeReference()).scanAndExtract(from: images) else { return }

        roaster = details.roaster
        coffeeName = details.coffeeName
        countryOfOrigin = details.countryOfOrigin ?? ""
        region = details.region ?? ""
        varieties = details.varieties ?? ""
        processes = details.processes ?? ""
        elevation = details.elevation ?? ""
        tastingNotes = details.tastingNotes ?? ""
        originType = details.originType
    }

    private func save() {
        let coffee = CoffeeBag(
            photosData: savedPhotosData,
            roaster: roaster,
            coffeeName: coffeeName,
            countryOfOrigin: countryOfOrigin.nilIfEmpty,
            region: region.nilIfEmpty,
            varieties: varieties.nilIfEmpty,
            processes: processes.nilIfEmpty,
            originType: originType,
            elevation: elevation.nilIfEmpty,
            tastingNotes: tastingNotes.nilIfEmpty,
            bitterness: bitterness,
            acidity: acidity,
            body: bodyLevel,
            funkiness: funkiness,
            overallRating: overallRating
        )
        modelContext.insert(coffee)
        onSave()
        dismiss()
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
