import SwiftUI
import SwiftData

@main
struct CottageConnectApp: App {
    let container: ModelContainer = {
        let schema = Schema([Member.self, SpareItem.self, Trade.self, TradeEvent.self, Guide.self,
                             Post.self, Comment.self, ConnectionRequest.self, DirectMessage.self, Invite.self])
        let config = ModelConfiguration("CottageConnectDemo", schema: schema)
        let container = try! ModelContainer(for: schema, configurations: config)
        SampleData.seedIfNeeded(container.mainContext)
        return container
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.moss)
        }
        .modelContainer(container)
    }
}
