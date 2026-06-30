//
//  CalendarManager.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import Defaults
import EventKit
import SwiftUI

// MARK: - CalendarManager

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    @Published var currentWeekStartDate: Date
    @Published var events: [EventModel] = []
    @Published var allCalendars: [CalendarModel] = []
    @Published var eventCalendars: [CalendarModel] = []
    @Published var reminderLists: [CalendarModel] = []
    @Published var selectedReminderList: CalendarModel?
    @Published var reminders: [ReminderModel] = []
    @Published var remindersLoading = false
    @Published var addingReminder = false
    @Published var reminderUpdatingIDs: Set<String> = []
    @Published var reminderErrorMessage: String?
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    private var selectedCalendars: [CalendarModel] = []
    private let calendarService = CalendarService()

    private var eventStoreChangedObserver: NSObjectProtocol?

    private init() {
        self.currentWeekStartDate = CalendarManager.startOfDay(Date())
        setupEventStoreChangedObserver()
        Task {
            await reloadCalendarAndReminderLists()
        }
    }

    deinit {
        if let observer = eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupEventStoreChangedObserver() {
        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.reloadCalendarAndReminderLists()
            }
        }
    }

    @MainActor
    func reloadCalendarAndReminderLists() async {
        let all = await calendarService.calendars()
        self.eventCalendars = all.filter { !$0.isReminder }
        self.reminderLists = all.filter { $0.isReminder }
        self.allCalendars = all // for legacy compatibility, can be removed if not needed
        updateSelectedCalendars()
        updateSelectedReminderList()
        await refreshSelectedReminders()
    }

    func checkCalendarAuthorization() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        DispatchQueue.main.async {
            print("📅 Current calendar authorization status: \(status)")
            self.calendarAuthorizationStatus = status
        }

        switch status {
        case .notDetermined:
            guard let granted = try? await calendarService.requestAccess(to: .event) else {
                self.calendarAuthorizationStatus = .notDetermined
                return
            }
            self.calendarAuthorizationStatus = granted ? .fullAccess : .denied
            if granted {
                await reloadCalendarAndReminderLists()
                events = await calendarService.events(
                    from: currentWeekStartDate,
                    to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
                    calendars: selectedCalendars.map { $0.id })
            }
        case .restricted, .denied:
            NSLog("Calendar access denied or restricted")
        case .fullAccess:
            NSLog("Full access")
            await reloadCalendarAndReminderLists()
            events = await calendarService.events(
                from: currentWeekStartDate,
                to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
                calendars: selectedCalendars.map { $0.id })
        case .writeOnly:
            NSLog("Write only")
        @unknown default:
            print("Unknown authorization status")
        }
    }
    
    func checkReminderAuthorization() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        DispatchQueue.main.async {
            print("📅 Current reminder authorization status: \(status)")
            self.reminderAuthorizationStatus = status
        }

        switch status {
        case .notDetermined:
            guard let granted = try? await calendarService.requestAccess(to: .reminder) else {
                self.reminderAuthorizationStatus = .notDetermined
                return
            }
            self.reminderAuthorizationStatus = granted ? .fullAccess : .denied
            if granted {
                await reloadCalendarAndReminderLists()
            }
        case .restricted, .denied:
            NSLog("Reminder access denied or restricted")
        case .fullAccess:
            NSLog("Full access")
            await reloadCalendarAndReminderLists()
        case .writeOnly:
            NSLog("Write only")
        @unknown default:
            print("Unknown authorization status")
        }
    }

    func refreshReminderAuthorizationStatus() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        reminderAuthorizationStatus = status
        if status == .fullAccess {
            await reloadCalendarAndReminderLists()
        } else {
            reminders = []
            remindersLoading = false
        }
    }

    func requestReminderAuthorization() async {
        guard let granted = try? await calendarService.requestAccess(to: .reminder) else {
            reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            return
        }
        reminderAuthorizationStatus = granted ? .fullAccess : .denied
        if granted {
            await reloadCalendarAndReminderLists()
        }
    }

    func updateSelectedReminderList() {
        let selectedID = Defaults[.selectedReminderListID]

        guard !selectedID.isEmpty else {
            selectedReminderList = nil
            reminders = []
            return
        }

        guard let list = reminderLists.first(where: { $0.id == selectedID }) else {
            Defaults[.selectedReminderListID] = ""
            selectedReminderList = nil
            reminders = []
            return
        }

        selectedReminderList = list
    }

    func setSelectedReminderListID(_ id: String) async {
        Defaults[.selectedReminderListID] = id
        updateSelectedReminderList()
        await refreshSelectedReminders()
    }

    func refreshSelectedReminders() async {
        reminderErrorMessage = nil

        guard reminderAuthorizationStatus == .fullAccess else {
            reminders = []
            remindersLoading = false
            return
        }

        guard let selectedReminderList else {
            reminders = []
            remindersLoading = false
            return
        }

        remindersLoading = true
        defer { remindersLoading = false }

        do {
            reminders = try await calendarService.reminders(
                in: selectedReminderList.id,
                includeCompleted: true
            )
        } catch {
            reminders = []
            reminderErrorMessage = error.localizedDescription
        }
    }

    func addReminderToSelectedList(title: String) async -> Bool {
        guard let selectedReminderList else {
            reminderErrorMessage = "Select a reminder list first."
            return false
        }

        addingReminder = true
        reminderErrorMessage = nil
        defer { addingReminder = false }

        do {
            _ = try await calendarService.addReminder(title: title, to: selectedReminderList.id)
            await refreshSelectedReminders()
            return true
        } catch {
            reminderErrorMessage = error.localizedDescription
            return false
        }
    }

    func updateSelectedCalendars() {
        // Populate selectedCalendarIDs based on Defaults calendar selection state
        switch Defaults[.calendarSelectionState] {
        case .all:
            selectedCalendarIDs = Set(allCalendars.map { $0.id })
        case .selected(let identifiers):
            selectedCalendarIDs = identifiers
        }

        // Update the local calendar objects that correspond to the selected ids
        selectedCalendars = allCalendars.filter { selectedCalendarIDs.contains($0.id) }
    }

    func getCalendarSelected(_ calendar: CalendarModel) -> Bool {
        return selectedCalendarIDs.contains(calendar.id)
    }

    func setCalendarSelected(_ calendar: CalendarModel, isSelected: Bool) async {
        var selectionState = Defaults[.calendarSelectionState]

        switch selectionState {
        case .all:
            if !isSelected {
                let identifiers = Set(allCalendars.map { $0.id }).subtracting([calendar.id])
                selectionState = .selected(identifiers)
            }

        case .selected(var identifiers):
            if isSelected {
                identifiers.insert(calendar.id)
            } else {
                identifiers.remove(calendar.id)
            }

            selectionState =
                identifiers.isEmpty
                ? .all : identifiers.count == allCalendars.count ? .all : .selected(identifiers)  // if empty, select all
        }

        Defaults[.calendarSelectionState] = selectionState
        updateSelectedCalendars()
        await updateEvents()
    }

    static func startOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }

    func updateCurrentDate(_ date: Date) async {
        currentWeekStartDate = Calendar.current.startOfDay(for: date)
        await updateEvents()
    }

    private func updateEvents() async {
        let calendarIDs = selectedCalendars.map { $0.id }
        let eventsResult = await calendarService.events(
            from: currentWeekStartDate,
            to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
            calendars: calendarIDs
        )
        self.events = eventsResult
    }
    
    func setReminderCompleted(reminderID: String, completed: Bool) async {
        do {
            try await calendarService.setReminderCompleted(reminderID: reminderID, completed: completed)
        } catch {
            reminderErrorMessage = error.localizedDescription
        }

        events = await calendarService.events(
            from: currentWeekStartDate,
            to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
            calendars: selectedCalendars.map { $0.id })
        await refreshSelectedReminders()
    }

    func setReminderCompleted(_ reminder: ReminderModel, completed: Bool) async {
        reminderUpdatingIDs.insert(reminder.id)
        reminderErrorMessage = nil
        defer { reminderUpdatingIDs.remove(reminder.id) }

        do {
            try await calendarService.setReminderCompleted(reminderID: reminder.id, completed: completed)
            await refreshSelectedReminders()
            await updateEvents()
        } catch {
            reminderErrorMessage = error.localizedDescription
        }
    }
}
