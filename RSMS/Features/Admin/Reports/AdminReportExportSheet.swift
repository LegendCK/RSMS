import SwiftUI

struct AdminReportExportSheet: View {
    @Binding var selectedScope: AdminReportScope
    @Binding var selectedFormat: AdminReportFormat
    let isExporting: Bool
    let onExport: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("MANAGEMENT EXPORT")
                                .font(AppTypography.overline)
                                .tracking(2)
                                .foregroundColor(AppColors.accent)
                            Text("Choose report scope and format")
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondaryDark)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.md)

                        LuxuryCardView(useGlass: false, cornerRadius: AppSpacing.radiusMedium) {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                Text("Report Scope")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Picker("Type", selection: $selectedScope) {
                                    ForEach(AdminReportScope.allCases, id: \.self) { scope in
                                        Text(scope.rawValue).tag(scope)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(AppSpacing.cardPadding)
                        }

                        LuxuryCardView(useGlass: false, cornerRadius: AppSpacing.radiusMedium) {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                Text("Format")
                                    .font(AppTypography.label)
                                    .foregroundColor(AppColors.textPrimaryDark)
                                Picker("Format", selection: $selectedFormat) {
                                    ForEach(AdminReportFormat.allCases, id: \.self) { format in
                                        Text(format.rawValue).tag(format)
                                    }
                                }
                                .pickerStyle(.inline)
                            }
                            .padding(AppSpacing.cardPadding)
                        }

                        PrimaryButton(title: isExporting ? "Preparing…" : "Export Report", isLoading: isExporting) {
                            onExport()
                        }
                        .disabled(isExporting)

                        Text("Exports use a live Supabase snapshot so files match system records.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondaryDark)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: AppSpacing.xl)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Removed cancel/close button as per design update
            }
        }
    }
}
