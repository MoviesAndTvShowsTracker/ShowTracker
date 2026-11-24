import SwiftUI

struct DiaryActivityItem: Codable, Identifiable, Sendable {
    let id: String
    let kind: String
    let mediaId: String?
    let title: String?
    let posterPath: String?
    let subtitle: String?
    let isRewatch: Bool?
    let watchedAt: String?
    let rating: Double?

    init(
        id: String,
        kind: String,
        mediaId: String? = nil,
        title: String? = nil,
        posterPath: String? = nil,
        subtitle: String? = nil,
        isRewatch: Bool? = nil,
        watchedAt: String? = nil,
        rating: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.mediaId = mediaId
        self.title = title
        self.posterPath = posterPath
        self.subtitle = subtitle
        self.isRewatch = isRewatch
        self.watchedAt = watchedAt
        self.rating = rating
    }

    var dayKey: String? {
        guard let watchedAt, watchedAt.count >= 10 else { return nil }
        return String(watchedAt.prefix(10))
    }

    var parsedDate: Date? {
        guard let dayKey else { return nil }
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        return Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
    }
}

struct DiaryActivityResponse: Decodable, Sendable {
    let success: Bool?
    let items: [DiaryActivityItem]?
}

struct DiaryActivityView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var items: [DiaryActivityItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var monthAnchor = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    private var calendar: Calendar { .current }

    private var itemsByDay: [String: [DiaryActivityItem]] {
        Dictionary(grouping: items.compactMap { item -> (String, DiaryActivityItem)? in
            guard let key = item.dayKey else { return nil }
            return (key, item)
        }, by: \.0).mapValues { $0.map(\.1) }
    }

    private var selectedKey: String {
        dayKey(for: selectedDay)
    }

    private var selectedItems: [DiaryActivityItem] {
        (itemsByDay[selectedKey] ?? []).sorted {
            ($0.watchedAt ?? "") > ($1.watchedAt ?? "")
        }
    }

    private var monthTitle: String {
        monthAnchor.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        Group {
            if loading && items.isEmpty {
                ProgressView().tint(theme.olive).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty, let error {
                ErrorStateView(message: error) { Task { await load() } }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        monthHeader
                        weekdayHeader
                        monthGrid
                        dayDetail
                        if let error {
                            InlineErrorBanner(message: error) { Task { await load() } }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .marqueeCanvas()
        .navigationTitle("Watch calendar")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await load() }
        .task {
            if UITestingFixtures.isEnabled {
                items = UITestingFixtures.diaryItems
                if let newest = items.compactMap(\.parsedDate).max() {
                    monthAnchor = startOfMonth(newest)
                    selectedDay = newest
                }
                loading = false
                return
            }
            await load()
        }
        .onChange(of: monthAnchor) { _, newMonth in
            if !calendar.isDate(selectedDay, equalTo: newMonth, toGranularity: .month) {
                selectedDay = startOfMonth(newMonth)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.olive)
                    .frame(width: 36, height: 36)
                    .background(theme.oliveSoft)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()
            VStack(spacing: 2) {
                Text(monthTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.ink)
                Text(monthSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.olive)
                    .frame(width: 36, height: 36)
                    .background(theme.oliveSoft)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isCurrentOrFutureMonth)
            .opacity(isCurrentOrFutureMonth ? 0.35 : 1)
        }
    }

    private var monthSummary: String {
        let keys = daysInMonth.map(dayKey(for:))
        let count = keys.reduce(0) { $0 + (itemsByDay[$1]?.count ?? 0) }
        if count == 0 { return "No watches this month" }
        return "\(count) marked · \(keys.filter { !(itemsByDay[$0] ?? []).isEmpty }.count) active days"
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...]) + Array(symbols[..<first])
        return HStack(spacing: 0) {
            ForEach(ordered, id: \.self) { day in
                Text(day.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let days = daysInMonth
        let leading = leadingEmptyCount
        let cells = Array(repeating: nil as Date?, count: leading) + days.map(Optional.some)
        let rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }

        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        if index < row.count, let day = row[index] {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 48)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private func dayCell(_ day: Date) -> some View {
        let key = dayKey(for: day)
        let count = itemsByDay[key]?.count ?? 0
        let selected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let intensity = min(1, Double(count) / 4)

        return Button {
            withAnimation(reduceMotion ? nil : MarqueeMotion.micro) {
                selectedDay = day
            }
            Haptics.light()
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(selected || isToday ? .bold : .medium))
                    .foregroundStyle(selected ? theme.surface : theme.ink)
                Capsule()
                    .fill(count == 0 ? Color.clear : theme.olive.opacity(0.25 + 0.75 * intensity))
                    .frame(width: 14, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? theme.ink : (isToday ? theme.oliveSoft : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day, count: count))
    }

    @ViewBuilder
    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                if !selectedItems.isEmpty {
                    Text("\(selectedItems.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.olive)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.oliveSoft)
                        .clipShape(Capsule())
                }
            }

            if items.isEmpty && !loading {
                Text("Mark a film or episode and days will light up here.")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
            } else if selectedItems.isEmpty {
                Text("Quiet day — nothing marked.")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                    .padding(.vertical, 8)
            } else {
                let films = selectedItems.filter { $0.kind == "film" }
                let episodes = selectedItems.filter { $0.kind != "film" }

                if !films.isEmpty {
                    sectionLabel("Films")
                    ForEach(films) { item in
                        dayRow(item)
                    }
                }
                if !episodes.isEmpty {
                    sectionLabel("Episodes")
                    ForEach(episodes) { item in
                        dayRow(item)
                    }
                }
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(theme.olive)
            .padding(.top, 4)
    }

    private func dayRow(_ item: DiaryActivityItem) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath, size: "w185"))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title ?? "Untitled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(2)
                    if item.isRewatch == true || item.subtitle == "Rewatch" {
                        Text("Rewatch")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.olive)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(theme.oliveSoft)
                            .clipShape(Capsule())
                    }
                }
                if let subtitle = item.subtitle, !subtitle.isEmpty, subtitle != "Rewatch" {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthAnchor),
              let start = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor))
        else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    private var leadingEmptyCount: Int {
        guard let start = daysInMonth.first else { return 0 }
        let weekday = calendar.component(.weekday, from: start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var isCurrentOrFutureMonth: Bool {
        let now = Date()
        return calendar.compare(monthAnchor, to: now, toGranularity: .month) != .orderedAscending
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
        if delta > 0, calendar.compare(next, to: Date(), toGranularity: .month) == .orderedDescending {
            return
        }
        withAnimation(reduceMotion ? nil : MarqueeMotion.standard) {
            monthAnchor = startOfMonth(next)
        }
        Haptics.light()
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func dayKey(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func accessibilityLabel(for day: Date, count: Int) -> String {
        let name = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if count == 0 { return "\(name), nothing marked" }
        return "\(name), \(count) marked"
    }

    private func load() async {
        error = nil
        do {
            items = try await DiaryService.activity(limit: 120)
            if let newest = items.compactMap(\.parsedDate).max() {
                monthAnchor = startOfMonth(newest)
                selectedDay = newest
            }
            loading = false
        } catch {
            if items.isEmpty { self.error = error.localizedDescription }
            else { self.error = "Couldn’t refresh calendar." }
            loading = false
        }
    }
}
