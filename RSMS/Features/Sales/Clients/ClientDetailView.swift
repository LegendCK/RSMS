//
//  ClientDetailView.swift
//  RSMS
//
//  Full client history dashboard for Sales Associates.
//  Tabs: Profile (editable) · Purchases · Appointments · After-Sales
//

import SwiftUI

struct ClientDetailView: View {
    @State private var vm: ClientDetailViewModel
    @State private var selectedTab = 0
    @State private var selectedAppointment: AppointmentDTO?
    @State private var selectedOrder: OrderDTO?
    @State private var selectedServiceTicket: ServiceTicketDTO?
    private let tabs = ["Profile", "Purchases", "Appointments", "After-Sales"]

    init(client: ClientDTO) {
        _vm = State(initialValue: ClientDetailViewModel(client: client))
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                clientHeader
                tabBar
                TabView(selection: $selectedTab) {
                    profileTab.tag(0)
                    purchasesTab.tag(1)
                    appointmentsTab.tag(2)
                    afterSalesTab.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
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
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == 0 {
                    Button(vm.isEditing ? "Cancel" : "Edit") {
                        if vm.isEditing { vm.cancelEditing() } else { vm.startEditing() }
                    }
                    .font(AppTypography.buttonSecondary)
                    .foregroundColor(AppColors.accent)
                }
            }
        }
        .task { await vm.loadHistory() }
        .alert("Save Failed", isPresented: $vm.showSaveError) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.saveErrorMessage) }
        .alert("Saved", isPresented: $vm.showSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: { Text("Client profile updated successfully.") }
        .sheet(isPresented: $vm.isEditing) {
            ClientEditView(vm: vm)
        }
        .sheet(item: $selectedAppointment) { appt in
            CreateAppointmentView(appointmentToEdit: appt) { _ in
                Task { await vm.loadHistory() }
            }
        }
        .sheet(item: $selectedOrder) { order in
            SalesClientOrderDetailSheet(order: order)
        }
        .sheet(item: $selectedServiceTicket) { ticket in
            RepairTicketDetailView(ticket: ticket)
        }
    }

    // MARK: - Header

    private var clientHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(vm.client.initials)
                            .font(AppTypography.heading2)
                            .foregroundColor(AppColors.accent)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.client.fullName)
                        .font(AppTypography.heading2)
                        .foregroundColor(AppColors.textPrimaryDark)
                    HStack(spacing: AppSpacing.xs) {
                        if let seg = vm.client.segment, !seg.isEmpty {
                            segmentBadge(seg)
                        }
                        Text(vm.client.email)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .lineLimit(1)
                    }
                }
                Spacer()
                // Lifetime value
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Lifetime")
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text(formattedLTV)
                        .font(AppTypography.label)
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)
            GoldDivider()
        }
        .background(AppColors.backgroundPrimary)
    }

    private var formattedLTV: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: vm.lifetimeValue)) ?? "₹0"
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { idx, title in
                    Button {
                        withAnimation { selectedTab = idx }
                    } label: {
                        VStack(spacing: 4) {
                            Text(title)
                                .font(AppTypography.label)
                                .foregroundColor(selectedTab == idx ? AppColors.accent : AppColors.textSecondaryDark)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                            Rectangle()
                                .fill(selectedTab == idx ? AppColors.accent : Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
        .background(AppColors.backgroundPrimary)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Profile Tab (read-only; edit opens as sheet)

    private var profileTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {

                // Contact
                sectionHeader("CONTACT")
                LuxuryCardView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        infoRow(icon: "envelope", value: vm.client.email)
                        if let p = vm.client.phone { GoldDivider(); infoRow(icon: "phone", value: p) }
                        if let dob = vm.client.dateOfBirth { GoldDivider(); infoRow(icon: "calendar", value: dob) }
                        if let nat = vm.client.nationality { GoldDivider(); infoRow(icon: "globe", value: nat) }
                        if let lang = vm.client.preferredLanguage { GoldDivider(); infoRow(icon: "text.bubble", value: lang) }
                    }
                    .padding(AppSpacing.cardPadding)
                }

                // Address
                let hasAddress = !(vm.client.addressLine1 ?? "").isEmpty
                if hasAddress {
                    sectionHeader("ADDRESS")
                    LuxuryCardView {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            if let a1 = vm.client.addressLine1 { Text(a1).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimaryDark) }
                            if let a2 = vm.client.addressLine2, !a2.isEmpty { Text(a2).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimaryDark) }
                            let cityState = [vm.client.city, vm.client.state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                            if !cityState.isEmpty { Text(cityState).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimaryDark) }
                            let pcCountry = [vm.client.postalCode, vm.client.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                            if !pcCountry.isEmpty { Text(pcCountry).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark) }
                        }
                        .padding(AppSpacing.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Preferences
                let b = vm.blob
                let hasPrefs = !b.preferences.preferredCategories.isEmpty || !b.preferences.preferredBrands.isEmpty
                if hasPrefs {
                    sectionHeader("PREFERENCES")
                    LuxuryCardView {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            if !b.preferences.preferredCategories.isEmpty {
                                Text("Categories").font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                                FlowLayout(spacing: AppSpacing.xs) {
                                    ForEach(b.preferences.preferredCategories, id: \.self) { cat in
                                        Text(cat).font(AppTypography.caption)
                                            .padding(.horizontal, AppSpacing.sm).padding(.vertical, 4)
                                            .background(AppColors.accent.opacity(0.1))
                                            .foregroundColor(AppColors.accent)
                                            .cornerRadius(AppSpacing.radiusSmall)
                                    }
                                }
                            }
                            if !b.preferences.preferredBrands.isEmpty {
                                if !b.preferences.preferredCategories.isEmpty { GoldDivider() }
                                Text("Brands").font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                                FlowLayout(spacing: AppSpacing.xs) {
                                    ForEach(b.preferences.preferredBrands, id: \.self) { brand in
                                        Text(brand).font(AppTypography.caption)
                                            .padding(.horizontal, AppSpacing.sm).padding(.vertical, 4)
                                            .background(AppColors.accent)
                                            .foregroundColor(.white)
                                            .cornerRadius(AppSpacing.radiusSmall)
                                    }
                                }
                            }
                            GoldDivider()
                            infoRow(icon: "bubble.left", value: "Prefers: \(b.preferences.communicationPreference)")
                        }
                        .padding(AppSpacing.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Sizes
                let hasSizes = !b.sizes.ring.isEmpty || !b.sizes.wrist.isEmpty || !b.sizes.shoe.isEmpty || !b.sizes.dress.isEmpty || !b.sizes.jacket.isEmpty
                if hasSizes {
                    sectionHeader("SIZES")
                    LuxuryCardView {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            sizeRow("Ring", b.sizes.ring)
                            sizeRow("Wrist", b.sizes.wrist)
                            sizeRow("Shoe", b.sizes.shoe)
                            sizeRow("Dress / Suit", b.sizes.dress)
                            sizeRow("Jacket", b.sizes.jacket)
                        }
                        .padding(AppSpacing.cardPadding)
                    }
                }

                // Anniversaries
                if !b.anniversaries.isEmpty {
                    sectionHeader("ANNIVERSARIES")
                    LuxuryCardView {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            ForEach(b.anniversaries) { a in
                                HStack {
                                    Text(a.label).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimaryDark)
                                    Spacer()
                                    Text(a.date).font(AppTypography.caption).foregroundColor(AppColors.textSecondaryDark)
                                }
                                if a.id != b.anniversaries.last?.id { GoldDivider().padding(.vertical, 2) }
                            }
                        }
                        .padding(AppSpacing.cardPadding)
                    }
                }

                // Notes
                if !b.notes.isEmpty {
                    sectionHeader("NOTES")
                    LuxuryCardView {
                        Text(b.notes)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.cardPadding)
                    }
                }

                // Last modified
                HStack {
                    Image(systemName: "clock")
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Text("Last updated \(vm.client.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, AppSpacing.xs)

                Spacer().frame(height: 30)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: - Purchases Tab

    private var purchasesTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if vm.isLoadingHistory {
                    ProgressView().tint(AppColors.accent).padding(.top, 60)
                } else if vm.orders.isEmpty {
                    emptyState(icon: "bag", message: "No purchases on record")
                } else {
                    // Summary bar
                    LuxuryCardView {
                        HStack {
                            statCell(label: "Orders", value: "\(vm.orders.count)")
                            Divider().frame(height: 30)
                            statCell(label: "Completed", value: "\(vm.orders.filter { $0.status == "completed" || $0.status == "delivered" }.count)")
                            Divider().frame(height: 30)
                            statCell(label: "Lifetime", value: formattedLTV)
                        }
                        .padding(AppSpacing.cardPadding)
                    }
                    .padding(.top, AppSpacing.sm)

                    ForEach(vm.orders) { order in
                        Button {
                            selectedOrder = order
                        } label: {
                            orderRow(order)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer().frame(height: 30)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
        }
    }

    private func orderRow(_ order: OrderDTO) -> some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(order.orderNumber ?? String(order.id.uuidString.prefix(8)).uppercased())
                            .font(AppTypography.monoID)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text(order.channel.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    Spacer()
                    Text(order.formattedTotal)
                        .font(AppTypography.priceSmall)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                HStack {
                    statusPill(order.status, color: orderStatusColor(order.status))
                    Spacer()
                    Text(order.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                    Image(systemName: "chevron.right")
                        .font(AppTypography.chevron)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    // MARK: - Appointments Tab

    private var appointmentsTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if vm.isLoadingHistory {
                    ProgressView().tint(AppColors.accent).padding(.top, 60)
                } else if vm.appointments.isEmpty {
                    emptyState(icon: "calendar.badge.clock", message: "No appointments on record")
                } else {
                    let upcoming = vm.upcomingAppointments
                    let past = vm.pastAppointments
                    
                    HStack {
                        sectionHeader("UPCOMING APPOINTMENTS")
                        Spacer()
                    }
                    
                    if upcoming.isEmpty {
                        sectionEmptyState(icon: "calendar.badge.clock", message: "No upcoming appointments")
                    } else {
                        ForEach(upcoming) { appt in
                            Button {
                                selectedAppointment = appt
                            } label: {
                                appointmentRow(appt)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if !past.isEmpty {
                        Spacer().frame(height: AppSpacing.sm)
                        DisclosureGroup(
                            content: {
                                VStack(spacing: AppSpacing.md) {
                                    ForEach(past) { appt in
                                        Button {
                                            selectedAppointment = appt
                                        } label: {
                                            appointmentRow(appt)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, AppSpacing.sm)
                            },
                            label: {
                                Text("PAST APPOINTMENTS")
                                    .font(AppTypography.overline)
                                    .tracking(2)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                        )
                        .accentColor(AppColors.textSecondaryDark)
                    }
                }
                Spacer().frame(height: 30)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
        }
    }

    private func appointmentRow(_ appt: AppointmentDTO) -> some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appt.type.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text(appt.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                    Text("\(appt.durationMinutes) min")
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                HStack {
                    statusPill(appt.status, color: appointmentStatusColor(appt.status))
                    Spacer()
                    if let note = appt.notes, !note.isEmpty {
                        Text(note)
                            .font(AppTypography.micro)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .lineLimit(1)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    // MARK: - After-Sales Tab

    private var afterSalesTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if vm.isLoadingHistory {
                    ProgressView().tint(AppColors.accent).padding(.top, 60)
                } else if vm.serviceTickets.isEmpty {
                    emptyState(icon: "wrench.and.screwdriver", message: "No after-sales tickets on record")
                } else {
                    ForEach(vm.serviceTickets) { ticket in
                        Button {
                            selectedServiceTicket = ticket
                        } label: {
                            serviceTicketRow(ticket)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer().frame(height: 30)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
        }
    }

    private func serviceTicketRow(_ ticket: ServiceTicketDTO) -> some View {
        LuxuryCardView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ticket.ticketNumber ?? String(ticket.id.uuidString.prefix(8)).uppercased())
                            .font(AppTypography.monoID)
                            .foregroundColor(AppColors.textSecondaryDark)
                        Text(ticket.type.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    Spacer()
                    if ticket.isOverdue {
                        Text("OVERDUE")
                            .font(AppTypography.nano)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(AppColors.error)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                HStack {
                    statusPill(ticket.status, color: ticketStatusColor(ticket.status))
                    Spacer()
                    if let cost = ticket.finalCost ?? ticket.estimatedCost {
                        let formatter: NumberFormatter = {
                            let f = NumberFormatter()
                            f.numberStyle = .currency
                            f.currencyCode = ticket.currency
                            return f
                        }()
                        Text(formatter.string(from: NSNumber(value: cost)) ?? "\(cost)")
                            .font(AppTypography.priceCompact)
                            .foregroundColor(AppColors.textPrimaryDark)
                    }
                    Text(ticket.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.micro)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                if let notes = ticket.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                        .lineLimit(2)
                }
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    // MARK: - Shared helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.overline)
            .tracking(2)
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(icon: String, value: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .frame(width: 18)
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
        }
    }

    private func sizeRow(_ label: String, _ value: String) -> some View {
        Group {
            if !value.isEmpty {
                HStack {
                    Text(label).font(AppTypography.bodyMedium).foregroundColor(AppColors.textSecondaryDark)
                    Spacer()
                    Text(value).font(AppTypography.label).foregroundColor(AppColors.textPrimaryDark)
                }
            }
        }
    }

    private func segmentBadge(_ segment: String) -> some View {
        Text(segment.replacingOccurrences(of: "_", with: " ").uppercased())
            .font(AppTypography.nano)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(segmentColor(segment))
            .foregroundColor(.white)
            .cornerRadius(4)
    }

    private func segmentColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "ultra_vip": return AppColors.accent
        case "vip":       return AppColors.accent.opacity(0.85)
        case "gold":      return Color(hex: "B8860B")
        case "silver":    return AppColors.neutral500
        default:          return AppColors.neutral400
        }
    }

    private func statusPill(_ status: String, color: Color) -> some View {
        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(AppTypography.nano)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.3), lineWidth: 0.5))
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(AppTypography.heading3).foregroundColor(AppColors.textPrimaryDark)
            Text(label).font(AppTypography.micro).foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(AppTypography.emptyStateIcon)
                .foregroundColor(AppColors.accent.opacity(0.4))
            Text(message)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func sectionEmptyState(icon: String, message: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(AppColors.accent.opacity(0.4))
            Text(message)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
    }

    // MARK: - Status colors

    private func orderStatusColor(_ s: String) -> Color {
        switch s {
        case "completed", "delivered": return .green
        case "confirmed", "processing": return AppColors.accent
        case "shipped": return .blue
        case "cancelled": return AppColors.error
        default: return .orange
        }
    }

    private func appointmentStatusColor(_ s: String) -> Color {
        switch s {
        case "completed": return .green
        case "confirmed": return AppColors.accent
        case "scheduled": return .blue
        case "cancelled", "no_show": return AppColors.error
        default: return .orange
        }
    }

    private func ticketStatusColor(_ s: String) -> Color {
        switch s {
        case "completed", "closed": return .green
        case "in_progress", "quality_check": return AppColors.accent
        case "awaiting_parts": return .orange
        case "declined": return AppColors.error
        default: return .blue
        }
    }
}

private struct SalesClientOrderDetailSheet: View {
    let order: OrderDTO
    @Environment(\.dismiss) private var dismiss
    @State private var items: [OrderItemWithProduct] = []
    @State private var isLoadingItems = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack {
                                Text(order.orderNumber ?? String(order.id.uuidString.prefix(8)).uppercased())
                                    .font(AppTypography.monoID)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Spacer()
                                Text(order.formattedTotal)
                                    .font(AppTypography.priceDisplay)
                                    .foregroundColor(AppColors.accent)
                            }
                            Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondaryDark)
                            Text(order.channel.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                                .fill(AppColors.backgroundSecondary)
                        )

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("ITEMS")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)

                            if isLoadingItems {
                                ProgressView("Loading items...")
                                    .tint(AppColors.accent)
                            } else if items.isEmpty {
                                Text("No item details available.")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            } else {
                                ForEach(items) { item in
                                    HStack(spacing: AppSpacing.sm) {
                                        Group {
                                            if let image = item.productPrimaryImage, !image.isEmpty {
                                                ProductArtworkView(imageSource: image, fallbackSymbol: "cube.box.fill", cornerRadius: AppSpacing.radiusSmall)
                                            } else {
                                                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                                                    .fill(AppColors.backgroundSecondary)
                                                    .overlay(
                                                        Image(systemName: "cube.box.fill")
                                                            .foregroundColor(AppColors.accent)
                                                    )
                                            }
                                        }
                                        .frame(width: 44, height: 44)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.productName)
                                                .font(AppTypography.bodyMedium)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                            Text("SKU: \(item.productSku) • Qty: \(item.quantity)")
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.textSecondaryDark)
                                        }
                                        Spacer()
                                        Text(formatCurrency(item.line_total, currency: order.currency))
                                            .font(AppTypography.bodySmall)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                                .fill(AppColors.backgroundSecondary)
                        )
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .navigationTitle("Order Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .task {
                await loadItems()
            }
        }
    }

    @MainActor
    private func loadItems() async {
        guard !isLoadingItems else { return }
        isLoadingItems = true
        defer { isLoadingItems = false }
        do {
            items = try await OrderFulfillmentService.shared.fetchOrderItems(orderId: order.id)
        } catch {
            items = []
        }
    }

    private func formatCurrency(_ value: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency) \(value)"
    }
}
