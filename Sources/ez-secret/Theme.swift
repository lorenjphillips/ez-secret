import AppKit
import SwiftUI

struct Theme {
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let field = Color(nsColor: .textBackgroundColor)
    static let fill = Color(nsColor: .quaternaryLabelColor)
    static let border = Color(nsColor: .separatorColor)
    static let accent = Color(nsColor: .controlAccentColor)
    static let accentText = Color.white
    static let danger = Color(nsColor: .systemRed)
    static let warning = Color(nsColor: .systemOrange)
    static let tooltipBase = Color(nsColor: .windowBackgroundColor)
    static let surface = Material.regular
    static let clear = Color.clear

    enum Space { static let none: CGFloat = 0, xxs: CGFloat = 4, xs: CGFloat = 8, md: CGFloat = 16, lg: CGFloat = 20 }
    enum Radius { static let control: CGFloat = 7, field: CGFloat = 7, panel: CGFloat = 14 }
    enum Size {
        static let panel: CGFloat = 380, initialHeight: CGFloat = 164, field: CGFloat = 28, nativeInput: CGFloat = 18, textInset: CGFloat = 2
        static let button: CGFloat = 28, actionWidth: CGFloat = 76, icon: CGFloat = 24
        static let hairline: CGFloat = 0.5, halo: CGFloat = 3, focusSoftness: CGFloat = 0.5, ring: CGFloat = 13, track: CGFloat = 1.5, timer: CGFloat = 28, tooltip: CGFloat = 24, tooltipWidth: CGFloat = 340
        static let shake: CGFloat = 3
    }
    enum TypeStyle {
        static let title = Font.system(size: 13, weight: .semibold)
        static let body = Font.system(size: 13, weight: .medium)
        static let caption = Font.system(size: 11)
        static let icon = Font.system(size: 12)
        static let input = NSFont.systemFont(ofSize: 13, weight: .regular)
    }
    enum Motion { static let hover = 0.14, tooltipDelay: UInt64 = 350_000_000, tick = 1.0, shake = 0.32 }
}

struct PanelButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, icon }
    let kind: Kind
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        let primary = kind == .primary
        let icon = kind == .icon
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        configuration.label
            .font(icon ? Theme.TypeStyle.icon : Theme.TypeStyle.body)
            .frame(minWidth: icon ? Theme.Size.icon : Theme.Size.actionWidth)
            .frame(height: Theme.Size.button)
            .foregroundStyle(primary ? Theme.accentText : icon && !hovered ? Theme.textSecondary : Theme.textPrimary)
            .background(shape.fill(primary ? Theme.accent : icon ? Theme.clear : Theme.fill))
            .overlay(shape.strokeBorder(kind == .secondary ? Theme.border : Theme.clear, lineWidth: Theme.Size.hairline).allowsHitTesting(false))
            .brightness(enabled && !icon ? (configuration.isPressed ? (scheme == .dark ? 0.08 : -0.08) : hovered ? (scheme == .dark ? 0.04 : -0.04) : 0) : 0)
            .opacity(enabled ? (icon && configuration.isPressed ? 0.65 : 1) : 0.45)
            .contentShape(shape)
            .animation(.easeOut(duration: Theme.Motion.hover), value: hovered)
            .animation(.easeOut(duration: Theme.Motion.hover), value: configuration.isPressed)
            .onHover { hovered = $0 }
    }
}

private struct PanelTooltip: ViewModifier {
    let text: String
    let alignment: HorizontalAlignment
    let wraps: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: Alignment(horizontal: alignment, vertical: .top)) {
                if visible {
                    Text(text)
                        .font(Theme.TypeStyle.caption)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, Theme.Space.xs)
                        .padding(.vertical, Theme.Space.xxs)
                        .frame(minHeight: Theme.Size.tooltip)
                        .frame(maxWidth: wraps ? Theme.Size.tooltipWidth : nil, alignment: .leading)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                        .background(Theme.tooltipBase, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).strokeBorder(Theme.border, lineWidth: Theme.Size.hairline))
                        .fixedSize(horizontal: !wraps, vertical: true)
                        .alignmentGuide(.top) { $0[.bottom] + Theme.Space.xxs }
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onHover { hovered = $0; if !$0 { visible = false } }
            .task(id: hovered) {
                guard hovered else { return }
                do { try await Task.sleep(nanoseconds: Theme.Motion.tooltipDelay) } catch { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: Theme.Motion.hover)) { visible = true }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: Theme.Motion.hover), value: visible)
            .onDisappear { visible = false }
            .accessibilityHint(text)
    }
}

extension View {
    func panelTooltip(_ text: String, alignment: HorizontalAlignment = .trailing, wraps: Bool = false) -> some View { modifier(PanelTooltip(text: text, alignment: alignment, wraps: wraps)) }
}
