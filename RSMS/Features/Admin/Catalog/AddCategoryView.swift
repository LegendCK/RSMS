//
//  AddCategoryView.swift
//  RSMS
//
//  Sheet for creating a new product category.
//  Saves to Supabase `categories` table and SwiftData.
//

import SwiftUI
import SwiftData

// MARK: - Available Icons for Categories

private let categoryIcons: [(symbol: String, label: String)] = [
    ("bag.fill",              "Bags"),
    ("sparkles",              "Jewelry"),
    ("clock.fill",            "Watches"),
    ("tshirt.fill",           "Clothing"),
    ("shoe.fill",             "Shoes"),
    ("glasses",               "Eyewear"),
    ("crown.fill",            "Premium"),
    ("star.fill",             "Featured"),
    ("tag.fill",              "General"),
    ("gift.fill",             "Gifts"),
    ("leaf.fill",             "Beauty"),
    ("camera.fill",           "Electronics"),
    ("house.fill",            "Home"),
    ("cart.fill",             "Accessories"),
    ("cube.fill",             "Other"),
]

// MARK: - View

struct AddCategoryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Form state
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedIcon: String = "tag.fill"
    @State private var isActive: Bool = true

    // UI state
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {

                        // MARK: Icon picker
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            sectionHeader("Category Icon")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(categoryIcons, id: \.symbol) { item in
                                        iconCell(item)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                            }
                        }

                        // MARK: Name
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            sectionHeader("Name *")
                            TextField("e.g. Handbags, Fine Watches…", text: $name)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .padding(AppSpacing.sm)
                                .background(AppColors.backgroundSecondary)
                                .cornerRadius(AppSpacing.radiusMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                        .stroke(name.isEmpty ? AppColors.border : AppColors.accent.opacity(0.6), lineWidth: 1)
                                )
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                        }

                        // MARK: Description
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            sectionHeader("Description")
                            TextField("Short description of this category", text: $description, axis: .vertical)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimaryDark)
                                .lineLimit(3...5)
                                .padding(AppSpacing.sm)
                                .background(AppColors.backgroundSecondary)
                                .cornerRadius(AppSpacing.radiusMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                                .padding(.horizontal, AppSpacing.screenHorizontal)
                        }

                        // MARK: Active toggle
                        HStack {
                            Text("Active")
                                .font(AppTypography.label)
                                .foregroundColor(AppColors.textPrimaryDark)
                            Spacer()
                            Toggle("", isOn: $isActive)
                                .tint(AppColors.accent)
                        }
                        .padding(AppSpacing.sm)
                        .background(AppColors.backgroundSecondary)
                        .cornerRadius(AppSpacing.radiusMedium)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        // Error banner
                        if let err = errorMessage {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.error)
                                Text(err)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.error)
                            }
                            .padding(AppSpacing.sm)
                            .background(AppColors.error.opacity(0.1))
                            .cornerRadius(AppSpacing.radiusMedium)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }

                        // MARK: Save button
                        Button(action: save) {
                            HStack(spacing: AppSpacing.xs) {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "checkmark")
                                    Text("Create Category")
                                }
                            }
                            .font(AppTypography.buttonPrimary)
                            .foregroundColor(AppColors.textPrimaryLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.accent.opacity(0.4) : AppColors.accent)
                            .cornerRadius(AppSpacing.radiusMedium)
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                    .padding(.top, AppSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Category")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(AppTypography.buttonSecondary)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Subviews

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .foregroundColor(AppColors.textSecondaryDark)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func iconCell(_ item: (symbol: String, label: String)) -> some View {
        let selected = selectedIcon == item.symbol
        return Button(action: { selectedIcon = item.symbol }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selected ? AppColors.accent : AppColors.backgroundSecondary)
                        .frame(width: 52, height: 52)
                    Image(systemName: item.symbol)
                        .font(AppTypography.iconMedium)
                        .foregroundColor(selected ? AppColors.primary : AppColors.neutral500)
                }
                Text(item.label)
                    .font(AppTypography.pico)
                    .foregroundColor(selected ? AppColors.accent : AppColors.textSecondaryDark)
            }
        }
    }

    // MARK: - Save Logic

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                // 1. Save to Supabase
                let dto = try await CatalogService.shared.createCategory(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespaces),
                    isActive: isActive
                )
                print("[AddCategoryView] Created category in Supabase: \(dto.id)")

                // 2. Also persist to local SwiftData for immediate UI refresh
                let localCategory = Category(
                    name: trimmedName,
                    icon: selectedIcon,
                    description: description.trimmingCharacters(in: .whitespaces),
                    displayOrder: 0
                )
                modelContext.insert(localCategory)
                try? modelContext.save()

                dismiss()
            } catch {
                print("[AddCategoryView] Error: \(error)")
                // If Supabase fails (e.g. no network), still save locally
                let localCategory = Category(
                    name: trimmedName,
                    icon: selectedIcon,
                    description: description.trimmingCharacters(in: .whitespaces),
                    displayOrder: 0
                )
                modelContext.insert(localCategory)
                try? modelContext.save()
                errorMessage = "Saved locally. Supabase sync failed: \(error.localizedDescription)"
                isSaving = false
                // Still dismiss after a short delay so user sees the message
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            }
        }
    }
}

#Preview {
    AddCategoryView()
        .modelContainer(for: [Category.self, Product.self], inMemory: true)
}
