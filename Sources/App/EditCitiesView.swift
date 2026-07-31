import SwiftUI

struct EditCitiesView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.cities) { city in
                        Button {
                            withAnimation { store.setHome(city.id) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(city.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if city.id == store.home?.id {
                                    Label("Home", systemImage: "house.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                    .onDelete { store.remove(atOffsets: $0) }
                    .onMove { store.cities.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Tap a city to make it home. Swipe left to remove.")
                }
            }
            .navigationTitle("Edit Cities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
