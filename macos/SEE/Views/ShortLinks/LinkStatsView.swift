import SwiftUI

struct LinkStatsView: View {
    @Environment(\.dismiss) private var dismiss
    let link: ShortLink
    @State private var viewModel = ShortLinkViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(link.shortURL)
                    .font(.title2.bold())
                    .foregroundStyle(Color.accentColor)

                if !link.title.isEmpty {
                    Text(link.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    StatCard(
                        title: L10n.tr("Today"),
                        value: viewModel.dailyVisits
                    )
                    StatCard(
                        title: L10n.tr("This Month"),
                        value: viewModel.monthlyVisits
                    )
                    StatCard(
                        title: L10n.tr("Total"),
                        value: viewModel.totalVisits
                    )
                }
                .padding()

                Spacer()
            }
            .padding()
            .navigationTitle(L10n.tr("Link Statistics"))
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 250)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Done")) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .task {
            await viewModel.loadStats(domain: link.domain, slug: link.slug)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: Int?

    var body: some View {
        VStack(spacing: 8) {
            if let value {
                Text("\(value)")
                    .font(.title.bold().monospacedDigit())
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
