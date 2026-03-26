//
//  ScannedItemCard.swift
//  RSMS — Premium Redesign v3
//
//  Luxury product card displayed after a successful barcode scan.
//  Slides up from bottom with a spring animation.
//
//  FIX v3:
//  - Replace .ultraThinMaterial with solid dark card for readability in bright light
//  - Stronger typography hierarchy: brand (gold), name (bold large), price (large right)
//  - Status badge: filled pill with color background
//  - Accept onRepairTap callback so ScannerViewModel.cancelAutoDismiss() fires
//    before the repair sheet opens, preventing the race condition.
//

import SwiftUI

struct ScannedItemCard: View {

    let result: ScanResult
    /// Called when "Log Repair" is tapped — before the sheet opens.
    /// Used to cancel the auto-dismiss timer in ScannerViewModel.
    var onRepairTap: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @State private var showRepairIntake = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Header Strip
            HStack(spacing: 8) {
                statusPill
                Spacer()
                Text(result.scannedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Hairline divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)

            // MARK: - Product Detail Row
            HStack(alignment: .center, spacing: 14) {
                productThumbnail

                VStack(alignment: .leading, spacing: 5) {
                    if let brand = result.brand, !brand.isEmpty {
                        Text(brand.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                            .foregroundStyle(AppColors.accent)
                    }
                    Text(result.productName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("SKU: \(result.sku)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.38))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.06))
                        )
                }

                Spacer()

                // Price — large, right-aligned, accented gold
                Text(result.formattedPrice)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.accent)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // MARK: - Barcode Footer
            HStack(spacing: 6) {
                Image(systemName: "barcode")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.3))
                Text(result.barcode)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // MARK: - Log Repair CTA (Inventory Controller only)
            if appState.currentUserRole == .inventoryController {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)

                Button {
                    // 1. Cancel the auto-dismiss timer FIRST to prevent race condition
                    onRepairTap?()
                    // 2. Then open the sheet
                    showRepairIntake = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 13))
                        Text("Log Repair")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(AppColors.accent.opacity(0.08))
                }
                .padding(.horizontal, 0)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.10, green: 0.09, blue: 0.12))           // Solid dark card
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)    // Subtle border
                )
                .shadow(color: Color.black.opacity(0.55), radius: 20, y: 8) // Strong shadow for depth
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .sheet(isPresented: $showRepairIntake) {
            RepairIntakeView(
                scanResult:       result,
                storeId:          appState.currentStoreId ?? UUID(),
                assignedToUserId: appState.currentUserProfile?.id
            )
            .environment(appState)
        }
    }

    // MARK: - Status Pill (filled, not outline)

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
            Text(result.itemStatus.displayName.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.18))
                .overlay(
                    Capsule().stroke(statusColor.opacity(0.35), lineWidth: 0.75)
                )
        )
    }

    private var statusColor: Color {
        switch result.itemStatus {
        case .inStock:  return Color(red: 0.2, green: 0.85, blue: 0.5)   // Vibrant green
        case .reserved: return Color(red: 1.0, green: 0.65, blue: 0.15)  // Warm amber
        case .sold:     return Color(red: 1.0, green: 0.35, blue: 0.35)  // Soft red
        case .damaged:  return Color(red: 0.9, green: 0.5, blue: 0.1)    // Orange
        case .returned: return Color(red: 0.65, green: 0.45, blue: 1.0)  // Purple
        }
    }

    // MARK: - Product Thumbnail

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
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.white.opacity(0.2))
        }
    }
}
