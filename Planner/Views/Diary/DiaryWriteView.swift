import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Diary Write / Edit View

struct DiaryWriteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let existingEntry: DiaryEntry?
    let theme: SeasonTheme
    
    @State private var text: String = ""
    @State private var selectedMood: Mood? = nil
    @State private var images: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showDeleteAlert = false
    
    private var dateComps: (year: Int, month: Int, day: Int) {
        if let e = existingEntry { return (e.year, e.month, e.day) }
        let cal = Calendar.current
        let now = Date()
        return (
            cal.component(.year, from: now),
            cal.component(.month, from: now),
            cal.component(.day, from: now)
        )
    }
    
    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedMood != nil ||
        !images.isEmpty
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : theme.diaryCardBackground
    }
    
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    private var adaptivePlaceholderColor: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.4)
        : Color.secondary.opacity(0.55)
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark
             ? LinearGradient(
                colors: [Color.black, Color(white: 0.1)],
                startPoint: .top,
                endPoint: .bottom
             )
             : theme.diaryBackgroundGradient
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    dateHeader
                    moodPicker
                    textEditor
                    imagePicker
                    
                    if existingEntry != nil {
                        deleteSection
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle(existingEntry == nil ? "New Diary" : "Edit Diary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save", action: save)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSave ? Color.green : Color.secondary)
                    .disabled(!canSave)
            }
        }
        .onAppear(perform: loadExisting)
        .onChange(of: pickerItems) { loadPhotos() }
        .alert("Delete Diary?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteEntry() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    // =========================================================
    // MARK: - Date Header
    // =========================================================
    
    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayOfWeek)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Text(fullDate)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(adaptiveTextColor)
            }
            Spacer()
            Text(theme.icon)
                .font(.system(size: 32))
        }
        .padding(16)
        .background(adaptiveCardBackground)
        .cornerRadius(16)
    }
    
    private var dayOfWeek: String {
        guard let date = Calendar.current.date(from: DateComponents(
            year: dateComps.year,
            month: dateComps.month,
            day: dateComps.day
        )) else { return "" }
        
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "EEEE"
        return fmt.string(from: date)
    }
    
    private var fullDate: String {
        guard let date = Calendar.current.date(from: DateComponents(
            year: dateComps.year,
            month: dateComps.month,
            day: dateComps.day
        )) else { return "" }
        
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "MMMM d, yyyy"
        return fmt.string(from: date)
    }
    
    // =========================================================
    // MARK: - Mood Picker
    // =========================================================
    
    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How are you feeling?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(adaptiveTextColor)
            
            HStack(spacing: 0) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    Button {
                        selectedMood = (selectedMood == mood) ? nil : mood
                    } label: {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.system(size: 26))
                                .scaleEffect(selectedMood == mood ? 1.18 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedMood)
                            
                            Text(mood.label)
                                .font(.system(size: 10, weight: selectedMood == mood ? .semibold : .medium))
                                .foregroundStyle(selectedMood == mood ? mood.color : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedMood == mood ? mood.color.opacity(0.13) : .clear)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(adaptiveCardBackground)
            .cornerRadius(14)
        }
    }
    
    // =========================================================
    // MARK: - Text Editor
    // =========================================================
    
    private var textEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Write something")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(adaptiveTextColor)
            
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(adaptiveCardBackground)
                    .cornerRadius(14)
                
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 15))
                    .foregroundStyle(adaptiveTextColor)
                    .frame(minHeight: 110, maxHeight: 220)
                    .padding(12)
                
                if text.isEmpty {
                    Text("Today's thoughts...")
                        .font(.system(size: 15))
                        .foregroundStyle(adaptivePlaceholderColor)
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // =========================================================
    // MARK: - Image Picker (✅ 고정 비율 4:3)
    // =========================================================
    
    private var imagePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Photos")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(adaptiveTextColor)
                
                Spacer()
                
                if images.count < 5 {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 5 - images.count,
                        matching: .images
                    ) {
                        Label("Add", systemImage: "plus.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.green)
                    }
                }
            }
            
            if images.isEmpty {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.action")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.secondary.opacity(0.45))
                        
                        Text("Tap to add photos")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .background(adaptiveCardBackground)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            } else {
                // ✅ 고정 비율 4:3, 삭제 버튼 우측 상단
                VStack(spacing: 12) {
                    ForEach(images.indices, id: \.self) { i in
                        GeometryReader { geo in
                            ZStack(alignment: .topTrailing) {
                                // 사진 (4:3 비율 고정)
                                Image(uiImage: images[i])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.width * 0.75)
                                    .clipped()
                                    .cornerRadius(16)
                                
                                // 삭제 버튼 (우측 상단, 명확한 UI)
                                Button {
                                    images.remove(at: i)
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(.black.opacity(0.75))
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "xmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                            }
                        }
                        .aspectRatio(4/3, contentMode: .fit)
                    }
                }
            }
        }
    }
    
    // =========================================================
    // MARK: - Delete Section
    // =========================================================
    
    private var deleteSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.top, 12)
            
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete this diary")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.red)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.1))
                )
            }
        }
        .padding(.top, 20)
    }
    
    // =========================================================
    // MARK: - Load / Save / Delete
    // =========================================================
    
    private func loadExisting() {
        guard let e = existingEntry else { return }
        text = e.text
        selectedMood = e.mood
        images = e.sortedImages.compactMap { UIImage(data: $0.imageData) }
    }
    
    private func loadPhotos() {
        Task {
            var loaded: [UIImage] = []
            for item in pickerItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    loaded.append(img)
                }
            }
            images.append(contentsOf: loaded)
            pickerItems = []
        }
    }
    
    private func save() {
        let diaryImages: [DiaryImage] = images.enumerated().compactMap { idx, img in
            guard let data = img.jpegData(compressionQuality: 0.7) else { return nil }
            return DiaryImage(imageData: data, order: idx)
        }
        
        if let existing = existingEntry {
            for old in existing.images {
                modelContext.delete(old)
            }
            existing.text = text
            existing.mood = selectedMood
            existing.images = diaryImages
            existing.themeName = theme.rawValue
            existing.updatedAt = Date()
        } else {
            let entry = DiaryEntry(
                year: dateComps.year,
                month: dateComps.month,
                day: dateComps.day,
                text: text,
                mood: selectedMood,
                images: diaryImages,
                themeName: theme.rawValue
            )
            modelContext.insert(entry)
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteEntry() {
        guard let existing = existingEntry else { return }
        modelContext.delete(existing)
        try? modelContext.save()
        dismiss()
    }
}
