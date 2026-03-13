import SwiftUI

struct UsageView: View {
    @State private var viewModel = UsageViewModel()

    var body: some View {
        Group {
            if !viewModel.isAvailable {
                EmptyStateView(
                    icon: "chart.bar",
                    title: L10n.tr("Usage Not Available"),
                    message: L10n.tr("Usage statistics are not available on this server.")
                )
            } else if let usage = viewModel.usage {
                ScrollView {
                    VStack(spacing: 16) {
                        // Storage summary
                        StorageCard(
                            fileCount: usage.fileCount,
                            storageUsageMb: usage.storageUsageMb,
                            storageUsageLimitMb: usage.storageUsageLimitMb
                        )

                        // Rate limit cards
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 16) {
                            UsageCard(
                                title: L10n.tr("API Calls"),
                                icon: "server.rack",
                                dayCount: usage.apiCountDay,
                                dayLimit: usage.apiCountDayLimit,
                                monthCount: usage.apiCountMonth,
                                monthLimit: usage.apiCountMonthLimit
                            )

                            UsageCard(
                                title: L10n.tr("Links"),
                                icon: "link",
                                dayCount: usage.linkCountDay,
                                dayLimit: usage.linkCountDayLimit,
                                monthCount: usage.linkCountMonth,
                                monthLimit: usage.linkCountMonthLimit
                            )

                            UsageCard(
                                title: L10n.tr("Text Shares"),
                                icon: "doc.text",
                                dayCount: usage.textCountDay,
                                dayLimit: usage.textCountDayLimit,
                                monthCount: usage.textCountMonth,
                                monthLimit: usage.textCountMonthLimit
                            )

                            UsageCard(
                                title: L10n.tr("Uploads"),
                                icon: "arrow.up.doc",
                                dayCount: usage.uploadCountDay,
                                dayLimit: usage.uploadCountDayLimit,
                                monthCount: usage.uploadCountMonth,
                                monthLimit: usage.uploadCountMonthLimit
                            )

                            UsageCard(
                                title: L10n.tr("QR Codes"),
                                icon: "qrcode",
                                dayCount: usage.qrcodeCountDay,
                                dayLimit: usage.qrcodeCountDayLimit,
                                monthCount: usage.qrcodeCountMonth,
                                monthLimit: usage.qrcodeCountMonthLimit
                            )
                        }
                    }
                    .padding()
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(L10n.tr("Usage"))
        .loadingOverlay(viewModel.isLoading)
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await viewModel.loadUsage() } }) {
                    Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                }
            }
            #endif
        }
        #if os(iOS)
        .refreshable {
            await viewModel.loadUsage()
        }
        #endif
        .task {
            await viewModel.loadUsage()
        }
    }
}

// MARK: - Storage Card

struct StorageCard: View {
    let fileCount: Int
    let storageUsageMb: String
    let storageUsageLimitMb: String

    private var isUnlimited: Bool {
        guard let limit = Double(storageUsageLimitMb) else { return false }
        return limit < 0
    }

    private var storageProgress: Double {
        guard let usage = Double(storageUsageMb),
              let limit = Double(storageUsageLimitMb),
              limit > 0 else { return 0 }
        return usage / limit
    }

    private func formatMb(_ value: String) -> String {
        guard let mb = Double(value) else { return value }
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.tr("Storage"), systemImage: "externaldrive")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("Files"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(fileCount)")
                        .font(.title2.weight(.semibold).monospacedDigit())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.tr("Used"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isUnlimited {
                        Text("\(formatMb(storageUsageMb)) / \(L10n.tr("Unlimited"))")
                            .font(.subheadline.weight(.medium).monospacedDigit())
                    } else {
                        Text("\(formatMb(storageUsageMb)) / \(formatMb(storageUsageLimitMb))")
                            .font(.subheadline.weight(.medium).monospacedDigit())
                    }
                }
            }

            if !isUnlimited {
                ProgressView(value: storageProgress)
                    .tint(storageProgress > 0.9 ? .red : storageProgress > 0.7 ? .orange : .accentColor)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Usage Card

struct UsageCard: View {
    let title: String
    let icon: String
    let dayCount: Int
    let dayLimit: Int
    let monthCount: Int
    let monthLimit: Int

    private var isUnlimitedDay: Bool { dayLimit < 0 }
    private var isUnlimitedMonth: Bool { monthLimit < 0 }

    private var dayProgress: Double {
        guard dayLimit > 0 else { return 0 }
        return Double(dayCount) / Double(dayLimit)
    }

    private var monthProgress: Double {
        guard monthLimit > 0 else { return 0 }
        return Double(monthCount) / Double(monthLimit)
    }

    private func limitText(_ count: Int, _ limit: Int) -> String {
        if limit < 0 {
            return "\(count) / \(L10n.tr("Unlimited"))"
        }
        return "\(count) / \(limit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.tr("Today"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(limitText(dayCount, dayLimit))
                        .font(.caption.monospacedDigit())
                }
                ProgressView(value: isUnlimitedDay ? 0 : dayProgress)
                    .tint(isUnlimitedDay ? .secondary.opacity(0.3) : dayProgress > 0.9 ? .red : dayProgress > 0.7 ? .orange : .accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.tr("This Month"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(limitText(monthCount, monthLimit))
                        .font(.caption.monospacedDigit())
                }
                ProgressView(value: isUnlimitedMonth ? 0 : monthProgress)
                    .tint(isUnlimitedMonth ? .secondary.opacity(0.3) : monthProgress > 0.9 ? .red : monthProgress > 0.7 ? .orange : .accentColor)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
