//
//  LuxuryTextField.swift
//  infosys2
//
//  Underline-style input field with luxury styling.
//

import SwiftUI

struct LuxuryTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil
    @FocusState private var isFocused: Bool
    @State private var isPasswordVisible: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Floating label when focused or has text
            if isFocused || !text.isEmpty {
                Text(placeholder.uppercased())
                    .font(AppTypography.overline)
                    .tracking(1.0)
                    .foregroundColor(isFocused ? AppColors.accent : AppColors.textSecondaryDark)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: AppSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(isFocused ? AppColors.accent : AppColors.neutral500)
                        .font(AppTypography.buttonPrimary)
                        .frame(width: 20)
                }

                if isSecure {
                    // Password field with toggle visibility
                    if isPasswordVisible {
                        TextField("", text: $text, prompt: promptText)
                            .focused($isFocused)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .font(AppTypography.bodyLarge)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("", text: $text, prompt: promptText)
                            .focused($isFocused)
                            .foregroundColor(AppColors.textPrimaryDark)
                            .font(AppTypography.bodyLarge)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    // Eye toggle button
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(AppColors.neutral500)
                            .font(.system(size: 18))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                } else {
                    TextField("", text: $text, prompt: promptText)
                        .focused($isFocused)
                        .foregroundColor(AppColors.textPrimaryDark)
                        .font(AppTypography.bodyLarge)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .frame(height: AppSpacing.touchTarget)

            // Underline
            Rectangle()
                .fill(isFocused ? AppColors.accent : AppColors.neutral700)
                .frame(height: isFocused ? 2 : 1)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var promptText: Text {
        Text(placeholder)
            .foregroundColor(AppColors.neutral500)
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 24) {
            LuxuryTextField(placeholder: "Email Address", text: .constant(""), icon: "envelope")
            LuxuryTextField(placeholder: "Password", text: .constant(""), isSecure: true, icon: "lock")
            LuxuryTextField(placeholder: "Full Name", text: .constant("John Doe"), icon: "person")
        }
        .padding()
    }
}
