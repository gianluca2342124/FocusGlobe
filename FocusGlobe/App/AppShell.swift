import SwiftUI

/// The persistent app shell: the five tabs (Passport · Shop · Home · Friends ·
/// Settings) switch **in place** here, with the bottom tab bar always visible.
/// This is the root of the navigation stack — the ritual/boarding/history flow
/// pushes *over* the shell (covering the bar), which is exactly right: a tab is
/// a place you dwell, a flow is a page you walk through.
struct AppShell: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        currentTab
            // The bar is a bottom safe-area inset, so no tab's scroll content is
            // ever hidden behind it and every tab lines up identically.
            .safeAreaInset(edge: .bottom, spacing: 0) { AppTabBar() }
            .ignoresSafeArea(.keyboard)   // the bar never rides the keyboard up
    }

    @ViewBuilder private var currentTab: some View {
        switch router.selectedTab {
        case .home:     HomeView()
        case .shop:     StoreView()
        case .passport: PassportView()
        case .friends:  FriendsView()
        case .settings: SettingsView()
        }
    }
}

/// The premium glass tab bar. A single floating capsule low over the safe area,
/// Home in the centre, the selected tab lifted in Celestial Teal. Adapts its max width on
/// iPad/Mac so it never stretches edge-to-edge on a wide screen.
struct AppTabBar: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var appModel: AppModel

    private struct Item: Identifiable {
        let id: AppRouter.Tab
        let title: String
        let system: String
    }

    private let items: [Item] = [
        Item(id: .passport, title: "Passport", system: "book.closed.fill"),
        Item(id: .shop,     title: "Shop",     system: "bag.fill"),
        // The filled house glyph — solid to match the rest of the filled tab
        // family, still the minimal SF house (no heavy door/chimney detailing).
        Item(id: .home,     title: "Home",     system: "house.fill"),
        Item(id: .friends,  title: "Friends",  system: "person.2.fill"),
        Item(id: .settings, title: "Settings", system: "gearshape.fill"),
    ]

    var body: some View {
        // A rigid bar ATTACHED to the bottom edge: full-width, square-cornered,
        // grounded on the #181721 neutral — never a floating rounded card. The
        // item row keeps a comfortable max width on iPad while the surface runs
        // edge to edge; only a subtle top hairline separates it from content.
        HStack(spacing: 0) {
            ForEach(items) { item in
                tab(item)
            }
        }
        // The interaction pill still glides between tabs — but only the bar animates,
        // never the whole two-tab tree (see the instant `tab` handler below).
        .animation(.easeInOut(duration: 0.22), value: router.selectedTab)
        .padding(.top, Layout.pad(7, 9))
        .padding(.bottom, Layout.pad(4, 6))
        .padding(.horizontal, Layout.pad(6, 12))
        .frame(maxWidth: Layout.pad(CGFloat(640), CGFloat(760)))
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                // #181721 by night, clean warm white by day; the hairline is
                // the adaptive token so it reads in both modes.
                .fill(AppColors.tabBarFill.opacity(0.98))
                .overlay(alignment: .top) { Rectangle().fill(AppColors.hairline).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tab(_ item: Item) -> some View {
        let active = router.selectedTab == item.id
        return Button {
            guard !active else { return }
            appModel.tapFeedback()
            // NO withAnimation around the tab switch: animating it forces
            // SwiftUI to render BOTH tab trees for a 0.22 s crossfade inside
            // the tap's transaction — the exact "menu lag" being fixed. The
            // content swaps in one frame; only the bar's pill glides.
            router.select(item.id)
        } label: {
            // Icon-only: a single large glyph in a selected "chip", centred in a
            // full-width cell with a ≥44 pt tap target. The name lives on only as
            // the VoiceOver label (see below), never as visible text.
            Image(systemName: item.system)
                .font(.system(size: Layout.pad(24, 27), weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(active ? AppColors.selectionGold
                                 : Color.dynamic(light: 0x26221D, lightAlpha: 0.55,
                                                 dark: 0xFFFFFF, darkAlpha: 0.68))
                .frame(width: Layout.pad(54, 62), height: 40)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(AppColors.selectionGold.opacity(0.17))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle(scale: 0.92))
        // The tab bar is icon-only, so this label is the ONLY name VoiceOver
        // has for it — and `item.title` is a catalog key, not copy.
        .accessibilityLabel(Text(LocalizedStringKey(item.title)))
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}
