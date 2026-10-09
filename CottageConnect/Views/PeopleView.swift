import SwiftUI
import SwiftData
import MapKit

/// Members near you, as a list or a map, within a radius the user picks.
struct PeopleView: View {
    @Environment(\.currentUser) private var me
    @Query(sort: \Member.name) private var members: [Member]
    @AppStorage("radiusMiles") private var radius = 50.0
    @State private var showMap = false
    @State private var role: MemberRole?
    @State private var position: MapCameraPosition = .automatic

    private var nearby: [Member] {
        guard let me else { return [] }
        return members
            .filter { $0.uid != me.uid && $0.status == .approved }
            .filter { role == nil || $0.role == role || $0.role == .both }
            .filter { Double(me.approxMiles(to: $0)) <= radius }
            .sorted { me.approxMiles(to: $0) < me.approxMiles(to: $1) }
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            if showMap { map } else { list }
        }
        .navigationTitle("People")
        .onAppear { position = .region(region) }
        .onChange(of: radius) { position = .region(region) }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("View", selection: $showMap) {
                Label("List", systemImage: "list.bullet").tag(false)
                Label("Map", systemImage: "map").tag(true)
            }
            .pickerStyle(.segmented)
            HStack {
                Image(systemName: "location.circle").foregroundStyle(Theme.moss)
                Text("Within \(Int(radius)) mi").font(.subheadline).monospacedDigit().frame(width: 110, alignment: .leading)
                Slider(value: $radius, in: 5...150, step: 5)
            }
            Picker("Role", selection: $role) {
                Text("Everyone").tag(MemberRole?.none)
                Text("Farmers").tag(MemberRole?.some(.farmer))
                Text("Practitioners").tag(MemberRole?.some(.practitioner))
            }
            .pickerStyle(.segmented)
        }
        .padding()
    }

    private var list: some View {
        List(nearby) { member in
            NavigationLink(value: member) { MemberRow(member: member) }
        }
        .overlay {
            if nearby.isEmpty {
                ContentUnavailableView("No one within \(Int(radius)) miles", systemImage: "person.3",
                                       description: Text("Widen the radius to see more people."))
            }
        }
    }

    private var map: some View {
        Map(position: $position) {
            if let me {
                MapCircle(center: me.approxCoordinate, radius: radius * 1609.34)
                    .foregroundStyle(Theme.moss.opacity(0.12))
                    .stroke(Theme.moss.opacity(0.5), lineWidth: 1)
                Annotation("You", coordinate: me.approxCoordinate) {
                    Image(systemName: "house.fill")
                        .padding(6)
                        .foregroundStyle(.white)
                        .background(Theme.clay, in: Circle())
                }
            }
            ForEach(nearby) { member in
                Annotation(member.name, coordinate: member.approxCoordinate) {
                    NavigationLink(value: member) { Avatar(name: member.name, size: 34) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var region: MKCoordinateRegion {
        let center = me?.approxCoordinate ?? CLLocationCoordinate2D(latitude: 42, longitude: -73.9)
        let meters = radius * 1609.34 * 2.4
        return MKCoordinateRegion(center: center, latitudinalMeters: meters, longitudinalMeters: meters)
    }
}

extension Member {
    /// Location snapped to a ~3 mile grid so pins never point at someone's house.
    var approxCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (latitude * 20).rounded() / 20, longitude: (longitude * 20).rounded() / 20)
    }
}

struct MemberRow: View {
    @Environment(\.currentUser) private var me
    let member: Member

    var body: some View {
        HStack(spacing: 12) {
            Avatar(name: member.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name).font(.headline)
                Text(member.products.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Tag(text: member.role.rawValue)
                if let me { Text("~\(me.approxMiles(to: member)) mi").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

/// A member's page. Until both people have asked to connect, only the basics are shown.
struct ProfileView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Query private var requests: [ConnectionRequest]
    @Query(sort: \SpareItem.createdAt, order: .reverse) private var items: [SpareItem]
    @Query private var members: [Member]
    let member: Member
    @State private var editing = false

    private var isMe: Bool { member.uid == me?.uid }
    private var state: ConnectionState {
        guard let me else { return .none }
        return Connections.state(between: me.uid, and: member.uid, requests: requests)
    }
    private var fullAccess: Bool { isMe || state == .connected }
    private var spares: [SpareItem] { items.filter { $0.ownerID == member.uid && $0.isAvailable } }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Avatar(name: member.name, size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(member.name).font(.title2.bold())
                        Tag(text: member.role.rawValue)
                        Text(locationLine).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if !isMe { Section { connectControls } }

            if !member.products.isEmpty {
                Section("Produces") { Text(member.products.joined(separator: " · ")) }
            }

            if fullAccess {
                if !member.bio.isEmpty { Section("About") { Text(member.bio) } }
                if !member.skills.isEmpty { Section("Skills") { Text(member.skills.joined(separator: " · ")) } }
                if let inviter = members.find(member.invitedByID) {
                    Section("Invited by") { Text(inviter.name) }
                }
            } else {
                Section {
                    Label("Connect with \(member.name.split(separator: " ").first ?? "") to see their full profile, skills, and to message them.",
                          systemImage: "lock")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Section("Spare items (\(spares.count))") {
                if spares.isEmpty { Text("Nothing listed right now.").foregroundStyle(.secondary) }
                ForEach(spares) { item in
                    NavigationLink(value: item) { ItemRow(item: item) }
                }
            }
        }
        .navigationTitle(member.name)
        .toolbar {
            if isMe {
                ToolbarItem(placement: .primaryAction) { Button("Edit") { editing = true } }
            }
        }
        .sheet(isPresented: $editing) { EditProfileView(member: member) }
    }

    private var locationLine: String {
        var parts = [fullAccess ? member.region : member.generalArea]
        if let me, !isMe { parts.append("~\(me.approxMiles(to: member)) mi away") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    @ViewBuilder
    private var connectControls: some View {
        switch state {
        case .none:
            Button { requestConnection() } label: {
                Label("Request to Connect", systemImage: "person.badge.plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .requested:
            Label("Request sent. You'll be connected once \(member.name) connects back.", systemImage: "clock")
                .foregroundStyle(.secondary)
        case .incoming:
            Text("\(member.name) asked to connect with you.").font(.callout)
            Button { requestConnection() } label: {
                Label("Connect Back", systemImage: "person.2").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .connected:
            NavigationLink(value: Conversation(otherID: member.uid)) {
                Label("Message", systemImage: "message")
            }
        }
    }

    private func requestConnection() {
        guard let me else { return }
        context.insert(ConnectionRequest(fromID: me.uid, toID: member.uid))
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var member: Member
    @State private var products = ""
    @State private var skills = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Shown to everyone") {
                    TextField("Name", text: $member.name)
                    Picker("I am a", selection: $member.role) {
                        ForEach(MemberRole.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("What you produce (comma separated)", text: $products)
                }
                Section {
                    TextField("Town and state", text: $member.region)
                    TextField("About you", text: $member.bio, axis: .vertical)
                    TextField("Skills (comma separated)", text: $skills)
                } header: {
                    Text("Shown once you're connected")
                } footer: {
                    Text("Before connecting, people only see your state and an approximate distance.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Profile")
            .onAppear {
                products = member.products.joined(separator: ", ")
                skills = member.skills.joined(separator: ", ")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        member.products = parseList(products)
                        member.skills = parseList(skills)
                        dismiss()
                    }
                }
            }
        }
        .sheetSize()
    }
}
