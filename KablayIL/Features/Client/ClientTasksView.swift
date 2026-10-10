import SwiftUI
import PhotosUI
import UIKit

struct ClientTasksView: View {
    @Environment(AppState.self) private var appState
    @State private var showLogin = false
    @State private var filter = TaskFilter.active

    private enum TaskFilter: String, CaseIterable, Identifiable {
        case active, completed, cancelled
        var id: String { rawValue }
    }

    private var visibleTasks: [RepairTask] {
        appState.clientTasks.filter { task in
            switch filter {
            case .active: [.open, .proposalReceived, .inProgress].contains(task.status)
            case .completed: task.status == .completed || task.status == .archived
            case .cancelled: task.status == .cancelled
            }
        }
    }

    var body: some View {
        Group {
            if appState.isAuthenticated {
                VStack(spacing: 0) {
                    Picker(appState.locale.text(he: "סטטוס", ru: "Статус", en: "Status"), selection: $filter) {
                        Text(appState.locale.text(he: "פעילות", ru: "Активные", en: "Active")).tag(TaskFilter.active)
                        Text(appState.locale.text(he: "הושלמו", ru: "Готовые", en: "Completed")).tag(TaskFilter.completed)
                        Text(appState.locale.text(he: "בוטלו", ru: "Отменены", en: "Cancelled")).tag(TaskFilter.cancelled)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    OfflineFreshnessLabel(
                        updatedAt: appState.clientTasksUpdatedAt,
                        isSavedCopy: appState.clientTasksShowingSavedCopy,
                        staleAfter: OfflineFreshness.personalTasks,
                        locale: appState.locale
                    )
                    .padding(.horizontal)

                    List(visibleTasks) { task in
                        NavigationLink { ClientTaskDetailView(task: task) } label: { ClientTaskRow(task: task) }
                    }
                    .listStyle(.plain)
                    .overlay {
                        if appState.isLoadingTasks && appState.clientTasks.isEmpty {
                            ProgressView()
                        } else if appState.clientTasksLoadFailed && appState.clientTasks.isEmpty {
                            ContentUnavailableView(
                                appState.locale.text(he: "אין בקשות שמורות", ru: "Нет сохранённых заявок", en: "No saved requests"),
                                systemImage: "wifi.exclamationmark",
                                description: Text(appState.locale.text(
                                    he: "לאחר התחברות, הבקשות יישמרו במכשיר לקריאה גם ללא רשת.",
                                    ru: "После подключения заявки сохранятся на устройстве для просмотра без сети.",
                                    en: "After connecting, requests are saved on this device for offline reading."
                                ))
                            )
                        } else if visibleTasks.isEmpty {
                            ContentUnavailableView(
                                emptyTitle,
                                systemImage: filter == .active ? "doc.badge.plus" : "checklist"
                            )
                        }
                    }
                }
                .task { await appState.loadClientTasks() }
                .refreshable { await appState.loadClientTasks(force: true) }
            } else {
                ContentUnavailableView {
                    Label(appState.locale.text(he: "הבקשות שלך", ru: "Ваши заявки", en: "Your requests"), systemImage: "doc.text")
                } description: {
                    Text(appState.locale.text(he: "היכנסו לפי מספר טלפון כדי לראות בקשות והצעות.", ru: "Войдите по телефону, чтобы видеть заявки и предложения.", en: "Sign in by phone to see requests and offers."))
                } actions: {
                    Button(appState.locale.text(he: "כניסה", ru: "Войти", en: "Sign in")) { showLogin = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle(appState.locale.text(he: "הבקשות שלי", ru: "Мои заявки", en: "My requests"))
        .sheet(isPresented: $showLogin) { PhoneLoginView() }
    }

    private var emptyTitle: String {
        switch filter {
        case .active: appState.locale.text(he: "אין בקשות פעילות", ru: "Нет активных заявок", en: "No active requests")
        case .completed: appState.locale.text(he: "אין בקשות שהושלמו", ru: "Нет выполненных заявок", en: "No completed requests")
        case .cancelled: appState.locale.text(he: "אין בקשות שבוטלו", ru: "Нет отменённых заявок", en: "No cancelled requests")
        }
    }
}

private struct ClientTaskRow: View {
    @Environment(AppState.self) private var appState
    let task: RepairTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title).font(.headline)
                Spacer()
                StatusPill(title: statusTitle, color: statusColor)
            }
            Label(task.city, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary)
            Label("\(task.proposalCount) " + appState.locale.text(he: "הצעות", ru: "предложения", en: "offers"), systemImage: "text.bubble")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label(
                taskBudgetText(task.budget, locale: appState.locale),
                systemImage: task.budget == nil ? "quote.bubble" : "shekelsign.circle"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(task.budget == nil ? Brand.red : .secondary)
        }
        .padding(.vertical, 6)
    }

    private var statusTitle: String {
        switch task.status {
        case .open: appState.locale.text(he: "פתוחה", ru: "Открыта", en: "Open")
        case .proposalReceived: appState.locale.text(he: "יש הצעות", ru: "Есть предложения", en: "Offers received")
        case .inProgress: appState.locale.text(he: "בעבודה", ru: "В работе", en: "In progress")
        case .completed: appState.locale.text(he: "הושלמה", ru: "Завершена", en: "Completed")
        case .cancelled: appState.locale.text(he: "בוטלה", ru: "Отменена", en: "Cancelled")
        case .archived: appState.locale.text(he: "ארכיון", ru: "Архив", en: "Archived")
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .completed: .green
        case .cancelled, .archived: .secondary
        case .inProgress: .blue
        case .proposalReceived: .orange
        case .open: Brand.red
        }
    }
}

struct ClientTaskDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    let task: RepairTask
    @State private var currentTask: RepairTask
    @State private var isLoadingDetail = false
    @State private var isCancelling = false
    @State private var showCancelConfirmation = false
    @State private var showCompletionProblemConfirmation = false
    @State private var showReview = false
    @State private var showCompletionConfirmation = false
    @State private var isResolvingCompletion = false
    @State private var successFeedback = 0

    init(task: RepairTask) {
        self.task = task
        _currentTask = State(initialValue: task)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                headerCard
                requestInformationCard
                TaskLocationCard(
                    city: currentTask.city,
                    address: currentTask.address,
                    location: currentTask.location
                )

                if !currentTask.attachmentURLs.isEmpty {
                    TaskPhotoGallery(urls: currentTask.attachmentURLs)
                }

                if currentTask.acceptedSpecialist != nil {
                    acceptedSpecialistCard
                }
                if currentTask.completion != nil {
                    completionCard
                }
                offersCard
                if let conversation {
                    NavigationLink { ConversationView(conversation: conversation) } label: {
                        Label(
                            appState.locale.text(he: "פתיחת שיחה עם בעל המקצוע", ru: "Открыть чат с мастером", en: "Open specialist chat"),
                            systemImage: "bubble.left.and.bubble.right.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.red)
                }
                actionsCard
            }
            .padding()
        }
        .background(Brand.canvas)
        .overlay {
            if isCancelling || isResolvingCompletion {
                ZStack {
                    Color.black.opacity(0.08).ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: .rect(cornerRadius: 18))
                }
            }
        }
        .navigationTitle(appState.locale.text(he: "פרטי בקשה", ru: "Заявка", en: "Request"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoadingDetail || isCancelling)
                .accessibilityLabel(appState.locale.text(he: "רענון", ru: "Обновить", en: "Refresh"))
            }
        }
        .task(id: task.id) { await refresh() }
        .refreshable { await refresh() }
        .sensoryFeedback(.success, trigger: successFeedback)
        .confirmationDialog(
            appState.locale.text(
                he: "לבטל את הבקשה \(displayNumber)?",
                ru: "Отменить заявку \(displayNumber)?",
                en: "Cancel request \(displayNumber)?"
            ),
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.locale.text(he: "ביטול בקשה", ru: "Отменить заявку", en: "Cancel request"), role: .destructive) {
                Task { await cancelRequest() }
            }
            Button(appState.locale.text(he: "לא עכשיו", ru: "Не сейчас", en: "Not now"), role: .cancel) {}
        } message: {
            Text(appState.locale.text(
                he: "הבקשה תיסגר לבעלי מקצוע. לא ניתן לבטל את הפעולה.",
                ru: "Заявка закроется для мастеров. Это действие нельзя отменить.",
                en: "The request will close to specialists. This action cannot be undone."
            ))
        }
        .confirmationDialog(
            appState.locale.text(he: "יש בעיה עם סיום העבודה?", ru: "Есть проблема с завершением?", en: "Is there a completion problem?"),
            isPresented: $showCompletionProblemConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.locale.text(he: "החזרת העבודה לביצוע", ru: "Вернуть в работу", en: "Return to in progress"), role: .destructive) {
                Task { await resolveCompletion(confirm: false) }
            }
            Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(appState.locale.text(
                he: "הבקשה תחזור למצב 'בעבודה'. פרטי העסקה והראיות יישמרו.",
                ru: "Заявка вернётся в статус «В работе». История и материалы сохранятся.",
                en: "The request returns to In progress. Its history and evidence stay preserved."
            ))
        }
        .sheet(isPresented: $showReview) {
            ClientReviewSheet(taskID: currentTask.id)
        }
        .sheet(isPresented: $showCompletionConfirmation) {
            if let completion = currentTask.completion {
                ClientCompletionConfirmationSheet(taskID: currentTask.id, completion: completion) { updated in
                    currentTask = updated
                    successFeedback += 1
                    showReview = true
                }
            }
        }
    }

    private var category: ServiceCategory? {
        appState.serviceCatalog.first { $0.id == currentTask.categoryID }
    }

    private var displayNumber: String {
        if let orderNumber = currentTask.orderNumber { return "#\(orderNumber)" }
        return "#\(currentTask.id.prefix(8).uppercased())"
    }

    private var canCancel: Bool {
        currentTask.status == .open || currentTask.status == .proposalReceived
    }

    private var conversation: ProfessionalConversation? {
        appState.professionalConversations.first { $0.taskID == currentTask.id }
    }

    private var statusTitle: String {
        switch currentTask.status {
        case .open: appState.locale.text(he: "פתוחה", ru: "Открыта", en: "Open")
        case .proposalReceived: appState.locale.text(he: "יש הצעות", ru: "Есть предложения", en: "Offers received")
        case .inProgress: appState.locale.text(he: "בעבודה", ru: "В работе", en: "In progress")
        case .completed:
            if currentTask.completion?.isPendingClientConfirmation == true {
                appState.locale.text(he: "ממתינה לאישור", ru: "Ждёт подтверждения", en: "Awaiting confirmation")
            } else {
                appState.locale.text(he: "הושלמה", ru: "Завершена", en: "Completed")
            }
        case .cancelled: appState.locale.text(he: "בוטלה", ru: "Отменена", en: "Cancelled")
        case .archived: appState.locale.text(he: "ארכיון", ru: "В архиве", en: "Archived")
        }
    }

    private var statusColor: Color {
        switch currentTask.status {
        case .open: Brand.red
        case .proposalReceived: .orange
        case .inProgress: .blue
        case .completed: .green
        case .cancelled, .archived: .secondary
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: category?.systemImage ?? "wrench.and.screwdriver.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(category.map { Color(hex: $0.tintHex) } ?? Brand.red)
                    .frame(width: 52, height: 52)
                    .background((category.map { Color(hex: $0.tintHex) } ?? Brand.red).opacity(0.12), in: .rect(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayNumber)
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(currentTask.title)
                        .font(.title2.bold())
                        .foregroundStyle(Brand.ink)
                }
                Spacer(minLength: 4)
                StatusPill(title: statusTitle, color: statusColor)
            }

            if let description = currentTask.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Label(
                currentTask.createdAt.formatted(date: .abbreviated, time: .shortened),
                systemImage: "calendar"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .brandCard()
    }

    private var requestInformationCard: some View {
        VStack(spacing: 0) {
            TaskDetailInfoRow(
                systemImage: "mappin.and.ellipse",
                title: appState.locale.text(he: "מיקום", ru: "Место", en: "Location"),
                value: locationTitle
            )
            Divider().padding(.leading, 48)
            TaskDetailInfoRow(
                systemImage: "clock.fill",
                title: appState.locale.text(he: "מועד", ru: "Когда", en: "Timing"),
                value: timingTitle
            )
            Divider().padding(.leading, 48)
            TaskDetailInfoRow(
                systemImage: "shekelsign.circle.fill",
                title: appState.locale.text(he: "תקציב", ru: "Бюджет", en: "Budget"),
                value: taskBudgetText(currentTask.budget, locale: appState.locale)
            )
        }
        .padding(.horizontal, 16)
        .brandCard()
    }

    @ViewBuilder
    private var acceptedSpecialistCard: some View {
        if let specialist = currentTask.acceptedSpecialist {
            VStack(alignment: .leading, spacing: 14) {
                Label(appState.locale.text(he: "בעל המקצוע שנבחר", ru: "Назначенный специалист", en: "Assigned specialist"), systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                HStack(spacing: 12) {
                    ClientSpecialistAvatar(url: specialist.avatarURL, name: specialist.name, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(specialist.name).font(.headline)
                        Text(appState.locale.text(he: "העבודה הוקצתה", ru: "Работа назначена", en: "Job assigned"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let profile = appState.specialists.first(where: { $0.id == specialist.specialistID }) {
                        NavigationLink { SpecialistProfileView(specialist: profile) } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.title2)
                        }
                        .accessibilityLabel(appState.locale.text(he: "פרופיל", ru: "Профиль", en: "Profile"))
                    }
                }

                HStack(spacing: 10) {
                    if let phoneURL = contactURL(scheme: "tel", value: specialist.phone) {
                        Link(destination: phoneURL) {
                            Label(appState.locale.text(he: "שיחה", ru: "Позвонить", en: "Call"), systemImage: "phone.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.red)
                    }
                    if let whatsappURL = whatsappURL(specialist.whatsapp ?? specialist.phone) {
                        Link(destination: whatsappURL) {
                            Label("WhatsApp", systemImage: "message.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Brand.red)
                    }
                }
            }
            .padding(18)
            .brandCard()
        }
    }

    @ViewBuilder
    private var completionCard: some View {
        if let completion = currentTask.completion {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    completion.isPendingClientConfirmation
                        ? appState.locale.text(he: "בעל המקצוע דיווח על סיום", ru: "Мастер сообщил о завершении", en: "Specialist reported completion")
                        : appState.locale.text(he: "העבודה אושרה", ru: "Работа подтверждена", en: "Work confirmed"),
                    systemImage: completion.isPendingClientConfirmation ? "clock.badge.checkmark" : "checkmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(completion.isPendingClientConfirmation ? .orange : .green)

                HStack {
                    Text(appState.locale.text(he: "סכום סופי של בעל המקצוע", ru: "Итог мастера", en: "Specialist final amount"))
                    Spacer()
                    Text("₪\(completion.specialistFinalAmount.formatted())")
                        .font(.title3.bold())
                }

                if let note = completion.specialistNote {
                    Text(note).font(.subheadline).foregroundStyle(.secondary)
                }
                if let expense = completion.expenseAmount {
                    LabeledContent(
                        appState.locale.text(he: "חומרים והוצאות", ru: "Материалы и расходы", en: "Materials and expenses"),
                        value: "₪\(expense.formatted())"
                    )
                    .font(.subheadline)
                }
                if !completion.specialistPhotoURLs.isEmpty {
                    CompletionPhotoStrip(
                        title: appState.locale.text(he: "תמונות בעל המקצוע", ru: "Фото мастера", en: "Specialist photos"),
                        urls: completion.specialistPhotoURLs
                    )
                }
                if !completion.expenseReceiptURLs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.locale.text(he: "מסמכי הוצאה ששותפו", ru: "Документы по расходам", en: "Shared expense documents"))
                            .font(.subheadline.weight(.semibold))
                        ForEach(Array(completion.expenseReceiptURLs.enumerated()), id: \.offset) { index, url in
                            Link(destination: url) {
                                Label(
                                    appState.locale.text(he: "פתיחת מסמך \(index + 1)", ru: "Открыть документ \(index + 1)", en: "Open document \(index + 1)"),
                                    systemImage: "doc.text.fill"
                                )
                            }
                        }
                    }
                }
                if let clientPaid = completion.clientPaidAmount {
                    LabeledContent(
                        appState.locale.text(he: "התשלום שדווח על ידי הלקוח", ru: "Оплачено по данным клиента", en: "Client-reported payment"),
                        value: "₪\(clientPaid.formatted())"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                if !completion.clientPhotoURLs.isEmpty {
                    CompletionPhotoStrip(
                        title: appState.locale.text(he: "תמונות הלקוח", ru: "Фото клиента", en: "Client photos"),
                        urls: completion.clientPhotoURLs
                    )
                }

                if completion.isPendingClientConfirmation {
                    Text(appState.locale.text(
                        he: "אשרו רק לאחר שבדקתם את העבודה ואת הסכום.",
                        ru: "Подтвердите после проверки результата и суммы.",
                        en: "Confirm only after checking the result and amount."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Button { showCompletionConfirmation = true } label: {
                        Label(appState.locale.text(he: "אישור העבודה", ru: "Подтвердить работу", en: "Confirm work"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(role: .destructive) { showCompletionProblemConfirmation = true } label: {
                        Text(appState.locale.text(he: "יש בעיה", ru: "Есть проблема", en: "There is a problem"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button { showReview = true } label: {
                        Label(appState.locale.text(he: "כתיבת ביקורת מאומתת", ru: "Оставить проверенный отзыв", en: "Leave a verified review"), systemImage: "star.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.red)
                }
            }
            .padding(18)
            .brandCard()
        }
    }

    private var offersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                currentTask.proposalCount == 0
                    ? appState.locale.text(he: "ממתינים להצעות", ru: "Ждём предложения", en: "Waiting for offers")
                    : appState.locale.text(he: "הצעות מבעלי מקצוע", ru: "Предложения мастеров", en: "Specialist offers"),
                systemImage: currentTask.proposalCount == 0 ? "text.bubble" : "text.bubble.fill"
            )
            .font(.headline)
            .foregroundStyle(currentTask.proposalCount == 0 ? Color.secondary : Brand.red)

            if currentTask.proposals.isEmpty {
                Text(currentTask.proposalCount == 0
                    ? appState.locale.text(he: "נודיע לכם מיד כשבעל מקצוע יגיב.", ru: "Сообщим сразу, когда мастер откликнется.", en: "We’ll notify you as soon as a specialist responds.")
                    : appState.locale.text(he: "טוענים את פרטי ההצעות…", ru: "Загружаем детали предложений…", en: "Loading offer details…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(currentTask.proposals) { proposal in
                    if proposal.id != currentTask.proposals.first?.id { Divider() }
                    TaskProposalCard(proposal: proposal)
                }
            }
        }
        .padding(18)
        .brandCard()
    }

    private var actionsCard: some View {
        VStack(spacing: 11) {
            if canCancel {
                Button(role: .destructive) { showCancelConfirmation = true } label: {
                    Label(appState.locale.text(he: "ביטול בקשה", ru: "Отменить заявку", en: "Cancel request"), systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 15))
                .controlSize(.large)
                .tint(.red)
            }

            Button {
                appState.prepareSimilarRequest(from: currentTask)
            } label: {
                Label(appState.locale.text(he: "בקשה דומה", ru: "Создать похожую", en: "Create similar request"), systemImage: "doc.on.doc.fill")
            }
            .buttonStyle(BrandSecondaryButtonStyle())

            NavigationLink { SupportView() } label: {
                Label(appState.locale.text(he: "עזרה עם הבקשה", ru: "Помощь с заявкой", en: "Get help with this request"), systemImage: "questionmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 3)
        }
        .padding(16)
        .brandCard()
    }

    private var locationTitle: String {
        if let address = currentTask.address, !address.isEmpty {
            if currentTask.city.isEmpty || address.localizedCaseInsensitiveContains(currentTask.city) { return address }
            return "\(address), \(currentTask.city)"
        }
        return currentTask.city.isEmpty
            ? appState.locale.text(he: "לא צוין", ru: "Не указано", en: "Not specified")
            : currentTask.city
    }

    private var timingTitle: String {
        if let scheduledFor = currentTask.scheduledFor {
            return scheduledFor.formatted(date: .abbreviated, time: .shortened)
        }
        switch currentTask.whenNeeded {
        case "urgent": return appState.locale.text(he: "דחוף", ru: "Срочно", en: "Urgent")
        case "soon": return appState.locale.text(he: "בימים הקרובים", ru: "В ближайшие дни", en: "In the next few days")
        case "flexible": return appState.locale.text(he: "גמיש", ru: "Можно договориться", en: "Flexible")
        case let value?: return value
        case nil: return appState.locale.text(he: "גמיש", ru: "Можно договориться", en: "Flexible")
        }
    }

    @MainActor
    private func refresh() async {
        guard !isLoadingDetail else { return }
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        async let conversations: Void = appState.loadProfessionalConversations()
        if let loaded = await appState.loadTask(id: task.id) {
            currentTask = loaded
        }
        _ = await conversations
    }

    @MainActor
    private func cancelRequest() async {
        guard !isCancelling else { return }
        isCancelling = true
        defer { isCancelling = false }
        if let cancelled = await appState.cancelTask(id: currentTask.id) {
            withAnimation(.snappy) { currentTask = cancelled }
            successFeedback += 1
        }
    }

    @MainActor
    private func resolveCompletion(confirm: Bool) async {
        guard let completion = currentTask.completion, completion.isPendingClientConfirmation else { return }
        isResolvingCompletion = true
        defer { isResolvingCompletion = false }
        if let updated = await appState.resolveTaskCompletion(
            id: currentTask.id,
            requestedAt: completion.requestedAt,
            confirm: confirm
        ) {
            withAnimation(.snappy) { currentTask = updated }
            successFeedback += 1
            if confirm { showReview = true }
        }
    }

    private func contactURL(scheme: String, value: String?) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        let allowed = value.filter { $0.isNumber || $0 == "+" }
        return URL(string: "\(scheme)://\(allowed)")
    }

    private func whatsappURL(_ value: String?) -> URL? {
        guard let value else { return nil }
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "https://wa.me/\(digits)")
    }
}

private struct ClientSpecialistAvatar: View {
    let url: URL?
    let name: String
    let size: CGFloat

    var body: some View {
        OfflineImage(url: url) { phase in
            if case let .success(image) = phase {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Brand.red.opacity(0.12)
                    Text(String(name.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(Brand.red)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
    }
}

private struct TaskProposalCard: View {
    @Environment(AppState.self) private var appState
    let proposal: TaskProposal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ClientSpecialistAvatar(url: proposal.specialistAvatarURL, name: proposal.specialistName, size: 48)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(proposal.specialistName).font(.headline)
                    if proposal.trust.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .accessibilityLabel(appState.locale.text(he: "מאומת", ru: "Проверен", en: "Verified"))
                    }
                    Spacer()
                    Text(proposal.price.map { "₪\($0.formatted())" }
                        ?? appState.locale.text(he: "מחיר לאחר בירור", ru: "Цена после уточнения", en: "Price after discussion"))
                        .font(.subheadline.bold())
                        .foregroundStyle(Brand.red)
                }
                if let rating = proposal.rating {
                    Label(
                        String(format: "%.1f · %d", rating, proposal.reviewCount ?? 0),
                        systemImage: "star.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                if let message = proposal.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                trustSummary
                if let specialist = appState.specialists.first(where: { $0.id == proposal.specialistID }) {
                    NavigationLink { SpecialistProfileView(specialist: specialist) } label: {
                        Label(appState.locale.text(he: "צפייה בפרופיל", ru: "Открыть профиль", en: "View profile"), systemImage: "person.crop.circle")
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var trustSummary: some View {
        let trust = proposal.trust
        let labels: [String] = [
            trust.phoneVerified ? appState.locale.text(he: "טלפון", ru: "Телефон", en: "Phone") : nil,
            trust.portfolioVerified ? appState.locale.text(he: "תיק עבודות", ru: "Портфолио", en: "Portfolio") : nil,
            trust.licenseVerified ? appState.locale.text(he: "רישיון", ru: "Лицензия", en: "License") : nil,
            trust.insuranceVerified ? appState.locale.text(he: "ביטוח", ru: "Страховка", en: "Insurance") : nil,
        ].compactMap { $0 }
        if !labels.isEmpty {
            Text(labels.map { "✓ \($0)" }.joined(separator: "  "))
                .font(.caption2)
                .foregroundStyle(.green)
        }
    }
}

private struct CompletionPhotoItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct CompletionPhotoStrip: View {
    let title: String
    let urls: [URL]
    @State private var selected: CompletionPhotoItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "photo.stack.fill")
                .font(.caption.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 9) {
                    ForEach(urls, id: \.absoluteString) { url in
                        Button { selected = CompletionPhotoItem(url: url) } label: {
                            OfflineImage(url: url) { phase in
                                if case let .success(image) = phase {
                                    image.resizable().scaledToFill()
                                } else {
                                    ProgressView()
                                }
                            }
                            .frame(width: 112, height: 84)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .fullScreenCover(item: $selected) { item in
            NavigationStack {
                ZoomablePortfolioPhoto(url: item.url)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selected = nil }
                        }
                    }
            }
        }
    }
}

private struct ClientCompletionConfirmationSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let taskID: String
    let completion: TaskCompletion
    let onConfirmed: (RepairTask) -> Void
    @State private var paidAmount: String
    @State private var note = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var isSubmitting = false

    init(taskID: String, completion: TaskCompletion, onConfirmed: @escaping (RepairTask) -> Void) {
        self.taskID = taskID
        self.completion = completion
        self.onConfirmed = onConfirmed
        _paidAmount = State(initialValue: String(completion.specialistFinalAmount))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(appState.locale.text(he: "סכום סופי של בעל המקצוע", ru: "Итог мастера", en: "Specialist final amount")) {
                    Text("₪\(completion.specialistFinalAmount.formatted())")
                        .font(.title3.bold())
                }
                Section(appState.locale.text(he: "כמה שילמתם בפועל?", ru: "Сколько вы заплатили?", en: "How much did you pay?")) {
                    TextField("₪", text: $paidAmount).keyboardType(.numberPad)
                }
                Section(appState.locale.text(he: "הערה", ru: "Комментарий", en: "Note")) {
                    TextField(
                        appState.locale.text(he: "אופציונלי", ru: "Необязательно", en: "Optional"),
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
                Section(appState.locale.text(he: "תמונות התוצאה שלכם", ru: "Ваши фото результата", en: "Your result photos")) {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 6, matching: .images) {
                        Label(photoPickerTitle, systemImage: "photo.badge.plus")
                    }
                    Text(appState.locale.text(
                        he: "פרטי כברירת מחדל. שום תמונה לא תפורסם ללא הסכמה נפרדת.",
                        ru: "По умолчанию приватно. Фото не публикуются без отдельного согласия.",
                        en: "Private by default. Nothing is published without separate consent."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(appState.locale.text(he: "אישור העבודה", ru: "Подтверждение работы", en: "Confirm work"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel")) { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.locale.text(he: "אישור", ru: "Подтвердить", en: "Confirm")) {
                        Task { await submit() }
                    }
                    .disabled(validPaidAmount == nil || isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .onChange(of: selectedPhotos) { _, items in
                Task { photoData = await normalizedPhotoData(items) }
            }
        }
    }

    private var validPaidAmount: Int? {
        guard let value = Int(paidAmount), (0...10_000_000).contains(value) else { return nil }
        return value
    }

    private var photoPickerTitle: String {
        photoData.isEmpty
            ? appState.locale.text(he: "הוספת תמונות", ru: "Добавить фото", en: "Add photos")
            : appState.locale.text(he: "נבחרו \(photoData.count)", ru: "Выбрано: \(photoData.count)", en: "Selected: \(photoData.count)")
    }

    @MainActor
    private func submit() async {
        guard let paid = validPaidAmount else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        if let updated = await appState.resolveTaskCompletion(
            id: taskID,
            requestedAt: completion.requestedAt,
            confirm: true,
            clientPaidAmount: paid,
            clientNote: note,
            photoData: photoData
        ) {
            onConfirmed(updated)
            dismiss()
        }
    }

    private func normalizedPhotoData(_ items: [PhotosPickerItem]) async -> [Data] {
        var result: [Data] = []
        for item in items.prefix(6) {
            guard let original = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: original) else { continue }
            let maxDimension: CGFloat = 2_000
            let largest = max(image.size.width, image.size.height)
            let scale = largest > maxDimension ? maxDimension / largest : 1
            let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
            let data = UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.82) { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            result.append(data)
        }
        return result
    }
}

private struct ClientReviewSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let taskID: String
    @State private var rating = 5
    @State private var text = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section(appState.locale.text(he: "דירוג", ru: "Оценка", en: "Rating")) {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { value in
                            Button { rating = value } label: {
                                Image(systemName: value <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .contain)
                }
                Section(appState.locale.text(he: "החוויה שלכם", ru: "Ваш отзыв", en: "Your review")) {
                    TextField(
                        appState.locale.text(he: "מה היה טוב?", ru: "Расскажите о результате", en: "Tell others about the result"),
                        text: $text,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                }
                Section {
                    Text(appState.locale.text(
                        he: "הביקורת מסומנת כמאומתת כי היא קשורה לעבודה שהושלמה ואושרה.",
                        ru: "Отзыв будет отмечен как проверенный: он связан с подтверждённой работой.",
                        en: "This review is verified because it belongs to a confirmed completed job."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(appState.locale.text(he: "ביקורת", ru: "Отзыв", en: "Review"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.locale.text(he: "שליחה", ru: "Отправить", en: "Send")) {
                        Task {
                            isSubmitting = true
                            if await appState.submitClientReview(taskID: taskID, rating: rating, text: text) {
                                dismiss()
                            }
                            isSubmitting = false
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }
}

private struct TaskDetailInfoRow: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.red)
                .frame(width: 34, height: 34)
                .background(Brand.softRed, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body.weight(.medium)).foregroundStyle(Brand.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }
}
