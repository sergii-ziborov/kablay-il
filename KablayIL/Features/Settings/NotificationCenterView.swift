import SwiftUI
import UIKit

struct NotificationCenterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            ForEach(appState.notifications) { notification in
                if notification.kind == "admin_credit_gift" && appState.isProfessional {
                    NavigationLink {
                        CreditsView()
                            .task { await appState.markNotificationRead(notification) }
                    } label: {
                        notificationRow(notification)
                    }
                } else if let taskID = notification.taskID {
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
        .listRowSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(appState.locale.text(he: "התראות", ru: "Уведомления", en: "Notifications"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(appState.locale.text(he: "סימון הכל", ru: "Прочитать все", en: "Mark all read")) {
                    Task { await appState.markNotificationsRead() }
                }
                .font(.subheadline.weight(.semibold))
                .disabled(appState.notifications.isEmpty)
            }
        }
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        let fromAdministration = notification.kind == "admin_credit_gift" || notification.kind == "admin_announcement"
        let accent = fromAdministration ? Color(red: 0.52, green: 0.29, blue: 0.77) : Brand.red
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: displayIcon(notification))
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(notification.isRead ? Color.primary : accent)
                .frame(width: 44, height: 44)
                .background((notification.isRead ? Color.primary : accent).opacity(0.12), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 9) {
                if fromAdministration {
                    Text(appState.locale.text(he: "מהנהלת KABLAY", ru: "От администрации KABLAY", en: "From KABLAY"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayTitle(notification))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if !notification.isRead {
                        Text(appState.locale.text(he: "חדש", ru: "Новое", en: "New"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.12), in: Capsule())
                    }
                }
                Text(displayBody(notification))
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(notification.isRead ? 0.76 : 0.90))
                    .fixedSize(horizontal: false, vertical: true)
                Text(notification.createdAt.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .shortened)
                        .locale(appState.locale.locale)
                ))
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.68))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(fromAdministration ? accent.opacity(0.09) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(accent.opacity(fromAdministration ? 0.35 : (notification.isRead ? 0 : 0.25)), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func displayTitle(_ notification: AppNotification) -> String {
        guard notification.title.en == "Request update" else {
            return notification.title.value(for: appState.locale)
        }
        switch notification.kind {
        case "new_jobs":
            return appState.session?.user.role == .admin
                ? appState.locale.text(he: "נוצרה הזמנה חדשה", ru: "Создан новый заказ", en: "New request created")
                : appState.locale.text(he: "הזמנה חדשה מתאימה", ru: "Новый подходящий заказ", en: "New matching job")
        case "task_updates":
            return appState.locale.text(he: "ההצעה שלכם נבחרה", ru: "Ваш отклик выбран", en: "Your offer was selected")
        case "registrations":
            return notification.id.contains("specialist.registered")
                ? appState.locale.text(he: "בעל מקצוע חדש נרשם", ru: "Зарегистрирован новый мастер", en: "New professional registered")
                : appState.locale.text(he: "משתמש חדש נרשם", ru: "Зарегистрирован новый пользователь", en: "New user registered")
        case "messages":
            return appState.locale.text(he: "הודעה חדשה", ru: "Новое сообщение", en: "New message")
        default:
            return notification.title.value(for: appState.locale)
        }
    }

    private func displayIcon(_ notification: AppNotification) -> String {
        guard notification.systemImage == "bell.fill" else { return notification.systemImage }
        switch notification.kind {
        case "new_jobs": return "briefcase.fill"
        case "task_updates": return "checkmark.circle.fill"
        case "registrations": return "person.crop.circle.badge.plus"
        case "messages": return "message.fill"
        default: return notification.systemImage
        }
    }

    private func displayBody(_ notification: AppNotification) -> String {
        let body = notification.body.value(for: appState.locale)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty { return body }
        switch notification.kind {
        case "new_jobs":
            return appState.locale.text(he: "פתחו את ההזמנה כדי לראות את הפרטים.", ru: "Откройте заказ, чтобы посмотреть детали.", en: "Open the job to see the details.")
        case "task_updates":
            return appState.locale.text(he: "הלקוח בחר בהצעה שלכם. פתחו את פרטי העבודה.", ru: "Клиент выбрал ваш отклик. Откройте заказ.", en: "The client selected your offer. Open the job.")
        case "registrations":
            return appState.locale.text(he: "בדקו את החשבון בלוח הניהול.", ru: "Проверьте аккаунт в панели администратора.", en: "Review the account in the admin dashboard.")
        case "messages":
            return appState.locale.text(he: "פתחו את הצ׳אט כדי לקרוא את ההודעה.", ru: "Откройте чат, чтобы прочитать сообщение.", en: "Open the chat to read the message.")
        default:
            return appState.locale.text(he: "פתחו את הפרטים כדי לראות מה השתנה.", ru: "Откройте уведомление, чтобы узнать подробности.", en: "Open the notification for details.")
        }
    }
}

struct NotificationDestinationView: View {
    @Environment(AppState.self) private var appState
    let destination: NotificationDestination

    var body: some View {
        Group {
            if destination.kind == "task_assignment" {
                NotificationTaskDestinationView(taskID: destination.taskID)
            } else if appState.isProfessional,
                      appState.workspaceMode == .professional || ["new_jobs", "task_updates"].contains(destination.kind) {
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
