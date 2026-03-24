//
//  ReserveSheetView.swift
//  RSMS
//
//  Confirmation sheet for reserving a product in boutique.
//

import SwiftUI
import SwiftData

struct ReserveSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let product: Product
    let selectedColor: String
    let selectedSize: String?

    @State private var isProcessing = false
    @State private var reservationConfirmed = false
    @State private var durationDays: Int = 2

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Reserve in Boutique")
                        .font(AppTypography.heading3)
                        .foregroundColor(AppColors.textPrimaryDark)
                    Spacer()
                    // Removed cancel/cross button as per design update
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        
                        // Product Summary
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            ProductArtworkView(
                                imageSource: product.imageList.first ?? product.imageName,
                                fallbackSymbol: "bag.fill",
                                cornerRadius: AppSpacing.radiusMedium
                            )
                            .frame(width: 80, height: 100)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.brand.uppercased())
                                    .font(AppTypography.overline)
                                    .tracking(2)
                                    .foregroundColor(AppColors.accent)
                                
                                Text(product.name)
                                    .font(AppTypography.bodyLarge)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                
                                Text(product.formattedPrice)
                                    .font(AppTypography.priceDisplay)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                    .padding(.top, 4)
                            }
                            Spacer()
                        }
                        
                        // Reservation Details
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("RESERVATION DETAILS")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.textSecondaryDark)
                            
                            VStack(spacing: AppSpacing.sm) {
                                detailRow(icon: "paintpalette", label: "Color", value: selectedColor)
                                if let size = selectedSize {
                                    Divider()
                                    detailRow(icon: "ruler", label: "Size", value: size)
                                }
                                Divider()
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.neutral400)
                                        .frame(width: 20)
                                    Text("Duration")
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                    Spacer()
                                    Picker("Days", selection: $durationDays) {
                                        ForEach(1...7, id: \.self) { day in
                                            Text("\(day) Days").tag(day)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(AppColors.textPrimaryDark)
                                }
                                Divider()
                                detailRow(icon: "building.2", label: "Boutique", value: "Flagship Store")
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.backgroundSecondary)
                            .cornerRadius(AppSpacing.radiusMedium)
                        }
                        
                        // Terms
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondaryDark)
                            
                            Text("By reserving this item, we ensure its availability for you to view in-store for your selected duration. No payment is required until you visit.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                                .lineSpacing(4)
                        }
                        .padding(.top, AppSpacing.sm)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(AppSpacing.screenHorizontal)
                }
                
                // Bottom Action
                VStack {
                    if reservationConfirmed {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.success)
                            Text("Reservation Confirmed")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.success)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColors.success.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        Button(action: handleReservation) {
                            ZStack {
                                if isProcessing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Confirm Reservation")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppColors.accent)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                    }
                }
                .padding(AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.lg)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.neutral400)
                .frame(width: 20)
            
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
        }
    }
    
    private func handleReservation() {
        guard !appState.isGuest else {
            // Guest attempting to reserve, handle auth flow naturally or prompt
            return
        }
        
        isProcessing = true
        
        // Simulate network delay and processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            // Decrement local stock cache to prevent others from over-ordering
            product.stockCount = max(0, product.stockCount - 1)

            let item = ReservationItem(
                remoteId: nil,
                customerEmail: appState.currentUserEmail,
                productId: product.id,
                productName: product.name,
                productBrand: product.brand,
                productImageName: product.imageList.first ?? product.imageName,
                selectedColor: selectedColor,
                selectedSize: selectedSize,
                durationDays: durationDays
            )
            
            modelContext.insert(item)
            try? modelContext.save()
            
            // Sync with Supabase Database
            Task {
                if let clientId = appState.currentUserProfile?.id {
                    let payload = ReservationInsertDTO(
                        clientId: clientId,
                        productId: product.id,
                        storeId: appState.currentStoreId, // Can be nil for normal web customers
                        selectedColor: selectedColor,
                        selectedSize: selectedSize,
                        status: "active",
                        expiresAt: item.expiresAt
                    )
                    do {
                        let dto = try await ReservationService.shared.createReservation(payload)
                        await MainActor.run {
                            item.remoteId = dto.id
                            try? modelContext.save()
                        }
                    } catch {
                        print("Supabase sync failed: \(error)")
                    }
                }
            }
            
            withAnimation {
                isProcessing = false
                reservationConfirmed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
}
