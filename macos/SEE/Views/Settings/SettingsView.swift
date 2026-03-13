import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var hasAPIKey: Bool
    @State private var baseURL = UserDefaults.standard.string(forKey: Constants.baseURLKey) ?? Constants.defaultBaseURL
    @State private var apiKey = KeychainService.getAPIKey() ?? ""
    @State private var showAPIKey = false
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    @State private var shortLinkDomains: [String] = []
    @State private var textDomains: [String] = []
    @State private var fileDomains: [String] = []
    @State private var defaultShortLinkDomain = UserDefaults.standard.string(forKey: Constants.defaultShortLinkDomainKey) ?? ""
    @State private var defaultTextDomain = UserDefaults.standard.string(forKey: Constants.defaultTextDomainKey) ?? ""
    @State private var defaultFileDomain = UserDefaults.standard.string(forKey: Constants.defaultFileDomainKey) ?? ""
    @State private var isLoadingDomains = false
    @State private var defaultFileLinkDisplay: LinkDisplayType = {
        if let saved = UserDefaults.standard.string(forKey: Constants.defaultFileLinkDisplayKey),
           let type = LinkDisplayType(rawValue: saved) {
            return type
        }
        return .sharePage
    }()
    @State private var pasteImageFormat: PasteImageFormat = {
        if let saved = UserDefaults.standard.string(forKey: Constants.pasteImageFormatKey),
           let fmt = PasteImageFormat(rawValue: saved) {
            return fmt
        }
        return .webp
    }()
    @State private var isClearingCache = false
    @State private var showClearHistoryAlert = false
    @State private var cacheCleared = false
    @State private var appLanguage = AppLocalization.selectedLanguage()

    enum ValidationResult {
        case success
        case failure(String)
    }

    init(hasAPIKey: Binding<Bool>? = nil) {
        _hasAPIKey = hasAPIKey ?? .constant(true)
    }

    var body: some View {
        Form {
            Section {
                #if os(macOS)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("Base URL"))
                        .font(.subheadline.weight(.medium))
                    TextField("", text: $baseURL, prompt: Text("https://s.ee/api/v1/"))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 420, alignment: .leading)
                        .onChange(of: baseURL) {
                            UserDefaults.standard.set(baseURL, forKey: Constants.baseURLKey)
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("API Key"))
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 6) {
                        Group {
                            if showAPIKey {
                                TextField("", text: $apiKey)
                            } else {
                                SecureField("", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 420, alignment: .leading)

                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        Button(L10n.tr("Paste from Clipboard")) {
                            if let clipboard = ClipboardService.getString() {
                                apiKey = clipboard
                            }
                        }

                        Button(action: validateKey) {
                            if isValidating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(L10n.tr("Verify API Key"))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.isEmpty || isValidating)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                #else
                TextField(L10n.tr("Base URL"), text: $baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .onChange(of: baseURL) {
                        UserDefaults.standard.set(baseURL, forKey: Constants.baseURLKey)
                    }

                SecureField(L10n.tr("API Key"), text: $apiKey)

                Button(L10n.tr("Paste from Clipboard")) {
                    if let clipboard = ClipboardService.getString() {
                        apiKey = clipboard
                    }
                }

                Button(action: validateKey) {
                    HStack {
                        Text(L10n.tr("Verify API Key"))
                        Spacer()
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(apiKey.isEmpty || isValidating)
                #endif

                if let validationResult {
                    switch validationResult {
                    case .success:
                        Label(
                            L10n.tr("API key verified successfully!"),
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Link(destination: URL(string: "https://s.ee/user/developers/")!) {
                    HStack {
                        Label(L10n.tr("Get your API Token"), systemImage: "key.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(L10n.tr("API Configuration"))
            }

            Section {
                if isLoadingDomains {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.tr("Loading domains..."))
                            .foregroundStyle(.secondary)
                    }
                } else if shortLinkDomains.isEmpty && textDomains.isEmpty && fileDomains.isEmpty {
                    Text(L10n.tr("No domains available. Verify your API key first."))
                        .foregroundStyle(.secondary)
                } else {
                    if !shortLinkDomains.isEmpty {
                        DomainPicker(
                            title: L10n.tr("Short Links"),
                            selection: $defaultShortLinkDomain,
                            domains: shortLinkDomains
                        )
                        .onChange(of: defaultShortLinkDomain) {
                            UserDefaults.standard.set(defaultShortLinkDomain, forKey: Constants.defaultShortLinkDomainKey)
                        }
                    }

                    if !textDomains.isEmpty {
                        DomainPicker(
                            title: L10n.tr("Text Sharing"),
                            selection: $defaultTextDomain,
                            domains: textDomains
                        )
                        .onChange(of: defaultTextDomain) {
                            UserDefaults.standard.set(defaultTextDomain, forKey: Constants.defaultTextDomainKey)
                        }
                    }

                    if !fileDomains.isEmpty {
                        DomainPicker(
                            title: L10n.tr("File Upload"),
                            selection: $defaultFileDomain,
                            domains: fileDomains
                        )
                        .onChange(of: defaultFileDomain) {
                            UserDefaults.standard.set(defaultFileDomain, forKey: Constants.defaultFileDomainKey)
                        }
                    }
                }
            } header: {
                Text(L10n.tr("Default Domains"))
            }

            Section {
                Picker(L10n.tr("File Upload Link Format"), selection: $defaultFileLinkDisplay) {
                    ForEach(LinkDisplayType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .onChange(of: defaultFileLinkDisplay) {
                    UserDefaults.standard.set(defaultFileLinkDisplay.rawValue, forKey: Constants.defaultFileLinkDisplayKey)
                }

                Picker(L10n.tr("Paste Image Format"), selection: $pasteImageFormat) {
                    ForEach(PasteImageFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .onChange(of: pasteImageFormat) {
                    UserDefaults.standard.set(pasteImageFormat.rawValue, forKey: Constants.pasteImageFormatKey)
                }
            } header: {
                Text(L10n.tr("File Upload"))
            }

            Section {
                Picker(L10n.tr("App Language"), selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: appLanguage) {
                    AppLocalization.setSelectedLanguage(appLanguage)
                }
            } header: {
                Text(L10n.tr("Language"))
            } footer: {
                Text(L10n.tr("Language changes apply immediately."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent(L10n.tr("Version")) {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                }

                Link(destination: Constants.websiteURL) {
                    LabeledContent(L10n.tr("Website")) {
                        Text("s.ee")
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Link(destination: URL(string: "https://s.ee/privacy/")!) {
                    LabeledContent(L10n.tr("Privacy Policy")) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://s.ee/terms/")!) {
                    LabeledContent(L10n.tr("Terms of Service")) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://s.ee/aup/")!) {
                    LabeledContent(L10n.tr("Acceptable Use Policy")) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(L10n.tr("About"))
            }

            #if os(macOS)
            Section {
            } header: {
                Text(L10n.tr("Cache"))
            } footer: {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: clearThumbnailCache) {
                        HStack(spacing: 8) {
                            Text(L10n.tr("Clear Thumbnail Cache"))
                            if isClearingCache {
                                ProgressView()
                                    .controlSize(.small)
                            } else if cacheCleared {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(isClearingCache)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.body)
                .foregroundStyle(.primary)
            }

            Section {
            } header: {
                Text(L10n.tr("Data"))
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { showClearHistoryAlert = true }) {
                        Text(L10n.tr("Clear Local History"))
                    }

                    Text(L10n.tr("Local history only stores records on this device."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.body)
                .foregroundStyle(.primary)
            }

            Section {
            } header: {
                Text(L10n.tr("Account"))
            } footer: {
                VStack(alignment: .leading, spacing: 0) {
                    Button(L10n.tr("Sign Out")) {
                        KeychainService.setAPIKey(nil)
                        hasAPIKey = false
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.body)
                .foregroundStyle(.primary)
            }
            #else
            Section {
                Button(action: clearThumbnailCache) {
                    HStack {
                        Text(L10n.tr("Clear Thumbnail Cache"))
                        Spacer()
                        if isClearingCache {
                            ProgressView()
                                .controlSize(.small)
                        } else if cacheCleared {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .disabled(isClearingCache)
            } header: {
                Text(L10n.tr("Cache"))
            }

            Section {
                Button(role: .destructive, action: { showClearHistoryAlert = true }) {
                    Text(L10n.tr("Clear Local History"))
                }
            } header: {
                Text(L10n.tr("Data"))
            } footer: {
                Text(L10n.tr("Local history only stores records on this device."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(L10n.tr("Sign Out"), role: .destructive) {
                    KeychainService.setAPIKey(nil)
                    hasAPIKey = false
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.tr("Settings"))
        .alert(L10n.tr("Clear Local History?"), isPresented: $showClearHistoryAlert) {
            Button(L10n.tr("Cancel"), role: .cancel) {}
            Button(L10n.tr("Clear"), role: .destructive) {
                clearLocalHistory()
            }
        } message: {
            Text(L10n.tr("This will only remove records stored on this device. Your files, links, and text shares on the server will not be affected. To delete data from the server, please visit s.ee."))
        }
        .task {
            await loadAllDomains()
        }
    }

    private func clearLocalHistory() {
        do {
            try modelContext.delete(model: ShortLink.self)
            try modelContext.delete(model: TextShare.self)
            try modelContext.delete(model: UploadedFile.self)
            try modelContext.save()
        } catch {
            // Silently handle
        }
    }

    private func loadAllDomains() async {
        guard KeychainService.getAPIKey() != nil else { return }
        isLoadingDomains = true
        defer { isLoadingDomains = false }

        // Fetch all three domain types
        do {
            let response: APIResponse<DomainsResponse> = try await APIClient.shared.request(.getDomains)
            shortLinkDomains = response.data?.domains ?? []
            if defaultShortLinkDomain.isEmpty, let first = shortLinkDomains.first {
                defaultShortLinkDomain = first
            }
        } catch { }

        do {
            let response: APIResponse<DomainsResponse> = try await APIClient.shared.request(.getTextDomains)
            textDomains = response.data?.domains ?? []
            if defaultTextDomain.isEmpty, let first = textDomains.first {
                defaultTextDomain = first
            }
        } catch { }

        do {
            let response: APIResponse<DomainsResponse> = try await APIClient.shared.request(.getFileDomains)
            fileDomains = response.data?.domains ?? []
            if defaultFileDomain.isEmpty, let first = fileDomains.first {
                defaultFileDomain = first
            }
        } catch { }
    }

    private func clearThumbnailCache() {
        isClearingCache = true
        cacheCleared = false
        Task {
            await ThumbnailService.shared.clearCache()
            isClearingCache = false
            cacheCleared = true
            // Reset checkmark after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            cacheCleared = false
        }
    }

    private func validateKey() {
        isValidating = true
        validationResult = nil

        UserDefaults.standard.set(baseURL, forKey: Constants.baseURLKey)
        KeychainService.setAPIKey(apiKey)

        Task {
            do {
                let _ = try await APIClient.shared.validateAPIKey()
                validationResult = .success
                await loadAllDomains()
            } catch {
                validationResult = .failure(error.localizedDescription)
            }
            isValidating = false
        }
    }
}
