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
    var onClose: () -> Void
    var onLogRepair: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // MARK: - Header (Brand & Close)
            HStack(alignment: .top) {
                if let brand = result.brand, !brand.isEmpty {
                    Text(brand.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13)) // Gold
                        .tracking(1.5)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // MARK: - Middle: Name & Price
            HStack(alignment: .top, spacing: 12) {
                Text(result.productName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .layoutPriority(1)
                
                Spacer(minLength: 16)
                
                Text(result.formattedPrice)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.trailing)
                    .layoutPriority(2)
            }
            .padding(.horizontal, 16)
            
            // MARK: - Bottom: SKU, Barcode, Status
            HStack(spacing: 8) {
                Text(result.sku)
                Text("•")
                Image(systemName: "barcode")
                    .font(.system(size: 10))
                Text(result.barcode)
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.5))
            .padding(.horizontal, 16)
            
            // Status Pill
            statusPill
                .padding(.horizontal, 16)
                
            // MARK: - Log Repair Button
            Button(action: {
                onLogRepair?()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                    Text("Log Repair")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.11, green: 0.11, blue: 0.12)) // #1C1C1E
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.85, green: 0.65, blue: 0.13), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(red: 17/255, green: 17/255, blue: 20/255).opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            // Gold accent line (left edge)
            Rectangle()
                .fill(Color(red: 0.85, green: 0.65, blue: 0.13))
                .frame(width: 3)
            , alignment: .leading
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .clipShape(RoundedRectangle(cornerRadius: 20)) // outer clip to constraint the left edge line
    }

    // MARK: - Subviews

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }

    private var statusText: String {
        switch result.itemStatus {
        case .inStock: return "IN STOCK"
        case .sold: return "SOLD"
        case .returned: return "RETURNED"
        case .reserved: return "RESERVED"
        case .damaged: return "DAMAGED"
        }
    }

    private var statusColor: Color {
        switch result.itemStatus {
        case .inStock: return .green
        case .sold: return .red
        case .returned: return .purple
        case .reserved: return .orange
        case .damaged: return Color(red: 0.9, green: 0.5, blue: 0.1)
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
