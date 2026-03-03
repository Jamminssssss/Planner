import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Diary Editor View (iOS Notes Style + Theme)

struct DiaryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.colorScheme)  private var colorScheme

    let entry: DiaryEntry?
    let theme: SeasonTheme

    // MARK: - State

    @State private var text:          String = ""
    @State private var selectedMood:  Mood?  = nil
    @State private var images:        [UIImage] = []
    @State private var pickerItems:   [PhotosPickerItem] = []

    @State private var showMoodPicker  = false
    @State private var showDeleteAlert = false
    @State private var showPhotoPicker = false
    @State private var showShareSheet  = false
    @State private var shareItems: [Any] = []

    @FocusState private var editorFocused: Bool

    // MARK: - Computed

    private var dateComps: (year: Int, month: Int, day: Int) {
        if let e = entry { return (e.year, e.month, e.day) }
        let cal = Calendar.current; let now = Date()
        return (cal.component(.year, from: now),
                cal.component(.month, from: now),
                cal.component(.day, from: now))
    }

    private var formattedDate: String {
        var comps = DateComponents()
        comps.year = dateComps.year; comps.month = dateComps.month; comps.day = dateComps.day
        guard let date = Calendar.current.date(from: comps) else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "MMMM d, yyyy  h:mm a"
        return fmt.string(from: entry?.updatedAt ?? date)
    }

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && images.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── 테마 배경 ──
            ThemeBackgroundView(theme: theme)

            VStack(spacing: 0) {
                // 날짜 헤더
                HStack {
                    Text(formattedDate)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(theme.icon)
                        .font(.system(size: 20))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // 기분 배지
                if let mood = selectedMood {
                    HStack(spacing: 6) {
                        Text(mood.emoji)
                        Text(mood.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.diaryAccent)
                        Button {
                            withAnimation { selectedMood = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.diaryAccent.opacity(0.12), in: Capsule())
                    .padding(.bottom, 6)
                    .transition(.scale.combined(with: .opacity))
                }

                // ── 스크롤 영역: 텍스트 + 이미지 인라인 ──
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 이미지만 있고 텍스트 없으면 → 이미지 먼저, 커서는 아래
                        if !images.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            inlineImages
                        }
                        // 자동 높이 텍스트 에디터
                        autoTextEditor
                        // 텍스트가 있을 때 이미지는 텍스트 바로 아래
                        if !images.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            inlineImages
                        }
                        Spacer(minLength: 40)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editorFocused = true
                    }
                }

                Divider()
                    .background(theme.diaryAccent.opacity(0.3))

                // 하단 툴바
                bottomToolbar
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
        }
        .onAppear {
            loadExisting()
        }
        .onChange(of: pickerItems) { loadPhotos() }
        .confirmationDialog("Mood", isPresented: $showMoodPicker, titleVisibility: .visible) {
            ForEach(Mood.allCases, id: \.self) { mood in
                Button("\(mood.emoji) \(mood.label)") {
                    withAnimation { selectedMood = mood }
                }
            }
            if selectedMood != nil {
                Button("Remove Mood", role: .destructive) {
                    withAnimation { selectedMood = nil }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Note?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteAndDismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $pickerItems,
            maxSelectionCount: 5,
            matching: .images
        )
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Auto-sizing TextEditor (내용 만큼만 높이 차지)

    private var autoTextEditor: some View {
        ZStack(alignment: .topLeading) {
            // 숨겨진 Text로 높이를 자동 계산
            Text(text.isEmpty ? " " : text)
                .font(.system(size: 17))
                .foregroundStyle(.clear)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $text)
                .font(.system(size: 17))
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)   // 외부 ScrollView가 담당
                .background(.clear)
                .padding(.horizontal, 16)
                .tint(theme.diaryAccent)
        }
    }

    // MARK: - Inline Images (텍스트 바로 아래 붙음)

    private var inlineImages: some View {
        VStack(spacing: 12) {
            ForEach(images.indices, id: \.self) { i in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: images[i])
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(theme.diaryAccent.opacity(0.3), lineWidth: 1)
                        )

                    Button {
                        images.remove(at: i)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            // 기분
            Button { showMoodPicker = true } label: {
                Image(systemName: selectedMood == nil ? "face.smiling" : "face.smiling.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(selectedMood != nil ? theme.diaryAccent : .primary)
            }

            Spacer()

            // 사진
            Button { showPhotoPicker = true } label: {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(theme.diaryAccent)
            }

            Spacer()

            // 저장 (항상 표시)
            Button { saveAndDismiss() } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isEmpty ? .secondary : theme.diaryAccent)
            }
            .disabled(isEmpty)

            // 삭제 (기존 항목만)
            if entry != nil {
                Spacer()
                Button { showDeleteAlert = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
        .background(
            colorScheme == .dark
                ? Color(white: 0.1).opacity(0.95)
                : theme.diaryCardBackground.opacity(0.95)
        )
    }

    private func shareText() {
        var items: [Any] = []

        // 날짜 + 기분 + 텍스트
        var shareString = ""
        var comps = DateComponents()
        comps.year = dateComps.year; comps.month = dateComps.month; comps.day = dateComps.day
        if let date = Calendar.current.date(from: comps) {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US")
            fmt.dateFormat = "MMMM d, yyyy"
            shareString += fmt.string(from: date) + "\n"
        }
        if let mood = selectedMood {
            shareString += "\(mood.emoji) \(mood.label)\n"
        }
        if !text.isEmpty {
            shareString += "\n" + text
        }
        if !shareString.isEmpty {
            items.append(shareString)
        }

        // 이미지 첨부
        for img in images {
            items.append(img)
        }

        guard !items.isEmpty else { return }
        shareItems = items
        showShareSheet = true
    }

    // MARK: - Load / Save / Delete

    private func loadExisting() {
        guard let e = entry else { return }
        text         = e.text
        selectedMood = e.mood
        images       = e.sortedImages.compactMap { UIImage(data: $0.imageData) }
    }

    private func loadPhotos() {
        Task {
            var loaded: [UIImage] = []
            for item in pickerItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img  = UIImage(data: data) {
                    loaded.append(img)
                }
            }
            images.append(contentsOf: loaded)
            pickerItems = []
        }
    }

    private func autoSave() {
        guard !isEmpty else { return }
        let diaryImages: [DiaryImage] = images.enumerated().compactMap { idx, img in
            guard let data = img.jpegData(compressionQuality: 0.8) else { return nil }
            return DiaryImage(imageData: data, order: idx)
        }
        if let existing = entry {
            for old in existing.images { modelContext.delete(old) }
            existing.text      = text
            existing.mood      = selectedMood
            existing.images    = diaryImages
            existing.themeName = theme.rawValue
            existing.updatedAt = Date()
        } else {
            let newEntry = DiaryEntry(
                year:      dateComps.year,
                month:     dateComps.month,
                day:       dateComps.day,
                text:      text,
                mood:      selectedMood,
                images:    diaryImages,
                themeName: theme.rawValue
            )
            modelContext.insert(newEntry)
        }
        try? modelContext.save()
    }

    private func saveAndDismiss() {
        guard !isEmpty else { dismiss(); return }

        let diaryImages: [DiaryImage] = images.enumerated().compactMap { idx, img in
            guard let data = img.jpegData(compressionQuality: 0.8) else { return nil }
            return DiaryImage(imageData: data, order: idx)
        }

        if let existing = entry {
            for old in existing.images { modelContext.delete(old) }
            existing.text      = text
            existing.mood      = selectedMood
            existing.images    = diaryImages
            existing.themeName = theme.rawValue
            existing.updatedAt = Date()
        } else {
            let newEntry = DiaryEntry(
                year:      dateComps.year,
                month:     dateComps.month,
                day:       dateComps.day,
                text:      text,
                mood:      selectedMood,
                images:    diaryImages,
                themeName: theme.rawValue
            )
            modelContext.insert(newEntry)
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteAndDismiss() {
        guard let existing = entry else { return }
        modelContext.delete(existing)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
