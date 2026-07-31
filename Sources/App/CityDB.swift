import Foundation

/// Offline city index backed by the bundled GeoNames extract (cities.tsv).
/// Rows are sorted by population descending, so scan order doubles as rank.
enum CityDB {
    struct Entry: Sendable {
        let city: City
        /// Diacritic-folded lowercase words of "name region country", for search.
        let words: [String]
    }

    private static let loadTask = Task<[Entry], Never>.detached(priority: .userInitiated) {
        guard let url = Bundle.main.url(forResource: "cities", withExtension: "tsv"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        var entries: [Entry] = []
        entries.reserveCapacity(70_000)
        for line in content.split(separator: "\n") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard f.count >= 5 else { continue }
            let city = City(
                name: String(f[0]),
                region: String(f[1]),
                country: String(f[2]),
                tzID: String(f[3]),
                population: Int(f[4]) ?? 0
            )
            entries.append(Entry(city: city, words: fold("\(f[0]) \(f[1]) \(f[2])")))
        }
        return entries
    }

    static func load() async -> [Entry] {
        await loadTask.value
    }

    static func fold(_ s: String) -> [String] {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// Every query token must prefix-match some word of the entry
    /// ("ashland or" matches Ashland / Oregon). Results keep database order.
    static func search(_ query: String, in entries: [Entry], limit: Int = 60) -> [City] {
        let tokens = fold(query)
        guard !tokens.isEmpty else {
            return entries.prefix(limit).map(\.city)
        }
        var results: [City] = []
        for entry in entries {
            let matches = tokens.allSatisfy { token in
                entry.words.contains { $0.hasPrefix(token) }
            }
            if matches {
                results.append(entry.city)
                if results.count >= limit { break }
            }
        }
        return results
    }
}
