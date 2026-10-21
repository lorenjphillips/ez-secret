import EzSecretCore
import AppKit
import SwiftUI

final class PromptModel: ObservableObject {
    @Published var secret = ""
    @Published var revealed = false
    @Published var errorMessage: String?
    @Published var secondsLeft: Int?
    @Published var fieldFocused = false
    @Published var focusRequest = 0
    @Published var errorPulse = 0

    let label: String
    let destination: Destination
    let rules: ValidationRules
    let requester: String?
    let timeoutSeconds: Int

    var onSave: (String) -> Void = { _ in }
    var onCancel: () -> Void = {}

    init(options: CLIOptions, requester: String?) {
        label = options.label
        destination = options.destination
        rules = options.rules
        self.requester = requester
        timeoutSeconds = options.timeoutSeconds
        secondsLeft = options.timeoutSeconds
    }

    func pasteFromClipboard() {
        defer { focusRequest += 1 }
        guard let s = NSPasteboard.general.string(forType: .string) else {
            errorMessage = "Clipboard has no text"
            errorPulse += 1
            return
        }
        secret = stripTrailingNewline(s)
        errorMessage = nil
    }

    func save() {
        guard !secret.isEmpty else {
            focusRequest += 1
            return
        }
        if let problem = rules.validate(secret) {
            errorMessage = problem
            errorPulse += 1
            focusRequest += 1
            NSSound.beep()
            return
        }
        onSave(secret)
    }
}

struct PromptView: View {
    @ObservedObject var model: PromptModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.none) {
            Text(model.label)
                .font(Theme.TypeStyle.title)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(model.label)
            destinationLine.padding(.top, Theme.Space.xxs)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                secretField
                if let error = model.errorMessage {
                    Text(error)
                        .font(Theme.TypeStyle.caption)
                        .foregroundStyle(Theme.danger)
                        .lineLimit(1)
                        .help(error)
                        .accessibilityLabel("Error: \(error)")
                }
            }
            .padding(.top, Theme.Space.md)
            .modifier(FieldShake(amount: shake))
            .zIndex(1)
            buttons.padding(.top, Theme.Space.md)
        }
        .padding(Theme.Space.lg)
        .frame(width: Theme.Size.panel)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: Theme.Size.hairline)
                .allowsHitTesting(false)
        }
        .onChange(of: model.errorPulse) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: Theme.Motion.shake)) { shake += 1 }
        }
    }

    private var destinationLine: some View {
        HStack(spacing: Theme.Space.none) {
            if let requester = model.requester, !requester.isEmpty {
                Text(requester)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(" · ")
                    .layoutPriority(2)
            }
            Text(destinationText(abbreviated: true))
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
        }
        .font(Theme.TypeStyle.caption)
        .foregroundStyle(Theme.textSecondary)
        .panelTooltip(contextText(abbreviated: false), alignment: .leading, wraps: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(contextText(abbreviated: false))
    }

    private func destinationText(abbreviated: Bool) -> String {
        func path(_ value: String) -> String { abbreviated ? Destination.abbreviate(value) : value }
        switch model.destination {
        case .envFile(let value, let key): return "\(path(value)) → \(key)"
        case .file(let value): return path(value)
        case .keychain(let service, let account): return "Keychain → \(service)/\(account)"
        }
    }

    private func contextText(abbreviated: Bool) -> String {
        let destination = destinationText(abbreviated: abbreviated)
        guard let requester = model.requester, !requester.isEmpty else { return destination }
        return "\(requester) · \(destination)"
    }

    private var placeholder: String {
        var parts: [String] = []
        if let prefix = model.rules.requiredPrefix { parts.append("Starts with \(prefix)") }
        if let length = model.rules.minLength { parts.append("\(length)+ characters") }
        return parts.isEmpty ? "Paste or type" : parts.joined(separator: ", ")
    }

    private var secretField: some View {
        HStack(spacing: Theme.Space.none) {
            SecretInput(model: model, placeholder: placeholder)
                .frame(height: Theme.Size.nativeInput)
                .padding(.leading, Theme.Space.xs)
                .padding(.trailing, Theme.Space.xxs)
            Button {
                model.revealed.toggle()
                model.focusRequest += 1
            } label: {
                Image(systemName: model.revealed ? "eye.slash" : "eye")
            }
            .buttonStyle(PanelButtonStyle(kind: .icon))
            .accessibilityLabel(model.revealed ? "Hide secret" : "Show secret")
            .panelTooltip(model.revealed ? "Hide secret" : "Show secret")
            Button { model.pasteFromClipboard() } label: {
                Image(systemName: "doc.on.clipboard")
            }
            .buttonStyle(PanelButtonStyle(kind: .icon))
            .accessibilityLabel("Paste from clipboard")
            .panelTooltip("Paste from clipboard")
        }
        .padding(.trailing, Theme.Space.xxs)
        .frame(height: Theme.Size.field)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                .fill(Theme.field)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: Theme.Size.hairline)
                }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.field + Theme.Size.halo, style: .continuous)
                .strokeBorder(model.fieldFocused ? Theme.accent.opacity(0.28) : Theme.clear, lineWidth: Theme.Size.halo)
                .padding(-Theme.Size.halo)
                .blur(radius: Theme.Size.focusSoftness)
        }
        .animation(.easeOut(duration: Theme.Motion.hover), value: model.fieldFocused)
    }

    private var buttons: some View {
        HStack(spacing: Theme.Space.xs) {
            if let seconds = model.secondsLeft { countdown(seconds) }
            Spacer(minLength: Theme.Space.xs)
            Button("Cancel", action: model.onCancel)
                .buttonStyle(PanelButtonStyle(kind: .secondary))
                .panelTooltip("Cancel (Esc)")
            Button("Save") { model.save() }
                .buttonStyle(PanelButtonStyle(kind: .primary))
                .disabled(model.secret.isEmpty)
                .panelTooltip("Save (Return)")
        }
    }

    private func countdown(_ seconds: Int) -> some View {
        let tint = seconds < 10 ? Theme.danger : seconds < 30 ? Theme.warning : Theme.textSecondary
        return HStack(spacing: Theme.Space.xxs) {
            ZStack {
                Circle().stroke(Theme.fill, lineWidth: Theme.Size.track)
                Circle()
                    .trim(from: 0, to: min(1, max(0, CGFloat(seconds) / CGFloat(max(1, model.timeoutSeconds)))))
                    .stroke(tint, style: StrokeStyle(lineWidth: Theme.Size.track, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: Theme.Motion.tick), value: seconds)
            }
            .frame(width: Theme.Size.ring, height: Theme.Size.ring)
            Text(String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60))
                .font(Theme.TypeStyle.caption)
                .monospacedDigit()
                .frame(minWidth: Theme.Size.timer, alignment: .leading)
        }
        .foregroundStyle(tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time remaining")
        .accessibilityValue("\(max(0, seconds)) seconds")
    }
}

private struct FieldShake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(amount * .pi * 6) * Theme.Size.shake, y: 0))
    }
}

private struct SecretInput: NSViewRepresentable {
    @ObservedObject var model: PromptModel
    let placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> InputContainer {
        let container = InputContainer()
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.onAttach = { [weak container] in container?.focusAtEnd() }
        container.onFocus = { [weak model] in model?.fieldFocused = true }
        return container
    }

    func updateNSView(_ container: InputContainer, context: Context) {
        let coordinator = context.coordinator
        let replace = container.field == nil || coordinator.revealed != model.revealed
        if replace {
            container.field?.delegate = nil
            container.field?.removeFromSuperview()
            let field = model.revealed ? NSTextField() : NSSecureTextField()
            field.isBordered = false
            field.isBezeled = false
            field.drawsBackground = false
            field.focusRingType = .none
            field.font = Theme.TypeStyle.input
            field.cell?.usesSingleLineMode = true
            field.cell?.isScrollable = true
            field.delegate = coordinator
            field.translatesAutoresizingMaskIntoConstraints = false
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            field.setAccessibilityLabel(model.label)
            container.addSubview(field)
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Theme.Size.textInset),
                field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Theme.Size.textInset),
                field.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                field.heightAnchor.constraint(equalToConstant: Theme.Size.nativeInput)
            ])
            container.field = field
            coordinator.revealed = model.revealed
        }
        guard let field = container.field else { return }
        if field.stringValue != model.secret { field.stringValue = model.secret }
        field.textColor = .labelColor
        field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: Theme.TypeStyle.input
        ])
        if let editor = field.currentEditor() as? NSTextView { editor.insertionPointColor = .controlAccentColor }
        if replace || coordinator.focusRequest != model.focusRequest {
            coordinator.focusRequest = model.focusRequest
            DispatchQueue.main.async { [weak container] in container?.focusAtEnd() }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let model: PromptModel
        var revealed = false
        var focusRequest = -1

        init(model: PromptModel) { self.model = model }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            model.secret = field.stringValue
            model.errorMessage = nil
        }

        func controlTextDidBeginEditing(_ notification: Notification) { model.fieldFocused = true }
        func controlTextDidEndEditing(_ notification: Notification) { model.fieldFocused = false }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                model.save()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                model.onCancel()
                return true
            }
            return false
        }
    }

    final class InputContainer: NSView {
        var field: NSTextField?
        var onAttach: (() -> Void)?
        var onFocus: (() -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.onAttach?() }
        }

        func focusAtEnd() {
            guard let field, let window else { return }
            guard window.makeFirstResponder(field) else { return }
            onFocus?()
            if let editor = field.currentEditor() as? NSTextView {
                editor.isAutomaticQuoteSubstitutionEnabled = false
                editor.isAutomaticDashSubstitutionEnabled = false
                editor.isAutomaticTextReplacementEnabled = false
                editor.isAutomaticSpellingCorrectionEnabled = false
                editor.isContinuousSpellCheckingEnabled = false
                editor.setSelectedRange(NSRange(location: (field.stringValue as NSString).length, length: 0))
                editor.scrollRangeToVisible(editor.selectedRange())
            }
        }
    }
}
