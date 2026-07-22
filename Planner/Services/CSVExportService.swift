import Foundation
import SwiftData

final class CSVExportService {
    static let shared = CSVExportService()
    private init() {}

    func generateCSV(plans: [Plan], options: PDFExportOptions) -> String {
        let filtered = filterPlans(plans, options: options)
        var rows: [String] = []

        let headers = ["Date", "Day", "Title", "Status", "Start Time", "End Time", "Memo", "Completed At", "Is Work", "Site Name", "Work Units", "Daily Wage (₩)", "Expected Income (₩)", "Paid", "Reminder"]
        rows.append(headers.map { escape($0) }.joined(separator: ","))

        let cal = Calendar.current
        let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
        let dayFmt = DateFormatter(); dayFmt.dateFormat = "EEEE"; dayFmt.locale = Locale(identifier: "en_US")
        let completedFmt = DateFormatter(); completedFmt.dateFormat = "yyyy-MM-dd HH:mm"

        for plan in filtered.sorted(by: { $0.scheduledDateOnly < $1.scheduledDateOnly }) {
            let date = cal.date(from: DateComponents(year: plan.year, month: plan.month, day: plan.day)) ?? Date()

            let startTime = plan.hasTime ? String(format: "%02d:%02d", plan.hour, plan.minute) : ""
            let endTime = plan.hasEndTime ? String(format: "%02d:%02d", plan.endHour, plan.endMinute) : ""
            let completedAt = plan.completedAt.map { completedFmt.string(from: $0) } ?? ""

            let cols: [String] = [
                dateFmt.string(from: date),
                dayFmt.string(from: date),
                plan.title,
                plan.status.rawValue.capitalized,
                startTime,
                endTime,
                plan.memo,
                completedAt,
                plan.isWorkSchedule ? "Yes" : "No",
                plan.siteName,
                plan.isWorkSchedule ? String(format: "%.1f", plan.workUnits) : "",
                plan.isWorkSchedule && plan.dailyWage > 0 ? "\(plan.dailyWage)" : "",
                plan.isWorkSchedule && plan.expectedIncome > 0 ? "\(Int(plan.expectedIncome))" : "",
                plan.isWorkSchedule ? (plan.isPaid ? "Yes" : "No") : "",
                plan.notificationEnabled ? "Yes" : "No"
            ]

            rows.append(cols.map { escape($0) }.joined(separator: ","))
        }

        return "\u{FEFF}" + rows.joined(separator: "\n") // BOM for UTF-8
    }

    func generateWorkCSV(plans: [Plan], year: Int, month: Int) -> String {
        let workPlans = plans
            .filter { $0.isWorkSchedule && $0.year == year && $0.month == month }
            .sorted { $0.scheduledDateOnly < $1.scheduledDateOnly }

        var rows: [String] = []
        let cal = Calendar.current
        let titleDate = cal.date(from: DateComponents(year: year, month: month)) ?? Date()
        
        let titleFmt = DateFormatter(); titleFmt.dateFormat = "MMMM yyyy"; titleFmt.locale = Locale(identifier: "en_US")
        rows.append(escape("Work Schedule — \(titleFmt.string(from: titleDate))"))
        rows.append("")

        let headers = ["Date", "Day", "Site", "Units", "Wage (₩)", "Income (₩)", "Payment", "Start", "End", "Memo"]
        rows.append(headers.map { escape($0) }.joined(separator: ","))

        let dateFmt = DateFormatter(); dateFmt.dateFormat = "MM/dd"
        let dayFmt  = DateFormatter(); dayFmt.dateFormat = "EEE"; dayFmt.locale = Locale(identifier: "en_US")

        var totalUnits: Double = 0, totalExpected: Double = 0, totalPaid: Double = 0

        for plan in workPlans {
            let date = cal.date(from: DateComponents(year: plan.year, month: plan.month, day: plan.day)) ?? Date()

            totalUnits += plan.workUnits
            totalExpected += plan.expectedIncome
            if plan.isPaid { totalPaid += plan.expectedIncome }

            let startTime = plan.hasTime ? String(format: "%02d:%02d", plan.hour, plan.minute) : ""
            let endTime   = plan.hasEndTime ? String(format: "%02d:%02d", plan.endHour, plan.endMinute) : ""

            let cols: [String] = [
                dateFmt.string(from: date),
                dayFmt.string(from: date),
                plan.siteName.isEmpty ? plan.title : plan.siteName,
                String(format: "%.1f", plan.workUnits),
                plan.dailyWage > 0 ? "\(plan.dailyWage)" : "",
                plan.expectedIncome > 0 ? "\(Int(plan.expectedIncome))" : "",
                plan.isPaid ? "Paid" : "Unpaid",
                startTime,
                endTime,
                plan.memo
            ]
            rows.append(cols.map { escape($0) }.joined(separator: ","))
        }

        rows.append("\nTOTAL,,,\(escape(String(format: "%.1f", totalUnits))),,\(escape("₩\(Int(totalExpected).formatted())")),\(escape("Paid: ₩\(Int(totalPaid).formatted())  Unpaid: ₩\(Int(totalExpected - totalPaid).formatted())")),,,")

        return "\u{FEFF}" + rows.joined(separator: "\n")
    }

    private func escape(_ str: String) -> String {
        if str.contains(",") || str.contains("\"") || str.contains("\n") {
            return "\"" + str.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return str
    }

    // 💡 최적화: Calendar의 isDate 내장 함수 활용으로 가독성 및 속도 향상
    func filterPlans(_ plans: [Plan], options: PDFExportOptions) -> [Plan] {
        let cal = Calendar.current
        let now = Date()

        let dateFiltered = plans.filter { plan in
            let date = plan.scheduledDateOnly
            switch options.range {
            case .today:     return cal.isDateInToday(date)
            case .thisWeek:  return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth: return cal.isDate(date, equalTo: now, toGranularity: .month)
            case .allTime:   return true
            }
        }

        return dateFiltered.filter { plan in
            if plan.isWorkSchedule && !options.includeWorkSchedule { return false }
            switch plan.status {
            case .completed: return options.includeCompleted
            case .planned:   return options.includePlanned
            case .canceled:  return options.includeCanceled
            }
        }
    }
}
