//
//  CursorScaleController.swift
//  boringNotch
//

import AppKit
import Combine
import Defaults
import Darwin
import KeyboardShortcuts

@MainActor
final class CursorScaleController: ObservableObject {
    static let shared = CursorScaleController()

    private typealias UACursorSetScale = @convention(c) (Double) -> Void
    private typealias UACursorGetScale = @convention(c) () -> Double

    private enum State {
        case inactive
        case timedActive(originalScale: Double, appliedScale: Double, timerID: UUID)
        case toggleActive(originalScale: Double, appliedScale: Double)
    }

    private enum CursorScaleError: String {
        case unsupported = "Boring Notch cannot read and set the macOS cursor size on this version, so the cursor shortcut is disabled."
        case readFailed = "Boring Notch could not read your current cursor size, so it did not change the cursor."
        case unsafeRestore = "Boring Notch did not restore the cursor because the current pointer size no longer matches the size it applied."
    }

    private let setScale: UACursorSetScale?
    private let getScale: UACursorGetScale?
    private var state: State = .inactive
    private var restoreTimer: Timer?
    private var isShortcutHeld = false

    @Published private(set) var lastStatusMessage: String?

    var isAvailable: Bool {
        setScale != nil && getScale != nil
    }

    var statusMessage: String? {
        if !isAvailable {
            return CursorScaleError.unsupported.rawValue
        }

        if let lastStatusMessage {
            return lastStatusMessage
        }

        if hasPersistedRestore {
            return "A previous cursor enlargement is pending restore. Restore is available only while the current pointer size still matches Boring Notch's enlarged value."
        }

        return nil
    }

    var canRestore: Bool {
        isAvailable && (isActive || hasPersistedRestore)
    }

    private var isActive: Bool {
        if case .inactive = state {
            return false
        }

        return true
    }

    private var hasPersistedRestore: Bool {
        Defaults[.cursorScaleOwnedOriginalScale] != nil && Defaults[.cursorScaleOwnedAppliedScale] != nil
    }

    private init() {
        let functions = Self.loadCursorScaleFunctions()
        setScale = functions?.setScale
        getScale = functions?.getScale
    }

    func registerShortcut() {
        KeyboardShortcuts.onKeyDown(for: .cursorScale) { [weak self] in
            Task { @MainActor in
                self?.handleShortcutDown()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .cursorScale) { [weak self] in
            Task { @MainActor in
                self?.handleShortcutUp()
            }
        }
    }

    func restorePersistedCursorIfSafe() {
        guard isAvailable else {
            publishFailure(.unsupported)
            return
        }

        guard hasPersistedRestore else { return }

        restoreFromPersistedState()
    }

    func handleShortcutDown() {
        guard isAvailable else {
            publishFailure(.unsupported)
            return
        }

        guard !isShortcutHeld else { return }
        isShortcutHeld = true
        lastStatusMessage = nil

        switch Defaults[.cursorScaleActivationMode] {
        case .timed:
            startTimed()
        case .toggle:
            toggle()
        }
    }

    func handleShortcutUp() {
        isShortcutHeld = false
    }

    func restore() {
        restoreTimer?.invalidate()
        restoreTimer = nil

        guard isAvailable else {
            publishFailure(.unsupported)
            return
        }

        switch state {
        case .inactive:
            restoreFromPersistedState()
        case .timedActive(let originalScale, let appliedScale, _),
             .toggleActive(let originalScale, let appliedScale):
            restore(originalScale: originalScale, expectedAppliedScale: appliedScale)
        }
    }

    private func startTimed() {
        guard let originalScale = currentOriginalScale() else {
            publishFailure(.readFailed)
            return
        }

        let timerID = UUID()
        let appliedScale = clampedCursorScale

        restoreTimer?.invalidate()
        persistRestore(originalScale: originalScale, appliedScale: appliedScale)
        setScale?(appliedScale)
        state = .timedActive(originalScale: originalScale, appliedScale: appliedScale, timerID: timerID)
        objectWillChange.send()

        restoreTimer = Timer.scheduledTimer(withTimeInterval: clampedDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.restoreTimed(timerID: timerID)
            }
        }
    }

    private func toggle() {
        restoreTimer?.invalidate()
        restoreTimer = nil

        switch state {
        case .toggleActive:
            restore()
        case .inactive, .timedActive:
            guard let originalScale = currentOriginalScale() else {
                publishFailure(.readFailed)
                return
            }

            let appliedScale = clampedCursorScale

            persistRestore(originalScale: originalScale, appliedScale: appliedScale)
            setScale?(appliedScale)
            state = .toggleActive(originalScale: originalScale, appliedScale: appliedScale)
            objectWillChange.send()
        }
    }

    private func restoreTimed(timerID: UUID) {
        guard case .timedActive(let originalScale, let appliedScale, let activeTimerID) = state,
              activeTimerID == timerID
        else {
            return
        }

        restoreTimer?.invalidate()
        restoreTimer = nil
        restore(originalScale: originalScale, expectedAppliedScale: appliedScale)
    }

    private func restoreFromPersistedState() {
        guard let originalScale = Defaults[.cursorScaleOwnedOriginalScale],
              let appliedScale = Defaults[.cursorScaleOwnedAppliedScale]
        else {
            return
        }

        restore(originalScale: originalScale, expectedAppliedScale: appliedScale)
    }

    private func restore(originalScale: Double, expectedAppliedScale: Double) {
        guard let currentScale = readCurrentScale() else {
            publishFailure(.readFailed)
            return
        }

        guard approximatelyEqual(currentScale, expectedAppliedScale) || approximatelyEqual(currentScale, originalScale) else {
            state = .inactive
            clearPersistedRestore()
            publishFailure(.unsafeRestore)
            return
        }

        if !approximatelyEqual(currentScale, originalScale) {
            setScale?(originalScale)
        }

        state = .inactive
        clearPersistedRestore()
        lastStatusMessage = nil
        objectWillChange.send()
    }

    private func currentOriginalScale() -> Double? {
        switch state {
        case .inactive:
            return readCurrentScale()
        case .timedActive(let originalScale, _, _), .toggleActive(let originalScale, _):
            return originalScale
        }
    }

    private func readCurrentScale() -> Double? {
        guard let scale = getScale?(), scale.isFinite, scale > 0 else {
            return nil
        }

        return scale
    }

    private func persistRestore(originalScale: Double, appliedScale: Double) {
        Defaults[.cursorScaleOwnedOriginalScale] = originalScale
        Defaults[.cursorScaleOwnedAppliedScale] = appliedScale
    }

    private func clearPersistedRestore() {
        Defaults[.cursorScaleOwnedOriginalScale] = nil
        Defaults[.cursorScaleOwnedAppliedScale] = nil
    }

    private func publishFailure(_ error: CursorScaleError) {
        lastStatusMessage = error.rawValue
        objectWillChange.send()
    }

    private func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.05
    }

    private var clampedDuration: TimeInterval {
        min(max(Defaults[.cursorScaleDuration], 0.5), 30)
    }

    private var clampedCursorScale: Double {
        min(max(Defaults[.cursorScaleAmount], 1.5), 8)
    }

    private static func loadCursorScaleFunctions() -> (setScale: UACursorSetScale, getScale: UACursorGetScale)? {
        let candidates = [
            "/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/UniversalAccess",
            "/usr/lib/libUniversalAccess.dylib",
            "/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/Libraries/libUAPreferences.dylib",
            "/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/Frameworks/UniversalAccessCore.framework/Versions/A/UniversalAccessCore",
        ]

        for path in candidates {
            guard let handle = dlopen(path, RTLD_NOW) else { continue }

            guard let getScale = ["UACursorGetScale", "_UACursorGetScale"].compactMap({ symbol -> UACursorGetScale? in
                guard let pointer = dlsym(handle, symbol) else { return nil }
                return unsafeBitCast(pointer, to: UACursorGetScale.self)
            }).first else {
                continue
            }

            for symbol in ["UACursorSetScale", "_UACursorSetScale"] {
                guard let pointer = dlsym(handle, symbol) else { continue }
                return (unsafeBitCast(pointer, to: UACursorSetScale.self), getScale)
            }
        }

        return nil
    }
}
