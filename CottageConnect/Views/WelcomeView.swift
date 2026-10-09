import SwiftUI
import SwiftData

/// Sign-in and invite-only joining. Providers are simulated for the demo.
struct WelcomeView: View {
    @State private var method: SignInMethod?
    @State private var joining = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.moss)
            VStack(spacing: 8) {
                Text("Cottage Connect").font(.largeTitle.bold())
                Text("Barter, learn, and lean on your neighbors.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 12) {
                signInButton("Continue with Apple", icon: "apple.logo", method: "Apple")
                signInButton("Continue with Google", icon: "globe", method: "Google")
                signInButton("Continue with Phone Number", icon: "phone", method: "Phone")
                Button("New here? Join with an invite code") { joining = true }
                    .padding(.top, 8)
            }
            .frame(maxWidth: 360)
            Text("Members join by invitation only.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.wheat.opacity(0.15))
        .sheet(item: $method) { DemoSignInView(method: $0.id) }
        .sheet(isPresented: $joining) { JoinView() }
    }

    private func signInButton(_ title: String, icon: String, method: String) -> some View {
        Button { self.method = SignInMethod(id: method) } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

private struct SignInMethod: Identifiable {
    let id: String
}

/// Stands in for the real Apple/Google/phone sign-in: pick an existing member.
struct DemoSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Member.joinedAt) private var members: [Member]
    @AppStorage("currentUserID") private var currentUserID = ""
    @AppStorage("signedIn") private var signedIn = false
    let method: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(members.filter { $0.status != .declined }) { member in
                        Button {
                            currentUserID = member.uid.uuidString
                            signedIn = true
                            dismiss()
                        } label: {
                            HStack {
                                Avatar(name: member.name)
                                VStack(alignment: .leading) {
                                    Text(member.name).font(.headline)
                                    Text(member.status == .pending ? "Pending review" : (member.isAdmin ? "Admin" : member.role.rawValue))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Demo: the real app will verify you with \(method). Choose who to sign in as.")
                }
            }
            .navigationTitle("Sign in with \(method)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .sheetSize()
    }
}

/// Invite code, then a profile. The new member waits for an admin to approve them.
struct JoinView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var invites: [Invite]
    @AppStorage("currentUserID") private var currentUserID = ""
    @AppStorage("signedIn") private var signedIn = false
    @State private var code = ""
    @State private var invite: Invite?
    @State private var codeError = false
    @State private var name = ""
    @State private var role: MemberRole = .farmer
    @State private var region = ""
    @State private var bio = ""
    @State private var products = ""
    @State private var skills = ""
    @State private var method = "Apple"

    var body: some View {
        NavigationStack {
            Form {
                if invite == nil {
                    Section {
                        TextField("Invite code", text: $code)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                    } footer: {
                        Text(codeError ? "That code isn't valid or has already been used." : "Ask a current member for a code. Try HARVEST for the demo.")
                            .foregroundStyle(codeError ? Theme.clay : Color.secondary)
                    }
                } else {
                    Section("Sign in with") {
                        Picker("Sign in with", selection: $method) {
                            Text("Apple").tag("Apple")
                            Text("Google").tag("Google")
                            Text("Phone").tag("Phone")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    Section("About you") {
                        TextField("Name", text: $name)
                        Picker("I am a", selection: $role) {
                            ForEach(MemberRole.allCases) { Text($0.rawValue).tag($0) }
                        }
                        TextField("Town and state", text: $region)
                        TextField("A little about you", text: $bio, axis: .vertical)
                        TextField("What you produce (comma separated)", text: $products)
                        TextField("Skills (comma separated)", text: $skills)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Join Cottage Connect")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if invite == nil {
                        Button("Next", action: checkCode).disabled(code.isEmpty)
                    } else {
                        Button("Join", action: join).disabled(name.isEmpty || region.isEmpty)
                    }
                }
            }
        }
        .sheetSize()
    }

    private func checkCode() {
        let entered = code.trimmingCharacters(in: .whitespaces).uppercased()
        invite = invites.first { $0.code == entered && $0.usedByID == nil }
        codeError = invite == nil
    }

    private func join() {
        guard let invite else { return }
        // Place new members near the person who invited them; real location comes later.
        let member = Member(name: name, role: role, region: region, bio: bio,
                            products: parseList(products), skills: parseList(skills),
                            latitude: 42.0 + Double.random(in: -0.3...0.3),
                            longitude: -73.8 + Double.random(in: -0.3...0.3),
                            status: .pending, invitedByID: invite.createdByID, signInMethod: method)
        context.insert(member)
        invite.usedByID = member.uid
        currentUserID = member.uid.uuidString
        signedIn = true
        dismiss()
    }
}

struct PendingReviewView: View {
    @Environment(\.currentUser) private var me
    @Query private var members: [Member]
    @AppStorage("signedIn") private var signedIn = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: me?.status == .declined ? "xmark.circle" : "hourglass.circle")
                .font(.system(size: 64))
                .foregroundStyle(Theme.clay)
            if me?.status == .declined {
                Text("Your request wasn't approved").font(.title2.bold())
            } else {
                Text("Thanks for joining, \(me?.name ?? "")!").font(.title2.bold())
                Text("\(members.name(me?.invitedByID)) invited you. An admin is reviewing your profile, and you'll be able to barter and post once you're approved.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)
                Text("Demo: sign out and sign in as Rosa (admin) to approve.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Sign Out") { signedIn = false }
                .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
