import SwiftUI
import UIKit

/// The city board: a fixed label column and a shared horizontally scrolling
/// grid of hour cells. Every column is one absolute instant; each row renders
/// it in that city's time zone. Tapping a cell selects that instant.
///
/// Interactions: hold and drag a row vertically to reorder (the top city is
/// home); swipe a city label left for Delete or right for Home, Mail-style.
/// Both gestures are UIKit-backed so vertical scrolling stays native.
struct TimeGridView: View {
    @EnvironmentObject private var store: AppStore

    @State private var activeDrag: (id: UUID, translation: CGFloat)?
    /// Row snapped open showing an action button (+width = home, -width = delete).
    @State private var openSwipe: (id: UUID, offset: CGFloat)?
    @State private var liveSwipe: (id: UUID, translation: CGFloat)?

    static let cellWidth: CGFloat = 56
    static let rowHeight: CGFloat = 92
    /// Height of the label card and the hour-cell band; both center in
    /// rowHeight so rows read as one aligned line.
    static let cardHeight: CGFloat = 76
    static let rowSpacing: CGFloat = 14
    static let hourCount = 72
    static let actionWidth: CGFloat = 68

    private static let dragStep = rowHeight + rowSpacing

    /// Sized to the longest city name so short names keep the column slim.
    private var labelWidth: CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .headline)
        let widest = store.cities
            .map { ($0.name as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 80
        return min(max(widest + 44, 134), 176)
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

    // MARK: Reorder drag

    /// Where the dragged row would land if released now.
    private func targetIndex(from: Int, translation: CGFloat) -> Int {
        let raw = from + Int((translation / Self.dragStep).rounded())
        return min(max(raw, 0), store.cities.count - 1)
    }

    /// The saved-city array is never mutated while the finger is down; a
    /// structural reorder would break the in-flight gesture. Rows shift
    /// visually via these offsets and the move commits once, on release.
    private func rowOffset(for id: UUID) -> CGFloat {
        guard let drag = activeDrag,
              let from = store.cities.firstIndex(where: { $0.id == drag.id })
        else { return 0 }
        if drag.id == id { return drag.translation }
        guard let j = store.cities.firstIndex(where: { $0.id == id }) else { return 0 }
        let to = targetIndex(from: from, translation: drag.translation)
        if from < to, j > from, j <= to { return -Self.dragStep }
        if to < from, j >= to, j < from { return Self.dragStep }
        return 0
    }

    private func isLifting(_ id: UUID) -> Bool {
        activeDrag?.id == id
    }

    private func dragGesture(for city: SavedCity) -> RowDragGesture {
        RowDragGesture(
            onBegan: {
                withAnimation { openSwipe = nil }
                activeDrag = (city.id, 0)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            },
            onChanged: { activeDrag = (city.id, $0) },
            onEnded: { translation in
                commitMove(city, translation: translation)
                activeDrag = nil
            },
            onCancelled: { activeDrag = nil }
        )
    }

    private func commitMove(_ city: SavedCity, translation: CGFloat) {
        guard let from = store.cities.firstIndex(where: { $0.id == city.id }) else { return }
        let to = targetIndex(from: from, translation: translation)
        guard to != from else { return }
        withAnimation(.snappy(duration: 0.25)) {
            store.cities.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
    }

    // MARK: Swipe actions

    /// A single swipe moves between its starting side and closed; returning
    /// past closed to the opposite side takes a fresh gesture, like Mail.
    private func swipeBounds(base: CGFloat, isHome: Bool) -> ClosedRange<CGFloat> {
        let lower: CGFloat = base > 0 ? 0 : -Self.actionWidth
        let upper: CGFloat = base < 0 ? 0 : (isHome ? 0 : Self.actionWidth)
        return lower...upper
    }

    private func swipeOffset(for city: SavedCity, isHome: Bool) -> CGFloat {
        let base = openSwipe?.id == city.id ? (openSwipe?.offset ?? 0) : 0
        guard let live = liveSwipe, live.id == city.id else { return base }
        let bounds = swipeBounds(base: base, isHome: isHome)
        return min(max(base + live.translation, bounds.lowerBound), bounds.upperBound)
    }

    private func swipeGesture(for city: SavedCity, isHome: Bool) -> RowSwipeGesture {
        RowSwipeGesture(
            onChanged: { translation in
                if let open = openSwipe, open.id != city.id {
                    withAnimation { openSwipe = nil }
                }
                liveSwipe = (city.id, translation)
            },
            onEnded: { translation in
                // Recompute from the recognizer's final translation; a fast
                // flick can end before any .changed update landed in state.
                let base = openSwipe?.id == city.id ? (openSwipe?.offset ?? 0) : 0
                let bounds = swipeBounds(base: base, isHome: isHome)
                let final = min(max(base + translation, bounds.lowerBound), bounds.upperBound)
                liveSwipe = nil
                withAnimation(.snappy(duration: 0.25)) {
                    if final < -Self.actionWidth / 2 {
                        openSwipe = (city.id, -Self.actionWidth)
                    } else if final > Self.actionWidth / 2, !isHome {
                        openSwipe = (city.id, Self.actionWidth)
                    } else {
                        openSwipe = nil
                    }
                }
            },
            onCancelled: { liveSwipe = nil }
        )
    }

    private func homeButton(for city: SavedCity) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                openSwipe = nil
                store.makeHome(city.id)
            }
        } label: {
            Image(systemName: "house.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: Self.actionWidth - 8, height: Self.cardHeight)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier("swipe-home-\(city.name)")
    }

    private func deleteButton(for city: SavedCity) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                openSwipe = nil
                store.removeCity(city.id)
            }
        } label: {
            Image(systemName: "trash.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: Self.actionWidth - 8, height: Self.cardHeight)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier("swipe-delete-\(city.name)")
    }

    private func labelRow(for city: SavedCity) -> some View {
        let isHome = city.id == store.home?.id
        let sOffset = swipeOffset(for: city, isHome: isHome)
        return ZStack {
            if sOffset > 0 {
                HStack {
                    homeButton(for: city)
                    Spacer(minLength: 0)
                }
            }
            if sOffset < 0 {
                HStack {
                    Spacer(minLength: 0)
                    deleteButton(for: city)
                }
            }
            CityLabelView(city: city, isHome: isHome)
                .offset(x: sOffset)
        }
        .animation(
            liveSwipe?.id == city.id ? nil : .snappy(duration: 0.25),
            value: sOffset
        )
        .frame(height: Self.rowHeight)
        .scaleEffect(isLifting(city.id) ? 1.04 : 1)
        .shadow(
            color: .black.opacity(isLifting(city.id) ? 0.18 : 0),
            radius: 7, y: 3
        )
        .offset(y: rowOffset(for: city.id))
        .zIndex(isLifting(city.id) ? 2 : 0)
        .onTapGesture {
            withAnimation { openSwipe = nil }
        }
        .gesture(dragGesture(for: city))
        .gesture(swipeGesture(for: city, isHome: isHome))
        .animation(
            isLifting(city.id) ? nil : .snappy(duration: 0.2),
            value: rowOffset(for: city.id)
        )
    }

    var body: some View {
        let start = timelineStart
        let instants = instants(from: start)
        let selectedIndex = indexOfSelection(from: start)
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: Self.rowSpacing) {
                    ForEach(store.cities) { city in
                        labelRow(for: city)
                    }
                }
                .frame(width: labelWidth, alignment: .leading)
                .padding(.leading, 14)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        // The anchor row lives outside the VStack: as a child
                        // it would add one row-spacing and shift every hour
                        // strip below its city card.
                        ZStack(alignment: .topLeading) {
                            HStack(spacing: 0) {
                                ForEach(0..<Self.hourCount, id: \.self) { i in
                                    Color.clear
                                        .frame(width: Self.cellWidth, height: 0)
                                        .id(i)
                                }
                            }
                            .frame(height: 0)

                            VStack(spacing: Self.rowSpacing) {
                            ForEach(store.cities) { city in
                                HourRowView(
                                    city: city,
                                    instants: instants,
                                    selectedIndex: selectedIndex
                                )
                                .frame(height: Self.rowHeight)
                                .offset(y: rowOffset(for: city.id))
                                .zIndex(isLifting(city.id) ? 2 : 0)
                                .animation(
                                    isLifting(city.id) ? nil : .snappy(duration: 0.2),
                                    value: rowOffset(for: city.id)
                                )
                            }
                            }
                        }
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
                        .accessibilityIdentifier("home-\(city.name)")
                }
            }
            HStack(spacing: 4) {
                Text(TimeUtil.weekdayString(instant, in: tz))
                    .fontWeight(.medium)
                if offset != 0 {
                    Text(offset > 0 ? "+\(offset)d" : "\(offset)d")
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            (offset > 0 ? Color.orange : Color.blue).opacity(0.2),
                            in: Capsule()
                        )
                }
                Text("· \(city.subtitle)")
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !isHome {
                    Text("· \(TimeUtil.relativeOffsetString(from: store.homeTimeZone, to: tz, at: instant))")
                        .fixedSize()
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            Text(TimeUtil.timeString(instant, in: tz))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: TimeGridView.cardHeight)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
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
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(.vertical, 8)
            }
        }
        .overlay(alignment: .leading) {
            if hour == 0 {
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 1.5)
                    .padding(.vertical, 8)
            }
        }
        .contentShape(Rectangle())
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? Color.accentColor.opacity(0.26) : tint)
            .padding(.horizontal, 0.5)
            .padding(.vertical, 8)
    }

    private var tint: Color {
        switch hour {
        case 8...17: Color.green.opacity(0.22)
        case 6, 7, 18...21: Color.yellow.opacity(0.18)
        default: Color.primary.opacity(0.06)
        }
    }
}
