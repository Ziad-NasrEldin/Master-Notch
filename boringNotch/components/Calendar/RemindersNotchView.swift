//
//  RemindersNotchView.swift
//  boringNotch
//

import AppKit
import Defaults
import EventKit
import SwiftUI

struct RemindersNotchView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.hideCompletedReminders) private var hideCompletedReminders
    @Default(.notchTheme) private var notchTheme
    @FocusState private var addFieldFocused: Bool
    @State private var newReminderTitle = ""
    @State private var selectingReminderListID: String?

    private var visibleReminders: [ReminderModel] {
        calendarManager.reminders.filter { reminder in
            !reminder.isCompleted || !hideCompletedReminders
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                statusLine
                content
            }
            .frame(width: 310, alignment: .leading)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 12) {
                topControls
                addReminderControl
            }
            .frame(width: 210, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
        .frame(width: 608, height: 142, alignment: .center)
        .contentShape(Rectangle())
        .onHover { hovering in
            calendarManager.setRemindersListHovering(hovering)
        }
        .task {
            await calendarManager.refreshReminderAuthorizationStatus()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.effectiveAccent)
                .frame(width: 14, height: 14)

            Text(statusTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(notchTheme.primaryForeground)
                .lineLimit(1)

            if calendarManager.selectedReminderList != nil {
                Label("\(visibleReminders.count)", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(notchTheme.secondaryForeground)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if calendarManager.reminderAuthorizationStatus != .fullAccess {
            stateMessage("Enable Reminders access to show your list.")
        } else if calendarManager.remindersLoading && calendarManager.reminders.isEmpty {
            loadingState
        } else if calendarManager.selectedReminderList == nil {
            stateMessage(calendarManager.reminderLists.isEmpty ? "No Reminder lists found." : "Choose a list to show here.")
        } else if let errorMessage = calendarManager.reminderErrorMessage,
                  visibleReminders.isEmpty {
            stateMessage(errorMessage)
        } else if visibleReminders.isEmpty {
            stateMessage("No reminders in this list.")
        } else {
            remindersList
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
        .frame(width: 300, height: 72, alignment: .center)
    }

    private func stateMessage(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(notchTheme.secondaryForeground)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 300, height: 72, alignment: .topLeading)
            .padding(.top, 2)
    }

    private var remindersList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 5) {
                ForEach(visibleReminders.prefix(6)) { reminder in
                    reminderRow(reminder)
                }
            }
            .padding(.trailing, 4)
        }
        .scrollIndicators(.visible)
        .frame(width: 310, height: 72, alignment: .topLeading)
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
            .frame(height: 20)
            .opacity(reminder.isCompleted ? 0.52 : 1)
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
                .frame(width: 13, height: 13)

            if reminder.isCompleted {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
            }
        }
    }

    private var topControls: some View {
        HStack(spacing: 9) {
            reminderListMenu

            controlButton(icon: "arrow.clockwise", title: "Refresh") {
                Task {
                    await calendarManager.refreshSelectedReminders()
                }
            }
            .disabled(calendarManager.remindersLoading)

            if calendarManager.reminderAuthorizationStatus != .fullAccess {
                controlButton(icon: permissionButtonIcon, title: permissionButtonTitle) {
                    handlePermissionAction()
                }
            }
        }
    }

    private var reminderListMenu: some View {
        Menu {
            Button {
                selectReminderList("")
            } label: {
                if calendarManager.selectedReminderList == nil {
                    Label("None", systemImage: "checkmark")
                } else {
                    Text("None")
                }
            }

            Divider()

            ForEach(calendarManager.reminderLists, id: \.id) { list in
                Button {
                    selectReminderList(list.id)
                } label: {
                    if calendarManager.selectedReminderList?.id == list.id {
                        Label(list.title, systemImage: "checkmark")
                    } else {
                        Text(list.title)
                    }
                }
                .disabled(selectingReminderListID == list.id)
            }
        } label: {
            HStack(spacing: 6) {
                if selectingReminderListID != nil {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.45)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 12, height: 12)
                }

                Text(selectedReminderListTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(notchTheme.primaryForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(notchTheme.secondaryForeground)
            }
            .padding(.horizontal, 8)
            .frame(width: reminderListMenuWidth, height: 28, alignment: .leading)
            .background(
                notchTheme.selectedTabBackground.opacity(notchTheme == .white ? 0.86 : 0.52),
                in: Capsule()
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .help("Change reminder list")
        .disabled(selectingReminderListID != nil)
    }

    private var addReminderControl: some View {
        HStack(spacing: 6) {
            TextField("New reminder", text: $newReminderTitle)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(notchTheme.primaryForeground)
                .frame(height: 28)
                .focused($addFieldFocused)
                .disabled(calendarManager.selectedReminderList == nil || calendarManager.addingReminder)
                .onTapGesture {
                    NSApp.activate(ignoringOtherApps: true)
                    addFieldFocused = true
                }
                .onSubmit(addReminder)

            Button(action: addReminder) {
                if calendarManager.addingReminder {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.45)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 22)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.effectiveAccent)
            .help("Add reminder")
            .disabled(
                calendarManager.selectedReminderList == nil
                    || trimmedNewReminderTitle.isEmpty
                    || calendarManager.addingReminder
            )
        }
        .padding(.horizontal, 9)
        .frame(width: 206, height: 32)
        .background(
            notchTheme.selectedTabBackground.opacity(notchTheme == .white ? 0.86 : 0.52),
            in: Capsule()
        )
    }

    private func controlButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(
                    notchTheme.selectedTabBackground.opacity(notchTheme == .white ? 0.86 : 0.52),
                    in: Circle()
                )
                .foregroundStyle(notchTheme.primaryForeground)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var trimmedNewReminderTitle: String {
        newReminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedReminderListTitle: String {
        calendarManager.selectedReminderList?.title ?? "List"
    }

    private var reminderListMenuWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        let titleWidth = selectedReminderListTitle.size(withAttributes: [.font: font]).width
        let chromeWidth: CGFloat = 48

        return min(max(72, ceil(titleWidth + chromeWidth)), 136)
    }

    private var statusTitle: String {
        if calendarManager.reminderAuthorizationStatus != .fullAccess {
            return "Reminders"
        }

        return calendarManager.selectedReminderList?.title ?? "Reminders"
    }

    private var statusIcon: String {
        calendarManager.reminderAuthorizationStatus == .fullAccess ? "checklist.checked" : "lock.slash"
    }

    private var permissionButtonTitle: String {
        calendarManager.reminderAuthorizationStatus == .notDetermined ? "Grant Access" : "Open Settings"
    }

    private var permissionButtonIcon: String {
        calendarManager.reminderAuthorizationStatus == .notDetermined ? "checkmark.shield" : "gear"
    }

    private func selectReminderList(_ id: String) {
        guard calendarManager.selectedReminderList?.id != id || id.isEmpty else { return }

        selectingReminderListID = id
        Task {
            await calendarManager.setSelectedReminderListID(id)
            await MainActor.run {
                selectingReminderListID = nil
            }
        }
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
        .frame(width: 640, height: 160)
        .background(Defaults[.notchTheme].background)
}
