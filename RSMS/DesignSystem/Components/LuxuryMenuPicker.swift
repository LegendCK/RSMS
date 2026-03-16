//
//  LuxuryMenuPicker.swift
//  RSMS
//
//  Pull-down menu picker that matches the LuxuryTextField underline aesthetic.
//  On iOS 26 the system Menu automatically renders with liquid-glass styling.
//

import SwiftUI

// MARK: - Data model

struct LuxuryPickerItem {
    let code: String    // stored value (e.g. ISO alpha-2 "FR", language code "fr")
    let name: String    // display label (e.g. "France", "French")
}

// MARK: - Component

struct LuxuryMenuPicker: View {
    let label: String
    let icon: String
    let items: [LuxuryPickerItem]
    @Binding var selection: String
    var placeholder: String = "Select…"

    private var selectedName: String {
        items.first { $0.code == selection }?.name ?? placeholder
    }
    private var hasSelection: Bool {
        items.contains { $0.code == selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Floating label — always visible (same as LuxuryDatePicker)
            Text(label.uppercased())
                .font(AppTypography.overline)
                .tracking(1.0)
                .foregroundColor(AppColors.textSecondaryDark)

            Menu {
                // "None" / clear option
                Button {
                    selection = ""
                } label: {
                    if selection.isEmpty {
                        Label("None", systemImage: "checkmark")
                    } else {
                        Text("None")
                    }
                }

                Divider()

                ForEach(items, id: \.code) { item in
                    Button {
                        selection = item.code
                    } label: {
                        if selection == item.code {
                            Label(item.name, systemImage: "checkmark")
                        } else {
                            Text(item.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: icon)
                        .foregroundColor(AppColors.neutral500)
                        .font(AppTypography.buttonPrimary)
                        .frame(width: 20)

                    Text(selectedName)
                        .font(AppTypography.bodyLarge)
                        .foregroundColor(hasSelection ? AppColors.textPrimaryDark : AppColors.neutral500)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(AppColors.neutral500)
                }
                .frame(height: AppSpacing.touchTarget)
            }
            .buttonStyle(.plain)

            // Underline — mirrors LuxuryTextField resting state
            Rectangle()
                .fill(AppColors.neutral700)
                .frame(height: 1)
        }
    }
}

// MARK: - Curated data sets

extension LuxuryPickerItem {

    // MARK: Nationalities (luxury-retail focus, ISO alpha-2)
    static let nationalities: [LuxuryPickerItem] = [
        .init(code: "AE", name: "🇦🇪 United Arab Emirates"),
        .init(code: "AU", name: "🇦🇺 Australia"),
        .init(code: "BE", name: "🇧🇪 Belgium"),
        .init(code: "BR", name: "🇧🇷 Brazil"),
        .init(code: "CA", name: "🇨🇦 Canada"),
        .init(code: "CH", name: "🇨🇭 Switzerland"),
        .init(code: "CN", name: "🇨🇳 China"),
        .init(code: "DE", name: "🇩🇪 Germany"),
        .init(code: "DK", name: "🇩🇰 Denmark"),
        .init(code: "ES", name: "🇪🇸 Spain"),
        .init(code: "FR", name: "🇫🇷 France"),
        .init(code: "GB", name: "🇬🇧 United Kingdom"),
        .init(code: "HK", name: "🇭🇰 Hong Kong"),
        .init(code: "ID", name: "🇮🇩 Indonesia"),
        .init(code: "IN", name: "🇮🇳 India"),
        .init(code: "IT", name: "🇮🇹 Italy"),
        .init(code: "JP", name: "🇯🇵 Japan"),
        .init(code: "KR", name: "🇰🇷 South Korea"),
        .init(code: "KW", name: "🇰🇼 Kuwait"),
        .init(code: "MX", name: "🇲🇽 Mexico"),
        .init(code: "MY", name: "🇲🇾 Malaysia"),
        .init(code: "NL", name: "🇳🇱 Netherlands"),
        .init(code: "NO", name: "🇳🇴 Norway"),
        .init(code: "NZ", name: "🇳🇿 New Zealand"),
        .init(code: "PH", name: "🇵🇭 Philippines"),
        .init(code: "PT", name: "🇵🇹 Portugal"),
        .init(code: "QA", name: "🇶🇦 Qatar"),
        .init(code: "RU", name: "🇷🇺 Russia"),
        .init(code: "SA", name: "🇸🇦 Saudi Arabia"),
        .init(code: "SE", name: "🇸🇪 Sweden"),
        .init(code: "SG", name: "🇸🇬 Singapore"),
        .init(code: "TH", name: "🇹🇭 Thailand"),
        .init(code: "TR", name: "🇹🇷 Turkey"),
        .init(code: "TW", name: "🇹🇼 Taiwan"),
        .init(code: "US", name: "🇺🇸 United States"),
        .init(code: "VN", name: "🇻🇳 Vietnam"),
        .init(code: "ZA", name: "🇿🇦 South Africa"),
    ]

    // MARK: Languages (ISO 639-1 codes)
    static let languages: [LuxuryPickerItem] = [
        .init(code: "ar", name: "Arabic"),
        .init(code: "zh", name: "Chinese (Mandarin)"),
        .init(code: "nl", name: "Dutch"),
        .init(code: "en", name: "English"),
        .init(code: "fr", name: "French"),
        .init(code: "de", name: "German"),
        .init(code: "el", name: "Greek"),
        .init(code: "hi", name: "Hindi"),
        .init(code: "id", name: "Indonesian"),
        .init(code: "it", name: "Italian"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "ko", name: "Korean"),
        .init(code: "ms", name: "Malay"),
        .init(code: "pl", name: "Polish"),
        .init(code: "pt", name: "Portuguese"),
        .init(code: "ru", name: "Russian"),
        .init(code: "es", name: "Spanish"),
        .init(code: "sv", name: "Swedish"),
        .init(code: "th", name: "Thai"),
        .init(code: "tr", name: "Turkish"),
        .init(code: "vi", name: "Vietnamese"),
    ]
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 32) {
            LuxuryMenuPicker(
                label: "Nationality",
                icon: "globe",
                items: LuxuryPickerItem.nationalities,
                selection: .constant("IN")
            )
            LuxuryMenuPicker(
                label: "Preferred Language",
                icon: "character.book.closed",
                items: LuxuryPickerItem.languages,
                selection: .constant("en")
            )
        }
        .padding()
    }
}
