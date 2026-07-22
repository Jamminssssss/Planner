import SwiftUI
import SwiftData
import UserNotifications

struct AddPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared

    // MARK: - Common State
    @State private var selectedDate: Date
    @State private var hasTime: Bool = false
    @State private var startTime: Date
    @State private var hasEndTime: Bool = false
    @State private var endTime: Date

    // MARK: - Mode toggle
    @State private var isWorkSchedule: Bool = false

    // MARK: - General plan
    @State private var title: String = ""
    @State private var memo: String  = ""
    @State private var selectedCategory: Category? = nil
    @State private var notificationEnabled: Bool   = false
    @State private var notificationSound: NotificationSound = .sound
    @State private var calendarSyncEnabled: Bool   = false

    // MARK: - Work schedule (글로벌 스탠다드 입력 방식으로 변경)
    // 💡 불필요한 버튼 옵션(WorkUnitsOption)을 제거하고 범용 텍스트 필드로 통합
    @State private var customWorkUnits: String = ""
    @State private var dailyWageText: String   = ""
    @State private var siteName: String        = ""
    @State private var isPaid: Bool            = false

    // MARK: - UI
    @State private var showCategoryPicker  = false
    @State private var showValidationAlert = false
    @State private var showPermissionAlert = false
    @State private var showPaywall         = false

    @Query(sort: \Category.createdAt) private var categories: [Category]

    // 💡 최적화: 달력에서 선택한 날짜를 완벽하게 TimePicker와 동기화
    init(selectedDate: Date = Date()) {
        _selectedDate = State(initialValue: selectedDate)
        
        let cal = Calendar.current
        let now = Date()
        var sc = cal.dateComponents([.year, .month, .day, .hour], from: now)
        sc.year = cal.component(.year, from: selectedDate)
        sc.month = cal.component(.month, from: selectedDate)
        sc.day = cal.component(.day, from: selectedDate)
        sc.minute = 0
        
        let start = cal.date(from: sc) ?? selectedDate
        _startTime = State(initialValue: start)
        
        var ec = sc
        ec.hour = (sc.hour ?? 8) + 8
        let end = cal.date(from: ec) ?? selectedDate
        _endTime = State(initialValue: end)
    }

    // MARK: - Computed Properties
    private var dateComponents: (year: Int, month: Int, day: Int) {
        let cal = Calendar.current
        return (cal.component(.year, from: selectedDate),
                cal.component(.month, from: selectedDate),
                cal.component(.day, from: selectedDate))
    }
    
    private func timeComps(_ d: Date) -> (hour: Int, minute: Int) {
        (Calendar.current.component(.hour, from: d), Calendar.current.component(.minute, from: d))
    }
    
    private var isFutureDate: Bool {
        Calendar.current.startOfDay(for: selectedDate) > Calendar.current.startOfDay(for: Date())
    }
    
    private var canEnableCalendarSync: Bool {
        guard hasTime else { return true }
        let cal = Calendar.current
        let now = Date()

        if hasEndTime {
            let startH = cal.component(.hour, from: startTime)
            let endH   = cal.component(.hour, from: endTime)
            let endM   = cal.component(.minute, from: endTime)

            var ec = cal.dateComponents([.year, .month, .day], from: selectedDate)
            ec.hour = endH; ec.minute = endM
            guard var endDate = cal.date(from: ec) else { return false }

            if endH < startH || (endH == startH && endM <= cal.component(.minute, from: startTime)) {
                endDate = cal.date(byAdding: .day, value: 1, to: endDate) ?? endDate
            }
            return endDate > now
        } else {
            var sc = cal.dateComponents([.year, .month, .day], from: selectedDate)
            sc.hour = cal.component(.hour, from: startTime)
            sc.minute = cal.component(.minute, from: startTime)
            guard let startDate = cal.date(from: sc) else { return false }
            return startDate > now
        }
    }
    
    // 수량/시간 입력값이 없으면 기본값 1.0으로 처리
    private var resolvedWorkUnits: Double {
        Double(customWorkUnits) ?? 1.0
    }
    
    private var resolvedDailyWage: Int {
        Int(dailyWageText.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    
    private var previewIncome: Double { resolvedWorkUnits * Double(resolvedDailyWage) }

    private var canSave: Bool {
        isWorkSchedule
            ? (!siteName.trimmingCharacters(in: .whitespaces).isEmpty || resolvedDailyWage > 0)
            : !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                workToggleSection

                if isWorkSchedule {
                    dateTimeSection
                    workFieldsSection
                    workCalendarSection
                } else {
                    if !categories.isEmpty { categorySection }
                    titleMemoSection
                    dateTimeSection
                    notificationSection
                }
            }
            .navigationTitle(isWorkSchedule ? String(localized: "work.add.nav.title", defaultValue: "New Work Schedule") : "New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { savePlan() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(canSave ? (isWorkSchedule ? .orange : .green) : .secondary)
                        .disabled(!canSave)
                }
            }
            .alert("Missing Title", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: { Text("Please enter a plan title.") }
            .alert("Notification Permission", isPresented: $showPermissionAlert) {
                Button("Go to Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Please allow notifications in Settings.") }
            .fullScreenCover(isPresented: $showPaywall) { PurchaseView() }
            .animation(.easeInOut(duration: 0.22), value: isWorkSchedule)
            .animation(.easeInOut(duration: 0.18), value: hasTime)
            .animation(.easeInOut(duration: 0.18), value: hasEndTime)
            .animation(.easeInOut(duration: 0.18), value: calendarSyncEnabled)
        }
    }

    // MARK: - UI Components
    
    private var workToggleSection: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isWorkSchedule ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isWorkSchedule ? .orange : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "work.toggle.title", defaultValue: "Work Schedule"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isWorkSchedule ? .orange : .primary)
                    Text(isWorkSchedule
                         ? String(localized: "work.toggle.subtitle.on", defaultValue: "Track shifts, hours, and earnings")
                         : String(localized: "work.toggle.subtitle.off", defaultValue: "Switch to track your work"))
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isWorkSchedule.animation()).tint(.orange).labelsHidden()
            }
            .padding(.vertical, 4)
        }
    }

    private var dateTimeSection: some View {
        Section {
            DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])

            Toggle(isOn: $hasTime.animation()) {
                Label(String(localized: "time.start", defaultValue: "Start Time"), systemImage: "clock")
                    .foregroundColor(hasTime ? (isWorkSchedule ? .orange : .green) : .primary)
            }
            .tint(isWorkSchedule ? .orange : .green)
            .onChange(of: hasTime) {
                if hasTime { startTime = Date() }
            }

            if hasTime {
                DatePicker(String(localized: "time.start", defaultValue: "Start Time"), selection: $startTime, displayedComponents: [.hourAndMinute])
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Toggle(isOn: $hasEndTime.animation()) {
                    Label(String(localized: "time.end", defaultValue: "End Time"), systemImage: "clock.badge.checkmark")
                        .foregroundColor(hasEndTime ? (isWorkSchedule ? .orange : .green) : .primary)
                }
                .tint(isWorkSchedule ? .orange : .green)
                .transition(.opacity.combined(with: .move(edge: .top)))

                if hasEndTime {
                    DatePicker(String(localized: "time.end", defaultValue: "End Time"), selection: $endTime, displayedComponents: [.hourAndMinute])
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        } header: { Text("Schedule") } footer: {
            if hasTime, hasEndTime {
                Text("⏱ \(timeString(startTime))  –  \(timeString(endTime))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isWorkSchedule ? .orange : .green)
            }
        }
    }

    // 💡 글로벌 스탠다드에 맞춘 (시간/수량) × (단가) 입력 폼 통합
    private var workFieldsSection: some View {
        let currencySymbol = Locale.current.currencySymbol ?? "$"
        
        return Group {
            Section {
                HStack {
                    Image(systemName: "building.2.fill").foregroundColor(.orange).frame(width: 20)
                    TextField(String(localized: "work.location.placeholder", defaultValue: "Location or Client name"), text: $siteName)
                }
                HStack {
                    Image(systemName: "text.bubble").foregroundColor(.secondary).frame(width: 20)
                    TextField(String(localized: "work.memo.placeholder", defaultValue: "Add notes..."), text: $memo).foregroundColor(.secondary)
                }
            } header: { Text(String(localized: "work.section.location", defaultValue: "Workplace / Client")) }

            Section {
                HStack(spacing: 16) {
                    // 수량/시간 입력
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "work.duration.label", defaultValue: "Hours / Qty"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("e.g. 8.5", text: $customWorkUnits)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("×")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    
                    Divider()
                    
                    // 단가/시급 입력
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "work.rate.label", defaultValue: "Pay Rate"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(currencySymbol).foregroundColor(.secondary)
                            TextField("Rate", text: $dailyWageText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
                .padding(.vertical, 4)
                
                // 수입 예상액 실시간 계산
                if previewIncome > 0 {
                    HStack {
                        Image(systemName: "banknote.fill").foregroundColor(.orange)
                        Text(String(localized: "work.income.preview", defaultValue: "Total Pay")).foregroundColor(.secondary)
                        Spacer()
                        Text("\(currencySymbol)\(Int(previewIncome).formatted())")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
            } header: { Text(String(localized: "work.section.earnings", defaultValue: "Earnings Calculation")) }
              footer: { Text(String(localized: "work.footer.calc", defaultValue: "Enter hours worked and hourly rate, or days and daily rate.")).foregroundColor(.secondary) }

            Section {
                HStack(spacing: 10) {
                    Image(systemName: isPaid ? "checkmark.seal.fill" : "checkmark.seal")
                        .font(.system(size: 20))
                        .foregroundColor(isPaid ? .green : .secondary)
                    Toggle(isPaid ? String(localized: "work.paid.toggle.label", defaultValue: "Paid") : String(localized: "work.unpaid.toggle.label", defaultValue: "Unpaid"), isOn: $isPaid)
                        .tint(.green)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isPaid ? .green : .red)
                }
            } header: { Text(String(localized: "work.section.payment", defaultValue: "Payment Status")) }
        }
    }

    private var workCalendarSection: some View {
        Section {
            Toggle(isOn: $calendarSyncEnabled) {
                Label("iOS 캘린더에 추가", systemImage: "calendar.badge.plus")
                    .foregroundColor(calendarSyncEnabled ? .orange : (canEnableCalendarSync ? .primary : .secondary))
            }
            .tint(.orange).disabled(!canEnableCalendarSync).opacity(canEnableCalendarSync ? 1 : 0.4)
            .onChange(of: canEnableCalendarSync) { if !canEnableCalendarSync { calendarSyncEnabled = false } }

            if calendarSyncEnabled { calendarSyncInfoRow(tint: .orange) }
        } header: { Text("캘린더 연동") } footer: {
            if !canEnableCalendarSync && hasTime { Text("⏰ 과거 시간으로는 iOS 캘린더에 추가할 수 없습니다.").foregroundColor(.red.opacity(0.7))
            } else if calendarSyncEnabled { Text("완료 처리 시 ✅로 업데이트되며, 삭제 시 캘린더에서도 제거됩니다.").foregroundColor(.secondary) }
        }
    }

    private var categorySection: some View {
        Section {
            Button { showCategoryPicker = true } label: {
                HStack {
                    if let cat = selectedCategory { CategoryBadge(category: cat) }
                    else { HStack(spacing: 6) { Image(systemName: "tag").foregroundColor(.secondary); Text("Select Category (optional)").foregroundColor(.secondary) } }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary.opacity(0.5))
                }
            }.buttonStyle(.plain)
        } header: { Text("Category") }
    }

    private var titleMemoSection: some View {
        Section {
            TextField("Plan title", text: $title).font(.system(size: 15))
            TextField("Add a memo (optional)", text: $memo, axis: .vertical).font(.system(size: 15)).lineLimit(3...6).foregroundColor(.secondary)
        } header: { Text("Details") }
    }

    private var notificationSection: some View {
        Section {
            Toggle("Reminder", isOn: $notificationEnabled).tint(.green)
                .disabled(!hasTime || (isFutureDate && !storeManager.isPro))
                .opacity((hasTime && (!isFutureDate || storeManager.isPro)) ? 1 : 0.5)

            if notificationEnabled && hasTime {
                Picker("Sound", selection: $notificationSound) {
                    ForEach(NotificationSound.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

            Toggle(isOn: $calendarSyncEnabled) {
                Label("iOS 캘린더에 추가", systemImage: "calendar.badge.plus")
                    .foregroundColor(calendarSyncEnabled ? .blue : (canEnableCalendarSync ? .primary : .secondary))
            }
            .tint(.blue).disabled(!canEnableCalendarSync).opacity(canEnableCalendarSync ? 1 : 0.4)
            .onChange(of: canEnableCalendarSync) { if !canEnableCalendarSync { calendarSyncEnabled = false } }

            if calendarSyncEnabled { calendarSyncInfoRow(tint: .blue) }
        } header: { Text("Notification") } footer: {
            if !hasTime { Text("Set a time to enable reminders.").foregroundColor(.secondary)
            } else if !canEnableCalendarSync { Text("⏰ 과거 시간으로는 iOS 캘린더에 추가할 수 없습니다.").foregroundColor(.red.opacity(0.7))
            } else if isFutureDate && !storeManager.isPro { Text("⭐️ Upgrade to Pro to set reminders for future dates.").foregroundColor(.orange) }
        }
    }

    @ViewBuilder
    private func calendarSyncInfoRow(tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundColor(tint.opacity(0.7)).font(.system(size: 13)).padding(.top, 1)
            Text("iOS 기본 캘린더에 등록됩니다. 완료하면 ✅ 표시로 업데이트되고, 삭제하면 캘린더에서도 제거됩니다.")
                .font(.system(size: 12)).foregroundColor(.secondary)
        }
        .padding(.vertical, 2).transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func savePlan() {
        let sc = timeComps(startTime)
        let ec = timeComps(endTime)

        if isWorkSchedule {
            let resolvedTitle = siteName.trimmingCharacters(in: .whitespaces).isEmpty ? String(localized: "work.toggle.title", defaultValue: "Work Schedule") : siteName.trimmingCharacters(in: .whitespaces)

            let plan = Plan(
                title: resolvedTitle, memo: memo,
                year: dateComponents.year, month: dateComponents.month, day: dateComponents.day,
                hasTime: hasTime, hour: hasTime ? sc.hour : 0, minute: hasTime ? sc.minute : 0,
                hasEndTime: hasTime && hasEndTime, endHour: (hasTime && hasEndTime) ? ec.hour : 0, endMinute: (hasTime && hasEndTime) ? ec.minute : 0,
                status: .planned, calendarSyncEnabled: calendarSyncEnabled, isWorkSchedule: true,
                workUnits: resolvedWorkUnits, dailyWage: resolvedDailyWage, siteName: siteName.trimmingCharacters(in: .whitespaces), isPaid: isPaid
            )
            modelContext.insert(plan)
            try? modelContext.save()

            if calendarSyncEnabled {
                Task {
                    let eventId = await CalendarService.shared.createEvent(for: plan)
                    plan.eventIdentifier = eventId
                    try? modelContext.save()
                }
            }
            dismiss()

        } else {
            let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
            guard !trimmedTitle.isEmpty else { showValidationAlert = true; return }
            if notificationEnabled && hasTime && isFutureDate && !storeManager.isPro { showPaywall = true; return }

            if notificationEnabled && hasTime {
                Task {
                    let status = await NotificationService.shared.checkPermissionStatus()
                    if status == .notDetermined {
                        let granted = await NotificationService.shared.requestPermission()
                        await MainActor.run { granted ? actualSave(title: trimmedTitle, sc: sc, ec: ec, scheduleNotification: true) : (showPermissionAlert = true) }
                    } else if status == .denied {
                        await MainActor.run { showPermissionAlert = true }
                    } else {
                        await MainActor.run { actualSave(title: trimmedTitle, sc: sc, ec: ec, scheduleNotification: true) }
                    }
                }
            } else {
                actualSave(title: trimmedTitle, sc: sc, ec: ec, scheduleNotification: false)
            }
        }
    }

    private func actualSave(title: String, sc: (hour: Int, minute: Int), ec: (hour: Int, minute: Int), scheduleNotification: Bool) {
        let plan = Plan(
            title: title, memo: memo,
            year: dateComponents.year, month: dateComponents.month, day: dateComponents.day,
            hasTime: hasTime, hour: hasTime ? sc.hour : 0, minute: hasTime ? sc.minute : 0,
            hasEndTime: hasTime && hasEndTime, endHour: (hasTime && hasEndTime) ? ec.hour : 0, endMinute: (hasTime && hasEndTime) ? ec.minute : 0,
            status: .planned, notificationEnabled: scheduleNotification, notificationSound: notificationSound,
            calendarSyncEnabled: calendarSyncEnabled, category: selectedCategory
        )
        modelContext.insert(plan)
        do { try modelContext.save() } catch { print("❌ Save failed:", error); return }

        if scheduleNotification { Task { await NotificationService.shared.schedule(for: plan) } }
        if calendarSyncEnabled {
            Task {
                let eventId = await CalendarService.shared.createEvent(for: plan)
                plan.eventIdentifier = eventId
                try? modelContext.save()
            }
        }
        dismiss()
    }

    private func timeString(_ date: Date) -> String {
        let h = Calendar.current.component(.hour, from: date)
        let m = Calendar.current.component(.minute, from: date)
        let displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", displayH, m, h < 12 ? "AM" : "PM")
    }
}
