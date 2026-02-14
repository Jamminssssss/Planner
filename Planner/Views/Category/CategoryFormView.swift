import SwiftUI
import SwiftData

/// 카테고리 생성 / 수정 폼
/// - `category == nil` → 생성 모드
/// - `category != nil` → 수정 모드
struct CategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    /// 수정 시 기존 카테고리 전달 (nil이면 생성 모드)
    let category: Category?
    
    // MARK: - Form State
    
    @State private var name: String = ""
    @State private var colorHex: String = "#4CAF50"
    @State private var iconName: String = "square.fill"
    
    @State private var showColorPicker = false
    @State private var showIconPicker = false
    
    // MARK: - Preset Colors
    
    private static let presetColors: [(name: String, hex: String)] = [
        ("Green",    "#4CAF50"),
        ("Red",      "#FF0000"),
        ("Blue",     "#3498DB"),
        ("Purple",   "#9B59B6"),
        ("Orange",   "#FF9800"),
        ("Pink",     "#E91E63"),
        ("Teal",     "#00BCD4"),
        ("Brown",    "#795548"),
        ("Yellow",   "#FFC107"),
        ("Indigo",   "#673AB7")
    ]
    
    // MARK: - Preset Icons
    
    private static let presetIcons: [(name: String, symbol: String)] = [
        ("Play",        "play.rectangle.fill"),
        ("Code",        "chevron.code"),
        ("Dumbbell",    "dumbbell.fill"),
        ("Book",        "books.fill"),
        ("Music",       "music.note.fill"),
        ("Pencil",      "pencil.fill"),
        ("Star",        "star.fill"),
        ("Heart",       "heart.fill"),
        ("Brain",       "brain.fill"),
        ("Camera",      "camera.fill"),
        ("Globe",       "globe"),
        ("Person",      "person.fill"),
        ("Leaf",        "leaf.fill"),
        ("Gear",        "gearshape.fill"),
        ("Cloud",       "cloud.fill"),
        ("Cup",         "cup.and.saucer.fill"),
        ("Shopping",    "shoppingbag.fill"),
        ("Game",        "gamecontroller.fill"),
        ("Chat",        "message.fill"),
        ("Square",      "square.fill")
    ]
    
    // MARK: - Computed
    
    private var isEditing: Bool { category != nil }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var navigationTitle: String {
        isEditing ? "Edit Category" : "New Category"
    }
    
    // MARK: - Init
    
    init(category: Category?) {
        self.category = category
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // 미리보기
                previewSection
                
                // 이름 입력
                nameSection
                
                // 색상 선택
                colorSection
                
                // 아이콘 선택
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
                    }
                }
            }
            .onAppear { loadExistingData() }
            .onChange(of: name) { if isEditing { updateCategory() } }
            .onChange(of: colorHex) { if isEditing { updateCategory() } }
            .onChange(of: iconName) { if isEditing { updateCategory() } }
        }
    }
    
    // MARK: - Sections
    
    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                
                VStack(spacing: 10) {
                    // 아이콘 원형 미리보기
                    ZStack {
                        Circle()
                            .fill((Color(hex: colorHex) ?? .green).opacity(0.15))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: iconName)
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: colorHex) ?? .green)
                    }
                    
                    // 이름 미리보기
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
        Section {
            TextField("Category name", text: $name)
                .font(.system(size: 15))
                .submitLabel(.done)
        } header: {
            Text("Name")
        }
    }
    
    private var colorSection: some View {
        Section {
            // 현재 색상 표시
            HStack {
                Text("Color")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Circle()
                    .fill(Color(hex: colorHex) ?? .green)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Preset 색상 그리드
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                spacing: 10
            ) {
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
        } header: {
            Text("Color")
        }
    }
    
    private var iconSection: some View {
        Section {
            // 현재 아이콘 표시
            HStack {
                Text("Icon")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: colorHex) ?? .green)
            }
            
            // Preset 아이콘 그리드
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                spacing: 8
            ) {
                ForEach(Self.presetIcons, id: \.symbol) { icon in
                    Button(action: { iconName = icon.symbol }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(iconName == icon.symbol
                                      ? (Color(hex: colorHex) ?? .green).opacity(0.2)
                                      : Color.secondary.opacity(0.06))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: icon.symbol)
                                .font(.system(size: 20))
                                .foregroundColor(
                                    iconName == icon.symbol
                                    ? (Color(hex: colorHex) ?? .green)
                                    : .secondary
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Icon")
        }
    }
    
    // MARK: - Data Logic
    
    /// 기존 카테고리 데이터 로드 (수정 모드)
    private func loadExistingData() {
        if let cat = category {
            name = cat.name
            colorHex = cat.colorHex
            iconName = cat.iconName
        }
    }
    
    /// 새 카테고리 저장 (생성 모드)
    private func saveCategory() {
        let newCategory = Category(
            name: name.trimmingCharacters(in: .whitespaces),
            colorHex: colorHex,
            iconName: iconName
        )
        
        modelContext.insert(newCategory)
        
        do {
            try modelContext.save()
        } catch {
            print("[CategoryFormView] Failed to save category: \(error)")
            return
        }
        
        dismiss()
    }
    
    /// 기존 카테고리 업데이트 (수정 모드 — onChange마다 호출)
    private func updateCategory() {
        guard let cat = category else { return }
        cat.name = name.trimmingCharacters(in: .whitespaces)
        cat.colorHex = colorHex
        cat.iconName = iconName
        
        do {
            try modelContext.save()
        } catch {
            print("[CategoryFormView] Failed to update category: \(error)")
        }
    }
}


