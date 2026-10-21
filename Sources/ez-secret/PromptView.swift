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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake: CGFloat = 0

    private var theme: Theme { Theme(scheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.none) {
            Text(model.label)
                .font(Theme.TypeStyle.title)
                .tracking(Theme.Size.titleTracking)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            destinationLine.padding(.top, Theme.Space.xs)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                secretField
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(Theme.TypeStyle.caption)
                        .foregroundStyle(theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Error: \(error)")
                }
            }
            .padding(.top, Theme.Space.xl)
            .modifier(FieldShake(amount: shake))
            .zIndex(1)
            buttons.padding(.top, Theme.Space.lg)
            if let seconds = model.secondsLeft {
                countdown(seconds).padding(.top, Theme.Space.md)
            }
        }
        .padding(Theme.Space.xl)
        .frame(width: Theme.Size.panel)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.panel)
                .strokeBorder(theme.border, lineWidth: Theme.Size.hairline)
                .allowsHitTesting(false)
        }
        .onChange(of: model.errorPulse) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: Theme.Motion.shake)) { shake += 1 }
        }
    }

    private var destinationLine: some View {
        HStack(spacing: Theme.Space.xxs) {
            if let requester = model.requester, !requester.isEmpty {
                Text("\(requester) →")
                    .lineLimit(1)
                    .frame(maxWidth: Theme.Size.requester, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Text(destinationText(abbreviated: true))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(Theme.TypeStyle.mono)
        .foregroundStyle(theme.textSecondary)
        .accessibilityHint(destinationText(abbreviated: false))
        .accessibilityElement(children: .combine)
    }

    private func destinationText(abbreviated: Bool) -> String {
        func path(_ value: String) -> String { abbreviated ? Destination.abbreviate(value) : value }
        switch model.destination {
        case .envFile(let value, let key): return "\(path(value)) · \(key)"
        case .file(let value): return path(value)
        case .keychain(let service, let account): return "Keychain · \(service)/\(account)"
        }
    }

    private var placeholder: String {
        var parts: [String] = []
        if let prefix = model.rules.requiredPrefix { parts.append("\(prefix)…") }
        if let length = model.rules.minLength { parts.append("\(length)+ chars") }
        return parts.isEmpty ? "Enter secret" : parts.joined(separator: "  ·  ")
    }

    private var secretField: some View {
        HStack(spacing: Theme.Space.xxs) {
            SecretInput(model: model, placeholder: placeholder, ink: theme.textPrimary, quiet: theme.textTertiary, accent: theme.accent)
                .frame(height: Theme.Size.input)
                .padding(.leading, Theme.Space.md)
            Button {
                model.revealed.toggle()
                model.focusRequest += 1
            } label: {
                Image(systemName: model.revealed ? "eye.slash" : "eye")
                    .font(Theme.TypeStyle.icon)
                    .frame(width: Theme.Size.icon)
            }
            .buttonStyle(PanelButtonStyle(kind: .icon))
            .accessibilityLabel(model.revealed ? "Hide secret" : "Show secret")
            .panelTooltip(model.revealed ? "Hide" : "Show")
            Button { model.pasteFromClipboard() } label: {
                HStack(spacing: Theme.Space.xxs) {
                    Image(systemName: "clipboard")
                    Text("Paste")
                }
            }
            .buttonStyle(PanelButtonStyle(kind: .chip))
            .panelTooltip("Paste from clipboard")
        }
        .padding(.trailing, Theme.Space.sm)
        .frame(height: Theme.Size.field)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.field)
                .fill(theme.field)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.field)
                        .strokeBorder(model.errorMessage != nil ? theme.danger : model.fieldFocused ? theme.accent : theme.border, lineWidth: Theme.Size.line)
                }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.field + Theme.Size.halo)
                .fill(model.errorMessage != nil ? theme.errorHalo : model.fieldFocused ? theme.focus : Theme.clear)
                .padding(-Theme.Size.halo)
        }
        .animation(.easeOut(duration: Theme.Motion.hover), value: model.fieldFocused)
    }

    private var buttons: some View {
        HStack(spacing: Theme.Space.sm) {
            Spacer(minLength: Theme.Space.none)
            Button(action: model.onCancel) { buttonLabel("Cancel", key: "esc") }
                .buttonStyle(PanelButtonStyle(kind: .secondary))
            Button { model.save() } label: { buttonLabel("Save", key: "↩", primary: true) }
                .buttonStyle(PanelButtonStyle(kind: .primary))
                .disabled(model.secret.isEmpty)
        }
    }

    private func buttonLabel(_ title: String, key: String, primary: Bool = false) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Text(title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(key)
                .font(key == "esc" ? Theme.TypeStyle.key : Theme.TypeStyle.returnKey)
                .frame(width: Theme.Size.keyWidth, height: Theme.Size.keyHeight)
                .background(primary && !model.secret.isEmpty ? theme.primaryKeycap : theme.hover, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .accessibilityHidden(true)
        }
        .frame(width: Theme.Size.actionWidth - Theme.Space.sm * 2)
    }

    private func countdown(_ seconds: Int) -> some View {
        let tint = seconds < 15 ? theme.danger : seconds < 60 ? theme.warning : theme.accent
        return HStack(spacing: Theme.Space.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.border)
                    Capsule().fill(tint)
                        .frame(width: geometry.size.width * min(1, max(0, CGFloat(seconds) / CGFloat(max(1, model.timeoutSeconds)))))
                        .animation(reduceMotion ? nil : .linear(duration: Theme.Motion.tick), value: seconds)
                }
            }
            .frame(height: Theme.Size.track)
            Text(String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60))
                .font(Theme.TypeStyle.mono)
                .foregroundStyle(seconds < 60 ? tint : theme.textTertiary)
                .frame(minWidth: Theme.Size.timer, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time remaining")
        .accessibilityValue("\(seconds) seconds")
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
    let ink: Color
    let quiet: Color
    let accent: Color

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> InputContainer {
        let container = InputContainer()
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
                field.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                field.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                field.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                field.heightAnchor.constraint(equalToConstant: Theme.Size.nativeInput)
            ])
            container.field = field
            coordinator.revealed = model.revealed
        }
        guard let field = container.field else { return }
        if field.stringValue != model.secret { field.stringValue = model.secret }
        field.textColor = NSColor(ink)
        field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: NSColor(quiet),
            .font: Theme.TypeStyle.placeholder
        ])
        if let editor = field.currentEditor() as? NSTextView { editor.insertionPointColor = NSColor(accent) }
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
