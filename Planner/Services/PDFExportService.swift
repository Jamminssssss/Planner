import UIKit
import SwiftData
import SwiftUI

enum PDFExportRange: String, CaseIterable {
    case today = "Today", thisWeek = "This Week", thisMonth = "This Month", allTime = "All Plans"
    var systemImage: String {
        switch self {
        case .today: return "calendar.circle"
        case .thisWeek: return "calendar.badge.clock"
        case .thisMonth: return "calendar"
        case .allTime: return "archivebox"
        }
    }
}

struct PDFExportOptions {
    var range: PDFExportRange = .thisMonth
    var includeWorkSchedule: Bool = true
    var includeCompleted: Bool = true
    var includePlanned: Bool = true
    var includeCanceled: Bool = false
    var includeMemo: Bool = true
    var includeStats: Bool = true
}

@MainActor
final class PDFExportService {
    static let shared = PDFExportService()
    private init() {}

    func generatePDF(plans: [Plan], options: PDFExportOptions) -> Data {
        // 동일하게 개선된 filter 호출
        let filtered = CSVExportService.shared.filterPlans(plans, options: options)
        let grouped  = groupByDate(filtered)

        let pageWidth: CGFloat = 595.2, pageHeight: CGFloat = 841.8, margin: CGFloat = 40
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = ["Title": "GrassPlanner – Export", "Author": "GrassPlanner"]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)

        return renderer.pdfData { ctx in
            var yOffset: CGFloat = margin

            ctx.beginPage()
            yOffset = drawCover(in: ctx.cgContext, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, plans: filtered, options: options)

            if options.includeStats && !filtered.isEmpty {
                ctx.beginPage()
                _ = drawStatsSummary(in: ctx.cgContext, pageWidth: pageWidth, margin: margin, plans: filtered, options: options)
            }

            ctx.beginPage()
            yOffset = margin + 10

            for (dateKey, dayPlans) in grouped {
                let estimatedHeight = CGFloat(dayPlans.count) * 90 + 60
                if yOffset + estimatedHeight > pageHeight - margin {
                    ctx.beginPage()
                    yOffset = margin + 10
                }
                yOffset = drawDaySection(in: ctx.cgContext, dateKey: dateKey, plans: dayPlans, yOffset: yOffset, pageWidth: pageWidth, margin: margin, options: options, ctx: ctx, pageHeight: pageHeight) + 16
            }
        }
    }

    private func groupByDate(_ plans: [Plan]) -> [(key: String, value: [Plan])] {
        Dictionary(grouping: plans) { String(format: "%04d-%02d-%02d", $0.year, $0.month, $0.day) }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.scheduledDate < $1.scheduledDate }) }
    }

    // MARK: - Drawing Components
    private func drawCover(in ctx: CGContext, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, plans: [Plan], options: PDFExportOptions) -> CGFloat {
        let gradColors = [UIColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1).cgColor, UIColor(red: 0.10, green: 0.38, blue: 0.14, alpha: 1).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradColors as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: pageWidth/2, y: 0), end: CGPoint(x: pageWidth/2, y: pageHeight*0.42), options: [])

        var y: CGFloat = 80
        let cx = pageWidth / 2

        ctx.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - 44, y: y, width: 88, height: 88))
        drawText("🌱", at: CGPoint(x: cx, y: y + 22), font: .systemFont(ofSize: 44), color: .white, centered: true)
        
        y += 108
        drawText("GrassPlanner", at: CGPoint(x: cx, y: y), font: .systemFont(ofSize: 32, weight: .bold), color: .white, centered: true)
        y += 42
        drawText("Plan Export Report", at: CGPoint(x: cx, y: y), font: .systemFont(ofSize: 16, weight: .medium), color: UIColor.white.withAlphaComponent(0.85), centered: true)
        y += 30
        drawText(options.range.rawValue, at: CGPoint(x: cx, y: y), font: .systemFont(ofSize: 13), color: UIColor.white.withAlphaComponent(0.70), centered: true)

        // Card Area
        let cardY = pageHeight * 0.42 + 30
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: margin, y: cardY, width: pageWidth - margin * 2, height: 260), cornerRadius: 12).cgPath)
        ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 10, color: UIColor.black.withAlphaComponent(0.08).cgColor)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        let completed = plans.filter { $0.status == .completed }.count
        let planned   = plans.filter { $0.status == .planned }.count
        let workCount = plans.filter { $0.isWorkSchedule }.count
        let rate = plans.isEmpty ? 0 : Int(Double(completed) / Double(plans.count) * 100)

        var cardY2 = cardY + 24
        drawText("Summary", at: CGPoint(x: margin + 24, y: cardY2), font: .systemFont(ofSize: 15, weight: .semibold), color: UIColor(red: 0.1, green: 0.38, blue: 0.14, alpha: 1))
        
        cardY2 += 32
        let cols: [(String, String, UIColor)] = [
            ("Total Plans", "\(plans.count)", .darkGray),
            ("Completed", "\(completed)", UIColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1)),
            ("Planned", "\(planned)", UIColor(red: 0.20, green: 0.40, blue: 0.80, alpha: 1)),
            ("Work Days", "\(workCount)", UIColor(red: 0.85, green: 0.45, blue: 0.10, alpha: 1)),
            ("Completion", "\(rate)%", UIColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1))
        ]

        let colW = (pageWidth - margin * 2 - 48) / 2
        for (i, col) in cols.enumerated() {
            let xPos = margin + 24 + (i % 2 == 0 ? 0 : colW)
            if i % 2 == 0 && i > 0 { cardY2 += 42 }
            drawStatRow(label: col.0, value: col.1, color: col.2, at: CGPoint(x: xPos, y: cardY2))
        }

        let fmt = DateFormatter(); fmt.dateStyle = .long; fmt.timeStyle = .short
        drawText("Generated: \(fmt.string(from: Date()))", at: CGPoint(x: cx, y: pageHeight - margin - 20), font: .systemFont(ofSize: 10), color: .gray, centered: true)

        return pageHeight
    }

    private func drawStatsSummary(in ctx: CGContext, pageWidth: CGFloat, margin: CGFloat, plans: [Plan], options: PDFExportOptions) -> CGFloat {
        var y = margin
        ctx.setFillColor(UIColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1).cgColor)
        ctx.fill(CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 32))
        drawText("📊  Statistics", at: CGPoint(x: margin + 12, y: y + 8), font: .systemFont(ofSize: 14, weight: .bold), color: .white)
        
        y += 40
        let workPlans = plans.filter { $0.isWorkSchedule }
        if options.includeWorkSchedule && !workPlans.isEmpty {
            y += 12
            ctx.setStrokeColor(UIColor.lightGray.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: margin, y: y)); ctx.addLine(to: CGPoint(x: pageWidth - margin, y: y)); ctx.strokePath()
            y += 14

            drawText("💼  Work Summary", at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 13, weight: .semibold))
            y += 24

            let totalUnits = workPlans.reduce(0) { $0 + $1.workUnits }
            let totalIncome = workPlans.reduce(0) { $0 + $1.expectedIncome }
            let paidIncome = workPlans.filter { $0.isPaid }.reduce(0) { $0 + $1.expectedIncome }

            let stats = [
                ("Work Days", "\(workPlans.count)"),
                ("Total Units", String(format: "%.1f", totalUnits)),
                ("Expected Income", "₩\(Int(totalIncome).formatted())"),
                ("Paid", "₩\(Int(paidIncome).formatted())"),
                ("Unpaid", "₩\(Int(totalIncome - paidIncome).formatted())")
            ]

            for (label, value) in stats {
                drawText(label, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 12), color: .darkGray)
                drawText(value, at: CGPoint(x: pageWidth - margin - 100, y: y), font: .systemFont(ofSize: 12, weight: .semibold))
                y += 22
            }
        }
        return y
    }

    private func drawDaySection(in ctx: CGContext, dateKey: String, plans: [Plan], yOffset: CGFloat, pageWidth: CGFloat, margin: CGFloat, options: PDFExportOptions, ctx pdfCtx: UIGraphicsPDFRendererContext, pageHeight: CGFloat) -> CGFloat {
        var y = yOffset
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()

        let fmt = DateFormatter(); fmt.dateFormat = "EEEE, MMM d, yyyy"
        let headerText = "\(fmt.string(from: date))   ✅ \(plans.filter { $0.status == .completed }.count)/\(plans.count)"

        ctx.setFillColor(UIColor(red: 0.94, green: 0.98, blue: 0.94, alpha: 1).cgColor)
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 28), cornerRadius: 6).cgPath)
        ctx.fillPath()
        drawText(headerText, at: CGPoint(x: margin + 10, y: y + 6), font: .systemFont(ofSize: 12, weight: .semibold), color: UIColor(red: 0.10, green: 0.38, blue: 0.14, alpha: 1))
        
        y += 36
        for plan in plans {
            if y + (options.includeMemo && !plan.memo.isEmpty ? 72 : 56) > pageHeight - margin {
                pdfCtx.beginPage()
                y = margin + 10
            }
            y = drawPlanRow(plan: plan, at: y, pageWidth: pageWidth, margin: margin, options: options, in: ctx)
        }
        return y
    }

    private func drawPlanRow(plan: Plan, at yOffset: CGFloat, pageWidth: CGFloat, margin: CGFloat, options: PDFExportOptions, in ctx: CGContext) -> CGFloat {
        var y = yOffset
        let leftX = margin + 10

        let barColor = plan.isWorkSchedule ? UIColor.systemOrange : (plan.status == .completed ? .systemGreen : (plan.status == .planned ? .systemBlue : .systemGray))
        ctx.setFillColor(barColor.cgColor)
        ctx.fill(CGRect(x: margin, y: y, width: 3, height: 46))

        drawText(plan.status == .completed ? "✅" : (plan.status == .canceled ? "🚫" : "📋"), at: CGPoint(x: leftX + 6, y: y + 12), font: .systemFont(ofSize: 14))
        
        let titleColor = plan.status == .canceled ? UIColor.darkGray : .black
        drawText(plan.title, at: CGPoint(x: leftX + 28, y: y + 8), font: .systemFont(ofSize: 13, weight: .semibold), color: titleColor)

        if plan.status == .completed {
            let strSize = (plan.title as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 13, weight: .semibold)])
            let badgeX = min(leftX + 28 + strSize.width + 8, pageWidth - margin - 50)
            ctx.setFillColor(UIColor.systemGreen.withAlphaComponent(0.15).cgColor)
            ctx.fill(CGRect(x: badgeX, y: y + 9, width: 36, height: 14))
            drawText("Done", at: CGPoint(x: badgeX + 4, y: y + 10), font: .systemFont(ofSize: 9, weight: .semibold), color: .systemGreen)
        }

        if let timeStr = plan.timeDisplay {
            ctx.setFillColor(UIColor.systemBlue.withAlphaComponent(0.12).cgColor)
            ctx.fill(CGRect(x: pageWidth - margin - 114, y: y + 6, width: 106, height: 18))
            drawText("⏱ \(timeStr)", at: CGPoint(x: pageWidth - margin - 110, y: y + 8), font: .systemFont(ofSize: 10), color: .systemBlue)
        }

        if plan.isWorkSchedule {
            let incomeStr = plan.expectedIncome > 0 ? " · ₩\(Int(plan.expectedIncome).formatted())" : ""
            drawText("🔨 \(plan.workUnits)unit\(incomeStr)\(plan.isPaid ? " 💰Paid" : " ⚠️Unpaid")", at: CGPoint(x: leftX + 28, y: y + 24), font: .systemFont(ofSize: 10), color: .systemOrange)
        }

        y += 44
        if options.includeMemo && !plan.memo.isEmpty {
            drawText("  \(plan.memo)", at: CGPoint(x: leftX + 28, y: y), font: .italicSystemFont(ofSize: 10), color: .darkGray, maxWidth: pageWidth - margin * 2 - 40)
            y += 18
        }

        ctx.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin + 10, y: y))
        ctx.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        ctx.strokePath()

        return y + 8
    }

    private func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor = .black, centered: Bool = false, maxWidth: CGFloat = 500) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let str = text as NSString
        let xPos = centered ? point.x - str.size(withAttributes: attrs).width / 2 : point.x
        str.draw(in: CGRect(x: xPos, y: point.y, width: maxWidth, height: 200), withAttributes: attrs)
    }

    private func drawStatRow(label: String, value: String, color: UIColor, at point: CGPoint) {
        drawText(value, at: point, font: .systemFont(ofSize: 22, weight: .bold), color: color)
        drawText(label, at: CGPoint(x: point.x, y: point.y + 26), font: .systemFont(ofSize: 11), color: .darkGray)
    }
}
