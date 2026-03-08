import Foundation
import SwiftData

// MARK: - CSV Export Service

final class CSVExportService {
    static let shared = CSVExportService()
    private init() {}

    // MARK: - Generate CSV

    func generateCSV(plans: [Plan], options: PDFExportOptions) -> String {
        let filtered = filterPlans(plans, options: options)

        var rows: [String] = []

        // Header row
        let headers = [
            "Date",
            "Day",
            "Title",
            "Status",
            "Category",
            "Start Time",
            "End Time",
            "Memo",
            "Completed At",
            "Is Work",
            "Site Name",
            "Work Units",
            "Daily Wage (₩)",
            "Expected Income (₩)",
            "Paid",
            "Reminder"
        ]
        rows.append(headers.map { escape($0) }.joined(separator: ","))

        // Data rows
        let cal = Calendar.current
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        let completedFmt = DateFormatter()
        completedFmt.dateFormat = "yyyy-MM-dd HH:mm"

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEEE"
        dayFmt.locale = Locale(identifier: "en_US")

        for plan in filtered.sorted(by: { $0.scheduledDateOnly < $1.scheduledDateOnly }) {
            var comps = DateComponents()
            comps.year = plan.year; comps.month = plan.month; comps.day = plan.day
            let date = cal.date(from: comps) ?? Date()

            let startTime: String = plan.hasTime
                ? String(format: "%02d:%02d", plan.hour, plan.minute) : ""
            let endTime: String = plan.hasEndTime
                ? String(format: "%02d:%02d", plan.endHour, plan.endMinute) : ""
            let completedAt: String = plan.completedAt.map { completedFmt.string(from: $0) } ?? ""

            let cols: [String] = [
                dateFmt.string(from: date),
                dayFmt.string(from: date),
                plan.title,
                plan.status.rawValue.capitalized,
                plan.category?.name ?? "",
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

        // BOM for Excel/Google Sheets UTF-8 인식
        return "\u{FEFF}" + rows.joined(separator: "\n")
    }

    // MARK: - Work-only CSV (월별 정산용)

    func generateWorkCSV(plans: [Plan], year: Int, month: Int) -> String {
        let workPlans = plans
            .filter { $0.isWorkSchedule && $0.year == year && $0.month == month }
            .sorted { $0.scheduledDateOnly < $1.scheduledDateOnly }

        var rows: [String] = []

        // 제목 행
        let cal = Calendar.current
        var titleComps = DateComponents(); titleComps.year = year; titleComps.month = month
        let titleDate = cal.date(from: titleComps) ?? Date()
        let titleFmt = DateFormatter(); titleFmt.dateFormat = "MMMM yyyy"; titleFmt.locale = Locale(identifier: "en_US")
        rows.append(escape("Work Schedule — \(titleFmt.string(from: titleDate))"))
        rows.append("")

        // Header
        let headers = ["Date", "Day", "Site", "Units", "Wage (₩)", "Income (₩)", "Payment", "Start", "End", "Memo"]
        rows.append(headers.map { escape($0) }.joined(separator: ","))

        let dateFmt = DateFormatter(); dateFmt.dateFormat = "MM/dd"
        let dayFmt  = DateFormatter(); dayFmt.dateFormat = "EEE"; dayFmt.locale = Locale(identifier: "en_US")

        var totalUnits:    Double = 0
        var totalExpected: Double = 0
        var totalPaid:     Double = 0

        for plan in workPlans {
            var comps = DateComponents()
            comps.year = plan.year; comps.month = plan.month; comps.day = plan.day
            let date = cal.date(from: comps) ?? Date()

            totalUnits    += plan.workUnits
            totalExpected += plan.expectedIncome
            if plan.isPaid { totalPaid += plan.expectedIncome }

            let startTime = plan.hasTime    ? String(format: "%02d:%02d", plan.hour,    plan.minute)    : ""
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

        // Summary row
        rows.append("")
        rows.append([
            escape("TOTAL"), "", "", escape(String(format: "%.1f", totalUnits)), "",
            escape("₩\(Int(totalExpected).formatted())"),
            escape("Paid: ₩\(Int(totalPaid).formatted())  Unpaid: ₩\(Int(totalExpected - totalPaid).formatted())"),
            "", "", ""
        ].joined(separator: ","))

        return "\u{FEFF}" + rows.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func escape(_ str: String) -> String {
        // CSV 셀에 쉼표·따옴표·줄바꿈이 포함되면 큰따옴표로 감싸기
        let needsQuoting = str.contains(",") || str.contains("\"") || str.contains("\n")
        if needsQuoting {
            return "\"" + str.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return str
    }

    private func filterPlans(_ plans: [Plan], options: PDFExportOptions) -> [Plan] {
        let cal = Calendar.current
        let now = Date()

        let dateFiltered: [Plan]
        switch options.range {
        case .today:
            let c = cal.dateComponents([.year, .month, .day], from: now)
            dateFiltered = plans.filter { $0.year == c.year && $0.month == c.month && $0.day == c.day }
        case .thisWeek:
            guard let ws = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
            let we = cal.date(byAdding: .day, value: 7, to: ws) ?? now
            dateFiltered = plans.filter { $0.scheduledDateOnly >= ws && $0.scheduledDateOnly < we }
        case .thisMonth:
            let c = cal.dateComponents([.year, .month], from: now)
            dateFiltered = plans.filter { $0.year == c.year && $0.month == c.month }
        case .allTime:
            dateFiltered = plans
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
