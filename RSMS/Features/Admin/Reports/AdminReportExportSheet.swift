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
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Icon + header
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppColors.accent.opacity(0.10))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(AppColors.accent)
                            }
                            Text("Export Report")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Choose a scope and file format")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 24)

                        // Scope section
                        formSection(title: "REPORT SCOPE") {
                            Picker("Scope", selection: $selectedScope) {
                                ForEach(AdminReportScope.allCases, id: \.self) { scope in
                                    Text(scope.rawValue).tag(scope)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }

                        // Format section
                        formSection(title: "FORMAT") {
                            ForEach(Array(AdminReportFormat.allCases.enumerated()), id: \.element) { index, format in
                                if index > 0 {
                                    Divider().padding(.leading, 16)
                                }
                                Button {
                                    selectedFormat = format
                                } label: {
                                    HStack {
                                        Text(format.rawValue)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedFormat == format {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(AppColors.accent)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Disclaimer
                        Text("Exports use a live Supabase snapshot so files match system records.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)

                        // Export button
                        Button {
                            onExport()
                        } label: {
                            HStack(spacing: 8) {
                                if isExporting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                }
                                Text(isExporting ? "Preparing…" : "Export Report")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isExporting ? AppColors.accent.opacity(0.6) : AppColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isExporting)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .principal) {
                    Text("EXPORT")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 20)
        }
    }
}
