import SwiftUI
import SwiftData

struct CreateShortLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ShortLinkViewModel
    var editingLink: ShortLink?

    private var isEditing: Bool { editingLink != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.tr("Target URL"), text: $viewModel.targetURL)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif

                    if !viewModel.targetURL.isEmpty && !viewModel.targetURL.isValidURL {
                        Text(L10n.tr("Please enter a valid URL"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if !viewModel.domains.isEmpty {
                        DomainPicker(
                            title: L10n.tr("Domain"),
                            selection: $viewModel.selectedDomain,
                            domains: viewModel.domains
                        )
                    }

                    TextField(L10n.tr("Custom Slug (optional)"), text: $viewModel.customSlug)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isEditing)

                    TextField(L10n.tr("Title (optional)"), text: $viewModel.title)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text(L10n.tr("Link Details"))
                }

                if !isEditing {
                    Section {
                        SecureField(L10n.tr("Password (optional)"), text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                    } header: {
                        Text(L10n.tr("Protection"))
                    }

                    Section {
                        Toggle(L10n.tr("Set Expiration"), isOn: $viewModel.enableExpiry)
                        if viewModel.enableExpiry {
                            DatePicker(
                                L10n.tr("Expire At"),
                                selection: Binding(
                                    get: { viewModel.expireAt ?? Date().addingTimeInterval(86400) },
                                    set: { viewModel.expireAt = $0 }
                                ),
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )

                            TextField(
                                L10n.tr("Redirect URL after expiry (optional)"),
                                text: $viewModel.expirationRedirectURL
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    } header: {
                        Text(L10n.tr("Expiration"))
                    }

                    if !viewModel.tags.isEmpty {
                        Section {
                            TagSelector(tags: viewModel.tags, selectedTagIDs: $viewModel.selectedTagIDs)
                        } header: {
                            Text(L10n.tr("Tags"))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? L10n.tr("Edit Short Link") : L10n.tr("New Short Link"))
            #if os(macOS)
            .frame(minWidth: 450, minHeight: 400)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? L10n.tr("Save") : L10n.tr("Create")) {
                        Task {
                            let success: Bool
                            if let link = editingLink {
                                success = await viewModel.updateShortLink(link, context: modelContext)
                            } else {
                                success = await viewModel.createShortLink(context: modelContext)
                            }
                            if success { dismiss() }
                        }
                    }
                    .disabled(viewModel.targetURL.isEmpty || viewModel.isLoading)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .loadingOverlay(viewModel.isLoading)
            .toast(message: $viewModel.successMessage)
            .toast(message: $viewModel.errorMessage, isError: true)
        }
        .task {
            if isEditing, let link = editingLink {
                viewModel.populateForm(from: link)
            }
            await viewModel.loadDomains()
            await viewModel.loadTags()
        }
    }
}
