//
//  AddCardView.swift
//  RSMS
//
//  Sheet for adding a new saved payment card.
//  Auto-detects card brand. Stores ONLY last 4 digits — never the full number.
//

import SwiftUI
import SwiftData

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    // Raw card number input (digits only, up to 16)
    @State private var rawCardNumber = ""
    @State private var cardHolderName = ""
    @State private var expiryMonth = Calendar.current.component(.month, from: Date())
    @State private var expiryYear  = Calendar.current.component(.year,  from: Date())
    @State private var setAsDefault = false
    @State private var errorMessage: String?

    private let months = Array(1...12)
    private var years: [Int] {
        let base = Calendar.current.component(.year, from: Date())
        return Array(base...(base + 20))
    }

    // MARK: - Derived

    private var formattedNumber: String {
        let digits = rawCardNumber.filter(\.isNumber).prefix(16)
        return stride(from: 0, to: digits.count, by: 4)
            .map { i -> String in
                let start = digits.index(digits.startIndex, offsetBy: i)
                let end   = digits.index(start, offsetBy: min(4, digits.count - i))
                return String(digits[start..<end])
            }
            .joined(separator: " ")
    }

    private var detectedBrand: String {
        let d = rawCardNumber.filter(\.isNumber)
        if d.hasPrefix("4")  { return "Visa" }
        if let n2 = Int(d.prefix(2)), (51...55).contains(n2) { return "Mastercard" }
        if d.hasPrefix("34") || d.hasPrefix("37") { return "Amex" }
        if d.hasPrefix("6011") || d.hasPrefix("65") { return "Discover" }
        return "Card"
    }

    private var lastFour: String {
        let digits = rawCardNumber.filter(\.isNumber)
        return String(digits.suffix(4))
    }

    private var displayedCardNumber: String {
        if rawCardNumber.isEmpty {
            return "•••• •••• •••• ••••"
        }
        
        let digits = rawCardNumber.filter(\.isNumber)
        let digitCount = digits.count
        
        // If we have a complete or nearly complete card number, show formatted
        if digitCount >= 16 {
            return formattedNumber
        }
        
        // Otherwise, show what we have plus dots for missing digits
        let remaining = 16 - digitCount
        let dots = String(repeating: "•", count: remaining)
        return formattedNumber + (digitCount % 4 == 0 ? " " : "") + dots
            .enumerated()
            .reduce(into: "") { result, element in
                if element.offset > 0 && element.offset % 4 == 0 {
                    result += " "
                }
                result.append(element.element)
            }
    }

    private var isFormValid: Bool {
        let digits = rawCardNumber.filter(\.isNumber)
        return digits.count >= 13
            && !cardHolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {

                        // Live card preview
                        cardPreview
                            .padding(.top, AppSpacing.md)

                        // Form
                        VStack(spacing: AppSpacing.lg) {
                            // Card number
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("CARD NUMBER")
                                    .font(AppTypography.overline)
                                    .tracking(1.0)
                                    .foregroundColor(AppColors.textSecondaryDark)
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "creditcard")
                                        .foregroundColor(AppColors.neutral500)
                                        .font(AppTypography.buttonPrimary)
                                        .frame(width: 20)
                                    TextField("", text: Binding(
                                        get: { formattedNumber },
                                        set: { newVal in
                                            // Strip spaces, keep digits only
                                            rawCardNumber = String(newVal.filter(\.isNumber).prefix(16))
                                        }
                                    ))
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundColor(AppColors.textPrimaryDark)
                                    .frame(maxWidth: .infinity)
                                    .autocorrectionDisabled()

                                    // Brand label
                                    if rawCardNumber.count >= 1 {
                                        Text(detectedBrand)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(AppColors.accent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(AppColors.accent.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                                .frame(height: AppSpacing.touchTarget)
                                Rectangle().fill(AppColors.neutral700).frame(height: 1)
                            }

                            // Cardholder name
                            LuxuryTextField(placeholder: "Name on Card", text: $cardHolderName, icon: "person")
                                .textInputAutocapitalization(.words)

                            // Expiry pickers
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("EXPIRY DATE")
                                    .font(AppTypography.overline)
                                    .tracking(1.0)
                                    .foregroundColor(AppColors.textSecondaryDark)

                                HStack(spacing: AppSpacing.md) {
                                    // Month
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Month")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                        Picker("Month", selection: $expiryMonth) {
                                            ForEach(months, id: \.self) { m in
                                                Text(String(format: "%02d", m)).tag(m)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(AppColors.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, AppSpacing.xs)
                                        .background(AppColors.backgroundSecondary)
                                        .cornerRadius(AppSpacing.radiusSmall)
                                    }

                                    // Year
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Year")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondaryDark)
                                        Picker("Year", selection: $expiryYear) {
                                            ForEach(years, id: \.self) { y in
                                                Text(String(y)).tag(y)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(AppColors.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, AppSpacing.xs)
                                        .background(AppColors.backgroundSecondary)
                                        .cornerRadius(AppSpacing.radiusSmall)
                                    }
                                }
                            }

                            // Set as default toggle
                            Toggle(isOn: $setAsDefault) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Set as Default")
                                        .font(AppTypography.label)
                                        .foregroundColor(AppColors.textPrimaryDark)
                                    Text("Use this card automatically at checkout")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondaryDark)
                                }
                            }
                            .tint(AppColors.accent)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.error)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        PrimaryButton(title: "Save Card") { saveCard() }
                            .disabled(!isFormValid)
                            .opacity(isFormValid ? 1 : 0.5)
                            .padding(.top, AppSpacing.sm)

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Card")
                        .font(AppTypography.navTitle)
                        .foregroundColor(AppColors.textPrimaryDark)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Card preview

    private var cardPreview: some View {
        ZStack {
            // Card background gradient
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 190)
                .shadow(color: AppColors.accent.opacity(0.3), radius: 12, x: 0, y: 6)

            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .offset(x: 90, y: -40)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 120, height: 120)
                .offset(x: -80, y: 50)

            VStack(alignment: .leading, spacing: 0) {
                // Brand
                HStack {
                    Spacer()
                    Text(rawCardNumber.isEmpty ? "•••• •••• •••• ••••" : detectedBrand.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, AppSpacing.lg)

                // Masked number
                Text(displayedCardNumber)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.bottom, AppSpacing.sm)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CARD HOLDER")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1)
                        Text(cardHolderName.isEmpty ? "YOUR NAME" : cardHolderName.uppercased())
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EXPIRES")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1)
                        Text(String(format: "%02d/%02d", expiryMonth, expiryYear % 100))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Save

    private func saveCard() {
        let digits = rawCardNumber.filter(\.isNumber)
        guard digits.count >= 13 else {
            errorMessage = "Please enter a valid card number."
            return
        }
        let name = cardHolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Please enter the cardholder name."
            return
        }
        errorMessage = nil

        let userEmail = appState.currentUserEmail

        // If setting as default, clear existing defaults first.
        // Fetch all cards and filter in Swift — avoids #Predicate String-equality
        // limitations in this SwiftData version, and is fine for a small dataset.
        if setAsDefault {
            let allCards = (try? modelContext.fetch(FetchDescriptor<SavedPaymentCard>())) ?? []
            allCards
                .filter { $0.customerEmail == userEmail }
                .forEach { $0.isDefault = false }
        }

        let card = SavedPaymentCard(
            customerEmail: userEmail,
            cardHolderName: name,
            lastFourDigits: String(digits.suffix(4)),
            expiryMonth: expiryMonth,
            expiryYear: expiryYear,
            cardBrand: detectedBrand,
            isDefault: setAsDefault
        )
        modelContext.insert(card)
        try? modelContext.save()
        dismiss()
    }
}
