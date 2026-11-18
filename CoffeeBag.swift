import Foundation
import SwiftData

@Model
final class CoffeeBag {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var photosData: [Data]

    var roaster: String
    var coffeeName: String
    var countryOfOrigin: String?
    var region: String?
    var varieties: String?
    var processes: String?
    var originTypeRaw: String?
    var elevation: String?
    var tastingNotes: String?

    var bitterness: Double
    var acidity: Double
    var body: Double
    var funkiness: Double

    var overallRating: Double

    var dateAdded: Date

    init(
        photosData: [Data] = [],
        roaster: String,
        coffeeName: String,
        countryOfOrigin: String? = nil,
        region: String? = nil,
        varieties: String? = nil,
        processes: String? = nil,
        originType: OriginType? = nil,
        elevation: String? = nil,
        tastingNotes: String? = nil,
        bitterness: Double = 3,
        acidity: Double = 3,
        body: Double = 3,
        funkiness: Double = 3,
        overallRating: Double = 0.0
    ) {
        self.id = UUID()
        self.photosData = photosData
        self.roaster = roaster
        self.coffeeName = coffeeName
        self.countryOfOrigin = countryOfOrigin
        self.region = region
        self.varieties = varieties
        self.processes = processes
        self.originTypeRaw = originType?.rawValue
        self.elevation = elevation
        self.tastingNotes = tastingNotes
        self.bitterness = bitterness
        self.acidity = acidity
        self.body = body
        self.funkiness = funkiness
        self.overallRating = overallRating
        self.dateAdded = Date()
    }
}
