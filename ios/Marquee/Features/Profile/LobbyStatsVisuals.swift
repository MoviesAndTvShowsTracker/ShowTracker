import SwiftUI

/// 24-hour lobby dial — mass of watching by hour. Olive = TV, softer olive = film lean.
struct HouseLightsDial: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let hours: [StatsHourBucket]
    let peakHour: Int
    let caption: String
    var onSelectHour: ((Int) -> Void)? = nil

    @State private var drawn = false
    @State private var selectedHour: Int?

    private var focusHour: Int { selectedHour ?? peakHour }
    private var focusMins: Int {
        hours.indices.contains(focusHour) ? (hours[focusHour].mins ?? 0) : 0
    }

    private var maxMins: CGFloat {
        let m = hours.map { CGFloat($0.mins ?? 0) }.max() ?? 1
        return max(m, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: "House lights")
            Text(caption)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            ZStack {
                Circle()
                    .stroke(theme.border, lineWidth: 1)
                    .frame(width: 220, height: 220)

                ForEach(0..<24, id: \.self) { hour in
                    let bucket = hours.indices.contains(hour) ? hours[hour] : StatsHourBucket(mins: 0, filmMins: 0, tvMins: 0, playCount: 0)
                    let mins = CGFloat(bucket.mins ?? 0)
                    let tv = CGFloat(bucket.tvMins ?? 0)
                    let intensity = mins / maxMins
                    let len: CGFloat = 18 + intensity * 52
                    let angle = Angle.degrees(Double(hour) / 24 * 360)
                    let isPeak = hour == focusHour && mins > 0

                    Capsule(style: .continuous)
                        .fill(tv >= (mins - tv) ? theme.olive : theme.olive.opacity(0.45))
                        .frame(width: isPeak ? 7 : 5, height: drawn || reduceMotion ? len : 8)
                        .offset(y: -(70 + len / 2))
                        .rotationEffect(angle)
                        .opacity(mins > 0 ? (selectedHour == nil || hour == selectedHour ? 1 : 0.45) : 0.15)
                        .accessibilityLabel(hourAccessibility(hour, mins: Int(mins)))
                }

                VStack(spacing: 2) {
                    Text(hourLabel(focusHour))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(theme.ink)
                        .contentTransition(.numericText())
                    Text(selectedHour == nil ? "peak" : StatsFormat.minutes(focusMins))
                        .font(.caption2.weight(.semibold))
                        .tracking(0.6)
                        .textCase(selectedHour == nil ? .uppercase : nil)
                        .foregroundStyle(theme.inkMuted)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 260, height: 260)
            .contentShape(Circle())
            .onTapGesture(coordinateSpace: .local) { location in
                let hour = hourAt(location, in: CGSize(width: 260, height: 260))
                withAnimation(MarqueeMotion.micro) {
                    selectedHour = hour == selectedHour ? nil : hour
                }
                onSelectHour?(hour)
            }
            .task(id: selectedHour) {
                guard selectedHour != nil else { return }
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                withAnimation(MarqueeMotion.standard) { selectedHour = nil }
            }
            .sensoryFeedback(.selection, trigger: selectedHour)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            HStack(spacing: 16) {
                Text("Tap an hour")
                    .foregroundStyle(theme.inkMuted.opacity(0.8))
                Spacer()
                legendDot(theme.olive, "TV")
                legendDot(theme.olive.opacity(0.45), "Film")
            }
            .font(.caption)
            .foregroundStyle(theme.inkMuted)
        }
        .padding(16)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            guard !reduceMotion else { drawn = true; return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                drawn = true
            }
        }
    }

    /// Angle from the dial center → hour (12a at the top, clockwise).
    private func hourAt(_ point: CGPoint, in size: CGSize) -> Int {
        let dx = point.x - size.width / 2
        let dy = point.y - size.height / 2
        var degrees = atan2(dx, -dy) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return Int((degrees / 15).rounded()) % 24
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        if h == 0 { return "12a" }
        if h == 12 { return "12p" }
        return h < 12 ? "\(h)a" : "\(h - 12)p"
    }

    private func hourAccessibility(_ hour: Int, mins: Int) -> String {
        "\(hourLabel(hour)), \(StatsFormat.minutes(mins))"
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

struct LobbyTypePlaque: View {
    @Environment(\.marqueeTheme) private var theme
    let lobby: StatsLobbyType

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionKicker(text: "Lobby type")
            Text(lobby.label ?? "Open House")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.ink)
            Text(lobby.blurb ?? "")
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
            HStack(spacing: 8) {
                if let t = lobby.finishLabel { chip(t) }
                if let t = lobby.mediaLabel { chip(t) }
                if let rate = lobby.rewatchRate, rate > 0 {
                    chip("\(rate)% rewatch")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.oliveSoft)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.olive)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.surfaceElevated.opacity(0.8))
            .clipShape(Capsule())
    }
}

struct SeasonArcRibbons: View {
    @Environment(\.marqueeTheme) private var theme
    let arcs: [StatsSeasonArc]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatsSectionHeader(kicker: "On a loop", title: "The shows you go back to")

            ForEach(arcs) { arc in
                arcRow(arc)
            }
        }
    }

    private func arcRow(_ arc: StatsSeasonArc) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(url: AppConfig.posterURL(path: arc.tvPosterImage))
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(arc.tvTitle ?? "Show")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text("\(arc.passCount ?? 1) passes · \(StatsFormat.minutes(arc.totalMins ?? 0))")
                    .font(.caption)
                    .foregroundStyle(theme.olive)

                VStack(alignment: .leading, spacing: 5) {
                    let passes = arc.passes ?? []
                    ForEach(Array(passes.prefix(4).enumerated()), id: \.offset) { index, pass in
                        ribbon(pass: pass, index: index, total: passes.count)
                    }
                    if passes.count > 4 {
                        Text("+\(passes.count - 4) more passes")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.inkMuted)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func ribbon(pass: StatsSeasonPass, index: Int, total: Int) -> some View {
        let eps = max(pass.episodes ?? 1, 1)
        let fraction = min(CGFloat(eps) / 40.0, 1.0)
        return HStack(spacing: 8) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(index == 0 ? theme.olive.opacity(0.55) : theme.olive)
                    .frame(width: max(28, geo.size.width * fraction), height: 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 8)
            Text(pass.label ?? "Pass")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.inkMuted)
                .lineLimit(1)
        }
        .accessibilityLabel("\(pass.label ?? "Pass"), \(pass.episodes ?? 0) episodes")
    }
}

struct BiggestNightStrip: View {
    @Environment(\.marqueeTheme) private var theme
    let night: StatsBiggestNight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(
                kicker: "Biggest night",
                title: night.date.map { shortDate($0) } ?? "One long night",
                trailing: "\(night.count ?? 0) plays · \(StatsFormat.minutes(night.minutes ?? 0))"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            CachedAsyncImage(url: AppConfig.posterURL(path: group.poster, size: "w185"))
                                .frame(width: 84, height: 126)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    if group.count > 1 {
                                        Text("×\(group.count)")
                                            .font(.caption2.weight(.bold).monospacedDigit())
                                            .foregroundStyle(MarqueeColor.saltGrey)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(MarqueeColor.deepOlive.opacity(0.88), in: Capsule())
                                            .padding(6)
                                    }
                                }
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.ink)
                                .lineLimit(2)
                            Text(group.detail)
                                .font(.caption2)
                                .foregroundStyle(theme.inkMuted)
                                .lineLimit(1)
                        }
                        .frame(width: 84, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .padding(.horizontal, -20)
        }
    }

    private struct NightGroup: Identifiable {
        let id: String
        let title: String
        let poster: String?
        var count: Int
        var mins: Int
        let isFilm: Bool

        var detail: String {
            let what = isFilm ? "film" : (count == 1 ? "episode" : "episodes")
            return isFilm ? StatsFormat.minutes(mins) : "\(count) \(what)"
        }
    }

    /// One tile per show or film, in the order the night unfolded.
    private var groups: [NightGroup] {
        var out: [NightGroup] = []
        var index: [String: Int] = [:]
        for item in night.items ?? [] {
            let key = "\(item.kind ?? "")-\(item.mediaId ?? item.title ?? "")"
            if let i = index[key] {
                out[i].count += 1
                out[i].mins += item.mins ?? 0
            } else {
                index[key] = out.count
                let isFilm = item.kind == "film"
                out.append(NightGroup(
                    id: key,
                    title: (isFilm ? item.title : item.subtitle ?? item.title) ?? "",
                    poster: item.stillOrPoster,
                    count: 1,
                    mins: item.mins ?? 0,
                    isFilm: isFilm
                ))
            }
        }
        return out
    }

    private func shortDate(_ iso: String) -> String {
        guard iso.count >= 10 else { return iso }
        let day = String(iso.prefix(10))
        let parts = day.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
        else { return iso }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

struct ShelvesBlock: View {
    @Environment(\.marqueeTheme) private var theme
    let library: StatsLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(
                kicker: "The shelves",
                title: "\(library.totalTracked ?? 0) shows tracked",
                trailing: library.completionRate.map { "\($0)% finished" }
            )
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                shelf("Watching", library.watching ?? 0)
                shelf("Caught up", library.caughtUp ?? 0)
                shelf("Backlog eps", library.backlog ?? 0)
                shelf("Finished", library.finished ?? 0)
            }
        }
    }

    private func shelf(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(theme.inkMuted)
            Text("\(value)")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(theme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct HotTakesBlock: View {
    @Environment(\.marqueeTheme) private var theme
    let takes: [StatsHotTake]

    var body: some View {
        if takes.isEmpty { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 12) {
                StatsSectionHeader(kicker: "Hot takes", title: "Where your stars split from the room")
                ForEach(takes) { take in
                    HStack(spacing: 12) {
                        CachedAsyncImage(url: AppConfig.posterURL(path: take.poster, size: "w185"))
                            .frame(width: 40, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(take.title ?? "Film")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)
                            Text("You \(star(take.userRating)) · room \(star(take.communityRating))")
                                .font(.caption)
                                .foregroundStyle(theme.inkMuted)
                        }
                        Spacer(minLength: 0)
                        Text((take.delta ?? 0) > 0 ? "Loved more" : "Cooler")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.olive)
                    }
                    .padding(10)
                    .background(theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func star(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }
}
