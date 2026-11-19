import AppKit
import CoreGraphics

private final class ScreenshotPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Captures before showing feedback, so the flash and preview never enter the image.
final class ScreenshotController: NSObject {
    private var capturing = false
    private var flashes: [NSPanel] = []
    private let shutter = NSSound(contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif", byReference: true)
    private var preview: NSPanel?
    private var previewFile: URL?
    private var hidePreview: DispatchWorkItem?

    static func folderURL(customPath: String?, systemPath: String? = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")) -> URL {
        let path = customPath ?? systemPath
        if let path, !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    func capture(customFolder: String?) {
        guard !capturing else { return }
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            return
        }
        hidePreview?.cancel()
        preview?.orderOut(nil)
        flashes.forEach { $0.orderOut(nil) }
        flashes.removeAll()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let folder = Self.folderURL(customPath: customFolder)
        let name = "Screenshot-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-"))-\(UUID().uuidString.prefix(8)).png"
        let file = folder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // Capture every display; screencapture suffixes extra display files automatically.
            process.arguments = ["-x", "-t", "png", file.path]
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.capturing = false
                    guard process.terminationStatus == 0, let image = NSImage(contentsOf: file) else {
                        self.showError("The screenshot could not be captured. Check Screen Recording access and the selected folder.")
                        return
                    }
                    NSPasteboard.general.clearContents()
                    let copied = NSPasteboard.general.writeObjects([image])
                    self.showFeedback(image: image, file: file, screen: screen)
                    if !copied { self.showError("The screenshot was saved, but could not be copied to the clipboard.") }
                }
            }
            capturing = true
            try process.run()
        } catch {
            capturing = false
            showError(error.localizedDescription)
        }
    }

    private func showFeedback(image: NSImage, file: URL, screen: NSScreen?) {
        shutter?.play()
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            for display in NSScreen.screens {
                let flash = makePanel(frame: display.frame)
                flash.backgroundColor = .white
                flash.ignoresMouseEvents = true
                flashes.append(flash)
                flash.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    flash.animator().alphaValue = 0
                } completionHandler: { [weak self] in
                    flash.orderOut(nil)
                    self?.flashes.removeAll { $0 === flash }
                }
            }
        }
        guard let screen else { return }
        let width: CGFloat = 240
        let height = min(180, width * image.size.height / max(image.size.width, 1))
        let bounds = screen.visibleFrame
        let panel = makePanel(frame: NSRect(x: bounds.maxX - width - 20, y: bounds.minY + 20, width: width, height: height))
        panel.hasShadow = true
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: width, height: height))
        button.image = image
        button.imageScaling = .scaleProportionallyUpOrDown
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.layer?.masksToBounds = true
        button.target = self
        button.action = #selector(openPreview)
        button.setAccessibilityLabel("Screenshot saved and copied. Open preview.")
        button.toolTip = "Saved and copied — click to open"
        panel.contentView = button
        preview = panel
        previewFile = file
        panel.orderFrontRegardless()
        let item = DispatchWorkItem { [weak self, weak panel] in
            panel?.orderOut(nil)
            self?.preview = nil
            self?.previewFile = nil
        }
        hidePreview = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    private func makePanel(frame: NSRect) -> NSPanel {
        let panel = ScreenshotPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }

    @objc private func openPreview() {
        guard let file = previewFile else { return }
        NSWorkspace.shared.open(file)
        preview?.orderOut(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Screenshot"
        alert.informativeText = message
        alert.runModal()
    }
}
