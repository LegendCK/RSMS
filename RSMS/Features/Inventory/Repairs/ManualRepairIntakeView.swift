//
//  ManualRepairIntakeView.swift
//  RSMS
//
//  Fix 7 — Manual repair intake for cases where the IC does not have a scan session.
//  The IC searches for a product by name, selects it, then fills the same
//  repair form fields as RepairIntakeView.
//
//  Architecture: View → ManualRepairIntakeViewModel → ServiceTicketService → Supabase
//

import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
@MainActor
final class ManualRepairIntakeViewModel {

    // MARK: Form State
    var searchText: String               = ""
    var selectedProduct: ProductDTO?     = nil
    var selectedType: RepairType         = .repair
    var conditionNotes: String           = ""
    var additionalNotes: String          = ""
    var estimatedCostText: String        = ""
    var slaDueDate: Date                 = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var includeSLA: Bool                 = true

    // MARK: Search State
    var searchResults: [ProductDTO]      = []
    var isSearching: Bool                = false
    var searchError: String?             = nil

    // MARK: Submit State
    var isSubmitting: Bool               = false
    var submittedTicket: ServiceTicketDTO? = nil
    var errorMessage: String?            = nil

    // MARK: Context
    let storeId: UUID
    let assignedToUserId: UUID?

    // MARK: Dependencies
    private let service: ServiceTicketServiceProtocol
    private let client = SupabaseManager.shared.client

    init(
        storeId: UUID,
        assignedToUserId: UUID?,
        service: ServiceTicketServiceProtocol
    ) {
        self.storeId          = storeId
        self.assignedToUserId = assignedToUserId
        self.service          = service
    }

    convenience init(storeId: UUID, assignedToUserId: UUID?) {
        self.init(
            storeId: storeId,
            assignedToUserId: assignedToUserId,
            service: ServiceTicketService.shared
        )
    }

    // MARK: Validation
    var isFormValid: Bool {
        selectedProduct != nil &&
        !conditionNotes.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var parsedCost: Double? {
        guard !estimatedCostText.isEmpty else { return nil }
        return Double(estimatedCostText.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: Product Search
    @discardableResult
    func search() async -> [ProductDTO] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            return []
        }
        isSearching  = true
        searchError  = nil
        defer { isSearching = false }
        do {
            let results: [ProductDTO] = try await client
                .from("products")
                .select()
                .ilike("name", value: "%\(query)%")
                .limit(20)
                .execute()
                .value
            searchResults = results
            return results
        } catch {
            searchError = "Search failed: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: Submit
    func submit() async {
        guard isFormValid, !isSubmitting else { return }
        guard let product = selectedProduct else { return }
        isSubmitting  = true
        errorMessage  = nil

        do {
            let slaString: String? = includeSLA
                ? slaDueDate.formatted(.iso8601.year().month().day())
                : nil

            let payload = ServiceTicketInsertDTO(
                clientId:       nil,
                storeId:        storeId,
                assignedTo:     assignedToUserId,
                productId:      product.id,
                orderId:        nil,
                type:           selectedType.rawValue,
                status:         RepairStatus.intake.rawValue,
                conditionNotes: conditionNotes.trimmingCharacters(in: .whitespaces),
                intakePhotos:   nil,
                estimatedCost:  parsedCost,
                currency:       "USD",
                slaDueDate:     slaString,
                notes:          additionalNotes.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? nil
                                    : additionalNotes.trimmingCharacters(in: .whitespaces)
            )

            submittedTicket = try await service.createTicket(payload)

            // Notify RepairTicketsListViewModel to reload
            NotificationCenter.default.post(name: .repairTicketCreated, object: nil)

        } catch {
            errorMessage = "Could not create ticket: \(error.localizedDescription)"
        }

        isSubmitting = false
    }
}

// MARK: - View

@MainActor
struct ManualRepairIntakeView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var vm: ManualRepairIntakeViewModel

    init(storeId: UUID, assignedToUserId: UUID?) {
        _vm = State(initialValue: ManualRepairIntakeViewModel(
            storeId: storeId,
            assignedToUserId: assignedToUserId
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if let ticket = vm.submittedTicket {
                    RepairTicketConfirmationView(ticket: ticket) { dismiss() }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    formBody
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.submittedTicket != nil)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Repair Ticket")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.submittedTicket == nil {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }

    // MARK: Form Body

    private var formBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                productSearchSection
                if vm.selectedProduct != nil {
                    serviceTypeSection
                    conditionSection
                    additionalNotesSection
                    estimatedCostSection
                    slaDueDateSection
                }
                if let err = vm.errorMessage { errorBanner(err) }
                if vm.selectedProduct != nil { submitButton }
                Spacer(minLength: AppSpacing.xxxl)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: Product Search Section

    private var productSearchSection: some View {
        sectionCard(label: "PRODUCT") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondaryDark)
                    TextField("Search product by name…", text: $vm.searchText)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await vm.search() } }
                    if vm.isSearching {
                        ProgressView().tint(AppColors.accent).scaleEffect(0.8)
                    } else if !vm.searchText.isEmpty {
                        Button { vm.searchText = ""; vm.searchResults = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                    }
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundTertiary)
                        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .stroke(AppColors.border, lineWidth: 1))
                )
                .onChange(of: vm.searchText) { _, _ in
                    Task { await vm.search() }
                }

                if let err = vm.searchError {
                    Text(err).font(AppTypography.caption).foregroundColor(AppColors.error)
                }

                // Search results
                if !vm.searchResults.isEmpty && vm.selectedProduct == nil {
                    VStack(spacing: 0) {
                        ForEach(vm.searchResults) { product in
                            Button {
                                vm.selectedProduct = product
                                vm.searchResults   = []
                                vm.searchText      = product.name
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.name)
                                            .font(AppTypography.label)
                                            .foregroundColor(AppColors.textPrimaryDark)
                                            .multilineTextAlignment(.leading)
                                        if let brand = product.brand {
                                            Text(brand.uppercased())
                                                .font(AppTypography.nano)
                                                .foregroundColor(AppColors.accent)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.neutral400)
                                }
                                .padding(.vertical, AppSpacing.sm)
                                .padding(.horizontal, AppSpacing.xs)
                            }
                            .buttonStyle(.plain)
                            if product.id != vm.searchResults.last?.id {
                                Divider().background(AppColors.border.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .fill(AppColors.backgroundTertiary)
                    )
                }

                // Selected product chip
                if let product = vm.selectedProduct {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        Text(product.name)
                            .font(AppTypography.label)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            vm.selectedProduct = nil
                            vm.searchText      = ""
                        } label: {
                            Text("Change")
                                .font(AppTypography.actionSmall)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .fill(AppColors.success.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(AppColors.success.opacity(0.3), lineWidth: 1))
                    )
                }
            }
        }
    }

    // MARK: Service Type

    private var serviceTypeSection: some View {
        sectionCard(label: "SERVICE TYPE") {
            VStack(spacing: 2) {
                ForEach(RepairType.allCases) { type in
                    Button {
                        withAnimation(.spring(response: 0.25)) { vm.selectedType = type }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: type.icon)
                                .font(.system(size: 15))
                                .foregroundColor(vm.selectedType == type ? AppColors.accent : AppColors.textSecondaryDark)
                                .frame(width: 22)
                            Text(type.displayName)
                                .font(AppTypography.label)
                                .foregroundColor(vm.selectedType == type ? AppColors.textPrimaryDark : AppColors.textSecondaryDark)
                            Spacer()
                            if vm.selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accent)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, AppSpacing.xs)
                        .padding(.horizontal, AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .fill(vm.selectedType == type ? AppColors.accent.opacity(0.07) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Condition Notes

    private var conditionSection: some View {
        sectionCard(label: "CONDITION AT INTAKE") {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Describe the item's condition *")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondaryDark)
                TextEditor(text: $vm.conditionNotes)
                    .frame(minHeight: 88)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimaryDark)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .fill(AppColors.backgroundTertiary)
                            .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                                .stroke(vm.conditionNotes.isEmpty
                                    ? AppColors.border
                                    : AppColors.accent.opacity(0.5), lineWidth: 1))
                    )
            }
        }
    }

    // MARK: Additional Notes

    private var additionalNotesSection: some View {
        sectionCard(label: "ADDITIONAL NOTES") {
            TextEditor(text: $vm.additionalNotes)
                .frame(minHeight: 60)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimaryDark)
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .fill(AppColors.backgroundTertiary)
                        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                            .stroke(AppColors.border, lineWidth: 1))
                )
        }
    }

    // MARK: Estimated Cost

    private var estimatedCostSection: some View {
        sectionCard(label: "ESTIMATED COST") {
            HStack(spacing: AppSpacing.sm) {
                Text("USD")
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textSecondaryDark)
                    .frame(width: 38)
                TextField("0.00  (optional)", text: $vm.estimatedCostText)
                    .keyboardType(.decimalPad)
                    .font(AppTypography.heading3)
                    .foregroundColor(AppColors.textPrimaryDark)
            }
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .fill(AppColors.backgroundTertiary)
                    .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                        .stroke(AppColors.border, lineWidth: 1))
            )
        }
    }

    // MARK: SLA

    private var slaDueDateSection: some View {
        sectionCard(label: "SLA DUE DATE") {
            VStack(spacing: AppSpacing.sm) {
                Toggle("Set a due date", isOn: $vm.includeSLA)
                    .tint(AppColors.accent)
                    .font(AppTypography.label)
                    .foregroundColor(AppColors.textPrimaryDark)
                if vm.includeSLA {
                    DatePicker("Due date", selection: $vm.slaDueDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppColors.accent)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.3), value: vm.includeSLA)
        }
    }

    // MARK: Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppColors.error)
            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textPrimaryDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                .fill(AppColors.error.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(AppColors.error.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: Submit Button

    private var submitButton: some View {
        Button {
            Task { await vm.submit() }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if vm.isSubmitting {
                    ProgressView().tint(.white).scaleEffect(0.85)
                    Text("Creating Ticket…")
                } else {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("Create Repair Ticket")
                }
            }
            .font(AppTypography.buttonPrimary)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                    .fill(LinearGradient(
                        colors: [AppColors.accent, AppColors.accentDark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            )
            .opacity(vm.isFormValid ? 1 : 0.45)
        }
        .disabled(!vm.isFormValid || vm.isSubmitting)
    }

    // MARK: Section Card

    private func sectionCard<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(label)
                .font(AppTypography.overline)
                .tracking(1.5)
                .foregroundColor(AppColors.accent)
            content()
                .padding(AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                        .fill(AppColors.backgroundSecondary)
                        .overlay(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge)
                            .stroke(AppColors.border.opacity(0.45), lineWidth: 0.75))
                )
        }
    }
}
