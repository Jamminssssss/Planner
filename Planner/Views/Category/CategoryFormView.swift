import SwiftUI
import SwiftData

/// 카테고리 생성 / 수정 폼
struct CategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let category: Category?
    
    // MARK: - Form State
    @State private var name: String = ""
    @State private var colorHex: String = "#4CAF50"
    @State private var iconName: String = "square.fill"
    
    // MARK: - Presets
    private static let presetColors: [(name: String, hex: String)] = [
        ("Green", "#4CAF50"), ("Red", "#FF0000"), ("Blue", "#3498DB"),
        ("Purple", "#9B59B6"), ("Orange", "#FF9800"), ("Pink", "#E91E63"),
        ("Teal", "#00BCD4"), ("Brown", "#795548"), ("Yellow", "#FFC107"),
        ("Indigo", "#673AB7")
    ]
    
    private static let presetIcons: [(name: String, symbol: String)] = [
        ("Play", "play.rectangle.fill"), ("Code", "chevron.code"),
        ("Dumbbell", "dumbbell.fill"), ("Book", "books.fill"),
        ("Music", "music.note.fill"), ("Pencil", "pencil.fill"),
        ("Star", "star.fill"), ("Heart", "heart.fill"),
        ("Brain", "brain.fill"), ("Camera", "camera.fill"),
        ("Globe", "globe"), ("Person", "person.fill"),
        ("Leaf", "leaf.fill"), ("Gear", "gearshape.fill"),
        ("Cloud", "cloud.fill"), ("Cup", "cup.and.saucer.fill"),
        ("Shopping", "shoppingbag.fill"), ("Game", "gamecontroller.fill"),
        ("Chat", "message.fill"), ("Square", "square.fill")
    ]
    
    // MARK: - Computed
    private var isEditing: Bool { category != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var navigationTitle: String { isEditing ? "Edit Category" : "New Category" }
    
    init(category: Category?) {
        self.category = category
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                previewSection
                nameSection
                colorSection
                iconSection
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isEditing {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isEditing {
                        Button("Save") { saveCategory() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isValid ? .green : .secondary)
                            .disabled(!isValid)
                    } else {
                        Button("Done") { dismiss() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
            }
            .onAppear { loadExistingData() }
            // 💡 최적화: 타이핑마다 save()를 호출하지 않고 메모리 객체만 동기화
            .onChange(of: name) { _, newValue in
                if isEditing { category?.name = newValue.trimmingCharacters(in: .whitespaces) }
            }
            .onChange(of: colorHex) { _, newValue in
                if isEditing { category?.colorHex = newValue }
            }
            .onChange(of: iconName) { _, newValue in
                if isEditing { category?.iconName = newValue }
            }
            // 💡 최적화: 화면을 닫을 때 한 번만 디스크에 저장 (성능 대폭 향상)
            .onDisappear {
                if isEditing {
                    try? modelContext.save()
                }
            }
        }
    }
    
    // MARK: - Sections
    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill((Color(hex: colorHex) ?? .green).opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: iconName)
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: colorHex) ?? .green)
                    }
                    if !name.isEmpty {
                        Text(name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: colorHex) ?? .green)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
    }
    
    private var nameSection: some View {
        Section(header: Text("Name")) {
            TextField("Category name", text: $name)
                .font(.system(size: 15))
                .submitLabel(.done)
        }
    }
    
    private var colorSection: some View {
        Section(header: Text("Color")) {
            HStack {
                Text("Color").foregroundColor(.primary)
                Spacer()
                Circle()
                    .fill(Color(hex: colorHex) ?? .green)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(Self.presetColors, id: \.hex) { color in
                    Button(action: { colorHex = color.hex }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: color.hex) ?? .green)
                                .frame(width: 36, height: 36)
                            if colorHex == color.hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var iconSection: some View {
        Section(header: Text("Icon")) {
            HStack {
                Text("Icon").foregroundColor(.primary)
                Spacer()
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: colorHex) ?? .green)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(Self.presetIcons, id: \.symbol) { icon in
                    Button(action: { iconName = icon.symbol }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(iconName == icon.symbol ? (Color(hex: colorHex) ?? .green).opacity(0.2) : Color.secondary.opacity(0.06))
                                .frame(width: 48, height: 48)
                            Image(systemName: icon.symbol)
                                .font(.system(size: 20))
                                .foregroundColor(iconName == icon.symbol ? (Color(hex: colorHex) ?? .green) : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Data Logic
    private func loadExistingData() {
        if let cat = category {
            name = cat.name
            colorHex = cat.colorHex
            iconName = cat.iconName
        }
    }
    
    private func saveCategory() {
        let newCategory = Category(
            name: name.trimmingCharacters(in: .whitespaces),
            colorHex: colorHex,
            iconName: iconName
        )
        modelContext.insert(newCategory)
        
        do { try modelContext.save() }
        catch { print("[CategoryFormView] Failed to save category: \(error)") }
        
        dismiss()
    }
}
