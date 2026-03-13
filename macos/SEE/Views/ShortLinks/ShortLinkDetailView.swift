import SwiftUI

struct ShortLinkDetailView: View {
    let link: ShortLink

    var body: some View {
        List {
            Section {
                LabeledContent(L10n.tr("Short URL")) {
                    HStack {
                        Text(link.shortURL)
                            .foregroundStyle(Color.accentColor)
                        Button(action: { ClipboardService.copy(link.shortURL) }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                LabeledContent(L10n.tr("Target URL")) {
                    HStack {
                        Text(link.targetURL)
                            .lineLimit(2)
                        Button(action: { ClipboardService.copy(link.targetURL) }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if !link.title.isEmpty {
                    LabeledContent(L10n.tr("Title"), value: link.title)
                }

                LabeledContent(L10n.tr("Domain"), value: link.domain)
                LabeledContent(L10n.tr("Slug"), value: link.slug)

                if let customSlug = link.customSlug {
                    LabeledContent(L10n.tr("Custom Slug"), value: customSlug)
                }
            }

            Section {
                LabeledContent(L10n.tr("Created"), value: link.createdAt.shortFormatted)

                if link.hasPassword {
                    Label(L10n.tr("Password Protected"), systemImage: "lock.fill")
                }

                if let expireAt = link.expireAt {
                    LabeledContent(L10n.tr("Expires"), value: expireAt.shortFormatted)
                }
            }
        }
        .navigationTitle(link.shortURL)
    }
}
