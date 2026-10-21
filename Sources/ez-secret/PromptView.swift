import EzSecretCore
import AppKit
import SwiftUI

final class PromptModel: ObservableObject {
    @Published var secret = ""
    @Published var revealed = false
    @Published var errorMessage: String?
    @Published var secondsLeft: Int?

    let label: String
    let destination: Destination
    let rules: ValidationRules
    let requester: String?

    var onSave: (String) -> Void = { _ in }
    var onCancel: () -> Void = {}

    init(options: CLIOptions, requester: String?) {
        label = options.label
        destination = options.destination
        rules = options.rules
        self.requester = requester
        secondsLeft = options.timeoutSeconds > 0 ? options.timeoutSeconds : nil
    }

    func pasteFromClipboard() {
        guard let s = NSPasteboard.general.string(forType: .string) else {
            errorMessage = "Clipboard has no text"
            return
        }
        secret = stripTrailingNewline(s)
        errorMessage = nil
    }

    func save() {
        if let problem = rules.validate(secret) {
            errorMessage = problem
            NSSound.beep()
            return
        }
        onSave(secret)
    }
}

struct PromptView: View {
    @ObservedObject var model: PromptModel
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            destinationChip
            secretField
            hintOrError
            buttons
            footer
        }
        .padding(22)
        .frame(width: 440)
        .onAppear { fieldFocused = true }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "key.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(model.label)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let who = model.requester {
                    Text("Requested by \(who)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var destinationChip: some View {
        HStack(spacing: 8) {
            Image(systemName: destinationIcon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Will be saved to")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.destination.shortDescription)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }

    private var destinationIcon: String {
        switch model.destination {
        case .envFile: return "doc.text"
        case .file: return "doc.badge.lock"
        case .keychain: return "lock.shield"
        }
    }

    private var secretField: some View {
        HStack(spacing: 8) {
            Group {
                if model.revealed {
                    TextField("Paste or type the secret", text: $model.secret)
                } else {
                    SecureField("Paste or type the secret", text: $model.secret)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .focused($fieldFocused)
            .onSubmit { model.save() }
            .onChange(of: model.secret) { _, _ in model.errorMessage = nil }

            Button {
                model.revealed.toggle()
                DispatchQueue.main.async { fieldFocused = true }
            } label: {
                Image(systemName: model.revealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(model.revealed ? "Hide" : "Show")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(model.errorMessage == nil ? Color(nsColor: .separatorColor) : Color.red, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var hintOrError: some View {
        if let err = model.errorMessage {
            Label(err, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        } else if let hint = model.rules.hint {
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var buttons: some View {
        HStack {
            Button {
                model.pasteFromClipboard()
            } label: {
                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
            }
            .controlSize(.regular)

            Spacer()

            Button("Cancel") { model.onCancel() }
                .keyboardShortcut(.cancelAction)

            Button("Save") { model.save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(model.secret.isEmpty)
        }
    }

    private var footer: some View {
        HStack {
            Text("Written straight to the destination. The agent only sees its length and a hash prefix.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let s = model.secondsLeft {
                Text(timeString(s))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
