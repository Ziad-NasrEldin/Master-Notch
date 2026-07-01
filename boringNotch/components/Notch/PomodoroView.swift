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

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            timerDial
                .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 10) {
                statusLine
                controls
                durationControls
            }
            .frame(width: 236, alignment: .leading)
        }
        .frame(width: 360, height: 128, alignment: .center)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            notchTheme.selectedTabBackground.opacity(notchTheme == .white ? 1 : 0.7),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(notchTheme.secondaryForeground.opacity(0.16), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    private var statusLine: some View {
        HStack(spacing: 7) {
            Image(systemName: phaseIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(timer.accent)
                .frame(width: 14, height: 14)

            Text(compactPhaseTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(notchTheme.primaryForeground)

            Spacer(minLength: 0)

            if timer.completedFocusSessions > 0 {
                Label("\(timer.completedFocusSessions)", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(notchTheme.secondaryForeground)
            }
        }
    }

    private var timerDial: some View {
        ZStack {
            Circle()
                .fill(notchTheme.background.opacity(notchTheme == .white ? 0.78 : 0.42))

            Circle()
                .stroke(notchTheme.secondaryForeground.opacity(0.16), lineWidth: 5)

            Circle()
                .trim(from: 0, to: max(timer.progress, timer.phase == .complete ? 1 : 0.018))
                .stroke(timer.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.35), value: timer.progress)

            Text(timer.timeDisplay)
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(notchTheme.primaryForeground)
        }
    }

    private var durationControls: some View {
        HStack(spacing: 8) {
            minuteStepper(title: "Focus", value: timer.workMinutes, range: 1...180) { timer.setWorkMinutes($0) }
            minuteStepper(title: "Break", value: timer.breakMinutes, range: 1...60) { timer.setBreakMinutes($0) }
        }
    }

    private func minuteStepper(title: String, value: Int, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(notchTheme.secondaryForeground)
                .lineLimit(1)

            Text("\(value)m")
                .font(.caption.weight(.semibold))
                .foregroundStyle(notchTheme.primaryForeground)
                .monospacedDigit()
                .lineLimit(1)

            Spacer(minLength: 0)

            Stepper("", value: Binding(
                get: { value },
                set: { onChange(min(max($0, range.lowerBound), range.upperBound)) }
            ), in: range)
            .labelsHidden()
            .controlSize(.mini)
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(
            notchTheme.background.opacity(notchTheme == .white ? 0.58 : 0.28),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(notchTheme.secondaryForeground.opacity(0.12), lineWidth: 1)
        )
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(action: timer.togglePrimaryAction) {
                Label(timer.primaryButtonTitle, systemImage: timer.primaryButtonIcon)
                    .frame(width: 104)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(timer.accent)

            Button(action: timer.skipPhase) {
                Label(skipTitle, systemImage: "forward.end.fill")
                    .labelStyle(.iconOnly)
                    .frame(width: 26)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(skipTitle)

            Button(action: timer.resetToIdle) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
                    .frame(width: 26)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Reset")
        }
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
        .frame(width: 470, height: 150)
}
