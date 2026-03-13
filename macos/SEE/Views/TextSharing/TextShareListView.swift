import SwiftUI
import SwiftData

struct TextShareListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TextShare.createdAt, order: .reverse) private var shares: [TextShare]
    @State private var viewModel = TextShareViewModel()
    @State private var showingCreate = false
    @State private var searchText = ""
    @State private var shareToEdit: TextShare?
    @State private var shareToDelete: TextShare?
    @State private var currentPage = 1

    private var filteredShares: [TextShare] {
        if searchText.isEmpty { return shares }
        let query = searchText.lowercased()
        return shares.filter {
            $0.title.lowercased().contains(query) ||
            $0.content.lowercased().contains(query) ||
            $0.slug.lowercased().contains(query)
        }
    }

    private var totalPages: Int { Pagination.totalPages(for: filteredShares.count) }
    private var pagedShares: [TextShare] { Pagination.page(filteredShares, page: currentPage) }

    var body: some View {
        Group {
            if shares.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: L10n.tr("No Text Shares"),
                    message: L10n.tr("Share text, code, or markdown with a link."),
                    buttonTitle: L10n.tr("Create Text Share"),
                    action: { showingCreate = true }
                )
            } else {
                List {
                    ForEach(pagedShares) { share in
                        TextShareRow(share: share) {
                            shareToEdit = share
                        } onDelete: {
                            shareToDelete = share
                        }
                    }

                    if totalPages > 1 {
                        PaginationView(currentPage: currentPage, totalPages: totalPages) { page in
                            currentPage = page
                        }
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                    }
                }
                .searchable(text: $searchText, prompt: L10n.tr("Search text shares"))
                .onChange(of: searchText) { currentPage = 1 }
            }
        }
        .navigationTitle(L10n.tr("Text Sharing"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreate = true }) {
                    Label(L10n.tr("New Text"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateTextShareView(viewModel: viewModel)
                #if os(iOS)
                .presentationDetents([.large])
                #endif
        }
        .sheet(item: $shareToEdit) { share in
            CreateTextShareView(viewModel: viewModel, editingShare: share)
                #if os(iOS)
                .presentationDetents([.large])
                #endif
        }
        .alert(L10n.tr("Delete Text Share?"), isPresented: .init(
            get: { shareToDelete != nil },
            set: { if !$0 { shareToDelete = nil } }
        )) {
            Button(L10n.tr("Cancel"), role: .cancel) {}
            Button(L10n.tr("Delete"), role: .destructive) {
                if let share = shareToDelete {
                    Task {
                        let _ = await viewModel.deleteTextShare(share, context: modelContext)
                    }
                }
            }
        } message: {
            Text(L10n.tr("This action cannot be undone."))
        }
        .toast(message: $viewModel.successMessage)
        .toast(message: $viewModel.errorMessage, isError: true)
        .onReceive(NotificationCenter.default.publisher(for: .createTextShare)) { _ in
            showingCreate = true
        }
    }
}

// MARK: - Row

struct TextShareRow: View {
    let share: TextShare
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var badgeText: String {
        switch share.textType {
        case TextType.sourceCode.rawValue: L10n.tr("Code")
        case TextType.markdown.rawValue: L10n.tr("Markdown")
        default: L10n.tr("Text")
        }
    }

    var body: some View {
        LinkRowView(
            shortURL: share.shortURL,
            title: share.title,
            subtitle: share.content,
            badge: badgeText,
            date: share.createdAt,
            onCopy: { ClipboardService.copy(share.shortURL) },
            onEdit: onEdit,
            onDelete: onDelete
        )
    }
}
