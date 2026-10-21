import AppKit
import SwiftUI

struct Theme {
    let scheme: ColorScheme
    private func color(_ light: UInt32, _ dark: UInt32) -> Color {
        let hex = scheme == .dark ? dark : light
        return Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    var surface: Color { color(0xF8FAF8, 0x1B2428) }
    var field: Color { color(0xFFFFFF, 0x11191D) }
    var border: Color { color(0xC4CECB, 0x465357) }
    var textPrimary: Color { color(0x1A2B2E, 0xEAF5F2) }
    var textSecondary: Color { color(0x536765, 0xADBFBB) }
    var textTertiary: Color { color(0x687B78, 0x8EA39F) }
    var accent: Color { color(0x0D6E5C, 0x64D9BA) }
    var accentText: Color { color(0xFFFFFF, 0x0B3029) }
    var danger: Color { color(0xBD3330, 0xFF8078) }
    var warning: Color { color(0x97600C, 0xE9BA64) }
    var hover: Color { textPrimary.opacity(0.06) }
    var pressed: Color { textPrimary.opacity(0.12) }
    var disabled: Color { color(0xDEE6E2, 0x303F40) }
    var primaryKeycap: Color { accentText.opacity(0.12) }
    var focus: Color { accent.opacity(0.12) }
    var errorHalo: Color { danger.opacity(0.08) }
    var tooltip: Color { color(0x233532, 0xE4EFEB) }
    var tooltipText: Color { color(0xFFFFFF, 0x172B26) }
    static let clear = Color.clear
    enum Space { static let none: CGFloat = 0, xxs: CGFloat = 4, xs: CGFloat = 8, sm: CGFloat = 12, md: CGFloat = 16, lg: CGFloat = 20, xl: CGFloat = 24 }
    enum Radius { static let small: CGFloat = 4, control: CGFloat = 9, field: CGFloat = 12, panel: CGFloat = 20 }
    enum Size {
        static let panel: CGFloat = 488, initialHeight: CGFloat = 240, field: CGFloat = 56, input: CGFloat = 24, nativeInput: CGFloat = 22
        static let button: CGFloat = 38, actionWidth: CGFloat = 108, chip: CGFloat = 30, icon: CGFloat = 30, keyWidth: CGFloat = 24, keyHeight: CGFloat = 20
        static let line: CGFloat = 1, hairline: CGFloat = 0.5, track: CGFloat = 3, halo: CGFloat = 3, requester: CGFloat = 80, timer: CGFloat = 34, tooltip: CGFloat = 28
        static let titleTracking: CGFloat = -0.35, shake: CGFloat = 3
    }
    enum TypeStyle {
        static let title = Font.system(size: 18, weight: .semibold), body = Font.system(size: 13, weight: .semibold)
        static let caption = Font.system(size: 11, weight: .medium), mono = Font.system(size: 11, design: .monospaced)
        static let returnKey = Font.system(size: 12, weight: .medium, design: .monospaced)
        static let icon = Font.system(size: 14), key = Font.system(size: 10, weight: .medium, design: .monospaced)
        static let input = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), placeholder = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    }
    enum Motion { static let hover = 0.14, tooltipDelay: UInt64 = 400_000_000, tick = 1.0, shake = 0.32 }
}

struct PanelButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, chip, icon }
    let kind: Kind
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled
    @State private var hovered = false
    func makeBody(configuration: Configuration) -> some View {
        let theme = Theme(scheme: scheme)
        let primary = kind == .primary
        let utility = kind == .chip || kind == .icon
        let shape = kind == .chip ? AnyShape(Capsule(style: .circular)) : AnyShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        configuration.label
            .font(utility ? Theme.TypeStyle.caption : Theme.TypeStyle.body)
            .padding(.horizontal, kind == .icon ? Theme.Space.none : Theme.Space.sm)
            .frame(height: utility ? Theme.Size.chip : Theme.Size.button)
            .foregroundStyle(!enabled ? theme.textSecondary : primary ? theme.accentText : theme.textPrimary)
            .background(shape.fill(primary ? (enabled ? theme.accent : theme.disabled) : kind == .chip ? theme.hover : Theme.clear))
            .overlay(shape.fill(enabled && configuration.isPressed ? theme.pressed : enabled && hovered ? theme.hover : Theme.clear).allowsHitTesting(false))
            .overlay(shape.stroke(kind == .secondary || kind == .chip ? theme.border : Theme.clear, lineWidth: Theme.Size.line).allowsHitTesting(false))
            .contentShape(shape)
            .animation(.easeOut(duration: Theme.Motion.hover), value: hovered)
            .animation(.easeOut(duration: Theme.Motion.hover), value: configuration.isPressed)
            .onHover { hovered = $0 }
    }
}

private struct PanelTooltip: ViewModifier {
    let text: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    @State private var visible = false
    func body(content: Content) -> some View {
        let theme = Theme(scheme: scheme)
        content
            .overlay(alignment: .topTrailing) {
                if visible {
                    Text(text)
                        .font(Theme.TypeStyle.caption)
                        .foregroundStyle(theme.tooltipText)
                        .padding(.horizontal, Theme.Space.sm)
                        .frame(height: Theme.Size.tooltip)
                        .background(theme.tooltip, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                        .fixedSize()
                        .offset(y: -Theme.Size.tooltip - Theme.Space.xxs)
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
    func panelTooltip(_ text: String) -> some View { modifier(PanelTooltip(text: text)) }
}
