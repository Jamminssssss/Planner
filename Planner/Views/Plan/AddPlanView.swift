import SwiftUI
import SwiftData
import UserNotifications

/// 계획 추가 화면 (결제 제한 포함)
struct AddPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var storeManager = StoreKitManager.shared

    // MARK: - Form State

    @State private var title: String = ""
    @State private var memo: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var selectedDate: Date = {
        let cal = Calendar.current
        let today = Date()
        return cal.date(from: cal.dateComponents([.year, .month, .day], from: today)) ?? today
    }()
    @State private var hasTime: Bool = false
    @State private var selectedTime: Date = {
        let now = Date()
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
        comps.hour = (comps.hour ?? 0) + 1
        comps.minute = 0
        return cal.date(from: comps) ?? now
    }()
    @State private var notificationEnabled: Bool = false
    @State private var notificationSound: NotificationSound = .sound
    @State private var calendarSyncEnabled: Bool = false

    // UI
    @State private var showCategoryPicker: Bool = false
    @State private var showValidationAlert: Bool = false
    @State private var showPermissionAlert: Bool = false
    @State private var showPaywall: Bool = false  // ← 결제 화면 트리거

    @Query(sort: \Category.createdAt)
    private var categories: [Category]

    // MARK: - Computed

    private var dateComponents: (year: Int, month: Int, day: Int) {
        let cal = Calendar.current
        return (
            cal.component(.year,  from: selectedDate),
            cal.component(.month, from: selectedDate),
            cal.component(.day,   from: selectedDate)
        )
    }

    private var timeComponents: (hour: Int, minute: Int) {
        let cal = Calendar.current
        return (
            cal.component(.hour,   from: selectedTime),
            cal.component(.minute, from: selectedTime)
        )
    }
    
    /// 선택한 날짜가 미래인지 확인 (다음날 이후)
    private var isFutureDate: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let selected = cal.startOfDay(for: selectedDate)
        return selected > today
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                categorySection
                titleMemoSection
                dateTimeSection
                notificationSection
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { savePlan() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
            .alert("Missing Title", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a plan title.")
            }
            .alert("Notification Permission", isPresented: $showPermissionAlert) {
                Button("Go to Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow notifications in Settings to enable reminders.")
            }
            .sheet(isPresented: $showPaywall) {
                PurchaseView()
            }
        }
    }

    // MARK: - Sections

    private var categorySection: some View {
        // 카테고리가 있을 때만 표시
        if !categories.isEmpty {
            return AnyView(
                Section {
                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack {
                            if let cat = selectedCategory {
                                CategoryBadge(category: cat)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag")
                                        .foregroundColor(.secondary)
                                    Text("Select Category (optional)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Category")
                }
                .sheet(isPresented: $showCategoryPicker) {
                    CategoryPickerSheet(selectedCategory: $selectedCategory)
                }
            )
        } else {
            return AnyView(EmptyView()) // 카테고리가 없으면 표시하지 않음
        }
    }


    private var titleMemoSection: some View {
        Section {
            TextField("Plan title", text: $title)
                .font(.system(size: 15))

            TextField("Add a memo (optional)", text: $memo, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(3...6)
                .foregroundColor(.secondary)
        } header: {
            Text("Details")
        }
    }

    private var dateTimeSection: some View {
        Section {
            DatePicker(
                "Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )

            Toggle("Set Time", isOn: $hasTime)
                .tint(.green)

            if hasTime {
                DatePicker(
                    "Time",
                    selection: $selectedTime,
                    displayedComponents: [.hourAndMinute]
                )
            }
        } header: {
            Text("Schedule")
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle("Reminder", isOn: $notificationEnabled)
                .tint(.green)
                .disabled(!hasTime || (isFutureDate && !storeManager.isPro))  // ← 미래 알림 제한
                .opacity((hasTime && (!isFutureDate || storeManager.isPro)) ? 1 : 0.5)

            if notificationEnabled && hasTime {
                Picker("Sound", selection: $notificationSound) {
                    ForEach(NotificationSound.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
            }
        } header: {
            Text("Notification")
        } footer: {
            if !hasTime {
                Text("Set a time to enable reminders.")
                    .foregroundColor(.secondary)
            } else if isFutureDate && !storeManager.isPro {
                Text("⭐️ Upgrade to Pro to set reminders for future dates.")
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Save Logic

    private func savePlan() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            showValidationAlert = true
            return
        }
        
        // ✅ 미래 알림 제한 체크 (Pro 아니면 차단)
        if notificationEnabled && hasTime && isFutureDate && !storeManager.isPro {
            showPaywall = true
            return
        }

        let wantNotification = notificationEnabled && hasTime

        if wantNotification {
            Task {
                let status = await NotificationService.shared.checkPermissionStatus()
                switch status {
                case .notDetermined:
                    let granted = await NotificationService.shared.requestPermission()
                    await MainActor.run {
                        if granted {
                            actualSave(title: trimmedTitle, scheduleNotification: true)
                        } else {
                            showPermissionAlert = true
                        }
                    }
                case .authorized, .provisional, .ephemeral:
                    await MainActor.run {
                        actualSave(title: trimmedTitle, scheduleNotification: true)
                    }
                case .denied:
                    await MainActor.run { showPermissionAlert = true }
                @unknown default:
                    await MainActor.run {
                        actualSave(title: trimmedTitle, scheduleNotification: true)
                    }
                }
            }
        } else {
            actualSave(title: trimmedTitle, scheduleNotification: false)
        }
    }

    private func actualSave(title: String, scheduleNotification: Bool) {
        let plan = Plan(
            title: title,
            memo: memo,
            year:  dateComponents.year,
            month: dateComponents.month,
            day:   dateComponents.day,
            hasTime: hasTime,
            hour:   hasTime ? timeComponents.hour   : 0,
            minute: hasTime ? timeComponents.minute : 0,
            status: .planned,
            notificationEnabled: scheduleNotification,
            notificationSound:   notificationSound,
            calendarSyncEnabled: calendarSyncEnabled,
            category: selectedCategory
        )

        modelContext.insert(plan)
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save plan:", error)
            return
        }

        if scheduleNotification {
            Task { await NotificationService.shared.schedule(for: plan) }
        }

        if calendarSyncEnabled {
            Task {
                let eventId = await CalendarService.shared.createEvent(for: plan)
                plan.eventIdentifier = eventId
                try? modelContext.save()
            }
        }

        dismiss()
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: Category?

    @Query(sort: \Category.createdAt)
    private var categories: [Category]

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button {
                        selectedCategory = category
                        dismiss()
                    } label: {
                        HStack {
                            CategoryBadge(category: category)
                            Spacer()
                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Select Category")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    AddPlanView()
        .modelContainer(for: [Category.self, Plan.self], inMemory: true)
}

