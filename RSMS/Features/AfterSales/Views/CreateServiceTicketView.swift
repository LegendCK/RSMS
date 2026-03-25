//
//  CreateServiceTicketView.swift
//  RSMS
//
//  Full after-sales ticket creation form: client, product, issue,
//  condition report, photos, and ticket type selection.
//

import SwiftUI
import PhotosUI

@MainActor
struct CreateServiceTicketView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var vm = CreateServiceTicketViewModel()
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.backgroundPrimary, AppColors.backgroundSecondary.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    ticketTypeSection
                    clientSection
                    productSection
                    issueSection
                    conditionSection
                    photosSection
                    orderLinkSection
                    additionalNotesSection

                    if let ticket = vm.createdTicket {
                        ticketCreatedBanner(ticket)
                    }

                    if let error = vm.errorMessage {
                        errorBanner(error)
                    }

                    createButton
                    Spacer(minLength: AppSpacing.xl)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Create Service Ticket")
                    .font(AppTypography.navTitle)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(AppColors.accent)
            }
        }
        .task { await loadInitialProducts() }
        .onChange(of: selectedPhotoItems) { _, newItems in
            handlePhotoSelectionChange(newItems)
        }
    }

    private func loadInitialProducts() async {
        await vm.loadClients()
        await vm.loadProducts()
    }

    private func handlePhotoSelectionChange(_ newItems: [PhotosPickerItem]) {
        Task { @MainActor in
            vm.selectedPhotoItems = newItems
            await vm.processSelectedPhotos()
        }
    }

    private func submitTicket() {
        Task { @MainActor in
            await vm.createTicket(
                storeId: appState.currentStoreId,
                assignedUserId: appState.currentUserProfile?.id
            )
        }
    }
}

// MARK: - Sections

private extension CreateServiceTicketView {

    // MARK: Ticket Type
    var ticketTypeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("SERVICE TYPE")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.xs) {
                ForEach(RepairType.allCases) { type in
                    Button {
                        vm.selectedTicketType = type
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: type.icon)
                                .font(AppTypography.iconSmall)
                            Text(type.displayName)
                                .font(AppTypography.bodySmall)
                        }
                        .foregroundColor(vm.selectedTicketType == type ? .white : AppColors.textPrimaryDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .fill(vm.selectedTicketType == type
                                      ? AppColors.accent
                                      : AppColors.backgroundSecondary)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    // MARK: Client
    var clientSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("CLIENT")

            if let client = vm.selectedClient {
                HStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle().fill(AppColors.accent.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Text(client.initials)
                            .font(AppTypography.avatarSmall)
                            .foregroundColor(AppColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.fullName)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                        Text(client.email)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                    Spacer()
                    Button { vm.clearClient() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.accent.opacity(0.08))
                )
            } else {
                if vm.isSearchingClients {
                    HStack(spacing: AppSpacing.xs) {
                        ProgressView().tint(AppColors.accent)
                        Text("Loading clients...")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                } else if vm.availableClients.isEmpty {
                    VStack(spacing: 0) {
                        Text("No clients found")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.sm)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .fill(AppColors.backgroundSecondary)
                    )
                } else {
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: AppSpacing.xs) {
                            ForEach(vm.availableClients) { client in
                                Button { vm.selectClient(client) } label: {
                                    HStack(spacing: AppSpacing.sm) {
                                        ZStack {
                                            Circle().fill(AppColors.accent.opacity(0.1))
                                                .frame(width: 32, height: 32)
                                            Text(client.initials)
                                                .font(AppTypography.nano)
                                                .foregroundColor(AppColors.accent)
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(client.fullName)
                                                .font(AppTypography.bodySmall)
                                                .foregroundColor(AppColors.textPrimaryDark)
                                            Text(client.email)
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.textSecondaryDark)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, AppSpacing.xs)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                                            .fill(AppColors.backgroundPrimary)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(AppSpacing.xs)
                    }
                    .frame(maxHeight: 190)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .fill(AppColors.backgroundSecondary)
                    )
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    // MARK: Product
    var productSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("PRODUCT")

            if let product = vm.selectedProduct {
                HStack(spacing: AppSpacing.sm) {
                    if let raw = product.primaryImageUrl {
                        ProductArtworkView(imageSource: raw, fallbackSymbol: "shippingbox.fill", cornerRadius: 10)
                            .frame(width: 48, height: 48)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.backgroundSecondary)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "shippingbox.fill")
                                    .foregroundColor(AppColors.textSecondaryDark)
                            )
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .lineLimit(1)
                        Text("SKU: \(product.sku)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                        if let brand = product.brand {
                            Text(brand.uppercased())
                                .font(AppTypography.nano)
                                .tracking(1)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    Spacer()
                    Button { vm.clearProduct() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.accent.opacity(0.08))
                )
            } else {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondaryDark)
                    TextField("Search product by name, SKU, or brand", text: $vm.productSearchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(AppTypography.bodyMedium)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundSecondary)
                )

                if vm.isSearchingProducts {
                    HStack(spacing: AppSpacing.xs) {
                        ProgressView().tint(AppColors.accent)
                        Text("Loading products...")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                    }
                }

                if !vm.filteredProducts.isEmpty && vm.selectedProduct == nil {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.xs) {
                            ForEach(vm.filteredProducts, id: \.id) { product in
                                Button { vm.selectProduct(product) } label: {
                                    productRow(product)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    func productRow(_ product: ProductDTO) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Group {
                if let raw = product.primaryImageUrl {
                    ProductArtworkView(imageSource: raw, fallbackSymbol: "shippingbox.fill", cornerRadius: 8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.backgroundSecondary)
                        .overlay(
                            Image(systemName: "shippingbox.fill")
                                .foregroundColor(AppColors.textSecondaryDark)
                        )
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .lineLimit(1)
                Text(product.sku)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(AppColors.backgroundSecondary.opacity(0.55))
        )
    }

    // MARK: Issue Description
    var issueSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("ISSUE DESCRIPTION")
            Text("Describe the problem or service request in detail.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            TextEditor(text: $vm.issueDescription)
                .frame(minHeight: 100)
                .font(AppTypography.bodyMedium)
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundSecondary)
                )
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    // MARK: Condition Report
    var conditionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("CONDITION REPORT")
            Text("Note the physical condition of the product at intake.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            TextEditor(text: $vm.conditionNotes)
                .frame(minHeight: 80)
                .font(AppTypography.bodyMedium)
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundSecondary)
                )
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    // MARK: Photos
    var photosSection: some View {
        let selectedImages = vm.selectedImages

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("PRODUCT PHOTOS")
            Text("Upload photos of the product showing the issue and overall condition.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)

            // Photo grid
            if !selectedImages.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: AppSpacing.xs) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))

                            Button {
                                vm.removePhoto(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(4)
                        }
                    }
                }
            }

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "camera.fill")
                    Text(selectedImages.isEmpty ? "Add Photos" : "Add More Photos")
                }
                .font(AppTypography.buttonSecondary)
                .foregroundColor(AppColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.accent.opacity(0.5), lineWidth: 1)
                )
            }

            if !selectedImages.isEmpty {
                Text("\(selectedImages.count) photo(s) selected")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    // MARK: Order Link
    var orderLinkSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("ORDER REFERENCE (OPTIONAL)")

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "number")
                    .foregroundColor(AppColors.textSecondaryDark)
                TextField("Order number", text: $vm.orderNumber)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(AppTypography.bodyMedium)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(AppColors.backgroundSecondary)
            )
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    // MARK: Additional Notes
    var additionalNotesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("ADDITIONAL NOTES (OPTIONAL)")

            TextEditor(text: $vm.additionalNotes)
                .frame(minHeight: 60)
                .font(AppTypography.bodyMedium)
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundSecondary)
                )
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
    }

    // MARK: Create Button
    var createButton: some View {
        Button {
            submitTicket()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                if vm.isCreatingTicket {
                    ProgressView().tint(.white)
                    Text(vm.isUploadingPhotos ? "Uploading Photos..." : "Creating Ticket...")
                } else if vm.createdTicket != nil {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Ticket Created")
                } else {
                    Image(systemName: "doc.badge.plus")
                    Text("Create Service Ticket")
                }
            }
            .font(AppTypography.buttonPrimary)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                    .fill(
                        vm.createdTicket != nil
                            ? LinearGradient(
                                colors: [AppColors.success, AppColors.success],
                                startPoint: .leading,
                                endPoint: .trailing
                              )
                            : LinearGradient(
                                colors: [AppColors.accent, AppColors.accentDark],
                                startPoint: .leading,
                                endPoint: .trailing
                              )
                    )
            )
            .opacity(vm.canCreateTicket || vm.createdTicket != nil ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!vm.canCreateTicket || vm.createdTicket != nil)
    }

    // MARK: Banners

    func ticketCreatedBanner(_ ticket: ServiceTicketDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(AppColors.success)
                Text("Service Ticket Created")
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            metadataRow(title: "Ticket ID", value: ticket.displayTicketNumber)
            metadataRow(title: "Type", value: ticket.ticketType.displayName)
            metadataRow(title: "Status", value: ticket.ticketStatus.displayName)
            if let client = vm.selectedClient {
                metadataRow(title: "Client", value: client.fullName)
            }
            if let product = vm.selectedProduct {
                metadataRow(title: "Product", value: product.name)
            }

            Button {
                vm.resetForm()
            } label: {
                Text("Create Another Ticket")
                    .font(AppTypography.buttonSecondary)
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .stroke(AppColors.accent.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.xs)
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

    // MARK: Helpers

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.overline)
            .tracking(1.8)
            .foregroundColor(AppColors.textSecondaryDark)
    }

    func metadataRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondaryDark)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
            Spacer(minLength: 0)
        }
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
