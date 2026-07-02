//
//  PomodoroView.swift
//  boringNotch
//

import Defaults
import SwiftUI

@MainActor
final class PomodoroTimerModel: ObservableObject {
    static let shared = PomodoroTimerModel()

    enum Phase: Equatable {
        case idle
        case work
        case breakTime
        case complete
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isRunning = false
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var completedFocusSessions: Int = 0
    @Published private(set) var workMinutes: Int
    @Published private(set) var breakMinutes: Int

    private var timer: Timer?
    private var totalSecondsForCurrentPhase: Int

    private init() {
        let initialWorkMinutes = PomodoroTimerModel.sanitizedMinutes(Defaults[.pomodoroWorkMinutes])
        workMinutes = initialWorkMinutes
        breakMinutes = PomodoroTimerModel.sanitizedMinutes(Defaults[.pomodoroBreakMinutes], range: 1...60)
        let initialSeconds = initialWorkMinutes * 60
        remainingSeconds = initialSeconds
        totalSecondsForCurrentPhase = initialSeconds
    }

    func setWorkMinutes(_ newValue: Int) {
        workMinutes = PomodoroTimerModel.sanitizedMinutes(newValue)
        Defaults[.pomodoroWorkMinutes] = workMinutes
        if phase == .idle || phase == .work, !isRunning {
            reset(to: .work)
        }
    }

    func setBreakMinutes(_ newValue: Int) {
        breakMinutes = PomodoroTimerModel.sanitizedMinutes(newValue, range: 1...60)
        Defaults[.pomodoroBreakMinutes] = breakMinutes
        if phase == .breakTime, !isRunning {
            reset(to: .breakTime)
        }
    }

    var progress: Double {
        guard totalSecondsForCurrentPhase > 0 else { return 0 }
        let elapsed = Double(totalSecondsForCurrentPhase - remainingSeconds)
        return min(max(elapsed / Double(totalSecondsForCurrentPhase), 0), 1)
    }

    var timeDisplay: String {
        let minutes = max(remainingSeconds, 0) / 60
        let seconds = max(remainingSeconds, 0) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var closedNotchLabel: String {
        switch phase {
        case .idle: return "Pomodoro"
        case .work: return isRunning ? "Focus" : "Paused"
        case .breakTime: return isRunning ? "Break" : "Paused"
        case .complete: return "Done"
        }
    }

    var closedNotchIcon: String {
        switch phase {
        case .idle: return "timer"
        case .work: return isRunning ? "flame.fill" : "pause.fill"
        case .breakTime: return isRunning ? "leaf.fill" : "pause.fill"
        case .complete: return "checkmark.seal.fill"
        }
    }

    var shouldShowClosedCountdown: Bool {
        phase != .idle
    }

    var accent: Color {
        switch phase {
        case .idle: return Color(red: 0.58, green: 0.70, blue: 1.0)
        case .work: return Color(red: 1.0, green: 0.36, blue: 0.42)
        case .breakTime: return Color(red: 0.30, green: 0.88, blue: 0.68)
        case .complete: return Color(red: 1.0, green: 0.78, blue: 0.30)
        }
    }

    var primaryButtonTitle: String {
        if isRunning { return "Pause" }
        switch phase {
        case .idle, .complete: return "Start"
        case .work, .breakTime: return "Resume"
        }
    }

    var primaryButtonIcon: String {
        isRunning ? "pause.fill" : "play.fill"
    }

    func togglePrimaryAction() {
        isRunning ? pause() : start()
    }

    func start() {
        if phase == .idle || phase == .complete {
            begin(.work)
        }
        isRunning = true
        startTimerIfNeeded()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func resetToIdle() {
        pause()
        phase = .idle
        remainingSeconds = workMinutes * 60
        totalSecondsForCurrentPhase = remainingSeconds
    }

    func skipPhase() {
        switch phase {
        case .idle:
            begin(.breakTime)
        case .work:
            completeWorkPhase()
        case .breakTime, .complete:
            begin(.work)
        }
        isRunning = true
        startTimerIfNeeded()
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard isRunning else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            advancePhase()
        }
    }

    private func advancePhase() {
        switch phase {
        case .work:
            completeWorkPhase()
        case .breakTime:
            completedFocusSessions += 1
            begin(.complete)
            isRunning = false
            timer?.invalidate()
            timer = nil
        case .idle, .complete:
            begin(.work)
        }
    }

    private func completeWorkPhase() {
        begin(.breakTime)
    }

    private func begin(_ newPhase: Phase) {
        phase = newPhase
        switch newPhase {
        case .idle, .work:
            remainingSeconds = workMinutes * 60
        case .breakTime:
            remainingSeconds = breakMinutes * 60
        case .complete:
            remainingSeconds = 0
        }
        totalSecondsForCurrentPhase = max(remainingSeconds, 1)
    }

    private func reset(to newPhase: Phase) {
        begin(newPhase)
        isRunning = false
    }

    private static func sanitizedMinutes(_ value: Int, range: ClosedRange<Int> = 1...180) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

struct PomodoroView: View {
    @ObservedObject private var timer = PomodoroTimerModel.shared
    @Default(.notchTheme) private var notchTheme
    let availableSize: CGSize?
    private let leftPaneLeadingInset: CGFloat = 12
    private let verticalPadding: CGFloat = 8

    init(availableSize: CGSize? = nil) {
        self.availableSize = availableSize
    }

    private var contentWidth: CGFloat {
        availableSize?.width ?? 540
    }

    private var outerHeight: CGFloat {
        availableSize?.height ?? 142
    }

    private var innerHeight: CGFloat {
        max(0, outerHeight - (verticalPadding * 2))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                statusLine
                timerReadout
                progressBar
            }
            .padding(.leading, leftPaneLeadingInset)
            .frame(width: 250, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 0)

            rightRail
        }
        .frame(width: contentWidth, height: innerHeight, alignment: .center)
        .padding(.vertical, verticalPadding)
        .frame(width: contentWidth, height: outerHeight, alignment: .center)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: phaseIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(timer.accent)
                .frame(width: 14, height: 14)

            Text(compactPhaseTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(notchTheme.primaryForeground)

            if timer.completedFocusSessions > 0 {
                Label("\(timer.completedFocusSessions)", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(notchTheme.secondaryForeground)
            }
        }
    }

    private var timerReadout: some View {
        Text(timer.timeDisplay)
            .font(.system(size: 50, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(notchTheme.primaryForeground)
            .contentTransition(.numericText())
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(notchTheme.secondaryForeground.opacity(0.14))

                Capsule()
                    .fill(timer.accent)
                    .frame(width: progressWidth(in: geometry.size.width))
            }
        }
        .frame(width: 240 - leftPaneLeadingInset, height: 4)
        .animation(.smooth(duration: 0.35), value: timer.progress)
    }

    private var rightRail: some View {
        ZStack {
            controls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            durationControls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 256, height: innerHeight, alignment: .center)
    }

    private var durationControls: some View {
        HStack(spacing: 8) {
            durationAdjuster(title: "Focus", value: timer.workMinutes, range: 1...180) {
                timer.setWorkMinutes($0)
            }
            durationAdjuster(title: "Break", value: timer.breakMinutes, range: 1...60) {
                timer.setBreakMinutes($0)
            }
        }
    }

    private func durationAdjuster(title: String, value: Int, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(notchTheme.secondaryForeground)
                .frame(width: 32, alignment: .leading)
                .lineLimit(1)

            Text("\(value)m")
                .font(.caption.weight(.semibold))
                .foregroundStyle(notchTheme.primaryForeground)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
                .lineLimit(1)

            Button {
                onChange(value - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 14, height: 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(notchTheme.secondaryForeground)
            .help("Decrease \(title.lowercased())")
            .disabled(value <= range.lowerBound)

            Button {
                onChange(value + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 14, height: 15)
            }
            .buttonStyle(.plain)
            .foregroundStyle(notchTheme.secondaryForeground)
            .help("Increase \(title.lowercased())")
            .disabled(value >= range.upperBound)
        }
        .padding(.horizontal, 6)
        .frame(width: 124, alignment: .center)
        .frame(height: 28)
        .background(
            notchTheme.selectedTabBackground.opacity(notchTheme == .white ? 0.86 : 0.52),
            in: Capsule()
        )
    }

    private var controls: some View {
        HStack(spacing: 10) {
            controlButton(icon: "arrow.counterclockwise", title: "Reset", size: 32) {
                timer.resetToIdle()
            }

            controlButton(icon: timer.primaryButtonIcon, title: timer.primaryButtonTitle, size: 44, isProminent: true) {
                timer.togglePrimaryAction()
            }

            controlButton(icon: "forward.end.fill", title: skipTitle, size: 32) {
                timer.skipPhase()
            }
        }
    }

    private func controlButton(icon: String, title: String, size: CGFloat, isProminent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isProminent ? 17 : 13, weight: .semibold))
                .frame(width: size, height: size)
                .background(controlBackground(isProminent: isProminent), in: Circle())
                .foregroundStyle(isProminent ? prominentControlForeground : notchTheme.primaryForeground)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func controlBackground(isProminent: Bool) -> Color {
        if isProminent {
            timer.accent
        } else {
            notchTheme.selectedTabBackground.opacity(notchTheme == .white ? 0.9 : 0.56)
        }
    }

    private var prominentControlForeground: Color {
        timer.phase == .complete ? Color.black.opacity(0.78) : Color.white
    }

    private func progressWidth(in availableWidth: CGFloat) -> CGFloat {
        let progress = max(timer.progress, timer.phase == .complete ? 1 : 0.02)
        return max(4, availableWidth * progress)
    }

    private var phaseIcon: String {
        switch timer.phase {
        case .idle: return "sparkles"
        case .work: return "flame.fill"
        case .breakTime: return "leaf.fill"
        case .complete: return "checkmark.seal.fill"
        }
    }

    private var compactPhaseTitle: String {
        switch timer.phase {
        case .idle: return "Pomodoro"
        case .work: return timer.isRunning ? "Focus" : "Paused"
        case .breakTime: return timer.isRunning ? "Break" : "Paused"
        case .complete: return "Done"
        }
    }

    private var skipTitle: String {
        switch timer.phase {
        case .idle: return "Break"
        case .work: return "Break"
        case .breakTime, .complete: return "Focus"
        }
    }
}

#Preview {
    PomodoroView()
        .frame(width: 640, height: 160)
}
