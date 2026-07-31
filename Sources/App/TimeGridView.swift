import SwiftUI
import UIKit

/// The city board: a fixed label column and a shared horizontally scrolling
/// grid of hour cells. Every column is one absolute instant; each row renders
/// it in that city's time zone. Tapping a cell selects that instant.
///
/// Reordering is a custom hold-then-drag gesture that moves the actual row
/// under the finger; city options live behind an explicit menu button. The
/// two interactions share no gesture, so neither can swallow the other.
struct TimeGridView: View {
    @EnvironmentObject private var store: AppStore

    /// Resets automatically when the gesture ends or is cancelled, so lift
    /// styling and row offsets can never outlive a drag.
    @GestureState private var rowDrag: RowDrag = .inactive

    static let cellWidth: CGFloat = 56
    static let rowHeight: CGFloat = 92
    static let rowSpacing: CGFloat = 16
    static let labelWidth: CGFloat = 150
    static let hourCount = 72

    private static let dragStep = rowHeight + rowSpacing

    private enum RowDrag {
        case inactive
        case pressing(UUID)
        case dragging(UUID, CGFloat)

        func isLifting(_ id: UUID) -> Bool {
            switch self {
            case .pressing(let p): p == id
            case .dragging(let d, _): d == id
            case .inactive: false
            }
        }
    }

    /// Hourly instants covering yesterday through tomorrow in home time,
    /// anchored to the current day so tapping a column never re-bases the
    /// grid. Only a selection outside that window (via the date picker)
    /// re-anchors, onto the selected day.
    private var timelineStart: Date {
        let cal = TimeUtil.calendar(store.homeTimeZone)
        let anchor = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: store.now))!
        let span = Double(Self.hourCount) * 3600
        let sel = store.selectedInstant
        if sel >= anchor && sel < anchor.addingTimeInterval(span) {
            return anchor
        }
        return cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: sel))!
    }

    private func instants(from start: Date) -> [Date] {
        (0..<Self.hourCount).map { start.addingTimeInterval(Double($0) * 3600) }
    }

    private func indexOfSelection(from start: Date) -> Int? {
        let idx = Int(floor(store.selectedInstant.timeIntervalSince(start) / 3600))
        return (0..<Self.hourCount).contains(idx) ? idx : nil
    }

    /// Where the dragged row would land if released now.
    private func targetIndex(from: Int, translation: CGFloat) -> Int {
        let raw = from + Int((translation / Self.dragStep).rounded())
        return min(max(raw, 0), store.cities.count - 1)
    }

    /// The saved-city array is never mutated while the finger is down; a
    /// structural reorder would cancel the in-flight gesture. Rows shift
    /// visually via these offsets and the move commits once, on release.
    private func rowOffset(for id: UUID) -> CGFloat {
        guard case .dragging(let dragID, let translation) = rowDrag,
              let from = store.cities.firstIndex(where: { $0.id == dragID })
        else { return 0 }
        if dragID == id { return translation }
        guard let j = store.cities.firstIndex(where: { $0.id == id }) else { return 0 }
        let to = targetIndex(from: from, translation: translation)
        if from < to, j > from, j <= to { return -Self.dragStep }
        if to < from, j >= to, j < from { return Self.dragStep }
        return 0
    }

    private func reorderGesture(for city: SavedCity) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($rowDrag) { value, state, _ in
                switch value {
                case .first(true):
                    state = .pressing(city.id)
                case .second(true, let drag):
                    state = .dragging(city.id, drag?.translation.height ?? 0)
                default:
                    state = .inactive
                }
            }
            .onChanged { value in
                if case .first(true) = value {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let from = store.cities.firstIndex(where: { $0.id == city.id })
                else { return }
                let to = targetIndex(from: from, translation: drag.translation.height)
                guard to != from else { return }
                withAnimation(.snappy(duration: 0.25)) {
                    store.cities.move(
                        fromOffsets: IndexSet(integer: from),
                        toOffset: to > from ? to + 1 : to
                    )
                }
            }
    }

    var body: some View {
        let start = timelineStart
        let instants = instants(from: start)
        let selectedIndex = indexOfSelection(from: start)
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: Self.rowSpacing) {
                    ForEach(store.cities) { city in
                        CityLabelView(city: city, isHome: city.id == store.home?.id)
                            .frame(height: Self.rowHeight)
                            .scaleEffect(rowDrag.isLifting(city.id) ? 1.04 : 1)
                            .shadow(
                                color: .black.opacity(rowDrag.isLifting(city.id) ? 0.18 : 0),
                                radius: 7, y: 3
                            )
                            .offset(y: rowOffset(for: city.id))
                            .zIndex(rowDrag.isLifting(city.id) ? 2 : 0)
                            .gesture(reorderGesture(for: city))
                            .animation(
                                rowDrag.isLifting(city.id) ? nil : .snappy(duration: 0.2),
                                value: rowOffset(for: city.id)
                            )
                    }
                }
                .frame(width: Self.labelWidth, alignment: .leading)
                .padding(.leading, 16)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: Self.rowSpacing) {
                            // Zero-height anchor row: gives each column a unique
                            // scroll id without duplicating ids across city rows.
                            HStack(spacing: 0) {
                                ForEach(0..<Self.hourCount, id: \.self) { i in
                                    Color.clear
                                        .frame(width: Self.cellWidth, height: 0)
                                        .id(i)
                                }
                            }
                            .frame(height: 0)

                            ForEach(store.cities) { city in
                                HourRowView(
                                    city: city,
                                    instants: instants,
                                    selectedIndex: selectedIndex
                                )
                                .frame(height: Self.rowHeight)
                                .offset(y: rowOffset(for: city.id))
                                .zIndex(rowDrag.isLifting(city.id) ? 2 : 0)
                                .animation(
                                    rowDrag.isLifting(city.id) ? nil : .snappy(duration: 0.2),
                                    value: rowOffset(for: city.id)
                                )
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 16)
                    }
                    .onAppear {
                        if let idx = selectedIndex {
                            proxy.scrollTo(max(idx - 1, 0), anchor: .leading)
                        }
                    }
                    // Follow jumps from the date picker or the Now button;
                    // plain cell taps keep the scroll position.
                    .onChange(of: start) { _, newStart in
                        if let idx = indexOfSelection(from: newStart) {
                            withAnimation { proxy.scrollTo(max(idx - 1, 0), anchor: .leading) }
                        }
                    }
                    .onChange(of: store.selection == nil) { _, isNow in
                        if isNow, let idx = indexOfSelection(from: timelineStart) {
                            withAnimation { proxy.scrollTo(max(idx - 1, 0), anchor: .leading) }
                        }
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }
}

private struct CityLabelView: View {
    @EnvironmentObject private var store: AppStore
    let city: SavedCity
    let isHome: Bool

    var body: some View {
        let tz = city.timeZone
        let instant = store.selectedInstant
        let offset = TimeUtil.dayOffset(of: instant, in: tz, relativeTo: store.homeTimeZone)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(city.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if isHome {
                    Image(systemName: "house.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
                Spacer(minLength: 0)
                optionsMenu
            }
            HStack(spacing: 4) {
                Text(city.subtitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !isHome {
                    Text("· \(TimeUtil.relativeOffsetString(from: store.homeTimeZone, to: tz, at: instant))")
                        .fixedSize()
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(TimeUtil.timeString(instant, in: tz))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(TimeUtil.weekdayString(instant, in: tz))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if offset != 0 {
                    Text(offset > 0 ? "+\(offset)d" : "\(offset)d")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            (offset > 0 ? Color.orange : Color.blue).opacity(0.2),
                            in: Capsule()
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var optionsMenu: some View {
        Menu {
            if !isHome {
                Button {
                    store.setHome(city.id)
                } label: {
                    Label("Set as Home", systemImage: "house")
                }
            }
            Button(role: .destructive) {
                withAnimation { store.remove(city.id) }
            } label: {
                Label("Remove City", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("options-\(city.name)")
    }
}

private struct HourRowView: View {
    @EnvironmentObject private var store: AppStore
    let city: SavedCity
    let instants: [Date]
    let selectedIndex: Int?

    var body: some View {
        let tz = city.timeZone
        let cal = TimeUtil.calendar(tz)
        HStack(spacing: 0) {
            ForEach(instants.indices, id: \.self) { i in
                HourCell(
                    instant: instants[i],
                    tz: tz,
                    hour: cal.component(.hour, from: instants[i]),
                    isSelected: i == selectedIndex
                )
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.2)) {
                        store.selection = instants[i]
                    }
                }
            }
        }
    }
}

private struct HourCell: View {
    let instant: Date
    let tz: TimeZone
    let hour: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 1) {
            if hour == 0 {
                Text(TimeUtil.weekdayString(instant, in: tz))
                    .font(.caption.weight(.bold))
                Text(TimeUtil.monthDayString(instant, in: tz))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if TimeUtil.usesAMPM {
                Text("\(hour % 12 == 0 ? 12 : hour % 12)")
                    .font(.callout.weight(isSelected ? .bold : .regular))
                    .monospacedDigit()
                Text(hour < 12 ? "AM" : "PM")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(hour)")
                    .font(.callout.weight(isSelected ? .bold : .regular))
                    .monospacedDigit()
            }
        }
        .frame(width: TimeGridView.cellWidth, height: TimeGridView.rowHeight)
        .background(background)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(.vertical, 16)
            }
        }
        .overlay(alignment: .leading) {
            if hour == 0 {
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 1.5)
                    .padding(.vertical, 10)
            }
        }
        .contentShape(Rectangle())
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.accentColor.opacity(0.26) : tint)
            .padding(.horizontal, 0.5)
            .padding(.vertical, 16)
    }

    private var tint: Color {
        switch hour {
        case 8...17: Color.green.opacity(0.22)
        case 6, 7, 18...21: Color.yellow.opacity(0.18)
        default: Color.primary.opacity(0.06)
        }
    }
}
