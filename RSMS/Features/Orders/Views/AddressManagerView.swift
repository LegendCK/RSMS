//
//  AddressManagerView.swift
//  RSMS
//
//  Lists all saved addresses for the current user.
//  Allows setting default, editing, deleting, and adding new addresses.
//

import SwiftUI
import SwiftData

struct AddressManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Query private var allAddresses: [SavedAddress]

    var onSelect: ((SavedAddress) -> Void)? = nil

    @State private var showAddNew  = false
    @State private var editAddress: SavedAddress? = nil

    private var addresses: [SavedAddress] {
        allAddresses
            .filter { $0.customerEmail == appState.currentUserEmail }
            .sorted { $0.isDefault && !$1.isDefault }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if addresses.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppSpacing.sm) {
                            ForEach(addresses) { address in
                                addressCard(address)
                            }
                            addNewButton
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.vertical, AppSpacing.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Saved Addresses")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddNew = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddNew) {
                AddressEditView()
            }
            .sheet(item: $editAddress) { addr in
                AddressEditView(address: addr)
            }
        }
    }

    // MARK: - Address Card

    private func addressCard(_ address: SavedAddress) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(address.isDefault ? AppColors.accent.opacity(0.12) : AppColors.backgroundSecondary)
                    .frame(width: 44, height: 44)
                Image(systemName: labelIcon(address.label))
                    .font(.system(size: 18))
                    .foregroundColor(address.isDefault ? AppColors.accent : AppColors.neutral600)
            }

            // Info
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(address.label)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                    if address.isDefault {
                        Text("DEFAULT")
                            .font(AppTypography.pico)
                            .tracking(1)
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppColors.accent.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                Text(address.line1)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)
                if !address.line2.isEmpty {
                    Text(address.line2)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                Text("\(address.city), \(address.state) \(address.zip)")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondaryDark)

                // Actions
                HStack(spacing: AppSpacing.md) {
                    if !address.isDefault {
                        Button("Set Default") {
                            withAnimation {
                                // Clear all defaults first
                                addresses.forEach { $0.isDefault = false }
                                address.isDefault = true
                                try? modelContext.save()
                            }
                        }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                    }
                    Button("Edit") { editAddress = address }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)

                    Button("Remove") {
                        withAnimation {
                            modelContext.delete(address)
                            try? modelContext.save()
                        }
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
                }
                .padding(.top, 4)
            }

            Spacer()

            // Select (when used as picker)
            if let onSelect {
                Button(action: { onSelect(address); dismiss() }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(address.isDefault ? AppColors.accent.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "mappin.and.ellipse")
                .font(AppTypography.iconDecorative)
                .foregroundColor(AppColors.neutral600)
            VStack(spacing: AppSpacing.xs) {
                Text("No Saved Addresses")
                    .font(AppTypography.heading2)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("Add an address to speed up checkout")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
            PrimaryButton(title: "Add Address") { showAddNew = true }
                .padding(.horizontal, 40)
        }
        .padding()
    }

    private var addNewButton: some View {
        Button(action: { showAddNew = true }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(AppColors.accent)
                Text("Add New Address")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.accent)
                Spacer()
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
    }

    private func labelIcon(_ l: String) -> String {
        switch l {
        case "Home": return "house.fill"
        case "Work": return "briefcase.fill"
        default:     return "mappin.circle.fill"
        }
    }
}
