import EzSecretCore
import AppKit
import SwiftUI

final class SecretPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    var onCancel: (() -> Void)?
}

final class PromptController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let options: CLIOptions
    private let model: PromptModel
    private var panel: SecretPanel?
    private var countdown: Timer?
    private var finished = false

    init(options: CLIOptions) {
        self.options = options
        self.model = PromptModel(options: options, requester: Session.requesterName())
        super.init()
        model.onSave = { [weak self] secret in self?.save(secret) }
        model.onCancel = { [weak self] in self?.finish(stdout: "cancelled", code: ExitCode.cancelled) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        showPanel()
        startCountdown()
    }

    private func installEditMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func showPanel() {
        let panel = SecretPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Secret requested"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.model.onCancel() }

        let hosting = NSHostingView(rootView: PromptView(model: model))
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        panel.center()
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(hosting)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, !self.finished else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.panel?.makeKeyAndOrderFront(nil)
        }
    }

    private func startCountdown() {
        guard options.timeoutSeconds > 0 else { return }
        countdown = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let left = self.model.secondsLeft else { return }
            if left <= 1 {
                self.finish(stdout: "timeout", code: ExitCode.timeout)
            } else {
                self.model.secondsLeft = left - 1
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model.onCancel()
        return false
    }

    private func save(_ secret: String) {
        guard !finished else { return }
        do {
            let result = try SecretStore.store(secret, to: options.destination, label: options.label, digest: options.digest)
            if options.clearClipboard { clearClipboardIfItHolds(secret) }
            finish(stdout: result.stdoutLine, code: ExitCode.stored)
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            finish(stdout: nil, code: ExitCode.storeFailed)
        }
    }

    private func clearClipboardIfItHolds(_ secret: String) {
        let pb = NSPasteboard.general
        guard let current = pb.string(forType: .string) else { return }
        if current == secret || stripTrailingNewline(current) == secret {
            pb.clearContents()
        }
    }

    private func finish(stdout line: String?, code: Int32) {
        guard !finished else { return }
        finished = true
        countdown?.invalidate()
        model.secret = ""
        panel?.orderOut(nil)
        if let line {
            print(line)
        }
        fflush(Darwin.stdout)
        exit(code)
    }
}

enum GUIRunner {
    static func run(options: CLIOptions) -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let controller = PromptController(options: options)
        app.delegate = controller
        app.run()
        exit(ExitCode.cancelled)
    }
}
