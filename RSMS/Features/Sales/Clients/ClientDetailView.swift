//
//  ClientDetailView.swift
//  infosys2
//

import SwiftUI

struct ClientDetailView: View {
    let client: ClientDTO
    
    // Parse preferences from notes if present
    private var blob: ClientNotesBlob {
        ClientNotesBlob.from(jsonString: client.notes)
    }
    
    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    
                    // Profile Header Card
                    VStack(spacing: AppSpacing.md) {
                        Circle()
                            .fill(AppColors.accent.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(client.initials)
                                    .font(AppTypography.heading2)
                                    .foregroundColor(AppColors.accent)
                            )
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text(client.fullName)
                                .font(AppTypography.heading2)
                                .foregroundColor(AppColors.textPrimaryDark)
                            
                            if let segment = client.segment, !segment.isEmpty {
                                Text(segment.capitalized.replacingOccurrences(of: "_", with: " "))
                                    .font(AppTypography.micro)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, AppSpacing.xxs)
                                    .background(segmentBadgeColor(segment))
                                    .foregroundColor(segmentBadgeTextColor(segment))
                                    .cornerRadius(AppSpacing.radiusSmall)
                            }
                        }
                    }
                    .padding(.top, AppSpacing.lg)
                    
                    // Contact Info
                    LuxuryCardView {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            contactRow(icon: "envelope", text: client.email)
                            if let phone = client.phone {
                                GoldDivider()
                                contactRow(icon: "phone", text: phone)
                            }
                            if let city = client.city, let country = client.country {
                                GoldDivider()
                                contactRow(icon: "mappin.and.ellipse", text: "\(city), \(country)")
                            }
                        }
                        .padding(AppSpacing.cardPadding)
                    }
                    
                    // Specific Sections from blob
                    
                    if !blob.preferences.preferredCategories.isEmpty || !blob.preferences.preferredBrands.isEmpty {
                        sectionHeader("PREFERENCES")
                        LuxuryCardView {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                if !blob.preferences.preferredCategories.isEmpty {
                                    Text("Categories:")
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    FlowLayout(spacing: AppSpacing.xs) {
                                        ForEach(blob.preferences.preferredCategories, id: \.self) { cat in
                                            Text(cat)
                                                .font(AppTypography.caption)
                                                .padding(.horizontal, AppSpacing.sm)
                                                .padding(.vertical, AppSpacing.xs)
                                                .background(AppColors.backgroundSecondary)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                                .cornerRadius(AppSpacing.radiusSmall)
                                        }
                                    }
                                }
                                
                                if !blob.preferences.preferredCategories.isEmpty && !blob.preferences.preferredBrands.isEmpty {
                                    GoldDivider().padding(.vertical, AppSpacing.xs)
                                }
                                
                                if !blob.preferences.preferredBrands.isEmpty {
                                    Text("Brands:")
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    FlowLayout(spacing: AppSpacing.xs) {
                                        ForEach(blob.preferences.preferredBrands, id: \.self) { brand in
                                            Text(brand)
                                                .font(AppTypography.caption)
                                                .padding(.horizontal, AppSpacing.sm)
                                                .padding(.vertical, AppSpacing.xs)
                                                .background(AppColors.accent)
                                                .foregroundColor(.white)
                                                .cornerRadius(AppSpacing.radiusSmall)
                                        }
                                    }
                                }
                                
                                Text("Prefers: " + blob.preferences.communicationPreference)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                    .padding(.top, AppSpacing.xs)
                            }
                            .padding(AppSpacing.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    if hasSizes(blob.sizes) {
                        sectionHeader("SIZES")
                        LuxuryCardView {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                sizeRow("Ring", blob.sizes.ring)
                                sizeRow("Wrist", blob.sizes.wrist)
                                sizeRow("Shoe", blob.sizes.shoe)
                                sizeRow("Dress/Suit", blob.sizes.dress)
                                sizeRow("Jacket", blob.sizes.jacket)
                            }
                            .padding(AppSpacing.cardPadding)
                        }
                    }
                    
                    if !blob.anniversaries.isEmpty {
                        sectionHeader("ANNIVERSARIES")
                        LuxuryCardView {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                ForEach(blob.anniversaries) { anniv in
                                    HStack {
                                        Text(anniv.label)
                                            .font(AppTypography.bodyMedium)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                        Spacer()
                                        Text(anniv.date)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                    }
                                    if anniv.id != blob.anniversaries.last?.id {
                                        GoldDivider().padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding(AppSpacing.cardPadding)
                        }
                    }
                    
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("CLIENT PROFILE")
                    .font(AppTypography.overline)
                    .tracking(2)
                    .foregroundColor(AppColors.accent)
            }
        }
    }
    
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .frame(width: 20)
            Text(text)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
        }
    }
    
    private func sizeRow(_ label: String, _ value: String) -> some View {
        Group {
            if !value.isEmpty {
                HStack {
                    Text(label)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Spacer()
                    Text(value)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
    }
    
    private func hasSizes(_ sizes: ClientSizes) -> Bool {
        return !sizes.ring.isEmpty || !sizes.wrist.isEmpty || !sizes.shoe.isEmpty || !sizes.dress.isEmpty || !sizes.jacket.isEmpty
    }
    
    private func segmentBadgeColor(_ segment: String?) -> Color {
        guard let segment = segment else { return AppColors.neutral300 }
        switch segment.lowercased() {
        case "vip", "ultra_vip": return AppColors.accent
        case "gold": return AppColors.accent.opacity(0.8)
        case "silver": return AppColors.neutral500
        default: return AppColors.backgroundSecondary
        }
    }
    
    private func segmentBadgeTextColor(_ segment: String?) -> Color {
        guard let segment = segment else { return AppColors.textPrimaryDark }
        switch segment.lowercased() {
        case "vip", "ultra_vip", "gold", "silver": return .white
        default: return AppColors.textPrimaryDark
        }
    }
}
