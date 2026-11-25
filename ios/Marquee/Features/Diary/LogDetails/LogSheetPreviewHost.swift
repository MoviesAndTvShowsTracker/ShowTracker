#if DEBUG
import SwiftUI

/// DEBUG screenshots only: presents the log sheet with sample content (`-previewLogSheet=…`).
struct LogSheetPreviewHost: View {
    @Environment(\.marqueeTheme) private var theme
    let kind: String
    @State private var presented = true

    var body: some View {
        theme.surface
            .ignoresSafeArea()
            .sheet(isPresented: $presented) { sheet }
    }

    @ViewBuilder
    private var sheet: some View {
        switch kind {
        case "episode":
            LogDetailsSheet(
                subject: LogDetailsSubject(title: "Breaking Bad", subtitle: "S1 · E3  …And the Bag's in the River", posterPath: "/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg"),
                mode: .new,
                initial: LogDetailsDraft(day: .yesterday),
                ratesFilm: false
            ) { _ in }
        case "edit":
            LogDetailsSheet(
                subject: LogDetailsSubject(title: "Inception", subtitle: "2010", posterPath: "/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg"),
                mode: .edit,
                initial: LogDetailsDraft(
                    day: .custom(Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 14))!),
                    rating: 4.5,
                    note: "First time, with Mom. The hallway fight still holds up."
                ),
                ratesFilm: true
            ) { _ in }
        case "calendar":
            LogDetailsSheet(
                subject: LogDetailsSubject(title: "Inception", subtitle: "2010", posterPath: "/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg"),
                mode: .new,
                initial: LogDetailsDraft(day: .custom(Calendar.current.date(byAdding: .day, value: -9, to: .now)!)),
                ratesFilm: true,
                calendarOpen: true
            ) { _ in }
        default:
            LogDetailsSheet(
                subject: LogDetailsSubject(title: "Inception", subtitle: "2010", posterPath: "/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg"),
                mode: .new,
                ratesFilm: true
            ) { _ in }
        }
    }
}
#endif
