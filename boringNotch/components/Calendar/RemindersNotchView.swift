//
//  RemindersNotchView.swift
//  boringNotch
//

import Defaults
import EventKit
import SwiftUI

struct RemindersNotchView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.hideCompletedReminders) private var hideCompletedReminders
    @Default(.notchTheme) private var notchTheme
    @FocusState private var addFieldFocused: Bool
    @State private var newReminderTitle = ""

    private var visibleReminders: [ReminderModel] {
        calendarManager.reminders.filter { reminder in
            !reminder.isCompleted || !hideCompletedReminders
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            header

            Group {
                if calendarManager.reminderAuthorizationStatus != .fullAccess {
                    permissionState
                } else if calendarManager.selectedReminderList == nil {
                    noListSelectedState
                } else {
                    reminderListState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 360, height: 128, alignment: .topLeading)
        .padding(.horizontal, 13)
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
        .task {
            await calendarManager.refreshReminderAuthorizationStatus()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.effectiveAccent)

            Text("Reminders")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(notchTheme.primaryForeground)

            if let selectedReminderList = calendarManager.selectedReminderList {
                Text(selectedReminderList.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(notchTheme.secondaryForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            if calendarManager.reminderAuthorizationStatus == .fullAccess,
               calendarManager.selectedReminderList != nil {
                Button {
                    Task {
                        await calendarManager.refreshSelectedReminders()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(notchTheme.secondaryForeground)
                .help("Refresh reminders")
                .disabled(calendarManager.remindersLoading)
            }
        }
        .frame(height: 20)
    }

    private var permissionState: some View {
        VStack(alignment: .leading, spacing: 7) {
            stateLine(
                icon: "lock",
                title: "Reminders access needed",
                message: "Enable access to show and update your list."
            )

            Button(action: handlePermissionAction) {
                Label(permissionButtonTitle, systemImage: permissionButtonIcon)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.effectiveAccent)
        }
    }

    private var noListSelectedState: some View {
        VStack(alignment: .leading, spacing: 7) {
            stateLine(
                icon: "list.bullet.rectangle",
                title: "No list selected",
                message: "Choose a Reminder list in Settings."
            )

            Button {
                SettingsWindowController.shared.showWindow()
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var reminderListState: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let errorMessage = calendarManager.reminderErrorMessage {
                errorBanner(errorMessage)
            }

            if calendarManager.remindersLoading && calendarManager.reminders.isEmpty {
                loadingState
            } else if visibleReminders.isEmpty {
                emptyState
            } else {
                remindersList
            }

            addReminderRow
        }
    }

    private var loadingState: some View {
        HStack(spacing: 7) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.62)
            Text("Loading reminders")
                .font(.caption)
                .foregroundStyle(notchTheme.secondaryForeground)
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .center)
    }

    private var emptyState: some View {
        stateLine(
            icon: "checkmark.circle",
            title: "No reminders",
            message: "Add one below to start this list."
        )
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
    }

    private var remindersList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 4) {
                ForEach(visibleReminders) { reminder in
                    reminderRow(reminder)
                }
            }
        }
        .scrollIndicators(.never)
        .frame(height: calendarManager.reminderErrorMessage == nil ? 55 : 37)
    }

    private var addReminderRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(notchTheme.secondaryForeground)

            TextField("New reminder", text: $newReminderTitle)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(notchTheme.primaryForeground)
                .focused($addFieldFocused)
                .onSubmit(addReminder)

            Button(action: addReminder) {
                if calendarManager.addingReminder {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.45)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.effectiveAccent)
            .help("Add reminder")
            .disabled(trimmedNewReminderTitle.isEmpty || calendarManager.addingReminder)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(
            notchTheme.background.opacity(notchTheme == .white ? 0.72 : 0.38),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(notchTheme.secondaryForeground.opacity(addFieldFocused ? 0.32 : 0.14), lineWidth: 1)
        )
    }

    private func reminderRow(_ reminder: ReminderModel) -> some View {
        let isUpdating = calendarManager.reminderUpdatingIDs.contains(reminder.id)

        return Button {
            toggleReminder(reminder)
        } label: {
            HStack(spacing: 8) {
                completionIndicator(for: reminder)

                Text(reminder.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(notchTheme.primaryForeground)
                    .lineLimit(1)
                    .strikethrough(reminder.isCompleted, color: notchTheme.secondaryForeground)

                Spacer(minLength: 0)

                if let dueDate = reminder.dueDate {
                    Text(dueDateLabel(for: dueDate))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(notchTheme.secondaryForeground)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                if isUpdating {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.45)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 23)
            .background(
                notchTheme.background.opacity(notchTheme == .white ? 0.58 : 0.26),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .opacity(reminder.isCompleted ? 0.5 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isUpdating)
        .accessibilityLabel(reminder.isCompleted ? "Mark \(reminder.title) incomplete" : "Mark \(reminder.title) complete")
    }

    private func completionIndicator(for reminder: ReminderModel) -> some View {
        let color = Color(reminder.calendar.color)

        return ZStack {
            Circle()
                .strokeBorder(color, lineWidth: 2)
                .frame(width: 14, height: 14)

            if reminder.isCompleted {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func stateLine(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(notchTheme.secondaryForeground)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(notchTheme.primaryForeground)

                Text(message)
                    .font(.caption2)
                    .foregroundStyle(notchTheme.secondaryForeground)
                    .lineLimit(2)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(message)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(.red)
        .padding(.horizontal, 7)
        .frame(height: 18)
        .background(
            Color.red.opacity(notchTheme == .white ? 0.10 : 0.18),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
    }

    private var trimmedNewReminderTitle: String {
        newReminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var permissionButtonTitle: String {
        calendarManager.reminderAuthorizationStatus == .notDetermined ? "Grant Access" : "Open Settings"
    }

    private var permissionButtonIcon: String {
        calendarManager.reminderAuthorizationStatus == .notDetermined ? "checkmark.shield" : "gear"
    }

    private func addReminder() {
        let title = trimmedNewReminderTitle
        guard !title.isEmpty, !calendarManager.addingReminder else { return }

        Task {
            let added = await calendarManager.addReminderToSelectedList(title: title)
            if added {
                await MainActor.run {
                    newReminderTitle = ""
                    addFieldFocused = true
                }
            }
        }
    }

    private func toggleReminder(_ reminder: ReminderModel) {
        Task {
            await calendarManager.setReminderCompleted(reminder, completed: !reminder.isCompleted)
        }
    }

    private func handlePermissionAction() {
        switch calendarManager.reminderAuthorizationStatus {
        case .notDetermined:
            Task {
                await calendarManager.requestReminderAuthorization()
            }
        default:
            openReminderSettings()
        }
    }

    private func openReminderSettings() {
        if let settingsURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
        ) {
            NSWorkspace.shared.open(settingsURL)
        }
    }

    private func dueDateLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    RemindersNotchView()
        .background(Defaults[.notchTheme].background)
}
