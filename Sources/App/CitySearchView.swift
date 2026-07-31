import SwiftUI

struct CitySearchView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var entries: [CityDB.Entry]?
    @State private var results: [City] = []

    var body: some View {
        NavigationStack {
            Group {
                if entries == nil {
                    ProgressView("Loading city database…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results, id: \.self) { city in
                        Button {
                            withAnimation { store.add(city) }
                            dismiss()
                        } label: {
                            row(for: city)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add City")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "City name, e.g. Ashland, Oregon"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                entries = await CityDB.load()
                refresh()
            }
            .onChange(of: query) {
                refresh()
            }
        }
    }

    private func row(for city: City) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.body.weight(.medium))
                Text([city.region, city.country].filter { !$0.isEmpty }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let tz = TimeZone(identifier: city.tzID) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeUtil.timeString(store.now, in: tz))
                        .font(.callout)
                        .monospacedDigit()
                    Text(TimeUtil.relativeOffsetString(from: store.homeTimeZone, to: tz, at: store.now))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func refresh() {
        guard let entries else { return }
        let q = query
        Task.detached(priority: .userInitiated) {
            let found = CityDB.search(q, in: entries)
            await MainActor.run {
                // Ignore stale results from an earlier keystroke.
                guard q == query else { return }
                results = found
            }
        }
    }
}
