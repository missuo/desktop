import SwiftUI
import SwiftData
import AVFoundation
import UserNotifications

#if os(macOS)
class ServiceProvider: NSObject {
    var modelContainer: ModelContainer?

    @objc func uploadPublic(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handleService(pboard: pboard, isPrivate: false)
    }

    @objc func uploadPrivate(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handleService(pboard: pboard, isPrivate: true)
    }

    private func handleService(pboard: NSPasteboard, isPrivate: Bool) {
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty,
              let container = modelContainer else { return }

        let paths = urls.map { $0.path }
        BackgroundUploader.upload(paths: paths, isPrivate: isPrivate, container: container)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let serviceProvider = ServiceProvider()
    var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let container = modelContainer else { return }

        for url in urls {
            guard url.scheme == "see", url.host == "upload" else { continue }

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []

            let isPrivate = queryItems.first(where: { $0.name == "private" })?.value == "1"
            guard let pathsValue = queryItems.first(where: { $0.name == "paths" })?.value,
                  !pathsValue.isEmpty else { continue }

            let paths = pathsValue.components(separatedBy: ",")
            BackgroundUploader.upload(paths: paths, isPrivate: isPrivate, container: container)
        }
    }
}
#endif

// MARK: - Background Uploader

enum BackgroundUploader {
    static func upload(paths: [String], isPrivate: Bool, container: ModelContainer) {
        let domain = UserDefaults.standard.string(forKey: Constants.defaultFileDomainKey)

        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound])

            let context = ModelContext(container)
            var successCount = 0
            var failCount = 0
            var lastURL: String?

            for path in paths {
                let fileURL = URL(fileURLWithPath: path)
                guard let data = try? Data(contentsOf: fileURL) else {
                    failCount += 1
                    continue
                }
                let filename = fileURL.lastPathComponent

                do {
                    let response = try await APIClient.shared.uploadFile(
                        data,
                        filename: filename,
                        domain: domain,
                        isPrivate: isPrivate,
                        progress: { _ in }
                    )

                    // Extract local media metadata
                    var localWidth = response.width
                    var localHeight = response.height
                    var localDuration: Double?

                    let ext = (filename as NSString).pathExtension.lowercased()
                    let videoExts = ["mp4", "mov", "m4v", "avi", "mkv", "webm", "3gp"]
                    let audioExts = ["mp3", "m4a", "aac", "wav", "flac", "ogg", "wma", "aiff"]
                    if videoExts.contains(ext) || audioExts.contains(ext) {
                        let asset = AVURLAsset(url: fileURL)
                        if videoExts.contains(ext),
                           let track = try? await asset.loadTracks(withMediaType: .video).first {
                            let size = try? await track.load(.naturalSize)
                            let transform = try? await track.load(.preferredTransform)
                            if let size, let transform {
                                let transformed = size.applying(transform)
                                localWidth = Int(abs(transformed.width))
                                localHeight = Int(abs(transformed.height))
                            }
                        }
                        let duration = try? await asset.load(.duration)
                        if let duration {
                            let seconds = CMTimeGetSeconds(duration)
                            if seconds.isFinite && seconds > 0 {
                                localDuration = seconds
                            }
                        }
                    }

                    let file = UploadedFile(
                        fileID: response.fileID,
                        filename: response.filename,
                        storename: response.storename,
                        size: response.size,
                        width: localWidth,
                        height: localHeight,
                        duration: localDuration,
                        url: response.url,
                        page: response.page,
                        path: response.path,
                        deleteHash: response.hash,
                        deleteURL: response.delete,
                        isPrivate: isPrivate
                    )
                    context.insert(file)
                    try? context.save()

                    if !isPrivate {
                        ClipboardService.copy(response.url)
                        lastURL = response.url
                    }

                    // Generate thumbnail in background
                    let responseURL = response.url
                    Task.detached(priority: .utility) {
                        await ThumbnailService.shared.generateAndCache(
                            for: fileURL,
                            identifier: responseURL,
                            size: 88
                        )
                    }

                    successCount += 1
                } catch {
                    failCount += 1
                }
            }

            // Send system notification
            let content = UNMutableNotificationContent()
            content.sound = .default
            if failCount == 0 {
                if successCount == 1 {
                    content.title = L10n.tr("Upload Complete")
                    if isPrivate {
                        content.body = L10n.tr("Private file uploaded successfully.")
                    } else {
                        content.body = L10n.tr("Link copied to clipboard.")
                        if let lastURL {
                            content.subtitle = lastURL
                        }
                    }
                } else {
                    content.title = L10n.tr("Upload Complete")
                    if isPrivate {
                        content.body = L10n.format("%ld private files uploaded successfully.", successCount)
                    } else {
                        content.body = L10n.format("%ld files uploaded. Last link copied to clipboard.", successCount)
                    }
                }
            } else if successCount == 0 {
                content.title = L10n.tr("Upload Failed")
                content.body = L10n.format("%ld file(s) failed to upload.", failCount)
            } else {
                content.title = L10n.tr("Upload Partially Complete")
                content.body = L10n.format("%ld succeeded, %ld failed.", successCount, failCount)
            }

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await center.add(request)
        }
    }
}

@main
struct SEEApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var localizationObserver = LocalizationObserver()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ShortLink.self,
            TextShare.self,
            UploadedFile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .id(localizationObserver.version)
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(after: .newItem) {
                Button(L10n.tr("New Short Link")) {
                    NotificationCenter.default.post(name: .createShortLink, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button(L10n.tr("New Text Share")) {
                    NotificationCenter.default.post(name: .createTextShare, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .id(localizationObserver.version)
                .modelContainer(sharedModelContainer)
        }

        MenuBarExtra("S.EE", image: "MenuBarIcon") {
            MenuBarView()
                .id(localizationObserver.version)
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    init() {
        #if os(macOS)
        appDelegate.modelContainer = sharedModelContainer
        appDelegate.serviceProvider.modelContainer = sharedModelContainer
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createShortLink = Notification.Name("createShortLink")
    static let createTextShare = Notification.Name("createTextShare")
}
