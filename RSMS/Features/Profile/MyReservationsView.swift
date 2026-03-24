//
//  MyReservationsView.swift
//  RSMS
//
//  Displays active and past boutique reservations for the user.
//

import SwiftUI
import SwiftData

struct MyReservationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReservationItem.addedAt, order: .reverse) private var allReservations: [ReservationItem]
    @Query private var allProducts: [Product]

    var userReservations: [ReservationItem] {
        allReservations.filter { $0.customerEmail == appState.currentUserEmail }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundSecondary.ignoresSafeArea()

            if userReservations.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(userReservations) { reservation in
                        if let product = allProducts.first(where: { $0.id == reservation.productId }) {
                            ZStack {
                                ReservationCard(reservation: reservation)
                                NavigationLink(destination: ProductDetailView(product: product)) {
                                    EmptyView()
                                }
                                .opacity(0)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    cancelReservation(reservation)
                                } label: {
                                    Label("Cancel", systemImage: "xmark.circle")
                                }
                                .tint(AppColors.error)
                            }
                        } else {
                            ReservationCard(reservation: reservation)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        cancelReservation(reservation)
                                    } label: {
                                        Label("Cancel", systemImage: "xmark.circle")
                                    }
                                    .tint(AppColors.error)
                                }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .padding(.top, AppSpacing.sm)
            }
        }
        .navigationTitle("My Reservations")
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.neutral400)
            
            Text("No Active Reservations")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)
            
            Text("Items you reserve to view in-store will appear here.")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

private struct ReservationCard: View {
    @Environment(\.modelContext) private var modelContext
    let reservation: ReservationItem

    var body: some View {
        let expired = reservation.isExpired

        HStack(alignment: .top, spacing: AppSpacing.md) {
            ProductArtworkView(
                imageSource: reservation.productImageName,
                fallbackSymbol: "bag.fill",
                cornerRadius: AppSpacing.radiusMedium
            )
            .frame(width: 80, height: 100)
            .opacity(expired ? 0.6 : 1.0)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(reservation.productBrand.uppercased())
                        .font(AppTypography.overline)
                        .tracking(1)
                        .foregroundColor(expired ? AppColors.textSecondaryLight : AppColors.accent)
                    Spacer()
                    
                    statusBadge
                }

                Text(reservation.productName)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(expired ? AppColors.textSecondaryDark : AppColors.textPrimaryDark)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(reservation.selectedColor)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                    
                    if let size = reservation.selectedSize {
                        Circle().fill(AppColors.neutral300).frame(width: 3, height: 3)
                        Text(size)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
                
                if !expired {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(reservation.timeRemainingString)
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.warning)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    private var statusBadge: some View {
        let isExpired = reservation.isExpired
        let label = isExpired ? "EXPIRED" : "ACTIVE"
        let color = isExpired ? AppColors.neutral500 : AppColors.success
        
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

// Global helper for cancellation across MyReservationsView
extension MyReservationsView {
    private func cancelReservation(_ reservation: ReservationItem) {
        if !reservation.isExpired {
            reservation.status = .cancelled
            
            // Restore inventory stock
            if let product = allProducts.first(where: { $0.id == reservation.productId }) {
                product.stockCount += 1
            }
            
            try? modelContext.save()
            
            if let remoteId = reservation.remoteId {
                Task {
                    do {
                        _ = try await ReservationService.shared.updateReservationStatus(id: remoteId, status: "cancelled")
                    } catch {
                        print("Failed to cancel remotely: \(error)")
                    }
                }
            }
        }
    }
}
