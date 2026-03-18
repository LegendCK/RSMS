import SwiftUI

struct AdminReportExportSheet: View {
    @Binding var selectedScope: AdminReportScope
    @Binding var selectedFormat: AdminReportFormat
    let isExporting: Bool
    let onExport: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Report") {
                    Picker("Type", selection: $selectedScope) {
                        ForEach(AdminReportScope.allCases, id: \.self) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(AdminReportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Button(action: onExport) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .tint(AppColors.accent)
                            }
                            Text(isExporting ? "Preparing…" : "Export Report")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .disabled(isExporting)
                } footer: {
                    Text("Exports use live Supabase snapshot so files match system records.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
