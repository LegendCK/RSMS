//
//  RecentScansListView.swift
//  RSMS
//
//  Displays a chronological list of recent scans in a premium dark-themed scroll view.
//  Includes auto-scroll and highlight animations for duplicate scan attempts.
//

import SwiftUI

struct RecentScansListView: View {
    @Bindable var viewModel: ScannerViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.recentScans) { scan in
                        RecentScanRowView(
                            result: scan,
                            isHighlighted: scan.id == viewModel.highlightedScanId
                        )
                        .id(scan.id)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
            .onChange(of: viewModel.recentScans.first?.id) { _, newId in
                if let newId = newId {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        proxy.scrollTo(newId, anchor: .top)
                    }
                }
            }
            .onChange(of: viewModel.highlightedScanId) { _, highlightedId in
                if let highlightedId = highlightedId {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        proxy.scrollTo(highlightedId, anchor: .center)
                    }
                }
            }
        }
    }
}

struct RecentScanRowView: View {
    let result: ScanResult
    let isHighlighted: Bool
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Left: Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // Middle: Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.productName)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimaryDark)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("SKU: \(result.sku)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondaryDark)
                    
                    Text("•")
                        .foregroundStyle(Color.white.opacity(0.2))
                    
                    Text(result.itemStatus.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(statusColor.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Right: Price
            Text(result.formattedPrice)
                .font(AppTypography.heading3)
                .foregroundStyle(AppColors.textPrimaryDark)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isHighlighted ? AppColors.accent.opacity(0.8) : Color.white.opacity(0.08),
                            lineWidth: isHighlighted ? 1.5 : 1
                        )
                )
        )
        .scaleEffect(isHighlighted ? 1.03 : 1.0)
        .shadow(color: isHighlighted ? AppColors.accent.opacity(0.3) : .clear, radius: 8, x: 0, y: 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
    }
    
    private var statusColor: Color {
        switch result.itemStatus {
        case .inStock:  return .green
        case .reserved: return .orange
        case .sold:     return .red
        case .damaged:  return Color(red: 0.9, green: 0.5, blue: 0.1)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        // Dummy data for preview requires a mocked ScannerViewModel which we'll skip for brevity
        Text("RecentScansListView Preview")
            .foregroundStyle(.white)
    }
}
