import UIKit
import SwiftData
import SwiftUI

// MARK: - PDF Export Range

enum PDFExportRange: String, CaseIterable {
    case today      = "Today"
    case thisWeek   = "This Week"
    case thisMonth  = "This Month"
    case allTime    = "All Plans"

    var systemImage: String {
        switch self {
        case .today:     return "calendar.circle"
        case .thisWeek:  return "calendar.badge.clock"
        case .thisMonth: return "calendar"
        case .allTime:   return "archivebox"
        }
    }
}

// MARK: - PDF Export Options

struct PDFExportOptions {
    var range: PDFExportRange = .thisMonth
    var includeWorkSchedule: Bool = true
    var includeCompleted: Bool = true
    var includePlanned: Bool = true
    var includeCanceled: Bool = false
    var includeMemo: Bool = true
    var includeStats: Bool = true
}

// MARK: - PDF Export Service

@MainActor
final class PDFExportService {

    static let shared = PDFExportService()
    private init() {}

    // MARK: - Public Entry Point

    func generatePDF(plans: [Plan], options: PDFExportOptions) -> Data {
        let filtered = filterPlans(plans, options: options)
        let grouped  = groupByDate(filtered)

        let pageWidth:  CGFloat = 595.2   // A4
        let pageHeight: CGFloat = 841.8
        let margin:     CGFloat = 40

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String:   "GrassPlanner – Export",
            kCGPDFContextAuthor as String:  "GrassPlanner",
            kCGPDFContextCreator as String: "GrassPlanner App"
        ]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        let data = renderer.pdfData { ctx in
            var yOffset: CGFloat = margin

            // ── Cover page ──
            ctx.beginPage()
            yOffset = drawCover(
                in: ctx.cgContext,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                margin: margin,
                plans: filtered,
                options: options
            )

            // ── Stats summary page ──
            if options.includeStats && !filtered.isEmpty {
                ctx.beginPage()
                yOffset = drawStatsSummary(
                    in: ctx.cgContext,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    margin: margin,
                    plans: filtered,
                    options: options
                )
            }

            // ── Daily plan pages ──
            ctx.beginPage()
            yOffset = margin + 10

            for (dateKey, dayPlans) in grouped {
                let estimatedHeight = CGFloat(dayPlans.count) * 90 + 60
                if yOffset + estimatedHeight > pageHeight - margin {
                    ctx.beginPage()
                    yOffset = margin + 10
                }
                yOffset = drawDaySection(
                    in: ctx.cgContext,
                    dateKey: dateKey,
                    plans: dayPlans,
                    yOffset: yOffset,
                    pageWidth: pageWidth,
                    margin: margin,
                    options: options,
                    ctx: ctx,
                    pageHeight: pageHeight
                )
                yOffset += 16
            }
        }

        return data
    }

    // MARK: - Filter & Group

    private func filterPlans(_ plans: [Plan], options: PDFExportOptions) -> [Plan] {
        let cal = Calendar.current
        let now = Date()

        let dateFiltered: [Plan]
        switch options.range {
        case .today:
            let c = cal.dateComponents([.year, .month, .day], from: now)
            dateFiltered = plans.filter {
                $0.year == c.year && $0.month == c.month && $0.day == c.day
            }
        case .thisWeek:
            guard let ws = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
            let we = cal.date(byAdding: .day, value: 7, to: ws) ?? now
            dateFiltered = plans.filter {
                let d = $0.scheduledDateOnly; return d >= ws && d < we
            }
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

    private func groupByDate(_ plans: [Plan]) -> [(key: String, value: [Plan])] {
        var dict: [String: [Plan]] = [:]
        for plan in plans {
            let key = String(format: "%04d-%02d-%02d", plan.year, plan.month, plan.day)
            dict[key, default: []].append(plan)
        }
        return dict
            .sorted { $0.key < $1.key }
            .map { (key: $0.key, value: $0.value.sorted { $0.scheduledDate < $1.scheduledDate }) }
    }

    // MARK: - Draw Cover

    private func drawCover(
        in ctx: CGContext,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        plans: [Plan],
        options: PDFExportOptions
    ) -> CGFloat {

        // Background gradient rectangle
        let gradColors = [
            UIColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1).cgColor,
            UIColor(red: 0.10, green: 0.38, blue: 0.14, alpha: 1).cgColor
        ]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradColors as CFArray,
            locations: [0, 1]
        )!
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: pageWidth / 2, y: 0),
            end:   CGPoint(x: pageWidth / 2, y: pageHeight * 0.42),
            options: []
        )

        var y: CGFloat = 80

        // App icon placeholder circle
        let circleR: CGFloat = 44
        let cx = pageWidth / 2
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - circleR, y: y, width: circleR * 2, height: circleR * 2))
        drawText("🌱", at: CGPoint(x: cx, y: y + 22), font: .systemFont(ofSize: 44), color: .white, centered: true, in: ctx)
        y += circleR * 2 + 20

        // Title
        drawText(
            "GrassPlanner",
            at: CGPoint(x: cx, y: y),
            font: .systemFont(ofSize: 32, weight: .bold),
            color: .white,
            centered: true,
            in: ctx
        )
        y += 42

        // Subtitle
        drawText(
            "Plan Export Report",
            at: CGPoint(x: cx, y: y),
            font: .systemFont(ofSize: 16, weight: .medium),
            color: UIColor.white.withAlphaComponent(0.85),
            centered: true,
            in: ctx
        )
        y += 30

        // Date range label
        drawText(
            options.range.rawValue,
            at: CGPoint(x: cx, y: y),
            font: .systemFont(ofSize: 13),
            color: UIColor.white.withAlphaComponent(0.70),
            centered: true,
            in: ctx
        )
        y += 60

        // White card area
        let cardY = pageHeight * 0.42 + 30
        ctx.setFillColor(UIColor.white.cgColor)
        let cardRect = CGRect(x: margin, y: cardY, width: pageWidth - margin * 2, height: 260)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 12)
        ctx.addPath(cardPath.cgPath)
        ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 10,
                      color: UIColor.black.withAlphaComponent(0.08).cgColor)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // Stats inside card
        let completed = plans.filter { $0.status == .completed }.count
        let planned   = plans.filter { $0.status == .planned }.count
        let workCount = plans.filter { $0.isWorkSchedule }.count
        let rate = plans.isEmpty ? 0 : Int(Double(completed) / Double(plans.count) * 100)

        let cardPadding: CGFloat = 24
        var cardY2 = cardY + 24

        drawText("Summary", at: CGPoint(x: margin + cardPadding, y: cardY2),
                 font: .systemFont(ofSize: 15, weight: .semibold),
                 color: UIColor(red: 0.1, green: 0.38, blue: 0.14, alpha: 1), in: ctx)
        cardY2 += 32

        let cols: [(label: String, value: String, color: UIColor)] = [
            ("Total Plans",  "\(plans.count)",  .darkGray),
            ("Completed",    "\(completed)",     UIColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1)),
            ("Planned",      "\(planned)",       UIColor(red: 0.20, green: 0.40, blue: 0.80, alpha: 1)),
            ("Work Days",    "\(workCount)",     UIColor(red: 0.85, green: 0.45, blue: 0.10, alpha: 1)),
            ("Completion",   "\(rate)%",         UIColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1))
        ]

        let colW = (pageWidth - margin * 2 - cardPadding * 2) / 2
        for (i, col) in cols.enumerated() {
            let xPos = margin + cardPadding + (i % 2 == 0 ? 0 : colW)
            if i % 2 == 0 && i > 0 { cardY2 += 42 }
            drawStatRow(label: col.label, value: col.value, color: col.color,
                        at: CGPoint(x: xPos, y: cardY2), width: colW, in: ctx)
        }

        // Generated date footer
        let fmt = DateFormatter(); fmt.dateStyle = .long; fmt.timeStyle = .short
        let genText = "Generated: \(fmt.string(from: Date()))"
        drawText(genText,
                 at: CGPoint(x: cx, y: pageHeight - margin - 20),
                 font: .systemFont(ofSize: 10),
                 color: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1),
                 centered: true, in: ctx)

        return pageHeight
    }

    // MARK: - Draw Stats Summary

    private func drawStatsSummary(
        in ctx: CGContext,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        plans: [Plan],
        options: PDFExportOptions
    ) -> CGFloat {

        var y: CGFloat = margin

        // Page title
        drawSectionHeader("📊  Statistics", at: CGPoint(x: margin, y: y),
                          pageWidth: pageWidth, margin: margin, in: ctx)
        y += 40

        // Category breakdown
        var catDict: [String: (color: UIColor, total: Int, done: Int)] = [:]
        for plan in plans {
            let name  = plan.category?.name ?? "Uncategorized"
            let color = plan.category.flatMap { UIColor(cgColor: $0.color.cgColor!) } ?? .gray
            var existing = catDict[name] ?? (color: color, total: 0, done: 0)
            existing.total += 1
            if plan.status == .completed { existing.done += 1 }
            catDict[name] = existing
        }

        if !catDict.isEmpty {
            drawText("By Category", at: CGPoint(x: margin, y: y),
                     font: .systemFont(ofSize: 13, weight: .semibold),
                     color: UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1), in: ctx)
            y += 22

            let barMaxW = pageWidth - margin * 2 - 120
            for (name, stat) in catDict.sorted(by: { $0.value.total > $1.value.total }) {
                let progress = stat.total > 0 ? CGFloat(stat.done) / CGFloat(stat.total) : 0

                // Category dot + name
                ctx.setFillColor(stat.color.cgColor)
                ctx.fillEllipse(in: CGRect(x: margin, y: y + 4, width: 8, height: 8))
                drawText(name, at: CGPoint(x: margin + 14, y: y),
                         font: .systemFont(ofSize: 12), color: UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1), in: ctx)

                // Count label
                drawText("\(stat.done)/\(stat.total)",
                         at: CGPoint(x: pageWidth - margin - 50, y: y),
                         font: .systemFont(ofSize: 11), color: UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1), in: ctx)

                y += 18
                // Progress bar
                ctx.setFillColor(UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1).cgColor)
                ctx.fill(CGRect(x: margin, y: y, width: barMaxW, height: 6))
                ctx.setFillColor(stat.color.cgColor)
                ctx.fill(CGRect(x: margin, y: y, width: barMaxW * progress, height: 6))
                y += 18
            }
        }

        // Work summary
        let workPlans = plans.filter { $0.isWorkSchedule }
        if options.includeWorkSchedule && !workPlans.isEmpty {
            y += 12
            drawSectionDivider(at: y, pageWidth: pageWidth, margin: margin, in: ctx)
            y += 14

            drawText("💼  Work Summary", at: CGPoint(x: margin, y: y),
                     font: .systemFont(ofSize: 13, weight: .semibold), color: UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1), in: ctx)
            y += 24

            let totalUnits  = workPlans.reduce(0.0) { $0 + $1.workUnits }
            let totalIncome = workPlans.reduce(0.0) { $0 + $1.expectedIncome }
            let paidIncome  = workPlans.filter { $0.isPaid }.reduce(0.0) { $0 + $1.expectedIncome }
            let unpaid      = totalIncome - paidIncome

            let workStats: [(String, String)] = [
                ("Work Days",        "\(workPlans.count)"),
                ("Total Units",      String(format: "%.1f", totalUnits)),
                ("Expected Income",  "₩\(Int(totalIncome).formatted())"),
                ("Paid",             "₩\(Int(paidIncome).formatted())"),
                ("Unpaid",           "₩\(Int(unpaid).formatted())")
            ]

            for (label, value) in workStats {
                drawKeyValue(label: label, value: value,
                             at: CGPoint(x: margin, y: y),
                             pageWidth: pageWidth, margin: margin, in: ctx)
                y += 22
            }
        }

        return y
    }

    // MARK: - Draw Day Section

    private func drawDaySection(
        in ctx: CGContext,
        dateKey: String,
        plans: [Plan],
        yOffset: CGFloat,
        pageWidth: CGFloat,
        margin: CGFloat,
        options: PDFExportOptions,
        ctx pdfCtx: UIGraphicsPDFRendererContext,
        pageHeight: CGFloat
    ) -> CGFloat {

        var y = yOffset

        // Date header bar
        let parts = dateKey.split(separator: "-").map { Int($0) ?? 0 }
        let (yr, mo, day) = (parts[0], parts[1], parts[2])
        var comps = DateComponents(); comps.year = yr; comps.month = mo; comps.day = day
        let date = Calendar.current.date(from: comps) ?? Date()

        let fmt = DateFormatter(); fmt.dateFormat = "EEEE, MMM d, yyyy"
        let dateStr = fmt.string(from: date)

        let completedCount = plans.filter { $0.status == .completed }.count
        let headerText = "\(dateStr)   ✅ \(completedCount)/\(plans.count)"

        // Header background
        ctx.setFillColor(UIColor(red: 0.94, green: 0.98, blue: 0.94, alpha: 1).cgColor)
        let headerRect = CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 28)
        let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 6)
        ctx.addPath(headerPath.cgPath)
        ctx.fillPath()

        drawText(headerText,
                 at: CGPoint(x: margin + 10, y: y + 6),
                 font: .systemFont(ofSize: 12, weight: .semibold),
                 color: UIColor(red: 0.10, green: 0.38, blue: 0.14, alpha: 1),
                 in: ctx)
        y += 36

        // Plan rows
        for plan in plans {
            // Check if new page needed
            let rowH: CGFloat = options.includeMemo && !plan.memo.isEmpty ? 72 : 56
            if y + rowH > pageHeight - margin {
                pdfCtx.beginPage()
                y = margin + 10
            }

            y = drawPlanRow(plan: plan, at: y, pageWidth: pageWidth,
                            margin: margin, options: options, in: ctx)
        }

        return y
    }

    // MARK: - Draw Plan Row

    private func drawPlanRow(
        plan: Plan,
        at yOffset: CGFloat,
        pageWidth: CGFloat,
        margin: CGFloat,
        options: PDFExportOptions,
        in ctx: CGContext
    ) -> CGFloat {

        var y = yOffset
        let rowPad: CGFloat = 10
        let leftX  = margin + rowPad

        // Status color bar
        let barColor: UIColor
        switch plan.status {
        case .completed: barColor = UIColor(red: 0.18, green: 0.65, blue: 0.25, alpha: 1)
        case .planned:   barColor = UIColor(red: 0.25, green: 0.45, blue: 0.85, alpha: 1)
        case .canceled:  barColor = UIColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1)
        }

        if plan.isWorkSchedule {
            ctx.setFillColor(UIColor(red: 0.95, green: 0.60, blue: 0.20, alpha: 1).cgColor)
        } else {
            ctx.setFillColor(barColor.cgColor)
        }
        ctx.fill(CGRect(x: margin, y: y, width: 3, height: 46))

        // Status icon
        let statusIcon = plan.status == .completed ? "✅" :
                         plan.status == .canceled  ? "🚫" : "📋"
        drawText(statusIcon, at: CGPoint(x: leftX + 6, y: y + 12),
                 font: .systemFont(ofSize: 14), color: UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1), in: ctx)

        // Title — 모든 상태에서 진한 색 (취소선 제거, PDF 가시성 확보)
        let titleX = leftX + 28
        let titleColor: UIColor
        switch plan.status {
        case .completed: titleColor = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        case .planned:   titleColor = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        case .canceled:  titleColor = UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1)
        }
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font:            UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: titleColor
        ]
        let titleStr = NSAttributedString(string: plan.title, attributes: titleAttr)
        titleStr.draw(at: CGPoint(x: titleX, y: y + 8))

        // 완료 항목 — 취소선 대신 초록 "Done" 배지로 표시
        if plan.status == .completed {
            let badgeColor = UIColor(red: 0.18, green: 0.65, blue: 0.25, alpha: 1)
            let titleSize  = (plan.title as NSString).size(withAttributes: titleAttr)
            let badgeX     = min(titleX + titleSize.width + 8, pageWidth - margin - 50)
            ctx.setFillColor(badgeColor.withAlphaComponent(0.15).cgColor)
            ctx.fill(CGRect(x: badgeX, y: y + 9, width: 36, height: 14))
            drawText("Done", at: CGPoint(x: badgeX + 4, y: y + 10),
                     font: .systemFont(ofSize: 9, weight: .semibold), color: badgeColor, in: ctx)
        }

        // Time badge
        if let timeStr = plan.timeDisplay {
            let timeBadgeX = pageWidth - margin - 110
            let blueColor  = UIColor(red: 0.20, green: 0.45, blue: 0.85, alpha: 1)
            ctx.setFillColor(blueColor.withAlphaComponent(0.12).cgColor)
            ctx.fill(CGRect(x: timeBadgeX - 4, y: y + 6, width: 106, height: 18))
            drawText("⏱ \(timeStr)", at: CGPoint(x: timeBadgeX, y: y + 8),
                     font: .systemFont(ofSize: 10), color: blueColor, in: ctx)
        }

        // Category badge
        if let cat = plan.category {
            let catColor = UIColor(cgColor: cat.color.cgColor ?? UIColor.gray.cgColor)
            drawText("[\(cat.name)]", at: CGPoint(x: titleX, y: y + 24),
                     font: .systemFont(ofSize: 10), color: catColor, in: ctx)
        }

        // Work info
        if plan.isWorkSchedule {
            let workInfoX = plan.category != nil ? titleX + 80 : titleX
            let incomeStr = plan.expectedIncome > 0 ? " · ₩\(Int(plan.expectedIncome).formatted())" : ""
            let paidBadge = plan.isPaid ? " 💰Paid" : " ⚠️Unpaid"
            drawText("🔨 \(plan.workUnits)unit\(incomeStr)\(paidBadge)",
                     at: CGPoint(x: workInfoX, y: y + 24),
                     font: .systemFont(ofSize: 10),
                     color: UIColor(red: 0.80, green: 0.40, blue: 0.10, alpha: 1),
                     in: ctx)
        }

        y += 44

        // Memo
        if options.includeMemo && !plan.memo.isEmpty {
            drawText("  \(plan.memo)",
                     at: CGPoint(x: leftX + 28, y: y),
                     font: .italicSystemFont(ofSize: 10),
                     color: UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1),
                     maxWidth: pageWidth - margin * 2 - 40,
                     in: ctx)
            y += 18
        }

        // Separator
        ctx.setStrokeColor(UIColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin + 10, y: y))
        ctx.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        ctx.strokePath()

        return y + 8
    }

    // MARK: - Draw Helpers

    private func drawText(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1),
        centered: Bool = false,
        maxWidth: CGFloat = 500,
        in ctx: CGContext
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color
        ]
        let str = text as NSString
        if centered {
            let size = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: point.x - size.width / 2, y: point.y), withAttributes: attrs)
        } else {
            let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: 200)
            str.draw(in: rect, withAttributes: attrs)
        }
    }

    private func drawSectionHeader(
        _ title: String,
        at point: CGPoint,
        pageWidth: CGFloat,
        margin: CGFloat,
        in ctx: CGContext
    ) {
        ctx.setFillColor(UIColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1).cgColor)
        ctx.fill(CGRect(x: margin, y: point.y, width: pageWidth - margin * 2, height: 32))
        drawText(title, at: CGPoint(x: margin + 12, y: point.y + 8),
                 font: .systemFont(ofSize: 14, weight: .bold), color: .white, in: ctx)
    }

    private func drawSectionDivider(at y: CGFloat, pageWidth: CGFloat, margin: CGFloat, in ctx: CGContext) {
        ctx.setStrokeColor(UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        ctx.strokePath()
    }

    private func drawStatRow(
        label: String, value: String, color: UIColor,
        at point: CGPoint, width: CGFloat, in ctx: CGContext
    ) {
        drawText(value, at: point, font: .systemFont(ofSize: 22, weight: .bold), color: color, in: ctx)
        drawText(label, at: CGPoint(x: point.x, y: point.y + 26),
                 font: .systemFont(ofSize: 11), color: UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1), in: ctx)
    }

    private func drawKeyValue(
        label: String, value: String,
        at point: CGPoint, pageWidth: CGFloat, margin: CGFloat, in ctx: CGContext
    ) {
        drawText(label, at: point, font: .systemFont(ofSize: 12), color: UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1), in: ctx)
        drawText(value,
                 at: CGPoint(x: pageWidth - margin - 100, y: point.y),
                 font: .systemFont(ofSize: 12, weight: .semibold), color: UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1), in: ctx)
    }
}

// MARK: - UIColor CGColor Helper

private extension UIColor {
    convenience init?(cgColor: CGColor?) {
        guard let cgColor = cgColor else { return nil }
        self.init(cgColor: cgColor)
    }
}
