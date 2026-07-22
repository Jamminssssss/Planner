import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.createdAt)
    private var categories: [Category]
    
    @State private var showAddCategory = false
    @State private var categoryToDelete: Category? = nil
    @State private var showDeleteConfirm = false
    
    var body: some View {
        NavigationStack {
            List {
                if categories.isEmpty {
                    emptyState
                } else {
                    ForEach(categories) { category in
                        NavigationLink {
                            CategoryFormView(category: category)
                        } label: {
                            categoryRow(category)
                        }
                    }
                    .onDelete(perform: deleteCategories)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddCategory = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
            .fullScreenCover(isPresented: $showAddCategory) {
                CategoryFormView(category: nil)
            }
            .confirmationDialog(
                "Delete \"\(categoryToDelete?.name ?? "")\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let cat = categoryToDelete {
                        deleteCategory(cat)
                    }
                    categoryToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
            } message: {
                Text("All plans in this category will also be deleted.")
            }
        }
    }
    
    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: category.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(category.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                let planCount = category.plans?.count ?? 0
                Text("\(planCount) plan\(planCount == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 36))
                .foregroundColor(.green.opacity(0.3))
            
            Text("No categories yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Text("Create a category to organize your plans.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showAddCategory = true }) {
                Text("+ Create Category")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.green)
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
    
    // MARK: - Delete
    
    private func deleteCategories(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        categoryToDelete = categories[index]
        showDeleteConfirm = true
    }
    
    private func deleteCategory(_ category: Category) {
        var eventIds: [String] = []
        
        // 💡 버그 수정: 경고창(All plans will also be deleted)의 내용과 실제 로직을 일치시킴.
        // 연결된 Plan들을 먼저 모두 명시적으로 삭제하여 고아 데이터(Orphaned Data) 방지.
        if let plans = category.plans {
            for plan in plans {
                NotificationService.shared.cancel(planId: plan.id)
                if let eventId = plan.eventIdentifier { eventIds.append(eventId) }
                
                // 플랜 자체를 모델 컨텍스트에서 명시적 삭제
                modelContext.delete(plan)
            }
        }
        
        modelContext.delete(category)
        
        do {
            try modelContext.save()
        } catch {
            print("[CategoryListView] Failed to delete category: \(error)")
        }
        
        // 💡 최적화: 캘린더 이벤트 삭제를 하나의 Task 블록 안에서 일괄 처리
        if !eventIds.isEmpty {
            Task {
                for eid in eventIds {
                    await CalendarService.shared.deleteEvent(identifier: eid)
                }
            }
        }
    }
}
