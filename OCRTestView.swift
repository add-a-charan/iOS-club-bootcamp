import SwiftUI

struct OCRTestView: View {
    @State private var resultText = "Press the button to scan..."
    
    var body: some View {
        VStack(spacing: 20) {
            // Displays your test image
            if let image = UIImage(named: "test_label") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
            } else {
                Text("⚠️ Missing 'test_label' in Assets")
                    .foregroundColor(.red)
            }
            
            // Displays the parsed OCR results
            ScrollView {
                Text(resultText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            Button("Run OCR") {
                runScanner()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func runScanner() {
        guard let image = UIImage(named: "test_label") else {
            resultText = "Image not found."
            return
        }
        
        resultText = "Scanning..."
        
        Task {
            let scanner = CoffeeScanner(reference: CoffeeReference())
            do {
                let details = try await scanner.scanAndExtract(from: [image])
                
                // Format the results nicely
                let output = """
                ☕️ COFFEE DETAILS:
                
                Name: \(details.coffeeName.isEmpty ? "Not found" : details.coffeeName)
                Roaster: \(details.roaster.isEmpty ? "Not found" : details.roaster)
                Country: \(details.countryOfOrigin ?? "Not found")
                Region: \(details.region ?? "Not found")
                Varieties: \(details.varieties ?? "Not found")
                Processes: \(details.processes ?? "Not found")
                Elevation: \(details.elevation ?? "Not found")
                Origin Type: \(details.originType?.rawValue ?? "Not found")
                Tasting Notes: \(details.tastingNotes ?? "Not found")
                """
                
                // Update the UI on the main thread
                await MainActor.run {
                    self.resultText = output
                }
            } catch {
                await MainActor.run {
                    self.resultText = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
