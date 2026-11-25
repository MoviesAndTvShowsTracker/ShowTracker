import SwiftUI

/// The one sheet for logging with details or editing a log, for films and episodes alike:
/// when you watched it, a rating (films), and a short note.
struct LogDetailsSheet: View {
    enum Mode { case new, edit }

    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    let subject: LogDetailsSubject
    let mode: Mode
    let showsRating: Bool
    let onSave: (LogDetailsDraft) async throws -> Void

    @State private var draft: LogDetailsDraft
    @State private var pickedDate: Date
    @State private var stars: Double
    @State private var calendarOpen = false
    @State private var saving = false
    @State private var error: String?
    @State private var detent: PresentationDetent
    @FocusState private var noteFocused: Bool

    init(
        subject: LogDetailsSubject,
        mode: Mode,
        initial: LogDetailsDraft = LogDetailsDraft(),
        showsRating: Bool,
        calendarOpen: Bool = false,
        onSave: @escaping (LogDetailsDraft) async throws -> Void
    ) {
        self.subject = subject
        self.mode = mode
        self.showsRating = showsRating
        self.onSave = onSave
        _calendarOpen = State(initialValue: calendarOpen)
        _detent = State(initialValue: calendarOpen ? .large : Self.compactDetent(showsRating: showsRating))
        _draft = State(initialValue: initial)
        _stars = State(initialValue: initial.rating ?? 0)
        let start: Date
        if case .custom(let date) = initial.day {
            start = date
        } else {
            start = initial.day.date()
        }
        _pickedDate = State(initialValue: start)
    }

    private var motion: Animation? { reduceMotion ? nil : MarqueeMotion.standard }

    /// Tall enough to show the whole form (films also have a rating row) without dragging.
    private static func compactDetent(showsRating: Bool) -> PresentationDetent {
        .fraction(showsRating ? 0.8 : 0.7)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    whenSection
                    if showsRating { ratingSection }
                    noteSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { saveBar }
            .background(theme.surface)
            .navigationTitle(mode == .new ? "Log" : "Edit log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(theme.olive)
                        .disabled(saving)
                }
            }
        }
        .presentationDetents([Self.compactDetent(showsRating: showsRating), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(saving)
        // Room for the calendar or the keyboard: grow to full height when either opens.
        .onChange(of: calendarOpen) { _, open in if open { withAnimation(motion) { detent = .large } } }
        .onChange(of: noteFocused) { _, focused in if focused { withAnimation(motion) { detent = .large } } }
        .onChange(of: draft.day) { _, day in
            if case .custom(let date) = day, !Calendar.current.isDate(date, inSameDayAs: pickedDate) {
                pickedDate = date
            }
        }
        .onChange(of: pickedDate) { _, date in
            // Picking today or yesterday in the calendar selects that pill.
            draft.day = WatchDay.from(date)
        }
        .onChange(of: stars) { _, value in draft.rating = value > 0 ? value : nil }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: AppConfig.posterURL(path: subject.posterPath))
                .frame(width: 52, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(subject.title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                if let subtitle = subject.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Watched")
            WatchDayPills(day: $draft.day, calendarOpen: $calendarOpen)
            if calendarOpen {
                DatePicker("Date watched", selection: $pickedDate, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(theme.olive)
                    .padding(8)
                    .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(motion, value: calendarOpen)
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionKicker(text: "Rating")
                Spacer()
                if stars > 0 {
                    Button("Clear") { stars = 0 }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.olive)
                        .transition(.opacity)
                }
            }
            StarRatingView(rating: $stars, size: .title2)
        }
        .animation(motion, value: stars > 0)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Note")
            DiaryNoteField(note: $draft.note, focused: $noteFocused)
        }
    }

    private var saveBar: some View {
        VStack(spacing: 10) {
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
            Button {
                Task { await save() }
            } label: {
                Group {
                    if saving {
                        ProgressView().tint(theme.onAccent)
                    } else {
                        Text(mode == .new ? "Log" : "Save")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(saving)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(theme.surface)
        .animation(motion, value: error)
    }

    private func save() async {
        saving = true
        error = nil
        var final = draft
        final.note = DiaryNote.trimmed(final.note)
        do {
            try await onSave(final)
            Haptics.success()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            saving = false
        }
    }
}
