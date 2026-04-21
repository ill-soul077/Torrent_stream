import SwiftUI

@MainActor
final class CommunityFeedViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var searchText = ""
    @Published var selectedTag: String? = nil
    @Published var isLoading = false
    @Published var error: String? = nil

    var availableTags: [String] {
        Array(Set(posts.flatMap { $0.tags })).sorted()
    }

    var filteredPosts: [CommunityPost] {
        let normalizedQuery = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return posts.filter { post in
            let matchesTag = selectedTag == nil || post.tags.contains(selectedTag ?? "")
            guard matchesTag else { return false }
            guard !normalizedQuery.isEmpty else { return true }

            let haystacks = [
                post.author_email,
                post.caption,
                post.torrent.name,
                post.torrent.category,
                post.torrent.size,
                post.tags.joined(separator: " ")
            ]

            return haystacks.contains { $0.lowercased().contains(normalizedQuery) }
        }
    }

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

    func selectTag(_ tag: String?) async {
        selectedTag = tag
    }

    func vote(postID: String, value: Int) async {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }

        let currentVote = posts[index].user_vote
        let requestedValue = currentVote == value ? 0 : value

        do {
            let state = try await APIService.shared.voteCommunityPost(postId: postID, value: requestedValue)
            posts[index].score = state.score
            posts[index].upvote_count = state.upvote_count
            posts[index].downvote_count = state.downvote_count
            posts[index].comment_count = state.comment_count
            posts[index].user_vote = state.user_vote
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
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var vm = CommunityFeedViewModel()

    var body: some View {
        ZStack {
            AppPalette.background(for: colorScheme).ignoresSafeArea()

            if vm.isLoading && vm.posts.isEmpty {
                ProgressView().tint(.purple)
            } else if let error = vm.error, vm.posts.isEmpty {
                CommunityMessageView(
                    icon: "exclamationmark.triangle.fill",
                    title: "Could not load Community",
                    message: error
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        searchSection

                        if !vm.availableTags.isEmpty || vm.selectedTag != nil {
                            tagFilterSection
                        }

                        if let error = vm.error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        if vm.posts.isEmpty {
                            CommunityMessageView(
                                icon: "person.3.fill",
                                title: "No posts yet",
                                message: "Share a torrent from its detail page to start the conversation."
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else if vm.filteredPosts.isEmpty {
                            CommunityMessageView(
                                icon: "magnifyingglass",
                                title: "No matching posts",
                                message: "Try a different search term or tag."
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else {
                            ForEach(vm.filteredPosts) { post in
                                VStack(alignment: .leading, spacing: 10) {
                                    NavigationLink(destination: CommunityPostDetailView(postID: post.id)) {
                                        CommunityPostCard(
                                            post: post,
                                            onTagTap: { tag in
                                                Task { await vm.selectTag(tag) }
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    feedActionBar(post: post)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await vm.load()
                }
            }
        }
        .appHeader("TorrentStream")
        .task {
            await vm.load()
        }
    }

    private func feedActionBar(post: CommunityPost) -> some View {
        HStack(spacing: 10) {
            feedActionButton(
                title: "\(post.upvote_count)",
                systemImage: "hand.thumbsup.fill",
                isActive: post.user_vote == 1,
                color: .green
            ) {
                Task { await vm.vote(postID: post.id, value: 1) }
            }

            feedActionButton(
                title: "\(post.downvote_count)",
                systemImage: "hand.thumbsdown.fill",
                isActive: post.user_vote == -1,
                color: .red
            ) {
                Task { await vm.vote(postID: post.id, value: -1) }
            }

            NavigationLink(destination: CommunityPostDetailView(postID: post.id)) {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                    Text("\(post.comment_count)")
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.14))
                .cornerRadius(999)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Score \(post.score)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private func feedActionButton(
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
            .font(.caption.weight(.semibold))
            .foregroundColor(isActive ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? color : color.opacity(0.14))
            .cornerRadius(999)
        }
        .buttonStyle(.plain)
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
                Text("Search Community")
                    .font(.headline)
                    .foregroundColor(AppPalette.primaryText(for: colorScheme))

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search posts, captions, tags, or authors", text: $vm.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(AppPalette.primaryText(for: colorScheme))

                if !vm.searchText.isEmpty {
                    Button(action: {
                        vm.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(AppPalette.subtleFill(for: colorScheme))
            .cornerRadius(12)
        }
    }

    private var tagFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Browse Tags")
                .font(.headline)
                .foregroundColor(AppPalette.primaryText(for: colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All", isActive: vm.selectedTag == nil) {
                        Task { await vm.selectTag(nil) }
                    }

                    ForEach(vm.availableTags, id: \.self) { tag in
                        filterChip(title: "#\(tag)", isActive: vm.selectedTag == tag) {
                            Task { await vm.selectTag(tag) }
                        }
                    }
                }
            }
        }
    }

    private func filterChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(isActive ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isActive ? Color.white : Color.white.opacity(0.08))
                .cornerRadius(999)
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

                        if !post.tags.isEmpty {
                            CommunityTagWrap(tags: post.tags)
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
    @State private var tagDraft = ""
    @State private var tags: [String] = []
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

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 10) {
                                TextField("Add a tag", text: $tagDraft)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(Color.white.opacity(0.07))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)

                                Button("Add") {
                                    addTag()
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(8)
                            }

                            if !tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(tags, id: \.self) { tag in
                                            Button(action: {
                                                tags.removeAll { $0 == tag }
                                            }) {
                                                HStack(spacing: 6) {
                                                    Text("#\(tag)")
                                                    Image(systemName: "xmark.circle.fill")
                                                }
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(Color.blue.opacity(0.22))
                                                .cornerRadius(999)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            Text("Up to 5 tags. Example: thriller, family, sci-fi")
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
                    torrent: torrent,
                    tags: tags
                )
                onPosted?("Posted to Community")
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func addTag() {
        let normalized = tagDraft
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "#", with: "")

        guard !normalized.isEmpty else { return }
        guard !tags.contains(normalized) else {
            tagDraft = ""
            return
        }
        guard tags.count < 5 else {
            error = "You can add up to 5 tags."
            return
        }

        tags.append(normalized)
        tagDraft = ""
        error = nil
    }
}

struct CommunityPostCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let post: CommunityPost
    var onTagTap: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CommunityPostHeader(post: post)

            if !post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(post.caption)
                    .font(.subheadline)
                    .foregroundColor(AppPalette.primaryText(for: colorScheme).opacity(0.88))
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(post.torrent.name)
                    .font(.headline)
                    .foregroundColor(AppPalette.primaryText(for: colorScheme))
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

            if !post.tags.isEmpty {
                CommunityTagWrap(tags: post.tags, onTap: onTagTap)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.cardBackground(for: colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppPalette.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }
}

struct CommunityPostHeader<PostType: CommunityPostPresentable>: View {
    @Environment(\.colorScheme) private var colorScheme
    let post: PostType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorHandle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppPalette.primaryText(for: colorScheme))
                    Text(post.created_at.communityTimestamp)
                        .font(.caption)
                        .foregroundColor(AppPalette.secondaryText(for: colorScheme))
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
    @Environment(\.colorScheme) private var colorScheme
    let comment: CommunityComment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.authorHandle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppPalette.primaryText(for: colorScheme))
                Spacer()
                Text(comment.created_at.communityTimestamp)
                    .font(.caption)
                    .foregroundColor(AppPalette.secondaryText(for: colorScheme))
            }
            Text(comment.content)
                .foregroundColor(AppPalette.primaryText(for: colorScheme).opacity(0.88))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.cardBackground(for: colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppPalette.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }
}

struct CommunityMessageView: View {
    @Environment(\.colorScheme) private var colorScheme
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
                .foregroundColor(AppPalette.primaryText(for: colorScheme))
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppPalette.secondaryText(for: colorScheme))
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

struct CommunityTagWrap: View {
    let tags: [String]
    var onTap: ((String) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button(action: {
                        onTap?(tag)
                    }) {
                        CommunityTag(text: "#\(tag)", color: .cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
