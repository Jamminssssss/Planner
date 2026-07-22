import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Diary Editor View (iOS Notes Style + Theme + Lock)

struct DiaryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.colorScheme)  private var colorScheme
    @Environment(\.scenePhase)   private var scenePhase

    let entry: DiaryEntry?
    let theme: SeasonTheme

    // MARK: - Lock & Premium
    @ObservedObject private var lockManager  = DiaryLockManager.shared
    @ObservedObject private var storeManager = StoreKitManager.shared

    @State private var isLocked          = false
    @State private var showLockOverlay   = false
    @State private var isLockProcessing  = false
    @State private var lockErrorMessage: String?
    @State private var showLockError     = false

    // MARK: - Editor State
    @State private var text:          String    = ""
    @State private var selectedMood:  Mood?     = nil
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
        fmt.locale     = Locale(identifier: "en_US")
        fmt.dateFormat = "MMMM d, yyyy  h:mm a"
        return fmt.string(from: entry?.updatedAt ?? date)
    }

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && images.isEmpty
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: theme)

            VStack(spacing: 0) {
                // Date header
                HStack {
                    Text(formattedDate)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()

                    Button(action: { dismiss() }) {
                        Text(theme.icon).font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close without saving")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Mood badge
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

                // Scroll area
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if !images.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            inlineImages
                        }
                        autoTextEditor
                        if !images.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            inlineImages
                        }
                        Spacer(minLength: 40)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editorFocused = true }
                }

                Divider().background(theme.diaryAccent.opacity(0.3))
                bottomToolbar
            }

            // Lock Overlay (이제 무료 사용자도 접근 가능)
            if showLockOverlay {
                DiaryLockOverlayView(theme: theme) {
                    guard let existing = entry else { return }
                    let result = try await lockManager.unlockEntry(existing)
                    text   = result.text
                    images = result.imageDatas.compactMap { UIImage(data: $0) }
                    withAnimation(.easeOut(duration: 0.25)) {
                        showLockOverlay = false
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExisting() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let e = entry, e.isLocked else { return }
            if !showLockOverlay, !lockManager.isSessionUnlocked(for: e) {
                text = ""
                images = []
                editorFocused = false
                withAnimation(.easeOut(duration: 0.25)) { showLockOverlay = true }
            }
        }
        .onChange(of: pickerItems) { _, _ in loadPhotos() }
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
        .alert("Lock Error", isPresented: $showLockError, presenting: lockErrorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection:   $pickerItems,
            maxSelectionCount: 5,
            matching: .images
        )
        .fullScreenCover(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Auto-sizing TextEditor
    private var autoTextEditor: some View {
        ZStack(alignment: .topLeading) {
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
                .scrollDisabled(true)
                .background(.clear)
                .padding(.horizontal, 16)
                .tint(theme.diaryAccent)
        }
    }

    // MARK: - Inline Images
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
            // Mood
            Button { showMoodPicker = true } label: {
                Image(systemName: selectedMood == nil ? "face.smiling" : "face.smiling.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(selectedMood != nil ? theme.diaryAccent : .primary)
            }

            Spacer()

            // Lock (누구나 자유롭게 잠금 설정 가능)
            LockStatusBadge(
                isLocked:    isLocked,
                accentColor: theme.diaryAccent,
                onTap:       handleLockTap
            )

            Spacer()

            // Photo
            Button { showPhotoPicker = true } label: {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(theme.diaryAccent)
            }

            Spacer()

            // Save
            Button { saveAndDismiss() } label: {
                if isLockProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(theme.diaryAccent)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(isEmpty ? .secondary : theme.diaryAccent)
                }
            }
            .disabled(isEmpty || isLockProcessing)

            // Delete
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

    // MARK: - Lock Tap Handler
    private func handleLockTap() {
        if isLocked {
            Task { await removeLockFromEntry() }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isLocked = true
            }
        }
    }

    private func removeLockFromEntry() async {
        guard let existing = entry else {
            withAnimation { isLocked = false }
            return
        }
        do {
            isLockProcessing = true
            try await lockManager.removeLock(from: existing, in: modelContext)
            withAnimation { isLocked = false }
        } catch LockError.userCancelled {
        } catch {
            lockErrorMessage = error.localizedDescription
            showLockError    = true
        }
        isLockProcessing = false
    }

    // MARK: - Load / Save / Delete
    private func loadExisting() {
        guard let e = entry else { return }

        selectedMood = e.mood
        isLocked     = e.isLocked

        if e.isLocked {
            withAnimation { showLockOverlay = true }
        } else {
            text   = e.text
            images = e.sortedImages.compactMap { UIImage(data: $0.imageData) }
        }
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

    private func saveAndDismiss() {
        guard !isEmpty else { dismiss(); return }
        isLockProcessing = true

        let imageDataList: [Data] = images.compactMap {
            $0.jpegData(compressionQuality: 0.8)
        }

        do {
            if let existing = entry {
                existing.mood      = selectedMood
                existing.themeName = theme.rawValue
                existing.updatedAt = Date()

                if isLocked {
                    let diaryImages = buildDiaryImages(from: imageDataList, encrypting: false)
                    // 💡 옵셔널 배열을 풀어서 for 루프 실행
                    for old in existing.images ?? [] { modelContext.delete(old) }
                    existing.images = diaryImages

                    try lockManager.reEncryptEntry(
                        existing,
                        newText:          text,
                        newImageDataList: imageDataList,
                        in:               modelContext
                    )
                } else {
                    let diaryImages = buildDiaryImages(from: imageDataList, encrypting: false)
                    // 💡 옵셔널 배열을 풀어서 for 루프 실행
                    for old in existing.images ?? [] { modelContext.delete(old) }
                    existing.text   = text
                    existing.images = diaryImages
                    existing.isLocked     = false
                    existing.encryptedText = nil
                    try? modelContext.save()
                }

            } else {
                let diaryImages = buildDiaryImages(from: imageDataList, encrypting: false)
                let newEntry = DiaryEntry(
                    year:      dateComps.year,
                    month:     dateComps.month,
                    day:       dateComps.day,
                    text:      isLocked ? "" : text,
                    mood:      selectedMood,
                    images:    diaryImages,
                    themeName: theme.rawValue,
                    isLocked:  isLocked
                )
                modelContext.insert(newEntry)

                if isLocked {
                    try lockManager.prepareNewLockedEntry(
                        newEntry,
                        text:          text,
                        imageDataList: imageDataList
                    )
                }
                try modelContext.save()
            }

            isLockProcessing = false
            dismiss()

        } catch {
            isLockProcessing = false
            lockErrorMessage = error.localizedDescription
            showLockError    = true
        }
    }

    private func buildDiaryImages(from dataList: [Data], encrypting: Bool) -> [DiaryImage] {
        dataList.enumerated().map { idx, data in
            DiaryImage(imageData: encrypting ? Data() : data, order: idx)
        }
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
