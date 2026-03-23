//
//  PaymentMethodsView.swift
//  RSMS
//
//  Lists the current user's saved payment cards.
//  Allows adding, removing, and setting a default card.
//  Card numbers are never stored — only last 4 digits and metadata.
//

import SwiftUI
import SwiftData

struct PaymentMethodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var allCards: [SavedPaymentCard]

    @State private var showAddCard = false

    private var cards: [SavedPaymentCard] {
        allCards
            .filter { $0.customerEmail == appState.currentUserEmail }
            .sorted { $0.isDefault && !$1.isDefault }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if cards.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(cards) { card in
                            cardRow(card)
                        }
                        addButton
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.lg)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Payment Methods")
                    .font(AppTypography.navTitle)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddCard = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showAddCard) {
            AddCardView()
        }
    }

    // MARK: - Card row

    private func cardRow(_ card: SavedPaymentCard) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {

            // Brand badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(card.isDefault ? AppColors.accent.opacity(0.12) : AppColors.backgroundTertiary)
                    .frame(width: 56, height: 38)
                Text(card.brandInitials)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(card.isDefault ? AppColors.accent : AppColors.textSecondaryDark)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Masked number + default badge
                HStack(spacing: AppSpacing.xs) {
                    Text(card.maskedNumber)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.textPrimaryDark)
                    if card.isDefault {
                        Text("DEFAULT")
                            .font(AppTypography.pico)
                            .tracking(1)
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accent.opacity(0.1))
                            .cornerRadius(4)
                    }
                    if card.isExpired {
                        Text("EXPIRED")
                            .font(AppTypography.pico)
                            .tracking(1)
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.error.opacity(0.08))
                            .cornerRadius(4)
                    }
                }

                // Name + expiry
                HStack(spacing: 6) {
                    Text(card.cardHolderName)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text("·")
                        .foregroundColor(AppColors.neutral600)
                    Text(card.expiryLabel)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(card.isExpired ? AppColors.error : AppColors.textSecondaryDark)
                }

                // Actions
                HStack(spacing: AppSpacing.md) {
                    if !card.isDefault {
                        Button("Set Default") {
                            withAnimation {
                                cards.forEach { $0.isDefault = false }
                                card.isDefault = true
                                try? modelContext.save()
                            }
                        }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.accent)
                    }
                    Button("Remove") {
                        withAnimation {
                            modelContext.delete(card)
                            try? modelContext.save()
                        }
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .stroke(
                    card.isDefault ? AppColors.accent.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "creditcard")
                .font(AppTypography.iconDecorative)
                .foregroundColor(AppColors.neutral600)
            VStack(spacing: AppSpacing.xs) {
                Text("No Payment Methods")
                    .font(AppTypography.heading2)
                    .foregroundColor(AppColors.textPrimaryDark)
                Text("Add a card to speed up checkout")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
            PrimaryButton(title: "Add Card") { showAddCard = true }
                .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: - Add button

    private var addButton: some View {
        Button { showAddCard = true } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(AppColors.accent)
                Text("Add New Card")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.accent)
                Spacer()
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .strokeBorder(
                        AppColors.accent.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
            )
        }
    }
}
