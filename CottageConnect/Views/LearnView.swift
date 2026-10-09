import SwiftUI
import SwiftData

/// Information sharing: how-tos and know-how from members.
struct LearnView: View {
    @Query(sort: \Guide.createdAt, order: .reverse) private var guides: [Guide]
    @Query private var members: [Member]
    @State private var topic: GuideTopic?
    @State private var search = ""
    @State private var showingAdd = false

    private var visible: [Guide] {
        guides.filter { g in
            (topic == nil || g.topic == topic)
            && (search.isEmpty || g.title.localizedCaseInsensitiveContains(search)
                || g.body.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        List {
            Picker("Topic", selection: $topic) {
                Text("All topics").tag(GuideTopic?.none)
                ForEach(GuideTopic.allCases) { Text($0.rawValue).tag(GuideTopic?.some($0)) }
            }
            ForEach(visible) { guide in
                NavigationLink(value: guide) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(guide.title).font(.headline)
                            Spacer()
                            Tag(text: guide.topic.rawValue, color: Theme.clay)
                        }
                        Text(guide.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                        Text("by \(members.name(guide.authorID))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search guides")
        .navigationTitle("Learn")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Share Know-How", systemImage: "square.and.pencil") { showingAdd = true }
            }
        }
        .sheet(isPresented: $showingAdd) { AddGuideView() }
    }
}

struct GuideDetailView: View {
    @Query private var members: [Member]
    let guide: Guide

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Tag(text: guide.topic.rawValue, color: Theme.clay)
                Text(guide.title).font(.title.bold())
                if let author = members.find(guide.authorID) {
                    NavigationLink(value: author) {
                        HStack {
                            Avatar(name: author.name, size: 28)
                            Text(author.name).font(.subheadline.weight(.medium))
                            Text(guide.createdAt, format: .dateTime.month().day()).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Text(guide.body).font(.body).lineSpacing(4)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding()
        }
        .navigationTitle("Guide")
    }
}

struct AddGuideView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var topic: GuideTopic = .growing
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Picker("Topic", selection: $topic) {
                    ForEach(GuideTopic.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("Share what you know", text: $text, axis: .vertical).lineLimit(8...20)
            }
            .formStyle(.grouped)
            .navigationTitle("Share Know-How")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        if let me { context.insert(Guide(authorID: me.uid, title: title, topic: topic, body: text)) }
                        dismiss()
                    }
                    .disabled(title.isEmpty || text.isEmpty)
                }
            }
        }
        .sheetSize()
    }
}
