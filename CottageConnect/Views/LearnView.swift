import SwiftUI
import SwiftData
import PhotosUI

/// Free resources: recipes, building plans, canning instructions and how-tos anyone can use.
struct LearnView: View {
    @Query(sort: \Guide.createdAt, order: .reverse) private var guides: [Guide]
    @Query private var members: [Member]
    @Query private var comments: [Comment]
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
            Section {
                Label("Recipes, building plans, canning instructions and how-tos shared by members. Free for everyone to use.",
                      systemImage: "books.vertical")
                    .font(.subheadline)
                    .foregroundStyle(Theme.moss)
                Picker("Type", selection: $topic) {
                    Text("All").tag(GuideTopic?.none)
                    ForEach(GuideTopic.allCases) { Text($0.rawValue).tag(GuideTopic?.some($0)) }
                }
            }
            ForEach(visible) { guide in
                NavigationLink(value: guide) {
                    HStack(alignment: .top, spacing: 12) {
                        if let photo = Photo.forGuide(guide) {
                            PhotoView(photo: photo)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(guide.title).font(.headline)
                                Spacer()
                                Tag(text: guide.topic.rawValue, color: Theme.clay)
                            }
                            Text(guide.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            Text(byline(guide)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search recipes, plans, how-tos")
        .navigationTitle("Free Resources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Share a Resource", systemImage: "square.and.arrow.up") { showingAdd = true }
            }
        }
        .sheet(isPresented: $showingAdd) { AddGuideView() }
    }

    private func byline(_ guide: Guide) -> String {
        let count = comments.filter { $0.postID == guide.uid }.count
        var parts = ["by \(members.name(guide.authorID))", "\(count) comment\(count == 1 ? "" : "s")"]
        if guide.attachment != nil { parts.append("attachment") }
        return parts.joined(separator: " · ")
    }
}

struct GuideDetailView: View {
    @Query private var members: [Member]
    let guide: Guide

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if let photo = Photo.forGuide(guide) {
                        PhotoView(photo: photo)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        if let url = URL(string: photo.source) {
                            Link(photo.credit, destination: url)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
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
                    }
                    Text(guide.body).lineSpacing(4)
                    if let data = guide.attachment {
                        AttachmentImage(data: data)
                    }
                }
                .padding(.vertical, 4)
            }
            CommentsSections(threadID: guide.uid, ownerID: guide.authorID, noun: "resource")
        }
        .navigationTitle(guide.topic.rawValue)
    }
}

/// Shows attached image data on both iOS and macOS.
struct AttachmentImage: View {
    let data: Data

    var body: some View {
        #if canImport(UIKit)
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 10))
        }
        #else
        if let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 10))
        }
        #endif
    }
}

struct AddGuideView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var topic: GuideTopic = .recipe
    @State private var text = ""
    @State private var photo: PhotosPickerItem?
    @State private var attachment: Data?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Picker("Type", selection: $topic) {
                    ForEach(GuideTopic.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("Ingredients, steps, or instructions", text: $text, axis: .vertical).lineLimit(8...20)
                Section {
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label(attachment == nil ? "Attach a Photo or Drawing" : "Replace Photo", systemImage: "photo")
                    }
                    if let attachment { AttachmentImage(data: attachment).frame(maxHeight: 200) }
                } footer: {
                    Text("Everything here is free for all members to read and use.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Share a Resource")
            .onChange(of: photo) {
                Task { attachment = try? await photo?.loadTransferable(type: Data.self) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        if let me {
                            context.insert(Guide(authorID: me.uid, title: title, topic: topic, body: text, attachment: attachment))
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty || text.isEmpty)
                }
            }
        }
        .sheetSize()
    }
}
