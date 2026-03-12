import SwiftUI
import SwiftData
import UserNotifications

struct AddPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared

    // MARK: - Common
    @State private var selectedDate: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month, .day], from: Date())) ?? Date()
    }()
    @State private var hasTime: Bool    = false
    @State private var startTime: Date  = {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month, .day, .hour], from: Date())
        c.hour = (c.hour ?? 8); c.minute = 0
        return cal.date(from: c) ?? Date()
    }()
    @State private var hasEndTime: Bool = false
    @State private var endTime: Date    = {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month, .day, .hour], from: Date())
        c.hour = (c.hour ?? 8) + 8; c.minute = 0
        return cal.date(from: c) ?? Date()
    }()

    // MARK: - Mode toggle
    @State private var isWorkSchedule: Bool = false

    // MARK: - General plan
    @State private var title: String = ""
    @State private var memo: String  = ""
    @State private var selectedCategory: Category? = nil
    @State private var notificationEnabled: Bool   = false
    @State private var notificationSound: NotificationSound = .sound
    @State private var calendarSyncEnabled: Bool   = false

    // MARK: - Work schedule
    @State private var workUnitsOption: WorkUnitsOption = .full
    @State private var customWorkUnits: String = "1.0"
    @State private var dailyWageText: String   = ""
    @State private var siteName: String        = ""
    @State private var isPaid: Bool            = false

    // MARK: - UI
    @State private var showCategoryPicker  = false
    @State private var showValidationAlert = false
    @State private var showPermissionAlert = false
    @State private var showPaywall         = false

    @Query(sort: \Category.createdAt) private var categories: [Category]

    // MARK: - Computed

    private var dateComponents: (year: Int, month: Int, day: Int) {
        let cal = Calendar.current
        return (cal.component(.year, from: selectedDate),
                cal.component(.month, from: selectedDate),
                cal.component(.day,   from: selectedDate))
    }
    private func timeComps(_ d: Date) -> (hour: Int, minute: Int) {
        (Calendar.current.component(.hour, from: d),
         Calendar.current.component(.minute, from: d))
    }
    private var isFutureDate: Bool {
        Calendar.current.startOfDay(for: selectedDate) > Calendar.current.startOfDay(for: Date())
    }
    // 캘린더 토글 활성화 조건:
    // - 종료시간이 있으면 → 종료시간이 미래일 때만 허용
    // - 종료시간 없으면  → 시작시간이 미래일 때만 허용
    // (야근처럼 시작이 과거여도 종료가 미래면 허용)
    private var canEnableCalendarSync: Bool {
        guard hasTime else { return true }  // 시간 없으면 종일 일정 → 허용
        let cal = Calendar.current
        let now = Date()

        if hasEndTime {
            let startH = cal.component(.hour,   from: startTime)
            let endH   = cal.component(.hour,   from: endTime)
            let endM   = cal.component(.minute, from: endTime)

            var ec = cal.dateComponents([.year, .month, .day], from: selectedDate)
            ec.hour = endH; ec.minute = endM
            guard var endDate = cal.date(from: ec) else { return false }

            // 종료 ≤ 시작 → 자정 넘기는 야근 → 다음날로 계산
            if endH < startH || (endH == startH && endM <= cal.component(.minute, from: startTime)) {
                endDate = cal.date(byAdding: .day, value: 1, to: endDate) ?? endDate
            }
            return endDate > now   // 종료시간이 미래면 허용
        } else {
            // 종료시간 없으면 시작시간 기준
            var sc = cal.dateComponents([.year, .month, .day], from: selectedDate)
            sc.hour = cal.component(.hour, from: startTime)
            sc.minute = cal.component(.minute, from: startTime)
            guard let startDate = cal.date(from: sc) else { return false }
            return startDate > now
        }
    }
    private var resolvedWorkUnits: Double {
        workUnitsOption == .custom ? (Double(customWorkUnits) ?? 1.0) : (workUnitsOption.value ?? 1.0)
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
                    workCalendarSection      // ✅ 근무 일정용 캘린더 연동
                } else {
                    if !categories.isEmpty { categorySection }
                    titleMemoSection
                    dateTimeSection
                    notificationSection      // ✅ 알림 + 캘린더 연동 통합
                }
            }
            .navigationTitle(
                isWorkSchedule
                    ? String(localized: "work.add.nav.title")
                    : "New Plan"
            )
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
                Button("Go to Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Please allow notifications in Settings.") }
            .sheet(isPresented: $showPaywall) { PurchaseView() }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(selectedCategory: $selectedCategory)
            }
            .animation(.easeInOut(duration: 0.22), value: isWorkSchedule)
            .animation(.easeInOut(duration: 0.18), value: hasTime)
            .animation(.easeInOut(duration: 0.18), value: hasEndTime)
            .animation(.easeInOut(duration: 0.18), value: calendarSyncEnabled)
        }
    }

    // MARK: - Work toggle section

    private var workToggleSection: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isWorkSchedule ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isWorkSchedule ? .orange : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "work.toggle.title"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isWorkSchedule ? .orange : .primary)
                    Text(isWorkSchedule
                         ? String(localized: "work.toggle.subtitle.on")
                         : String(localized: "work.toggle.subtitle.off"))
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isWorkSchedule.animation()).tint(.orange).labelsHidden()
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Date & time section (shared)

    private var dateTimeSection: some View {
        Section {
            DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])

            Toggle(isOn: $hasTime.animation()) {
                Label(String(localized: "time.start"), systemImage: "clock")
                    .foregroundColor(hasTime ? (isWorkSchedule ? .orange : .green) : .primary)
            }
            .tint(isWorkSchedule ? .orange : .green)
            .onChange(of: hasTime) {
                if hasTime {
                    // 토글 켜는 순간 현재 시각으로 설정
                    startTime = Date()
                }
            }

            if hasTime {
                DatePicker(String(localized: "time.start"),
                           selection: $startTime, displayedComponents: [.hourAndMinute])
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Toggle(isOn: $hasEndTime.animation()) {
                    Label(String(localized: "time.end"), systemImage: "clock.badge.checkmark")
                        .foregroundColor(hasEndTime ? (isWorkSchedule ? .orange : .green) : .primary)
                }
                .tint(isWorkSchedule ? .orange : .green)
                .transition(.opacity.combined(with: .move(edge: .top)))

                if hasEndTime {
                    DatePicker(String(localized: "time.end"),
                               selection: $endTime, displayedComponents: [.hourAndMinute])
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        } header: {
            Text("Schedule")
        } footer: {
            if hasTime, hasEndTime {
                Text("⏱ \(timeString(startTime))  –  \(timeString(endTime))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isWorkSchedule ? .orange : .green)
            }
        }
    }

    // MARK: - Work-only fields

    private var workFieldsSection: some View {
        Group {
            // Site info
            Section {
                HStack {
                    Image(systemName: "mappin.and.ellipse").foregroundColor(.orange).frame(width: 20)
                    TextField(String(localized: "work.site.placeholder"), text: $siteName)
                }
                HStack {
                    Image(systemName: "text.bubble").foregroundColor(.secondary).frame(width: 20)
                    TextField(String(localized: "work.memo.placeholder"), text: $memo)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(String(localized: "work.section.site"))
            } footer: {
                Text(String(localized: "work.footer.site")).foregroundColor(.secondary)
            }

            // Units
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ForEach(WorkUnitsOption.allCases, id: \.self) { opt in
                            Button(action: { workUnitsOption = opt }) {
                                Text(opt.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(workUnitsOption == opt ? Color.orange : Color.secondary.opacity(0.12))
                                    .foregroundColor(workUnitsOption == opt ? .white : .primary)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if workUnitsOption == .custom {
                        HStack {
                            TextField(String(localized: "work.custom.units.placeholder"),
                                      text: $customWorkUnits).keyboardType(.decimalPad)
                            Text(String(localized: "work.stat.total.units"))
                                .foregroundColor(.secondary).font(.system(size: 14))
                        }
                        .padding(10).background(Color.secondary.opacity(0.08)).cornerRadius(8)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(String(localized: "work.section.units"))
            }

            // Daily wage
            Section {
                HStack {
                    Text("₩").foregroundColor(.secondary)
                    TextField(String(localized: "work.wage.placeholder"),
                              text: $dailyWageText).keyboardType(.numberPad)
                }
                if previewIncome > 0 {
                    HStack {
                        Image(systemName: "wonsign.circle.fill").foregroundColor(.orange)
                        Text(String(localized: "work.income.preview")).foregroundColor(.secondary)
                        Spacer()
                        Text("₩\(Int(previewIncome).formatted())")
                            .font(.system(size: 16, weight: .bold)).foregroundColor(.orange)
                    }
                }
            } header: {
                Text(String(localized: "work.section.wage"))
            } footer: {
                Text(String(localized: "work.footer.calc")).foregroundColor(.secondary)
            }

            // Payment
            Section {
                HStack(spacing: 10) {
                    Image(systemName: isPaid ? "wonsign.circle.fill" : "wonsign.circle")
                        .font(.system(size: 20))
                        .foregroundColor(isPaid ? .green : .secondary)
                    Toggle(isPaid
                           ? String(localized: "work.paid.toggle.label")
                           : String(localized: "work.unpaid.toggle.label"),
                           isOn: $isPaid)
                        .tint(.green)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isPaid ? .green : .red)
                }
            } header: {
                Text(String(localized: "work.section.payment"))
            } footer: {
                Text(String(localized: "work.footer.payment")).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - ✅ 근무 일정용 캘린더 연동 섹션

    private var workCalendarSection: some View {
        Section {
            Toggle(isOn: $calendarSyncEnabled) {
                Label("iOS 캘린더에 추가", systemImage: "calendar.badge.plus")
                    .foregroundColor(calendarSyncEnabled ? .orange : (canEnableCalendarSync ? .primary : .secondary))
            }
            .tint(.orange)
            .disabled(!canEnableCalendarSync)
            .opacity(canEnableCalendarSync ? 1 : 0.4)
            .onChange(of: canEnableCalendarSync) {
                if !canEnableCalendarSync { calendarSyncEnabled = false }
            }

            if calendarSyncEnabled {
                calendarSyncInfoRow(tint: .orange)
            }
        } header: {
            Text("캘린더 연동")
        } footer: {
            if !canEnableCalendarSync && hasTime {
                Text("⏰ 과거 시간으로는 iOS 캘린더에 추가할 수 없습니다.")
                    .foregroundColor(.red.opacity(0.7))
            } else if calendarSyncEnabled {
                Text("완료 처리 시 ✅로 업데이트되며, 삭제 시 캘린더에서도 제거됩니다.")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - General plan sections

    private var categorySection: some View {
        Section {
            Button { showCategoryPicker = true } label: {
                HStack {
                    if let cat = selectedCategory {
                        CategoryBadge(category: cat)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "tag").foregroundColor(.secondary)
                            Text("Select Category (optional)").foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12)).foregroundColor(.secondary.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
        } header: { Text("Category") }
    }

    private var titleMemoSection: some View {
        Section {
            TextField("Plan title", text: $title).font(.system(size: 15))
            TextField("Add a memo (optional)", text: $memo, axis: .vertical)
                .font(.system(size: 15)).lineLimit(3...6).foregroundColor(.secondary)
        } header: { Text("Details") }
    }

    // MARK: - ✅ 알림 + 캘린더 연동 통합 섹션

    private var notificationSection: some View {
        Section {
            // 알림 토글
            Toggle("Reminder", isOn: $notificationEnabled).tint(.green)
                .disabled(!hasTime || (isFutureDate && !storeManager.isPro))
                .opacity((hasTime && (!isFutureDate || storeManager.isPro)) ? 1 : 0.5)

            if notificationEnabled && hasTime {
                Picker("Sound", selection: $notificationSound) {
                    ForEach(NotificationSound.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

            // ✅ 캘린더 연동 토글 (과거 시간이면 비활성화)
            Toggle(isOn: $calendarSyncEnabled) {
                Label("iOS 캘린더에 추가", systemImage: "calendar.badge.plus")
                    .foregroundColor(calendarSyncEnabled ? .blue : (canEnableCalendarSync ? .primary : .secondary))
            }
            .tint(.blue)
            .disabled(!canEnableCalendarSync)
            .opacity(canEnableCalendarSync ? 1 : 0.4)
            .onChange(of: canEnableCalendarSync) {
                if !canEnableCalendarSync { calendarSyncEnabled = false }
            }

            if calendarSyncEnabled {
                calendarSyncInfoRow(tint: .blue)
            }

        } header: { Text("Notification") }
          footer: {
            if !hasTime {
                Text("Set a time to enable reminders.").foregroundColor(.secondary)
            } else if !canEnableCalendarSync {
                Text("⏰ 과거 시간으로는 iOS 캘린더에 추가할 수 없습니다.")
                    .foregroundColor(.red.opacity(0.7))
            } else if isFutureDate && !storeManager.isPro {
                Text("⭐️ Upgrade to Pro to set reminders for future dates.").foregroundColor(.orange)
            }
        }
    }

    // MARK: - 캘린더 연동 안내 행 (공통)

    @ViewBuilder
    private func calendarSyncInfoRow(tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(tint.opacity(0.7))
                .font(.system(size: 13))
                .padding(.top, 1)
            Text("iOS 기본 캘린더에 등록됩니다. 완료하면 ✅ 표시로 업데이트되고, 삭제하면 캘린더에서도 제거됩니다.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Save

    private func savePlan() {
        let sc = timeComps(startTime)
        let ec = timeComps(endTime)

        if isWorkSchedule {
            let resolvedTitle = siteName.trimmingCharacters(in: .whitespaces).isEmpty
                ? String(localized: "work.toggle.title")
                : siteName.trimmingCharacters(in: .whitespaces)

            let plan = Plan(
                title: resolvedTitle, memo: memo,
                year: dateComponents.year, month: dateComponents.month, day: dateComponents.day,
                hasTime: hasTime,
                hour: hasTime ? sc.hour : 0, minute: hasTime ? sc.minute : 0,
                hasEndTime: hasTime && hasEndTime,
                endHour:   (hasTime && hasEndTime) ? ec.hour   : 0,
                endMinute: (hasTime && hasEndTime) ? ec.minute : 0,
                status: .planned,
                calendarSyncEnabled: calendarSyncEnabled,  // ✅
                isWorkSchedule: true,
                workUnits: resolvedWorkUnits, dailyWage: resolvedDailyWage,
                siteName: siteName.trimmingCharacters(in: .whitespaces),
                isPaid: isPaid
            )
            modelContext.insert(plan)
            try? modelContext.save()

            // ✅ 근무 일정도 캘린더 연동
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

            if notificationEnabled && hasTime && isFutureDate && !storeManager.isPro {
                showPaywall = true; return
            }

            let wantNotification = notificationEnabled && hasTime
            if wantNotification {
                Task {
                    let status = await NotificationService.shared.checkPermissionStatus()
                    switch status {
                    case .notDetermined:
                        let granted = await NotificationService.shared.requestPermission()
                        await MainActor.run {
                            granted ? actualSave(title: trimmedTitle, sc: sc, ec: ec, scheduleNotification: true)
                                    : (showPermissionAlert = true)
                        }
                    case .authorized, .provisional, .ephemeral:
                        await MainActor.run { actualSave(title: trimmedTitle, sc: sc, ec: ec, scheduleNotification: true) }
                    case .denied:
                        await MainActor.run { showPermissionAlert = true }
                    @unknown default:
                        await MainActor.run { actualSave(title: trimmedTitle, sc: sc, ec: ec, scheduleNotification: true) }
                    }
                }
            } else {
                actualSave(title: trimmedTitle, sc: sc, ec: ec, scheduleNotification: false)
            }
        }
    }

    private func actualSave(title: String,
                            sc: (hour: Int, minute: Int),
                            ec: (hour: Int, minute: Int),
                            scheduleNotification: Bool) {
        let plan = Plan(
            title: title, memo: memo,
            year: dateComponents.year, month: dateComponents.month, day: dateComponents.day,
            hasTime: hasTime,
            hour: hasTime ? sc.hour : 0, minute: hasTime ? sc.minute : 0,
            hasEndTime: hasTime && hasEndTime,
            endHour:   (hasTime && hasEndTime) ? ec.hour   : 0,
            endMinute: (hasTime && hasEndTime) ? ec.minute : 0,
            status: .planned,
            notificationEnabled: scheduleNotification,
            notificationSound: notificationSound,
            calendarSyncEnabled: calendarSyncEnabled,   // ✅
            category: selectedCategory
        )
        modelContext.insert(plan)
        do { try modelContext.save() } catch { print("❌ Save failed:", error); return }

        if scheduleNotification { Task { await NotificationService.shared.schedule(for: plan) } }

        // ✅ iOS 캘린더 이벤트 생성
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
        let h = Calendar.current.component(.hour,   from: date)
        let m = Calendar.current.component(.minute, from: date)
        let displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", displayH, m, h < 12 ? "AM" : "PM")
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: Category?
    @Query(sort: \Category.createdAt) private var categories: [Category]

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button { selectedCategory = category; dismiss() } label: {
                        HStack {
                            CategoryBadge(category: category)
                            Spacer()
                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark").foregroundColor(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Select Category")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    AddPlanView()
        .modelContainer(for: [Category.self, Plan.self], inMemory: true)
}
