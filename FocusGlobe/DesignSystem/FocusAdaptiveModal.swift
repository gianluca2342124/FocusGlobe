import SwiftUI

/// FocusGlobe's adaptive presentation layer.
///
/// A phone wants a bottom sheet with a drag indicator and a detent. A wide Mac
/// window wants a compact dialog sized to its own content, sitting over a page
/// that stays visible. Reusing the phone presentation on the desktop is what
/// produced the oversized panels with large empty regions: a `.medium` detent is
/// a fraction of a 1400 pt-tall window, so a dialog holding two rows was handed
/// half the screen and had to fill it with nothing.
///
/// These modifiers pick the right one from the CONTAINER size (`focusViewport`,
/// which is driven by a `GeometryReader`, never `UIScreen.main.bounds`), so a
/// resized Mac window switches live. Only `.wide` gets the desktop treatment —
/// iPhone and iPad portrait keep exactly the sheets they have today.
///
/// Nothing here changes what a dialog *does*; it only changes how it is shown.

// MARK: - Desktop dialog chrome

/// A compact desktop panel: the app's dark surface, a hairline border, one
/// restrained shadow and a fixed close control. Sized to its content, capped so
/// it can never grow into a full-window sheet.
struct FocusDesktopDialog<Content: View>: View {
    /// The dialog's fixed width. Content-sized dialogs still need a definite
    /// width or text would lay out against the whole window.
    var width: CGFloat
    /// A ceiling, not a target. The dialog is only this tall if its content
    /// genuinely needs it; beyond it the content scrolls.
    var maximumHeight: CGFloat
    var title: String?
    /// Off when the content already provides its own close/Cancel control —
    /// a desktop dialog must never show two.
    var showsCloseButton: Bool = true
    let onClose: () -> Void
    @ViewBuilder let content: Content

    private var needsTitleBar: Bool { title != nil || showsCloseButton }

    var body: some View {
        VStack(spacing: 0) {
            // A compact title bar rather than a mobile drag indicator — nothing
            // on a desktop dialog is draggable.
            if needsTitleBar {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if showsCloseButton {
                        FocusDialogCloseButton(action: onClose)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, title == nil ? 0 : 10)
            }

            content
        }
        .frame(width: width)
        .frame(maxHeight: maximumHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.backgroundTop)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.42), radius: 28, y: 14)
    }
}

/// The one close control desktop dialogs use, with pointer hover feedback and a
/// 44 pt target.
struct FocusDialogCloseButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(AppColors.textPrimary.opacity(hovering ? 0.14 : 0.07)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .onHover { hovering = $0 }
        .accessibilityLabel("Close")
    }
}

/// A zero-size button whose only job is to bind the Escape key.
///
/// iOS has no `onExitCommand`; `.cancelAction` is the portable equivalent and
/// resolves to Escape on a hardware keyboard, which is what a Mac window has.
struct FocusEscapeKeyCatcher: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { Color.clear.frame(width: 0, height: 0) }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

// MARK: - Adaptive presentation

private struct FocusAdaptiveDialogModifier<DialogContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let width: CGFloat
    let maximumHeightFraction: CGFloat
    let title: String?
    let showsCloseButton: Bool
    /// Dialogs that hold an intentional selection (placement, purchase,
    /// destructive confirmation) opt out, so a stray click outside cannot throw
    /// the choice away.
    let dismissOnBackdrop: Bool
    @ViewBuilder let dialogContent: () -> DialogContent

    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if viewport.isWide {
            content.overlay {
                if isPresented {
                    ZStack {
                        // Restrained dim: the page underneath stays legible,
                        // which is the point of a desktop dialog.
                        Color.black.opacity(0.34)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { if dismissOnBackdrop { close() } }

                        FocusDesktopDialog(width: min(width, viewport.size.width - 80),
                                           maximumHeight: viewport.size.height * maximumHeightFraction,
                                           title: title,
                                           showsCloseButton: showsCloseButton,
                                           onClose: close) {
                            dialogContent()
                        }
                    }
                    .transition(
                        reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.97))
                    )
                    // Escape closes, like every other desktop dialog.
                    // `.onExitCommand` is macOS/tvOS-only; on iOS the Escape key
                    // arrives through the cancel-action keyboard shortcut.
                    .background(FocusEscapeKeyCatcher(action: close))
                }
            }
            .animation(reduceMotion ? .none : AppMotion.content, value: isPresented)
        } else {
            // Phone and iPad portrait: untouched.
            content.sheet(isPresented: $isPresented) { dialogContent() }
        }
    }

    private func close() { isPresented = false }
}

private struct FocusAdaptiveItemDialogModifier<Item: Identifiable, DialogContent: View>: ViewModifier {
    @Binding var item: Item?
    let width: CGFloat
    let maximumHeightFraction: CGFloat
    let title: (Item) -> String?
    let showsCloseButton: Bool
    let dismissOnBackdrop: Bool
    @ViewBuilder let dialogContent: (Item) -> DialogContent

    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if viewport.isWide {
            content.overlay {
                if let current = item {
                    ZStack {
                        Color.black.opacity(0.34)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { if dismissOnBackdrop { item = nil } }

                        FocusDesktopDialog(width: min(width, viewport.size.width - 80),
                                           maximumHeight: viewport.size.height * maximumHeightFraction,
                                           title: title(current),
                                           showsCloseButton: showsCloseButton,
                                           onClose: { item = nil }) {
                            dialogContent(current)
                        }
                    }
                    .transition(
                        reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.97))
                    )
                    .background(FocusEscapeKeyCatcher { item = nil })
                }
            }
            .animation(reduceMotion ? .none : AppMotion.content, value: item?.id)
        } else {
            content.sheet(item: $item) { dialogContent($0) }
        }
    }
}

extension View {
    /// A centred desktop dialog on a wide window; the existing sheet everywhere
    /// else. `width` is the desktop width — it has no effect on a phone.
    func focusAdaptiveDialog<DialogContent: View>(
        isPresented: Binding<Bool>,
        width: CGFloat,
        maximumHeightFraction: CGFloat = 0.78,
        title: String? = nil,
        showsCloseButton: Bool = true,
        dismissOnBackdrop: Bool = true,
        @ViewBuilder content: @escaping () -> DialogContent
    ) -> some View {
        modifier(FocusAdaptiveDialogModifier(isPresented: isPresented,
                                             width: width,
                                             maximumHeightFraction: maximumHeightFraction,
                                             title: title,
                                             showsCloseButton: showsCloseButton,
                                             dismissOnBackdrop: dismissOnBackdrop,
                                             dialogContent: content))
    }

    /// The `item:` form, for dialogs driven by an optional value.
    func focusAdaptiveDialog<Item: Identifiable, DialogContent: View>(
        item: Binding<Item?>,
        width: CGFloat,
        maximumHeightFraction: CGFloat = 0.78,
        title: @escaping (Item) -> String? = { _ in nil },
        showsCloseButton: Bool = true,
        dismissOnBackdrop: Bool = true,
        @ViewBuilder content: @escaping (Item) -> DialogContent
    ) -> some View {
        modifier(FocusAdaptiveItemDialogModifier(item: item,
                                                 width: width,
                                                 maximumHeightFraction: maximumHeightFraction,
                                                 title: title,
                                                 showsCloseButton: showsCloseButton,
                                                 dismissOnBackdrop: dismissOnBackdrop,
                                                 dialogContent: content))
    }

    /// An anchored popover attached to the control that opened it — the right
    /// shape for a small panel launched from a specific button. On a phone
    /// `presentationCompactAdaptation(.sheet)` turns it back into the sheet the
    /// app already uses, so nothing changes there.
    func focusAnchoredPopover<PopoverContent: View>(
        isPresented: Binding<Bool>,
        width: CGFloat,
        arrowEdge: Edge = .top,
        @ViewBuilder content: @escaping () -> PopoverContent
    ) -> some View {
        popover(isPresented: isPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: arrowEdge) {
            content()
                .frame(idealWidth: width)
                .presentationCompactAdaptation(.sheet)
        }
    }
}

// MARK: - Desktop row hover

/// Pointer feedback for a tappable row inside a desktop dialog. A no-op where
/// there is no pointer.
struct FocusHoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = 12
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.textPrimary.opacity(hovering ? 0.06 : 0))
            )
            .onHover { hovering = $0 }
            .animation(AppMotion.press, value: hovering)
    }
}

extension View {
    func focusHoverHighlight(cornerRadius: CGFloat = 12) -> some View {
        modifier(FocusHoverHighlight(cornerRadius: cornerRadius))
    }
}
