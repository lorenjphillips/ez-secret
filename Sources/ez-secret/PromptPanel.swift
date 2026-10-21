import EzSecretCore
import AppKit
import SwiftUI
import Combine

final class SecretPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handleShortcut(event) { return }
        super.sendEvent(event)
    }

    override func keyDown(with event: NSEvent) {
        if handleShortcut(event) { return }
        super.keyDown(with: event)
    }

    func handleShortcut(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 36, 76:
            if !event.isARepeat { onSave?() }
            return true
        case 53:
            if !event.isARepeat { onCancel?() }
            return true
        default:
            return false
        }
    }

    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
}

final class PromptController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let options: CLIOptions
    private let model: PromptModel
    private var panel: SecretPanel?
    private var countdown: Timer?
    private var contentObservation: AnyCancellable?
    private var finished = false

    init(options: CLIOptions) {
        self.options = options
        self.model = PromptModel(options: options, requester: Session.requesterName(requester: options.requester))
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
            contentRect: NSRect(x: 0, y: 0, width: Theme.Size.panel, height: Theme.Size.initialHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.onSave = { [weak self] in self?.model.save() }
        panel.onCancel = { [weak self] in self?.model.onCancel() }

        let hosting = NSHostingView(rootView: PromptView(model: model))
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        panel.center()
        self.panel = panel
        contentObservation = model.$errorMessage.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.resizeToFit() }
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, !self.finished else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.panel?.makeKeyAndOrderFront(nil)
            self.model.focusRequest += 1
        }
    }

    private func resizeToFit() {
        guard let panel, let hosting = panel.contentView else { return }
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        guard size.height != panel.frame.height else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
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
            finish(stdout: result.stdoutLine, code: ExitCode.stored)
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            finish(stdout: nil, code: ExitCode.storeFailed)
        }
    }

    private func finish(stdout line: String?, code: Int32) {
        guard !finished else { return }
        finished = true
        countdown?.invalidate()
        contentObservation?.cancel()
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
