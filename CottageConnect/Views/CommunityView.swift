import SwiftUI
import SwiftData

struct CommunityView: View {
    @Query(sort: \Post.createdAt, order: .reverse) private var posts: [Post]
    @Query private var comments: [Comment]
    @Query private var members: [Member]
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(posts) { post in
                NavigationLink(value: post) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.title).font(.headline)
                        Text(post.body).lineLimit(2).foregroundStyle(.secondary)
                        HStack {
                            Text(members.name(post.authorID))
                            Text(post.createdAt, style: .relative)
                            Spacer()
                            Label("\(comments.filter { $0.postID == post.uid }.count)", systemImage: "bubble.left")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Community")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Post", systemImage: "square.and.pencil") { showingAdd = true }
            }
        }
        .sheet(isPresented: $showingAdd) { AddPostView() }
        .overlay {
            if posts.isEmpty {
                ContentUnavailableView("Nothing here yet", systemImage: "bubble.left.and.bubble.right",
                                       description: Text("Ask a question, share advice, or announce an event."))
            }
        }
    }
}

struct PostDetailView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Query(sort: \Comment.createdAt) private var allComments: [Comment]
    @Query private var members: [Member]
    let post: Post
    @State private var draft = ""
    @State private var replyingTo: UUID?

    private var comments: [Comment] { allComments.filter { $0.postID == post.uid } }
    private var isPoster: Bool { me?.uid == post.authorID }
    private var canComment: Bool {
        guard let me else { return false }
        return CommentRules.canComment(on: post, as: me.uid, comments: allComments)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.title).font(.title3.bold())
                    HStack {
                        Avatar(name: members.name(post.authorID), size: 24)
                        Text(members.name(post.authorID)).font(.subheadline.weight(.medium))
                        Text(post.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(post.body)
                }
                .padding(.vertical, 4)
            }

            Section("Comments") {
                if comments.isEmpty {
                    Text("No comments yet.").foregroundStyle(.secondary)
                }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(members.name(comment.authorID)).font(.subheadline.weight(.semibold))
                            if comment.authorID == post.authorID { Tag(text: "Poster") }
                            Spacer()
                            Text(comment.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                        }
                        if let to = comment.replyToAuthorID {
                            Text("↪ replying to \(members.name(to))").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(comment.text)
                        if isPoster && comment.authorID != me?.uid {
                            Button("Reply") { replyingTo = comment.authorID }
                                .font(.caption.weight(.medium))
                                .buttonStyle(.borderless)
                        }
                    }
                    .padding(.leading, comment.replyToAuthorID == nil ? 0 : 16)
                }
            }

            Section {
                if canComment {
                    if let replyingTo {
                        HStack {
                            Text("Replying to \(members.name(replyingTo))").font(.caption)
                            Spacer()
                            Button("Cancel") { self.replyingTo = nil }.font(.caption).buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        TextField(isPoster ? "Reply to your post" : "Add your comment", text: $draft, axis: .vertical)
                        Button("Send", action: send)
                            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Label("You've left your comment. You can comment again once \(members.name(post.authorID)) replies to you.",
                          systemImage: "lock")
                        .font(.callout).foregroundStyle(.secondary)
                }
            } footer: {
                if !isPoster && canComment {
                    Text("Each member gets one comment per post until the poster replies to them.")
                }
            }
        }
        .navigationTitle("Post")
    }

    private func send() {
        guard let me else { return }
        context.insert(Comment(postID: post.uid, authorID: me.uid, text: draft,
                               replyToAuthorID: isPoster ? replyingTo : nil))
        draft = ""
        replyingTo = nil
    }
}

struct AddPostView: View {
    @Environment(\.currentUser) private var me
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("What's on your mind?", text: $text, axis: .vertical).lineLimit(5...12)
            }
            .formStyle(.grouped)
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        if let me { context.insert(Post(authorID: me.uid, title: title, body: text)) }
                        dismiss()
                    }
                    .disabled(title.isEmpty || text.isEmpty)
                }
            }
        }
        .sheetSize()
    }
}
