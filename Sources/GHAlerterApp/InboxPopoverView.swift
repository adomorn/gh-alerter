import AppKit
import SwiftUI
import GHAlerterCore

struct InboxPopoverView: View {
    @ObservedObject var inboxStore: InboxStore
    let onCheckNow: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PR Inbox")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Check now", action: onCheckNow)
            }

            if let lastErrorMessage = inboxStore.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PullRequestSection(
                        title: "Review requested for me",
                        pullRequests: inboxStore.reviewRequests
                    )

                    ApprovalSection(events: inboxStore.approvals)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if let lastSuccessfulCheck = inboxStore.lastSuccessfulCheck {
                    Text("Last checked \(dateFormatter.string(from: lastSuccessfulCheck))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Settings", action: onOpenSettings)
                Button("Quit", action: onQuit)
            }
        }
        .padding(16)
        .frame(width: 420, height: 420, alignment: .topLeading)
    }
}

private struct PullRequestSection: View {
    let title: String
    let pullRequests: [PullRequestRef]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if pullRequests.isEmpty {
                Text("No pull requests")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pullRequests) { pullRequest in
                    PullRequestRow(pullRequest: pullRequest)
                }
            }
        }
    }
}

private struct ApprovalSection: View {
    let events: [GitHubEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My PR approvals")
                .font(.headline)

            if events.isEmpty {
                Text("No approvals")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    ApprovalRow(event: event)
                }
            }
        }
    }
}

private struct PullRequestRow: View {
    let pullRequest: PullRequestRef

    var body: some View {
        Button {
            NSWorkspace.shared.open(pullRequest.url)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(pullRequest.title)
                    .font(.callout)
                    .lineLimit(2)

                Text("\(pullRequest.owner)/\(pullRequest.repo)#\(pullRequest.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ApprovalRow: View {
    let event: GitHubEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PullRequestRow(pullRequest: event.pr)

            if let actor = approvalActor {
                Text("Approved by \(actor)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var approvalActor: String? {
        if case .prApproved(_, _, let actor, _) = event {
            return actor
        }

        return nil
    }
}
