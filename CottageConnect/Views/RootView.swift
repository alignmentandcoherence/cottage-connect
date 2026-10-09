import SwiftUI
import SwiftData

enum AppSection: String, CaseIterable, Identifiable {
    case barter = "Barter"
    case learn = "Resources"
    case community = "Community"
    case people = "People"
    case inbox = "Inbox"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .barter: "arrow.left.arrow.right"
        case .learn: "books.vertical"
        case .community: "bubble.left.and.bubble.right"
        case .people: "person.3"
        case .inbox: "tray"
        }
    }
}

/// Features shown in the UI but not built yet.
enum ComingSoon: String, CaseIterable, Identifiable {
    case events = "Events & Workshops"
    case toolLibrary = "Tool Library"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .events: "calendar"
        case .toolLibrary: "wrench.and.screwdriver"
        }
    }
}

/// Tabs on iPhone, sidebar on iPad and Mac.
struct RootView: View {
    @Query(sort: \Member.joinedAt) private var members: [Member]
    @Query private var trades: [Trade]
    @Query private var requests: [ConnectionRequest]
    @AppStorage("currentUserID") private var currentUserID = ""
    @AppStorage("signedIn") private var signedIn = false
    @State private var selection: AppSection? = .barter

    private var me: Member? { signedIn ? members.find(UUID(uuidString: currentUserID)) : nil }

    private var inboxCount: Int {
        guard let me else { return 0 }
        let pending = me.isAdmin ? members.filter { $0.status == .pending }.count : 0
        return trades.filter { $0.waitingOnID == me.uid }.count
            + Connections.incoming(for: me.uid, requests: requests).count
            + pending
    }

    var body: some View {
        Group {
            if let me {
                if me.status == .approved { mainLayout } else { PendingReviewView() }
            } else {
                WelcomeView()
            }
        }
        .environment(\.currentUser, me)
    }

    @ViewBuilder
    private var mainLayout: some View {
        #if os(macOS)
        sidebarLayout
        #else
        if UIDevice.current.userInterfaceIdiom == .pad { sidebarLayout } else { tabLayout }
        #endif
    }

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(AppSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .badge(section == .inbox ? inboxCount : 0)
                            .tag(section)
                    }
                }
                Section("Coming soon") {
                    ForEach(ComingSoon.allCases) { feature in
                        Label(feature.rawValue, systemImage: feature.icon)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Cottage Connect")
        } detail: {
            stack(for: selection ?? .barter)
                .id(selection)
        }
    }

    private var tabLayout: some View {
        TabView {
            ForEach(AppSection.allCases) { section in
                stack(for: section)
                    .tabItem { Label(section.rawValue, systemImage: section.icon) }
                    .badge(section == .inbox ? inboxCount : 0)
            }
        }
    }

    private func stack(for section: AppSection) -> some View {
        NavigationStack {
            content(for: section)
                .appDestinations()
                .toolbar {
                    ToolbarItem(placement: .navigation) { MeButton() }
                }
        }
    }

    @ViewBuilder
    private func content(for section: AppSection) -> some View {
        switch section {
        case .barter: BarterView()
        case .learn: LearnView()
        case .community: CommunityView()
        case .people: PeopleView()
        case .inbox: InboxView()
        }
    }
}

struct Conversation: Hashable {
    let otherID: UUID
}

extension View {
    /// Every navigable record, registered once per navigation stack.
    func appDestinations() -> some View {
        navigationDestination(for: Member.self) { ProfileView(member: $0) }
            .navigationDestination(for: SpareItem.self) { ItemDetailView(item: $0) }
            .navigationDestination(for: Trade.self) { TradeDetailView(trade: $0) }
            .navigationDestination(for: Guide.self) { GuideDetailView(guide: $0) }
            .navigationDestination(for: Post.self) { PostDetailView(post: $0) }
            .navigationDestination(for: Conversation.self) { ChatView(otherID: $0.otherID) }
    }
}

/// The signed-in member's avatar; opens their profile, spare items and the demo user switcher.
struct MeButton: View {
    @Environment(\.currentUser) private var me
    @State private var showingMe = false

    var body: some View {
        Button { showingMe = true } label: {
            Avatar(name: me?.name ?? "?", size: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your profile")
        .sheet(isPresented: $showingMe) { MeView() }
    }
}
