import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    /// The first city is the home (reference) city; reordering changes it.
    @Published var cities: [SavedCity] = [] { didSet { persist() } }
    /// nil means "follow the current time".
    @Published var selection: Date?
    @Published var now = Date()

    private static let citiesKey = "overlap.cities"
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
            loaded = true
            return
        }
        if let data = UserDefaults.standard.data(forKey: Self.citiesKey),
           let saved = try? JSONDecoder().decode([SavedCity].self, from: data) {
            cities = saved
        }
        loaded = true
    }

    var home: SavedCity? { cities.first }

    var homeTimeZone: TimeZone { home?.timeZone ?? .current }

    var selectedInstant: Date { selection ?? now }

    func add(_ city: City) {
        cities.append(SavedCity(city: city))
    }

    func removeCity(_ id: UUID) {
        cities.removeAll { $0.id == id }
    }

    /// Home is positional: moving a city to the front makes it home.
    func makeHome(_ id: UUID) {
        guard let idx = cities.firstIndex(where: { $0.id == id }), idx != 0 else { return }
        let city = cities.remove(at: idx)
        cities.insert(city, at: 0)
    }

    private func persist() {
        guard loaded else { return }
        if let data = try? JSONEncoder().encode(cities) {
            UserDefaults.standard.set(data, forKey: Self.citiesKey)
        }
    }
}
