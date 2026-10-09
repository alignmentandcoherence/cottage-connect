import Foundation
import SwiftData

// The community rules from the product brief live here so views stay simple.

enum Barter {
    static func startTrade(for item: SpareItem, by requesterID: UUID, note: String, in context: ModelContext) -> Trade {
        let trade = Trade(itemID: item.uid, requesterID: requesterID, ownerID: item.ownerID)
        context.insert(trade)
        context.insert(TradeEvent(tradeID: trade.uid, actorID: requesterID, action: .started, note: note))
        return trade
    }

    /// The owner's first ask, or either side's counteroffer. Passes the turn to the other party.
    static func propose(_ trade: Trade, by actorID: UUID, itemIDs: [UUID], note: String, in context: ModelContext) {
        let isFirstAsk = trade.offeredItemIDs.isEmpty && actorID == trade.ownerID && trade.status == .awaitingOwner
        trade.offeredItemIDs = itemIDs
        trade.status = actorID == trade.ownerID ? .awaitingRequester : .awaitingOwner
        trade.updatedAt = .now
        context.insert(TradeEvent(tradeID: trade.uid, actorID: actorID,
                                  action: isFirstAsk ? .asked : .countered, itemIDs: itemIDs, note: note))
    }

    static func accept(_ trade: Trade, by actorID: UUID, items: [SpareItem], in context: ModelContext) {
        trade.status = .accepted
        trade.updatedAt = .now
        // Everything in the swap is spoken for now.
        for item in items where item.uid == trade.itemID || trade.offeredItemIDs.contains(item.uid) {
            item.isAvailable = false
        }
        context.insert(TradeEvent(tradeID: trade.uid, actorID: actorID, action: .accepted))
    }

    static func decline(_ trade: Trade, by actorID: UUID, note: String = "", in context: ModelContext) {
        trade.status = .declined
        trade.updatedAt = .now
        context.insert(TradeEvent(tradeID: trade.uid, actorID: actorID, action: .declined, note: note))
    }
}

enum CommentRules {
    /// Anyone other than the poster gets one comment, and another each time the poster replies to them.
    static func canComment(on post: Post, as memberID: UUID, comments: [Comment]) -> Bool {
        if post.authorID == memberID { return true }
        let onPost = comments.filter { $0.postID == post.uid }
        guard let lastMine = onPost.filter({ $0.authorID == memberID }).map(\.createdAt).max() else { return true }
        return onPost.contains {
            $0.authorID == post.authorID && $0.replyToAuthorID == memberID && $0.createdAt > lastMine
        }
    }
}

enum ConnectionState {
    case none, requested, incoming, connected
}

enum Connections {
    static func state(between me: UUID, and other: UUID, requests: [ConnectionRequest]) -> ConnectionState {
        let sent = requests.contains { $0.fromID == me && $0.toID == other }
        let received = requests.contains { $0.fromID == other && $0.toID == me }
        switch (sent, received) {
        case (true, true): return .connected
        case (true, false): return .requested
        case (false, true): return .incoming
        case (false, false): return .none
        }
    }

    /// People who asked to connect with `me` that `me` hasn't answered yet.
    static func incoming(for me: UUID, requests: [ConnectionRequest]) -> [UUID] {
        requests.filter { $0.toID == me }.map(\.fromID)
            .filter { state(between: me, and: $0, requests: requests) == .incoming }
    }

    static func connected(for me: UUID, requests: [ConnectionRequest]) -> [UUID] {
        requests.filter { $0.toID == me }.map(\.fromID)
            .filter { state(between: me, and: $0, requests: requests) == .connected }
    }
}
