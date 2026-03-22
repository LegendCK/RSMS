//
//  ScannedItemCard.swift
//  RSMS
//
//  Luxury product card displayed after a successful barcode scan.
//  Slides up from bottom with a spring animation.
//
//  CHANGED: added @Environment(AppState.self) and a "Log Repair" CTA
//  at the bottom of the card, visible only when the logged-in user is
//  an inventoryController. Tapping opens RepairIntakeView as a sheet.
//
//  REPLACE the existing ScannedItemCard.swift with this file.
//

import SwiftUI

struct ScannedItemCard: View {

    let result: ScanResult

    @Environment(AppState.self) private var appState
    @State private var showRepairIntake = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Header Strip
            HStack(spacing: AppSpacing.sm) {
                statusPill
                Spacer()
                Text(result.scannedAt.formatted(date: .omitted, time: .shortened))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondaryDark)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)

            Divider().background(Color.white.opacity(0.08))

            // MARK: - Product Detail Row
            HStack(alignment: .center, spacing: AppSpacing.md) {
                productThumbnail

                VStack(alignment: .leading, spacing: 4) {
                    if let brand = result.brand, !brand.isEmpty {
                        Text(brand.uppercased())
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.accent)
                            .tracking(1.5)
                    }
                    Text(result.productName)
                        .font(AppTypography.heading3)
                        .foregroundStyle(AppColors.textPrimaryDark)
                        .lineLimit(2)

                    Text("SKU: \(result.sku)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondaryDark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.07))
                        )
                }

                Spacer()

                Text(result.formattedPrice)
                    .font(AppTypography.heading2)
                    .foregroundStyle(AppColors.textPrimaryDark)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)

            // MARK: - Barcode Footer
            HStack {
                Image(systemName: "barcode")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondaryDark)
                Text(result.barcode)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppColors.textSecondaryDark)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)

            // MARK: - Log Repair CTA (Inventory Controller only)
            if appState.currentUserRole == .inventoryController {
                Divider().background(Color.white.opacity(0.08))

                Button {
                    showRepairIntake = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 12))
                        Text("Log Repair")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xs)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        // Sheet lives on the card so it always has the correct scanResult
        .sheet(isPresented: $showRepairIntake) {
            RepairIntakeView(
                scanResult:       result,
                storeId:          appState.currentStoreId ?? UUID(),
                assignedToUserId: appState.currentUserProfile?.id
            )
            .environment(appState)
        }
    }

    // MARK: - Subviews

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle().fill(statusColor).frame(width: 6, height: 6)
            Text(result.itemStatus.displayName)
                .font(AppTypography.caption)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(statusColor.opacity(0.15)))
    }

    private var statusColor: Color {
        switch result.itemStatus {
        case .inStock:  return .green
        case .reserved: return .orange
        case .sold:     return .red
        case .damaged:  return Color(red: 0.9, green: 0.5, blue: 0.1)
        case .returned: return .purple
        }
    }

    @ViewBuilder
    private var productThumbnail: some View {
        Group {
            if let urlStr = result.imageUrls?.first,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
            Image(systemName: "photo")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textSecondaryDark)
        }
    }
}
