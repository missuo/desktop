import SwiftUI
import SwiftData

struct CreateTextShareView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: TextShareViewModel
    var editingShare: TextShare?

    private var isEditing: Bool { editingShare != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.tr("Untitled"), text: $viewModel.title)
                        .textFieldStyle(.roundedBorder)

                    Picker(L10n.tr("Type"), selection: $viewModel.textType) {
                        ForEach(TextType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

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
                } header: {
                    Text(L10n.tr("Details"))
                }

                Section {
                    TextEditor(text: $viewModel.content)
                        .font(viewModel.textType == .sourceCode ? .system(.body, design: .monospaced) : .body)
                        .frame(minHeight: 200)
                } header: {
                    Text(L10n.tr("Content"))
                }

                if !isEditing {
                    Section {
                        SecureField(L10n.tr("Password (optional)"), text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)

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
                        }
                    } header: {
                        Text(L10n.tr("Options"))
                    }

                    if !viewModel.tags.isEmpty {
                        Section {
                            TagSelector(
                                tags: viewModel.tags,
                                selectedTagIDs: $viewModel.selectedTagIDs,
                                maxSelection: 5
                            )
                        } header: {
                            Text(L10n.tr("Tags"))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? L10n.tr("Edit Text Share") : L10n.tr("New Text Share"))
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 500)
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
                            if let share = editingShare {
                                success = await viewModel.updateTextShare(share, context: modelContext)
                            } else {
                                success = await viewModel.createTextShare(context: modelContext)
                            }
                            if success { dismiss() }
                        }
                    }
                    .disabled(viewModel.content.isEmpty || viewModel.isLoading)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .loadingOverlay(viewModel.isLoading)
            .toast(message: $viewModel.successMessage)
            .toast(message: $viewModel.errorMessage, isError: true)
        }
        .task {
            if isEditing, let share = editingShare {
                viewModel.populateForm(from: share)
            }
            await viewModel.loadDomains()
            await viewModel.loadTags()
        }
    }
}
