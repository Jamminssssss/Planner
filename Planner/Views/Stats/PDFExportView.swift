import SwiftUI
import SwiftData

// MARK: - Export Tab & Modes
enum ExportTab: String, CaseIterable {
    case pdf = "PDF"
    case csv = "CSV"
    var icon: String { self == .pdf ? "doc.richtext.fill" : "tablecells.fill" }
}

enum CSVMode: String, CaseIterable {
    case allPlans  = "All Plans"
    case workMonth = "Work Monthly"
    var icon: String { self == .allPlans ? "list.bullet.rectangle" : "hammer.fill" }
    var description: String { self == .allPlans ? "Export plans with full details" : "Monthly work schedule & income" }
}

struct PDFExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Query private var allPlans: [Plan]

    @State private var selectedTab: ExportTab = .pdf
    @State private var options = PDFExportOptions()

    @State private var isGeneratingPDF = false
    @State private var generatedPDF:   Data? = nil
    @State private var showPDFShare    = false

    @State private var csvMode: CSVMode = .allPlans
    @State private var isGeneratingCSV = false
    @State private var generatedCSV:   Data? = nil
    @State private var showCSVShare    = false
    
    @State private var workMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    private var previewCount: Int {
        let cal = Calendar.current; let now = Date()
        let dateFiltered: [Plan]
        switch options.range {
        case .today:
            let c = cal.dateComponents([.year, .month, .day], from: now)
            dateFiltered = allPlans.filter { $0.year == c.year && $0.month == c.month && $0.day == c.day }
        case .thisWeek:
            guard let ws = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
            let we = cal.date(byAdding: .day, value: 7, to: ws) ?? now
            dateFiltered = allPlans.filter { $0.scheduledDateOnly >= ws && $0.scheduledDateOnly < we }
        case .thisMonth:
            let c = cal.dateComponents([.year, .month], from: now)
            dateFiltered = allPlans.filter { $0.year == c.year && $0.month == c.month }
        case .allTime:
            dateFiltered = allPlans
        }
        return dateFiltered.filter { plan in
            if plan.isWorkSchedule && !options.includeWorkSchedule { return false }
            switch plan.status {
            case .completed: return options.includeCompleted
            case .planned:   return options.includePlanned
            case .canceled:  return options.includeCanceled
            }
        }.count
    }

    private var workMonthPlans: [Plan] {
        let y = Calendar.current.component(.year, from: workMonth)
        let m = Calendar.current.component(.month, from: workMonth)
        return allPlans.filter { $0.isWorkSchedule && $0.year == y && $0.month == m }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabSwitcher.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        if selectedTab == .pdf { pdfContent } else { csvContent }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20).padding(.top, 12)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Export").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(.secondary) } }
            .fullScreenCover(isPresented: $showPDFShare) { if let pdf = generatedPDF { PDFShareSheet(pdfData: pdf, fileName: pdfFileName()) } }
            .fullScreenCover(isPresented: $showCSVShare) { if let csv = generatedCSV { CSVShareSheet(csvData: csv, fileName: csvFileName()) } }
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(ExportTab.allCases, id: \.self) { tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon).font(.system(size: 14))
                        Text(tab.rawValue).font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(selectedTab == tab ? (tab == .pdf ? Color.green : Color.blue) : Color.clear)
                    .cornerRadius(10)
                }.buttonStyle(.plain)
            }
        }
        .padding(4).background(Color.secondary.opacity(0.10)).cornerRadius(12)
    }

    private var pdfContent: some View {
        VStack(spacing: 20) {
            headerCard(icon: "doc.richtext.fill", iconColor: .green, title: "PDF Report", subtitle: "Formatted report with cover page & statistics", count: previewCount, countColor: .green)
            rangeSection
            contentSection
            actionButton(label: isGeneratingPDF ? "Generating..." : (previewCount == 0 ? "No Plans" : "Generate & Share PDF"), icon: "square.and.arrow.up", color: .green, isLoading: isGeneratingPDF, disabled: isGeneratingPDF || previewCount == 0, action: generatePDF)
        }
    }

    private var csvContent: some View {
        VStack(spacing: 20) {
            headerCard(icon: "tablecells.fill", iconColor: .blue, title: "CSV Spreadsheet", subtitle: "Open in Google Sheets, Excel, or Numbers", count: csvMode == .workMonth ? workMonthPlans.count : previewCount, countColor: .blue)
            sheetsGuideCard
            csvModeSection
            if csvMode == .workMonth { workMonthSection } else { rangeSection; contentSection }
            actionButton(label: isGeneratingCSV ? "Generating..." : "Export CSV for Google Sheets", icon: "arrow.up.doc.fill", color: .blue, isLoading: isGeneratingCSV, disabled: isGeneratingCSV, action: generateCSV)
        }
    }

    private func headerCard(icon: String, iconColor: Color, title: String, subtitle: String, count: Int, countColor: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: icon).font(.system(size: 24)).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 17, weight: .semibold))
                Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "doc.text").font(.system(size: 11)).foregroundColor(countColor)
                    Text("\(count) plan\(count == 1 ? "" : "s")").font(.system(size: 12, weight: .medium)).foregroundColor(countColor)
                }
                .padding(.horizontal, 10).padding(.vertical, 4).background(countColor.opacity(0.10)).cornerRadius(8).padding(.top, 2)
            }
            Spacer()
        }
        .padding(16).background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var sheetsGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) { Image(systemName: "info.circle.fill").foregroundColor(.blue); Text("How to open in Google Sheets").font(.system(size: 13, weight: .semibold)).foregroundColor(.blue) }
            VStack(alignment: .leading, spacing: 6) {
                guideStep("1", "Tap [Export CSV] → tap Share"); guideStep("2", "Save to Files or send via email/AirDrop"); guideStep("3", "Google Sheets → New → Import → Upload .csv"); guideStep("4", "Select [Replace spreadsheet] → Import data ✅")
            }
        }.padding(14).background(Color.blue.opacity(0.06)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.20), lineWidth: 1))
    }

    private func guideStep(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) { Text(num).font(.system(size: 11, weight: .bold)).foregroundColor(.white).frame(width: 18, height: 18).background(Color.blue).cornerRadius(9); Text(text).font(.system(size: 12)).foregroundColor(.secondary) }
    }

    private var csvModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Export Type")
            HStack(spacing: 10) {
                ForEach(CSVMode.allCases, id: \.self) { mode in
                    Button(action: { csvMode = mode }) {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon).font(.system(size: 20)).foregroundColor(csvMode == mode ? .white : .blue)
                            Text(mode.rawValue).font(.system(size: 12, weight: .semibold)).foregroundColor(csvMode == mode ? .white : .primary)
                            Text(mode.description).font(.system(size: 10)).foregroundColor(csvMode == mode ? .white.opacity(0.85) : .secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14).padding(.horizontal, 8)
                        .background(csvMode == mode ? Color.blue : Color.secondary.opacity(0.07)).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(csvMode == mode ? Color.blue : Color.clear, lineWidth: 2))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(16).background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var workMonthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Month")
            HStack {
                Button(action: { workMonth = Calendar.current.date(byAdding: .month, value: -1, to: workMonth) ?? workMonth }) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.blue).frame(width: 36, height: 36).background(Color.blue.opacity(0.10)).cornerRadius(10)
                }.buttonStyle(.plain)
                Spacer()
                Text(workMonthTitle).font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { workMonth = Calendar.current.date(byAdding: .month, value: 1, to: workMonth) ?? workMonth }) {
                    Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold)).foregroundColor(.blue).frame(width: 36, height: 36).background(Color.blue.opacity(0.10)).cornerRadius(10)
                }.buttonStyle(.plain)
            }
            let wPlans = workMonthPlans
            if wPlans.isEmpty {
                Text("No work schedules for this month.").font(.system(size: 13)).foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
            } else {
                let totalIncome = wPlans.reduce(0.0) { $0 + $1.expectedIncome }
                let unpaid = wPlans.filter { !$0.isPaid }.reduce(0.0) { $0 + $1.expectedIncome }
                HStack(spacing: 12) {
                    miniStat(label: "Days",   value: "\(wPlans.count)",                    color: .blue)
                    miniStat(label: "Income", value: "₩\(Int(totalIncome).formatted())",   color: .green)
                    miniStat(label: "Unpaid", value: "₩\(Int(unpaid).formatted())",        color: unpaid > 0 ? .red : .secondary)
                }
            }
        }.padding(16).background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func miniStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) { Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.7); Text(label).font(.system(size: 11)).foregroundColor(.secondary) }
        .frame(maxWidth: .infinity).padding(.vertical, 8).background(color.opacity(0.08)).cornerRadius(8)
    }

    private var rangeSection: some View {
        let accent: Color = selectedTab == .pdf ? .green : .blue
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Date Range")
            VStack(spacing: 8) {
                ForEach(PDFExportRange.allCases, id: \.self) { range in
                    Button(action: { options.range = range }) {
                        HStack(spacing: 14) {
                            Image(systemName: range.systemImage).font(.system(size: 17)).foregroundColor(options.range == range ? accent : .secondary).frame(width: 24)
                            Text(range.rawValue).font(.system(size: 15)).foregroundColor(.primary)
                            Spacer()
                            if options.range == range { Image(systemName: "checkmark.circle.fill").foregroundColor(accent) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12).background(options.range == range ? accent.opacity(0.08) : Color.secondary.opacity(0.05)).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(options.range == range ? accent.opacity(0.4) : Color.clear, lineWidth: 1.5))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(16).background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var contentSection: some View {
        let accent: Color = selectedTab == .pdf ? .green : .blue
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Include")
            VStack(spacing: 0) {
                toggleRow(icon: "checkmark.circle.fill", iconColor: .green, label: "Completed Plans", isOn: $options.includeCompleted, accent: accent); Divider().padding(.leading, 52)
                toggleRow(icon: "clock.fill", iconColor: .blue, label: "Planned (Upcoming)", isOn: $options.includePlanned, accent: accent); Divider().padding(.leading, 52)
                toggleRow(icon: "xmark.circle.fill", iconColor: .red, label: "Canceled Plans", isOn: $options.includeCanceled, accent: accent); Divider().padding(.leading, 52)
                toggleRow(icon: "hammer.fill", iconColor: .orange, label: "Work Schedule", isOn: $options.includeWorkSchedule, accent: accent); Divider().padding(.leading, 52)
                toggleRow(icon: "text.alignleft", iconColor: .gray, label: "Memo / Notes", isOn: $options.includeMemo, accent: accent)
                if selectedTab == .pdf { Divider().padding(.leading, 52); toggleRow(icon: "chart.bar.fill", iconColor: .purple, label: "Statistics Summary", isOn: $options.includeStats, accent: accent) }
            }
        }.padding(16).background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func toggleRow(icon: String, iconColor: Color, label: String, isOn: Binding<Bool>, accent: Color) -> some View {
        HStack(spacing: 14) { Image(systemName: icon).font(.system(size: 17)).foregroundColor(iconColor).frame(width: 24); Text(label).font(.system(size: 15)).foregroundColor(.primary); Spacer(); Toggle("", isOn: isOn).tint(accent).labelsHidden() }.padding(.vertical, 12)
    }

    private func actionButton(label: String, icon: String, color: Color, isLoading: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading { ProgressView().progressViewStyle(.circular).tint(.white) } else { Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(.white) }
                Text(label).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity).frame(height: 56)
            .background { if disabled { Color.secondary } else { LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing) } }.cornerRadius(14)
        }.disabled(disabled).buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View { Text(text.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary).padding(.leading, 4) }
    private var workMonthTitle: String { let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "en_US"); return f.string(from: workMonth) }
    private func pdfFileName() -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return "GrassPlanner_\(options.range.rawValue.replacingOccurrences(of: " ", with: "_"))_\(f.string(from: Date())).pdf" }
    private func csvFileName() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        if csvMode == .workMonth { let mf = DateFormatter(); mf.dateFormat = "yyyy-MM"; return "GrassPlanner_Work_\(mf.string(from: workMonth)).csv" }
        return "GrassPlanner_\(options.range.rawValue.replacingOccurrences(of: " ", with: "_"))_\(f.string(from: Date())).csv"
    }

    // 💡 최적화: 메인 스레드 블로킹 방지 및 "Generating..." UI 노출을 위한 스레드 양보(Yield) 처리
    private func generatePDF() {
        isGeneratingPDF = true
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            let pdf = PDFExportService.shared.generatePDF(plans: allPlans, options: options)
            await MainActor.run { generatedPDF = pdf; isGeneratingPDF = false; showPDFShare = true }
        }
    }

    private func generateCSV() {
        isGeneratingCSV = true
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            let cal = Calendar.current; let csvString: String
            if csvMode == .workMonth {
                let y = cal.component(.year, from: workMonth); let m = cal.component(.month, from: workMonth)
                csvString = CSVExportService.shared.generateWorkCSV(plans: allPlans, year: y, month: m)
            } else { csvString = CSVExportService.shared.generateCSV(plans: allPlans, options: options) }
            await MainActor.run { generatedCSV = csvString.data(using: .utf8); isGeneratingCSV = false; showCSVShare = true }
        }
    }
}

struct PDFShareSheet: UIViewControllerRepresentable {
    let pdfData: Data; let fileName: String
    func makeUIViewController(context: Context) -> UIActivityViewController { let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName); try? pdfData.write(to: url); return UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct CSVShareSheet: UIViewControllerRepresentable {
    let csvData: Data; let fileName: String
    func makeUIViewController(context: Context) -> UIActivityViewController { let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName); try? csvData.write(to: url); return UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
