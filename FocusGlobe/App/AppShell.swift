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
/// Home in the centre, the selected tab lifted in gold. Adapts its max width on
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
        Item(id: .home,     title: "Home",     system: "house.fill"),
        Item(id: .friends,  title: "Friends",  system: "person.2.fill"),
        Item(id: .settings, title: "Settings", system: "gearshape.fill"),
    ]

    var body: some View {
        // A rigid, app-like bar pinned to the bottom edge: the tab row sits above
        // the home-indicator safe area, and the material fills all the way down to
        // the screen edge so nothing floats. Rounded only at the top.
        HStack(spacing: 0) {
            ForEach(items) { item in
                tab(item)
            }
        }
        .padding(.top, Layout.pad(9, 11))
        .padding(.bottom, Layout.pad(4, 6))
        .padding(.horizontal, Layout.pad(6, 12))
        .frame(maxWidth: Layout.pad(CGFloat(640), CGFloat(760)))
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0, topTrailingRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 0,
                                                bottomTrailingRadius: 0, topTrailingRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.34)))
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.12)).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: .black.opacity(0.28), radius: 12, y: -2)
    }

    private func tab(_ item: Item) -> some View {
        let active = router.selectedTab == item.id
        return Button {
            guard !active else { return }
            appModel.tapFeedback()
            withAnimation(.easeInOut(duration: 0.22)) { router.select(item.id) }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.system)
                    .font(.system(size: Layout.pad(17, 20), weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(item.title)
                    .font(.system(size: Layout.pad(10, 11.5), weight: .semibold, design: .rounded))
            }
            .foregroundStyle(active ? AppColors.gold : .white.opacity(0.68))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.gold.opacity(0.14))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle(scale: 0.92))
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}
