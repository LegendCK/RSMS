import SwiftUI

struct SalesAfterSalesView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = SalesAfterSalesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.backgroundPrimary, AppColors.backgroundSecondary.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        requestTypeCard
                        if vm.requestType == .exchange {
                            exchangeQueueCard
                        }
                        lookupCard

                        if let result = vm.warrantyResult {
                            resultCard(result)
                            astCard(result)
                        }

                        if let ticket = vm.createdTicket {
                            ticketCreatedCard(ticket)
                            if vm.requestType == .exchange {
                                exchangeProcessingCard
                            }
                        }

                        if let error = vm.errorMessage {
                            errorBanner(error)
                        }

                        Spacer(minLength: AppSpacing.xl)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("After-Sales")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
            }
            .task {
                await vm.refreshExchangeQueue(
                    storeId: appState.currentStoreId,
                    staffUserId: appState.currentUserProfile?.id
                )
            }
        }
    }
}

private extension SalesAfterSalesView {
    var requestTypeCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("REQUEST TYPE")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(AppColors.textSecondaryDark)

            Picker("Request Type", selection: $vm.requestType) {
                ForEach(AfterSalesRequestType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    var lookupCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("WARRANTY LOOKUP")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(AppColors.textSecondaryDark)

            Picker("Lookup", selection: $vm.lookupMode) {
                ForEach(WarrantyLookupMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.lookupMode) { _, mode in
                if mode == .productId {
                    Task { await vm.loadProductsIfNeeded() }
                }
            }

            TextField(vm.lookupMode.placeholder, text: $vm.lookupQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(AppTypography.bodyMedium)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundSecondary)
                )

            if vm.lookupMode == .productId {
                productPickerSection
            }

            Button {
                Task { await vm.lookupWarranty() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if vm.isLookingUp {
                        ProgressView().tint(.white)
                        Text("Validating...")
                    } else {
                        Image(systemName: "checkmark.shield")
                        Text("Validate Warranty")
                    }
                }
                .font(AppTypography.buttonPrimary)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accent, AppColors.accentDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .opacity(vm.canLookup ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!vm.canLookup)
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .task {
            await vm.loadProductsIfNeeded()
        }
    }

    var exchangeQueueCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("EXCHANGE QUEUE")
                    .font(AppTypography.overline)
                    .tracking(1.8)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                Button {
                    Task {
                        await vm.refreshExchangeQueue(
                            storeId: appState.currentStoreId,
                            staffUserId: appState.currentUserProfile?.id
                        )
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppColors.accent)
                }
            }

            if vm.isLoadingExchangeQueue {
                HStack(spacing: AppSpacing.xs) {
                    ProgressView()
                    Text("Loading queue...")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
            }

            if let queueMessage = vm.queueMessage {
                Text(queueMessage)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }

            if vm.unassignedExchangeTickets.isEmpty {
                Text("No unassigned exchange tickets.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            } else {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(vm.unassignedExchangeTickets.prefix(4), id: \.id) { ticket in
                        HStack(spacing: AppSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ticket.displayTicketNumber)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Text(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondaryDark)
                            }
                            Spacer()
                            Button {
                                Task {
                                    await vm.claimExchangeTicket(
                                        ticket,
                                        staffUserId: appState.currentUserProfile?.id,
                                        staffName: appState.currentUserName.isEmpty ? "Staff" : appState.currentUserName
                                    )
                                    await vm.refreshExchangeQueue(
                                        storeId: appState.currentStoreId,
                                        staffUserId: appState.currentUserProfile?.id
                                    )
                                }
                            } label: {
                                if vm.isClaimingTicketId == ticket.id {
                                    ProgressView()
                                } else {
                                    Text("Claim")
                                }
                            }
                            .font(AppTypography.caption)
                            .buttonStyle(.borderedProminent)
                            .tint(AppColors.accent)
                            .disabled(vm.isClaimingTicketId != nil)
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .fill(AppColors.backgroundSecondary)
                        )
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    var productPickerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Find Product")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondaryDark)
                TextField("Search name, SKU, or product ID", text: $vm.productSearchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(AppTypography.bodySmall)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(AppColors.backgroundSecondary)
            )

            if vm.isLoadingProducts {
                HStack(spacing: AppSpacing.xs) {
                    ProgressView()
                        .tint(AppColors.accent)
                    Text("Loading products...")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondaryDark)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, AppSpacing.xs)
            } else if vm.filteredProducts.isEmpty {
                Text("No matching product found.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, AppSpacing.xs)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.xs) {
                        ForEach(vm.filteredProducts, id: \.id) { product in
                            Button {
                                vm.selectProductForLookup(product)
                            } label: {
                                productLookupRow(product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 250)
            }
        }
    }

    func productLookupRow(_ product: ProductDTO) -> some View {
        let isSelected = vm.selectedLookupProductId == product.id

        return HStack(spacing: AppSpacing.sm) {
            Group {
                if let raw = product.primaryImageUrl {
                    ProductArtworkView(imageSource: raw, fallbackSymbol: "shippingbox.fill", cornerRadius: 10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.backgroundSecondary)
                        .overlay(
                            Image(systemName: "shippingbox.fill")
                                .foregroundColor(AppColors.textSecondaryDark)
                        )
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(product.sku)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(1)
                Text(product.id.uuidString)
                    .font(AppTypography.nano)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondaryDark)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(isSelected ? AppColors.accent.opacity(0.12) : AppColors.backgroundSecondary.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(isSelected ? AppColors.accent.opacity(0.45) : AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }

    func resultCard(_ result: WarrantyLookupResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("WARRANTY RESULT")
                    .font(AppTypography.overline)
                    .tracking(1.8)
                    .foregroundColor(AppColors.textSecondaryDark)
                Spacer()
                statusBadge(for: result.status)
            }

            if let brand = result.brand, !brand.isEmpty {
                Text(brand.uppercased())
                    .font(AppTypography.nano)
                    .tracking(1.5)
                    .foregroundColor(AppColors.accent)
            }

            Text(result.productName ?? "Product not found")
                .font(AppTypography.heading3)
                .foregroundColor(AppColors.textPrimaryDark)

            metadataRow(title: "Coverage Period", value: result.coveragePeriodText)
            metadataRow(title: "Eligible Services", value: result.eligibleServices.joined(separator: ", ").isEmpty ? "None" : result.eligibleServices.joined(separator: ", "))
            metadataRow(title: "Purchase Date", value: result.purchasedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unavailable")
            metadataRow(title: "Order", value: result.orderNumber ?? result.orderId?.uuidString ?? "Unavailable")
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    func astCard(_ result: WarrantyLookupResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("CREATE AST")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(AppColors.textSecondaryDark)

            Text("The warranty result will be linked automatically to the ticket notes.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            TextEditor(text: $vm.customerNotes)
                .frame(minHeight: 88)
                .font(AppTypography.bodyMedium)
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundSecondary)
                )

            Button {
                Task {
                    await vm.createAfterSalesTicket(
                        currentStoreId: appState.currentStoreId,
                        assignedUserId: appState.currentUserProfile?.id
                    )
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if vm.isCreatingTicket {
                        ProgressView().tint(.white)
                        Text("Creating AST...")
                    } else {
                        Image(systemName: "doc.badge.plus")
                        Text("Create \(vm.requestType.rawValue) AST")
                    }
                }
                .font(AppTypography.buttonPrimary)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                        .fill(AppColors.secondary)
                )
                .opacity(vm.canCreateTicket ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!vm.canCreateTicket)
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    func ticketCreatedCard(_ ticket: ServiceTicketDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(AppColors.success)
                Text("AST Created")
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
            }

            metadataRow(title: "Ticket", value: ticket.displayTicketNumber)
            metadataRow(title: "Type", value: ticket.ticketType.displayName)
            metadataRow(title: "Status", value: ticket.ticketStatus.displayName)
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                .fill(AppColors.success.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                        .stroke(AppColors.success.opacity(0.35), lineWidth: 1)
                )
        )
    }

    var exchangeProcessingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PROCESS EXCHANGE")
                .font(AppTypography.overline)
                .tracking(1.8)
                .foregroundColor(AppColors.textSecondaryDark)

            Text("Run exchange workflow with backend sync: approval, replacement order, and closure.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            HStack(spacing: AppSpacing.sm) {
                Button {
                    Task { await vm.approveExchange() }
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        if vm.isApprovingExchange {
                            ProgressView().tint(.white)
                            Text("Approving...")
                        } else {
                            Image(systemName: vm.exchangeApproved ? "checkmark.circle.fill" : "checkmark.circle")
                            Text(vm.exchangeApproved ? "Approved" : "Approve Exchange")
                        }
                    }
                    .font(AppTypography.buttonSecondary)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .fill(vm.exchangeApproved ? AppColors.success : AppColors.accent)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!vm.canApproveExchange)
                .opacity(vm.canApproveExchange || vm.exchangeApproved ? 1 : 0.45)
            }

            TextField("Replacement Product UUID (optional)", text: $vm.replacementProductIdText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(AppTypography.bodyMedium)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundSecondary)
                )

            TextField("Replacement Quantity", text: $vm.replacementQuantityText)
                .keyboardType(.numberPad)
                .font(AppTypography.bodyMedium)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundSecondary)
                )

            Button {
                Task { await vm.createReplacementOrder() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if vm.isCreatingReplacementOrder {
                        ProgressView().tint(.white)
                        Text("Creating Replacement...")
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(vm.replacementOrderNumber == nil ? "Create Replacement Order" : "Replacement Order Created")
                    }
                }
                .font(AppTypography.buttonSecondary)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(vm.replacementOrderNumber == nil ? AppColors.secondary : AppColors.success)
                )
            }
            .buttonStyle(.plain)
            .disabled(!vm.canCreateReplacementOrder)
            .opacity(vm.canCreateReplacementOrder || vm.replacementOrderNumber != nil ? 1 : 0.45)

            if let replacementOrderNumber = vm.replacementOrderNumber {
                metadataRow(title: "Replacement Order", value: replacementOrderNumber)
            }

            Button {
                Task { await vm.completeExchange() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if vm.isCompletingExchange {
                        ProgressView().tint(.white)
                        Text("Completing...")
                    } else {
                        Image(systemName: vm.exchangeCompleted ? "checkmark.seal.fill" : "checkmark.seal")
                        Text(vm.exchangeCompleted ? "Exchange Completed" : "Mark Exchange Completed")
                    }
                }
                .font(AppTypography.buttonSecondary)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(vm.exchangeCompleted ? AppColors.success : AppColors.accentDark)
                )
            }
            .buttonStyle(.plain)
            .disabled(!vm.canCompleteExchange)
            .opacity(vm.canCompleteExchange || vm.exchangeCompleted ? 1 : 0.45)
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    func statusBadge(for status: WarrantyCoverageStatus) -> some View {
        let color: Color = {
            switch status {
            case .valid: return AppColors.success
            case .expired: return AppColors.warning
            case .notFound: return AppColors.error
            }
        }()

        return Text(status.rawValue)
            .font(AppTypography.nano)
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
    }

    func metadataRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.error)
            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(AppColors.error.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.error.opacity(0.35), lineWidth: 1)
                )
        )
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                    .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
            )
    }
}
