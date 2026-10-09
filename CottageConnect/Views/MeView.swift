import SwiftUI
import SwiftData

/// The signed-in member's own page: profile, spare items, invites, and the demo switcher.
struct MeView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SpareItem.createdAt, order: .reverse) private var items: [SpareItem]
    @Query(sort: \Invite.createdAt, order: .reverse) private var invites: [Invite]
    @Query(sort: \Member.joinedAt) private var members: [Member]
    @AppStorage("currentUserID") private var currentUserID = ""
    @AppStorage("signedIn") private var signedIn = false
    @State private var addingItem = false

    private var myItems: [SpareItem] { items.filter { $0.ownerID == me?.uid } }
    private var myInvites: [Invite] { invites.filter { $0.createdByID == me?.uid } }

    var body: some View {
        NavigationStack {
            List {
                if let me {
                    Section {
                        NavigationLink(value: me) {
                            HStack(spacing: 12) {
                                Avatar(name: me.name, size: 48)
                                VStack(alignment: .leading) {
                                    Text(me.name).font(.headline)
                                    Text(me.isAdmin ? "\(me.role.rawValue) · Admin" : me.role.rawValue)
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    ForEach(myItems) { item in
                        NavigationLink(value: item) { ItemRow(item: item) }
                    }
                    Button("Add Spare Item", systemImage: "plus") { addingItem = true }
                } header: {
                    Text("Items I can spare")
                } footer: {
                    Text("Veggies, meat, dairy, eggs, wood, or your time and skills.")
                }

                Section {
                    ForEach(myInvites) { invite in
                        HStack {
                            Text(invite.code).font(.body.monospaced().weight(.semibold))
                            Spacer()
                            if let used = invite.usedByID {
                                Text("Used by \(members.name(used))").font(.caption).foregroundStyle(.secondary)
                            } else {
                                ShareLink(item: "Join me on Cottage Connect! Use invite code \(invite.code).") {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                    Button("Create Invite Code", systemImage: "envelope.badge") {
                        if let me { context.insert(Invite(createdByID: me.uid)) }
                    }
                } header: {
                    Text("Invite someone")
                } footer: {
                    Text("New members join by invitation and are reviewed by an admin before they can trade.")
                }

                Section("Coming soon") {
                    ForEach(ComingSoon.allCases) { feature in
                        Label(feature.rawValue, systemImage: feature.icon).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Menu {
                        ForEach(members.filter { $0.status == .approved }) { member in
                            Button(member.name) { currentUserID = member.uid.uuidString }
                        }
                    } label: {
                        Label("Switch member (demo)", systemImage: "person.2.circle")
                    }
                    Button("Sign Out", role: .destructive) {
                        signedIn = false
                        dismiss()
                    }
                }
            }
            .navigationTitle("You")
            .appDestinations()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $addingItem) { AddItemView() }
        }
        .sheetSize()
    }
}
