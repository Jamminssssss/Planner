import Foundation
import EventKit
import UIKit

final class CalendarService {
    static let shared = CalendarService()
    private let eventStore = EKEventStore()
    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestWriteOnlyAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            print("[CalendarService] Permission request failed: \(error)")
            return false
        }
    }

    // MARK: - Create Event

    func createEvent(for plan: Plan) async -> String? {
        let granted = await requestPermission()
        guard granted else {
            print("[CalendarService] Calendar permission denied")
            return nil
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = plan.title
        event.notes = plan.memo.isEmpty ? nil : plan.memo

        var comps = DateComponents()
        comps.year = plan.year
        comps.month = plan.month
        comps.day = plan.day

        if plan.hasTime {
            comps.hour = plan.hour
            comps.minute = plan.minute

            guard let start = Calendar.current.date(from: comps) else { return nil }
            event.startDate = start
            event.endDate = start.addingTimeInterval(60 * 60)
            event.isAllDay = false
        } else {
            guard let start = Calendar.current.date(from: comps) else { return nil }
            event.startDate = start
            event.endDate = start.addingTimeInterval(60 * 60 * 24)
            event.isAllDay = true
        }

        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("[CalendarService] Failed to create event: \(error)")
            return nil
        }
    }

    // MARK: - Delete Event

    func deleteEvent(identifier: String) {
        guard let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }

    // MARK: - Open Calendar App (FIXED)

    /// iOS에서 정상 동작하는 방식 (calshow)
    func openCalendar(for plan: Plan) {
        var comps = DateComponents()
        comps.year = plan.year
        comps.month = plan.month
        comps.day = plan.day

        guard let date = Calendar.current.date(from: comps) else { return }

        let interval = date.timeIntervalSinceReferenceDate
        let urlString = "calshow:\(interval)"

        guard let url = URL(string: urlString) else { return }

        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }
}
