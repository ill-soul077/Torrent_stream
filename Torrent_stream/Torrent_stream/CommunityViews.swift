import SwiftUI

@MainActor
final class CommunityFeedViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            posts = try await APIService.shared.getCommunityPosts()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
final class CommunityPostDetailViewModel: ObservableObject {
    @Published var post: CommunityPostDetail? = nil
    @Published var comments: [CommunityComment] = []
    @Published var commentDraft = ""
    @Published var isLoading = false
    @Published var isSubmittingComment = false
    @Published var error: String? = nil

    private let postID: String

    init(postID: String) {
        self.postID = postID
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let postRequest = APIService.shared.getCommunityPost(postID)
            async let commentsRequest = APIService.shared.getCommunityComments(postId: postID)
            post = try await postRequest
            comments = try await commentsRequest
        } catch {
            self.error = error.localizedDescription
        }
    }

    func vote(_ value: Int) async {
        guard let currentPost = post else { return }
        let requestedValue = currentPost.user_vote == value ? 0 : value

        do {
            let state = try await APIService.shared.voteCommunityPost(postId: postID, value: requestedValue)
            applyVoteState(state)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func submitComment() async {
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmittingComment = true
        defer { isSubmittingComment = false }

        do {
            let comment = try await APIService.shared.addCommunityComment(postId: postID, content: trimmed)
            comments.append(comment)
            commentDraft = ""

            if var currentPost = post {
                currentPost.comment_count += 1
                post = currentPost
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func applyVoteState(_ state: CommunityVoteState) {
        guard var currentPost = post else { return }
        currentPost.score = state.score
        currentPost.upvote_count = state.upvote_count
        currentPost.downvote_count = state.downvote_count
        currentPost.comment_count = state.comment_count
        currentPost.user_vote = state.user_vote
        post = currentPost
    }
}

struct CommunityFeedView: View {
    @StateObject private var vm = CommunityFeedViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if vm.isLoading && vm.posts.isEmpty {
                ProgressView().tint(.purple)
            } else if let error = vm.error, vm.posts.isEmpty {
                CommunityMessageView(
                    icon: "exclamationmark.triangle.fill",
                    title: "Could not load Community",
                    message: error
                )
            } else if vm.posts.isEmpty {
                CommunityMessageView(
                    icon: "person.3.fill",
                    title: "No posts yet",
                    message: "Share a torrent from its detail page to start the conversation."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.posts) { post in
                            NavigationLink(destination: CommunityPostDetailView(postID: post.id)) {
                                CommunityPostCard(post: post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await vm.load()
                }
            }
        }
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load()
        }
    }
}

struct CommunityPostDetailView: View {
    let postID: String
    @StateObject private var vm: CommunityPostDetailViewModel

    init(postID: String) {
        self.postID = postID
        _vm = StateObject(wrappedValue: CommunityPostDetailViewModel(postID: postID))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if vm.isLoading && vm.post == nil {
                ProgressView().tint(.purple)
            } else if let error = vm.error, vm.post == nil {
                CommunityMessageView(
                    icon: "exclamationmark.triangle.fill",
                    title: "Could not load post",
                    message: error
                )
            } else if let post = vm.post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        CommunityPostHeader(post: post)

                        voteSection(post: post)

                        if !post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What they said")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(post.caption)
                                    .foregroundColor(.white.opacity(0.88))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Comments")
                                .font(.headline)
                                .foregroundColor(.white)

                            if vm.comments.isEmpty {
                                Text("No comments yet.")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            } else {
                                ForEach(vm.comments) { comment in
                                    CommunityCommentRow(comment: comment)
                                }
                            }
                        }

                        commentComposer
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load()
        }
    }

    private func voteSection(post: CommunityPostDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Votes")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                voteButton(
                    title: "\(post.upvote_count)",
                    systemImage: "hand.thumbsup.fill",
                    isActive: post.user_vote == 1,
                    color: .green
                ) {
                    Task { await vm.vote(1) }
                }

                voteButton(
                    title: "\(post.downvote_count)",
                    systemImage: "hand.thumbsdown.fill",
                    isActive: post.user_vote == -1,
                    color: .red
                ) {
                    Task { await vm.vote(-1) }
                }

                Spacer()

                Text("Score \(post.score)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }

    private func voteButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(isActive ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? color : color.opacity(0.16))
            .cornerRadius(8)
        }
    }

    private var commentComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Comment")
                .font(.headline)
                .foregroundColor(.white)

            TextField("Share your thoughts", text: $vm.commentDraft, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(Color.white.opacity(0.07))
                .cornerRadius(8)
                .foregroundColor(.white)

            if let error = vm.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: {
                Task { await vm.submitComment() }
            }) {
                Group {
                    if vm.isSubmittingComment {
                        ProgressView().tint(.white)
                    } else {
                        Text("Post Comment")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.purple)
                .cornerRadius(8)
            }
            .disabled(vm.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSubmittingComment)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

struct CommunityPostComposerView: View {
    let torrent: TorrentItem
    var onPosted: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var isSubmitting = false
    @State private var error: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sharing")
                                .font(.headline)
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(torrent.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                HStack(spacing: 8) {
                                    if !torrent.category.isEmpty {
                                        CommunityTag(text: torrent.category, color: .blue)
                                    }
                                    if !torrent.size.isEmpty {
                                        CommunityTag(text: torrent.size, color: .gray)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Caption")
                                .font(.headline)
                                .foregroundColor(.white)

                            TextEditor(text: $caption)
                                .frame(minHeight: 160)
                                .padding(8)
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(8)
                                .foregroundColor(.white)

                            Text("Optional. Add a short review or why you liked it.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        if let error = error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Post to Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Post")
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() {
        Task {
            isSubmitting = true
            error = nil
            defer { isSubmitting = false }

            do {
                _ = try await APIService.shared.createCommunityPost(
                    caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                    torrent: torrent
                )
                onPosted?("Posted to Community")
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct CommunityPostCard: View {
    let post: CommunityPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CommunityPostHeader(post: post)

            if !post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(post.caption)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.88))
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(post.torrent.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !post.torrent.category.isEmpty {
                        CommunityTag(text: post.torrent.category, color: .blue)
                    }
                    if !post.torrent.size.isEmpty {
                        CommunityTag(text: post.torrent.size, color: .gray)
                    }
                    CommunityTag(text: "Score \(post.score)", color: .green)
                    CommunityTag(text: "\(post.comment_count) comments", color: .orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

struct CommunityPostHeader<PostType: CommunityPostPresentable>: View {
    let post: PostType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorHandle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(post.created_at.communityTimestamp)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                if post.user_vote == 1 {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundColor(.green)
                } else if post.user_vote == -1 {
                    Image(systemName: "hand.thumbsdown.fill")
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct CommunityCommentRow: View {
    let comment: CommunityComment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.authorHandle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(comment.created_at.communityTimestamp)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Text(comment.content)
                .foregroundColor(.white.opacity(0.88))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

struct CommunityMessageView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundColor(.purple.opacity(0.8))
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}

struct CommunityTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

protocol CommunityPostPresentable {
    var authorHandle: String { get }
    var created_at: String { get }
    var user_vote: Int { get }
}

extension CommunityPost: CommunityPostPresentable {}
extension CommunityPostDetail: CommunityPostPresentable {}

private extension String {
    var communityTimestamp: String {
        if let separatorIndex = firstIndex(of: "T") {
            var result = self
            result.replaceSubrange(separatorIndex...separatorIndex, with: " ")
            return String(result.prefix(16))
        }
        return String(prefix(16))
    }
}
