import SwiftUI
import SwiftData

/// Everything other members can spare. Strictly barter: no money changes hands.
struct BarterView: View {
    @Environment(\.currentUser) private var me
    @Query(sort: \SpareItem.createdAt, order: .reverse) private var items: [SpareItem]
    @Query private var members: [Member]
    @State private var category: ItemCategory?
    @State private var search = ""

    private var visible: [SpareItem] {
        items.filter { item in
            item.isAvailable
            && item.ownerID != me?.uid
            && members.find(item.ownerID)?.status == .approved
            && (category == nil || item.category == category)
            && (search.isEmpty || item.title.localizedCaseInsensitiveContains(search)
                || item.details.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        List {
            Section {
                Label("Barter only. Trade what you grow, make, or know. No money changes hands.",
                      systemImage: "arrow.left.arrow.right.circle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.moss)
            }
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("All", selected: category == nil) { category = nil }
                        ForEach(ItemCategory.allCases) { c in
                            chip(c.rawValue, selected: category == c) { category = c }
                        }
                    }
                }
            }
            Section {
                ForEach(visible) { item in
                    NavigationLink(value: item) {
                        ItemRow(item: item, ownerName: distanceLabel(for: item))
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Eggs, firewood, fencing…")
        .navigationTitle("Barter")
        .overlay {
            if visible.isEmpty {
                ContentUnavailableView("Nothing listed here yet", systemImage: "basket",
                                       description: Text("Add your own spare items from your profile."))
            }
        }
    }

    private func distanceLabel(for item: SpareItem) -> String {
        guard let owner = members.find(item.ownerID) else { return "" }
        guard let me else { return owner.name }
        return "\(owner.name) · ~\(me.approxMiles(to: owner)) mi"
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(selected ? .white : Theme.moss)
                .background(selected ? Theme.moss : Theme.moss.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ItemDetailView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var members: [Member]
    @Query private var trades: [Trade]
    @Bindable var item: SpareItem
    @State private var showingStart = false

    private var owner: Member? { members.find(item.ownerID) }
    private var isMine: Bool { item.ownerID == me?.uid }
    private var myOpenTrade: Trade? {
        trades.first { $0.itemID == item.uid && $0.requesterID == me?.uid && $0.status.isOpen }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    ItemImage(item: item, padding: 24)
                        .frame(height: 200)
                    Label(item.category.rawValue, systemImage: item.category.icon)
                        .font(.subheadline).foregroundStyle(Theme.moss)
                    Text(item.title).font(.title2.bold())
                    if !item.quantity.isEmpty { Text(item.quantity).foregroundStyle(.secondary) }
                }
                .padding(.vertical, 4)
                if !item.details.isEmpty { Text(item.details) }
            }

            if let owner, !isMine {
                Section("Offered by") {
                    NavigationLink(value: owner) {
                        HStack {
                            Avatar(name: owner.name)
                            VStack(alignment: .leading) {
                                Text(owner.name).font(.headline)
                                if let me {
                                    Text("\(owner.generalArea) · ~\(me.approxMiles(to: owner)) mi away")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                if isMine {
                    Toggle("Available to trade", isOn: $item.isAvailable)
                    Button("Remove listing", role: .destructive) {
                        context.delete(item)
                        dismiss()
                    }
                } else if let trade = myOpenTrade {
                    NavigationLink(value: trade) {
                        Label("View your trade", systemImage: "arrow.left.arrow.right")
                    }
                } else if item.isAvailable {
                    Button {
                        showingStart = true
                    } label: {
                        Label("Start a Trade", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("This item has already been traded.").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(item.title)
        .sheet(isPresented: $showingStart) { StartTradeView(item: item) }
    }
}

/// The requester's opening move: express interest and let the owner choose what's fair.
struct StartTradeView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var members: [Member]
    @Query private var items: [SpareItem]
    let item: SpareItem
    @State private var note = ""

    private var ownerName: String { members.name(item.ownerID) }
    private var mySpares: [SpareItem] { items.filter { $0.ownerID == me?.uid && $0.isAvailable } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ItemRow(item: item, ownerName: ownerName)
                }
                Section {
                    Text("\(ownerName) will be notified and will look through your spare items to pick what seems fair. You can then accept, decline, or propose something else.")
                        .font(.callout).foregroundStyle(.secondary)
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                }
                Section("Your spare items (\(mySpares.count))") {
                    if mySpares.isEmpty {
                        Text("You haven't listed anything yet. Add spare items from your profile so \(ownerName) has something to choose from.")
                            .font(.callout).foregroundStyle(Theme.clay)
                    }
                    ForEach(mySpares) { ItemRow(item: $0) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Start a Trade")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        if let me { _ = Barter.startTrade(for: item, by: me.uid, note: note, in: context) }
                        dismiss()
                    }
                }
            }
        }
        .sheetSize()
    }
}

struct AddItemView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: ItemCategory = .veggies
    @State private var quantity = ""
    @State private var details = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("What can you spare?", text: $title)
                Picker("Category", selection: $category) {
                    ForEach(ItemCategory.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                }
                TextField(category == .timeSkill ? "How much time? (e.g. 2 hours)" : "How much? (e.g. 2 dozen)",
                          text: $quantity)
                TextField("Details", text: $details, axis: .vertical)
            }
            .formStyle(.grouped)
            .navigationTitle("New Spare Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let me {
                            context.insert(SpareItem(ownerID: me.uid, title: title, category: category,
                                                     quantity: quantity, details: details))
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .sheetSize()
    }
}
