import SwiftUI

struct NotificationCenterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            ForEach(appState.notifications) { notification in
                if let taskID = notification.taskID {
                    NavigationLink {
                        NotificationDestinationView(destination: NotificationDestination(
                            taskID: taskID,
                            conversationID: notification.conversationID,
                            kind: notification.kind
                        ))
                            .task { await appState.markNotificationRead(notification) }
                    } label: {
                        notificationRow(notification)
                    }
                } else {
                    Button {
                        Task { await appState.markNotificationRead(notification) }
                    } label: {
                        notificationRow(notification)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay {
            if appState.isLoadingNotifications {
                ProgressView()
            } else if appState.notifications.isEmpty {
                ContentUnavailableView(
                    appState.locale.text(he: "אין התראות חדשות", ru: "Новых уведомлений нет", en: "No new notifications"),
                    systemImage: "bell.slash",
                    description: Text(appState.locale.text(he: "עדכונים על בקשות והודעות יופיעו כאן.", ru: "Здесь появятся обновления заявок и сообщений.", en: "Request and message updates will appear here."))
                )
            }
        }
        .refreshable { await appState.loadNotifications() }
        .task { await appState.loadNotifications() }
        .listStyle(.plain)
        .navigationTitle(appState.locale.text(he: "התראות", ru: "Уведомления", en: "Notifications"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(appState.locale.text(he: "סימון הכל", ru: "Прочитать все", en: "Mark all read")) {
                    Task { await appState.markNotificationsRead() }
                }
                .font(.caption)
                .disabled(appState.notifications.isEmpty)
            }
        }
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
                Image(systemName: notification.systemImage)
                    .foregroundStyle(notification.isRead ? Color.secondary : Brand.red)
                    .frame(width: 40, height: 40)
                    .background((notification.isRead ? Color.secondary : Brand.red).opacity(0.10), in: .circle)
                VStack(alignment: .leading, spacing: 5) {
                    Text(notification.title.value(for: appState.locale)).font(.headline)
                    Text(notification.body.value(for: appState.locale)).font(.subheadline).foregroundStyle(.secondary)
                    Text(notification.createdAt, style: .relative).font(.caption).foregroundStyle(.tertiary)
                }
                if !notification.isRead { Circle().fill(Brand.red).frame(width: 8, height: 8) }
            }
            .padding(.vertical, 5)
    }
}

struct NotificationDestinationView: View {
    @Environment(AppState.self) private var appState
    let destination: NotificationDestination

    var body: some View {
        Group {
            if appState.isProfessional, appState.workspaceMode == .professional {
                ProfessionalNotificationDestinationView(destination: destination)
            } else if let conversationID = destination.conversationID,
                      let conversation = appState.professionalConversations.first(where: { $0.id == conversationID }) {
                ConversationView(conversation: conversation)
            } else {
                NotificationTaskDestinationView(taskID: destination.taskID)
            }
        }
        .task(id: destination.conversationID) {
            if destination.conversationID != nil { await appState.loadProfessionalConversations(force: true) }
        }
    }
}

struct NotificationTaskDestinationView: View {
    @Environment(AppState.self) private var appState
    let taskID: String
    @State private var task: RepairTask?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let task {
                ClientTaskDetailView(task: task)
            } else if didLoad {
                ContentUnavailableView(
                    appState.locale.text(he: "הבקשה אינה זמינה", ru: "Заявка недоступна", en: "Request unavailable"),
                    systemImage: "doc.text.magnifyingglass"
                )
            } else {
                ProgressView()
            }
        }
        .task(id: taskID) {
            task = await appState.loadTask(id: taskID)
            didLoad = true
        }
    }
}
