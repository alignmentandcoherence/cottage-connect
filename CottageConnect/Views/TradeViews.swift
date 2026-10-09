import SwiftUI
import SwiftData

struct TradeDetailView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Query private var members: [Member]
    @Query private var items: [SpareItem]
    @Query(sort: \TradeEvent.date) private var allEvents: [TradeEvent]
    let trade: Trade
    @State private var proposing = false
    @State private var confirmingDecline = false

    private var item: SpareItem? { items.find(trade.itemID) }
    private var events: [TradeEvent] { allEvents.filter { $0.tradeID == trade.uid } }
    private var offered: [SpareItem] { trade.offeredItemIDs.compactMap { items.find($0) } }
    private var isOwner: Bool { me?.uid == trade.ownerID }
    private var myTurn: Bool { me != nil && trade.waitingOnID == me?.uid }
    /// The owner hasn't made their first ask yet.
    private var awaitingFirstAsk: Bool { trade.status == .awaitingOwner && trade.offeredItemIDs.isEmpty }
    /// Both sides choose from the requester's spare items, since that's what the requester gives.
    private var pool: [SpareItem] {
        items.filter { $0.ownerID == trade.requesterID && ($0.isAvailable || trade.offeredItemIDs.contains($0.uid)) }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(headline).font(.headline)
                        Spacer()
                        statusTag
                    }
                    if let item { ItemRow(item: item, ownerName: members.name(trade.ownerID)) }
                }
                .padding(.vertical, 4)
            }

            Section(offered.isEmpty ? "In exchange" : "\(members.name(trade.requesterID)) would give") {
                if offered.isEmpty {
                    Text(awaitingFirstAsk
                         ? "Waiting for \(members.name(trade.ownerID)) to choose from \(members.name(trade.requesterID))'s spare items."
                         : "Nothing selected.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(offered) { ItemRow(item: $0) }
                }
            }

            if trade.status.isOpen {
                Section {
                    if myTurn {
                        actionButtons
                    } else {
                        Label("Waiting on \(members.name(trade.waitingOnID))", systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if trade.status == .accepted, let me {
                Section {
                    Label("Trade agreed. Connect with each other to arrange the swap.", systemImage: "checkmark.seal")
                        .foregroundStyle(Theme.moss)
                    if let other = members.find(trade.otherParty(to: me.uid)) {
                        NavigationLink(value: other) { Text("View \(other.name)'s profile") }
                    }
                }
            }

            Section("History") {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(members.name(event.actorID)) \(event.action.rawValue)")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(event.date, style: .relative).font(.caption).foregroundStyle(.secondary)
                        }
                        if !event.itemIDs.isEmpty {
                            Text(event.itemIDs.compactMap { items.find($0)?.title }.joined(separator: ", "))
                                .font(.subheadline)
                        }
                        if !event.note.isEmpty {
                            Text("“\(event.note)”").font(.subheadline).italic().foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Trade")
        .sheet(isPresented: $proposing) {
            ItemPickerView(
                title: awaitingFirstAsk ? "Make an Ask" : "Propose Something New",
                prompt: isOwner
                    ? "Pick what you'd like from \(members.name(trade.requesterID))'s spare items."
                    : "Choose what you'd offer instead.",
                pool: pool,
                initial: Set(trade.offeredItemIDs)
            ) { ids, note in
                if let me { Barter.propose(trade, by: me.uid, itemIDs: ids, note: note, in: context) }
            }
        }
        .confirmationDialog("Decline this trade?", isPresented: $confirmingDecline) {
            Button("Decline", role: .destructive) {
                if let me { Barter.decline(trade, by: me.uid, in: context) }
            }
        }
    }

    private var headline: String {
        guard let me else { return "" }
        let itemName = item?.title ?? "an item"
        if me.uid == trade.requesterID { return "You asked for \(itemName)" }
        if me.uid == trade.ownerID { return "\(members.name(trade.requesterID)) wants your \(itemName)" }
        return "\(members.name(trade.requesterID)) ↔ \(members.name(trade.ownerID))"
    }

    private var statusTag: some View {
        switch trade.status {
        case .accepted: Tag(text: "Agreed")
        case .declined: Tag(text: "Declined", color: .secondary)
        case .awaitingOwner, .awaitingRequester: Tag(text: myTurn ? "Your turn" : "Waiting", color: Theme.clay)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if awaitingFirstAsk {
            Button { proposing = true } label: {
                Label("Choose What Seems Fair", systemImage: "checklist").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                if let me { Barter.accept(trade, by: me.uid, items: items, in: context) }
            } label: {
                Label("Accept", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button { proposing = true } label: {
                Label("Propose Something New", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        Button("Decline", role: .destructive) { confirmingDecline = true }
    }
}

/// Multi-select of spare items with a note, used for asks and counteroffers.
struct ItemPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let prompt: String
    let pool: [SpareItem]
    let onSend: ([UUID], String) -> Void
    @State private var selected: Set<UUID>
    @State private var note = ""

    init(title: String, prompt: String, pool: [SpareItem], initial: Set<UUID>,
         onSend: @escaping ([UUID], String) -> Void) {
        self.title = title
        self.prompt = prompt
        self.pool = pool
        self.onSend = onSend
        _selected = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(prompt).font(.callout).foregroundStyle(.secondary)
                }
                Section("Spare items") {
                    if pool.isEmpty {
                        Text("No spare items listed. Use the note to ask for time, a skill, or something else.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(pool) { item in
                        Button {
                            if selected.contains(item.uid) { selected.remove(item.uid) } else { selected.insert(item.uid) }
                        } label: {
                            HStack {
                                ItemRow(item: item)
                                Image(systemName: selected.contains(item.uid) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Theme.moss)
                                    .font(.title3)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section {
                    TextField("Note (e.g. \"plus an hour of weeding\")", text: $note, axis: .vertical)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        onSend(pool.map(\.uid).filter(selected.contains), note)
                        dismiss()
                    }
                    .disabled(selected.isEmpty && note.isEmpty)
                }
            }
        }
        .sheetSize()
    }
}
