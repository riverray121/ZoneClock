import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published var cities: [SavedCity] = [] { didSet { persist() } }
    @Published var homeID: UUID? { didSet { persist() } }
    /// nil means "follow the current time".
    @Published var selection: Date?
    @Published var now = Date()

    private static let citiesKey = "overlap.cities"
    private static let homeKey = "overlap.homeID"
    private var loaded = false

    init() {
        // UI tests inject a fixed board: "Name|Region|Country|tzID" rows
        // separated by ";".
        if let seed = ProcessInfo.processInfo.environment["UITEST_CITIES"] {
            cities = seed.split(separator: ";").compactMap { row in
                let f = row.split(separator: "|", omittingEmptySubsequences: false)
                guard f.count == 4 else { return nil }
                return SavedCity(city: City(
                    name: String(f[0]), region: String(f[1]),
                    country: String(f[2]), tzID: String(f[3]), population: 0))
            }
            homeID = cities.first?.id
            return
        }
        if let data = UserDefaults.standard.data(forKey: Self.citiesKey),
           let saved = try? JSONDecoder().decode([SavedCity].self, from: data) {
            cities = saved
            if let raw = UserDefaults.standard.string(forKey: Self.homeKey) {
                homeID = UUID(uuidString: raw)
            }
        }
        loaded = true
    }

    var home: SavedCity? {
        cities.first(where: { $0.id == homeID }) ?? cities.first
    }

    var homeTimeZone: TimeZone { home?.timeZone ?? .current }

    var selectedInstant: Date { selection ?? now }

    func add(_ city: City) {
        cities.append(SavedCity(city: city))
        if homeID == nil { homeID = cities.first?.id }
    }

    func remove(_ id: UUID) {
        cities.removeAll { $0.id == id }
        if homeID == id { homeID = cities.first?.id }
    }

    func setHome(_ id: UUID) {
        guard let idx = cities.firstIndex(where: { $0.id == id }) else { return }
        let city = cities.remove(at: idx)
        cities.insert(city, at: 0)
        homeID = id
    }

    private func persist() {
        guard loaded else { return }
        if let data = try? JSONEncoder().encode(cities) {
            UserDefaults.standard.set(data, forKey: Self.citiesKey)
        }
        UserDefaults.standard.set(homeID?.uuidString, forKey: Self.homeKey)
    }
}
