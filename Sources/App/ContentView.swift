import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingSearch = false

    private let ticker = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            if store.cities.isEmpty {
                emptyState
            } else {
                header
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                Divider()
                TimeGridView()
                Text("Tap an hour to preview · hold and drag to reorder · swipe a city for actions")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
            }
        }
        .sheet(isPresented: $showingSearch) {
            CitySearchView()
        }
        .onReceive(ticker) { store.now = $0 }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 0) {
                Text("Zone")
                    .foregroundStyle(.tint)
                Text("Clock")
            }
            .font(.system(size: 22, weight: .bold, design: .rounded))
            Spacer()
            // The empty state has its own Add City button; one entry
            // point at a time.
            if !store.cities.isEmpty {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("Add City")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("No Cities Yet")
                    .font(.title3.weight(.semibold))
                Text("Add the places you care about and compare their times at a glance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingSearch = true
            } label: {
                Label("Add City", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding(.horizontal, 44)
        // Bottom-weighted padding lifts the block above geometric center,
        // where a lone content block reads as centered.
        .padding(.bottom, 110)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        let homeTZ = store.homeTimeZone
        let selection = Binding(
            get: { store.selectedInstant },
            set: { store.selection = $0 }
        )
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.home.map { "\($0.name)  ·  Home" } ?? "Local Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(TimeUtil.timeString(store.selectedInstant, in: homeTZ))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .fixedSize()
                Text(TimeUtil.fullDateString(store.selectedInstant, in: homeTZ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                DatePicker("Selected date", selection: selection, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.timeZone, homeTZ)
                HStack(spacing: 8) {
                    Button("Now") {
                        withAnimation { store.selection = nil }
                    }
                    .buttonStyle(.bordered)
                    .font(.callout.weight(.semibold))
                    .disabled(store.selection == nil)
                    DatePicker("Selected time", selection: selection, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .environment(\.timeZone, homeTZ)
                }
            }
        }
    }
}
