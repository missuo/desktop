import SwiftUI

struct TextShareDetailView: View {
    let share: TextShare

    var body: some View {
        List {
            Section {
                LabeledContent(L10n.tr("Title"), value: share.title)

                LabeledContent(L10n.tr("Link")) {
                    HStack {
                        Text(share.shortURL)
                            .foregroundStyle(Color.accentColor)
                        Button(action: { ClipboardService.copy(share.shortURL) }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                LabeledContent(L10n.tr("Type")) {
                    Text(TextType(rawValue: share.textType)?.displayName ?? share.textType)
                }

                LabeledContent(L10n.tr("Domain"), value: share.domain)
                LabeledContent(L10n.tr("Created"), value: share.createdAt.shortFormatted)
            }

            Section {
                Text(share.content)
                    .font(share.textType == TextType.sourceCode.rawValue
                          ? .system(.body, design: .monospaced) : .body)
                    .textSelection(.enabled)
            } header: {
                Text(L10n.tr("Content"))
            }
        }
        .navigationTitle(share.title)
    }
}
