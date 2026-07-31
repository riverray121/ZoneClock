import Foundation

/// A row from the bundled city database.
struct City: Hashable, Sendable {
    let name: String
    let region: String
    let country: String
    let tzID: String
    let population: Int
}

/// A city the user has added to their board.
struct SavedCity: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var region: String
    var country: String
    var tzID: String

    var timeZone: TimeZone { TimeZone(identifier: tzID) ?? .current }

    var subtitle: String {
        // "Region, Country" for US cities reads better than "Region, United States".
        if country == "United States" {
            return region.isEmpty ? country : region
        }
        return [region, country].filter { !$0.isEmpty }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            .joined(separator: ", ")
    }

    init(city: City) {
        self.id = UUID()
        self.name = city.name
        self.region = city.region
        self.country = city.country
        self.tzID = city.tzID
    }
}
