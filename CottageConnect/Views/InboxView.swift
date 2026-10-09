import SwiftUI
import SwiftData

/// Notifications: trades waiting on you, connection requests, members to review, and messages.
struct InboxView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Query(sort: \Trade.updatedAt, order: .reverse) private var trades: [Trade]
    @Query private var requests: [ConnectionRequest]
    @Query private var members: [Member]
    @Query(sort: \DirectMessage.createdAt, order: .reverse) private var messages: [DirectMessage]

    private var myTrades: [Trade] {
        guard let me else { return [] }
        return trades.filter { $0.ownerID == me.uid || $0.requesterID == me.uid }
    }
    private var needsMe: [Trade] { myTrades.filter { $0.waitingOnID == me?.uid } }
    private var otherTrades: [Trade] { myTrades.filter { $0.waitingOnID != me?.uid } }
    private var incoming: [UUID] { me.map { Connections.incoming(for: $0.uid, requests: requests) } ?? [] }
    private var connected: [UUID] { me.map { Connections.connected(for: $0.uid, requests: requests) } ?? [] }
    private var toReview: [Member] { me?.isAdmin == true ? members.filter { $0.status == .pending } : [] }

    var body: some View {
        List {
            if !toReview.isEmpty {
                Section("Members to review") {
                    ForEach(toReview) { ReviewRow(member: $0) }
                }
            }

            Section("Needs your response") {
                if needsMe.isEmpty { Text("You're all caught up.").foregroundStyle(.secondary) }
                ForEach(needsMe) { trade in
                    NavigationLink(value: trade) { TradeRow(trade: trade) }
                }
            }

            if !incoming.isEmpty {
                Section("Connection requests") {
                    ForEach(incoming, id: \.self) { id in
                        if let member = members.find(id) {
                            HStack {
                                NavigationLink(value: member) { MemberRow(member: member) }
                                Button("Connect Back") {
                                    if let me { context.insert(ConnectionRequest(fromID: me.uid, toID: id)) }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
            }

            Section("Messages") {
                if connected.isEmpty {
                    Text("Connect with someone to message them.").foregroundStyle(.secondary)
                }
                ForEach(connected, id: \.self) { id in
                    NavigationLink(value: Conversation(otherID: id)) {
                        HStack {
                            Avatar(name: members.name(id))
                            VStack(alignment: .leading) {
                                Text(members.name(id)).font(.headline)
                                Text(lastMessage(with: id) ?? "Say hello").font(.subheadline)
                                    .foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
            }

            if !otherTrades.isEmpty {
                Section("Your trades") {
                    ForEach(otherTrades) { trade in
                        NavigationLink(value: trade) { TradeRow(trade: trade) }
                    }
                }
            }
        }
        .navigationTitle("Inbox")
    }

    private func lastMessage(with id: UUID) -> String? {
        messages.first { ($0.fromID == id && $0.toID == me?.uid) || ($0.toID == id && $0.fromID == me?.uid) }?.text
    }
}

struct TradeRow: View {
    @Environment(\.currentUser) private var me
    @Query private var members: [Member]
    @Query private var items: [SpareItem]
    let trade: Trade

    var body: some View {
        HStack {
            Image(systemName: "arrow.left.arrow.right.circle.fill").font(.title2).foregroundStyle(Theme.clay)
            VStack(alignment: .leading, spacing: 2) {
                Text(items.find(trade.itemID)?.title ?? "Item").font(.headline)
                Text(summary).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(trade.updatedAt, style: .relative).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        let other = members.name(me.map { trade.otherParty(to: $0.uid) })
        switch trade.status {
        case .accepted: return "Agreed with \(other)"
        case .declined: return "Declined"
        case .awaitingOwner, .awaitingRequester:
            if trade.waitingOnID == me?.uid {
                return trade.offeredItemIDs.isEmpty ? "\(other) wants this. Choose what's fair." : "\(other) made an offer"
            }
            return "Waiting on \(other)"
        }
    }
}

/// Admin approval for someone who joined with an invite.
struct ReviewRow: View {
    @Query private var members: [Member]
    @Bindable var member: Member

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Avatar(name: member.name)
                VStack(alignment: .leading) {
                    Text(member.name).font(.headline)
                    Text("Invited by \(members.name(member.invitedByID)) · signed in with \(member.signInMethod)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("\(member.role.rawValue) · \(member.region)").font(.subheadline)
            if !member.bio.isEmpty { Text(member.bio).font(.subheadline).foregroundStyle(.secondary) }
            HStack {
                Button("Approve") { member.status = .approved }.buttonStyle(.borderedProminent)
                Button("Decline", role: .destructive) { member.status = .declined }.buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Direct messages, only available between connected members.
struct ChatView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Query(sort: \DirectMessage.createdAt) private var allMessages: [DirectMessage]
    @Query private var requests: [ConnectionRequest]
    @Query private var members: [Member]
    let otherID: UUID
    @State private var draft = ""

    private var messages: [DirectMessage] {
        guard let me else { return [] }
        return allMessages.filter {
            ($0.fromID == me.uid && $0.toID == otherID) || ($0.fromID == otherID && $0.toID == me.uid)
        }
    }
    private var isConnected: Bool {
        guard let me else { return false }
        return Connections.state(between: me.uid, and: otherID, requests: requests) == .connected
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            bubble(message).id(message.persistentModelID)
                        }
                    }
                    .padding()
                }
                .onAppear { scrollToEnd(proxy) }
                .onChange(of: messages.count) { scrollToEnd(proxy) }
            }
            Divider()
            if isConnected {
                HStack {
                    TextField("Message", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(send)
                    Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            } else {
                Text("You can message each other once you're both connected.")
                    .font(.callout).foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle(members.name(otherID))
    }

    private func bubble(_ message: DirectMessage) -> some View {
        let mine = message.fromID == me?.uid
        return HStack {
            if mine { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(mine ? Color.white : Color.primary)
                .background(mine ? Theme.moss : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
            if !mine { Spacer(minLength: 40) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        if let last = messages.last { proxy.scrollTo(last.persistentModelID) }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let me, !text.isEmpty else { return }
        context.insert(DirectMessage(fromID: me.uid, toID: otherID, text: text))
        draft = ""
    }
}
