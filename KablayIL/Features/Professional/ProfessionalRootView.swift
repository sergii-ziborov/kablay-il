import SwiftUI
import UIKit
import PhotosUI
import StoreKit
import UniformTypeIdentifiers

struct ProfessionalRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            Tab(appState.locale.text(he: "הזמנות", ru: "Заказы", en: "Jobs"), systemImage: "tray.full.fill") {
                NavigationStack { AvailableLeadsView() }
            }
            Tab(appState.locale.text(he: "המשימות שלי", ru: "Мои задачи", en: "My work"), systemImage: "archivebox.fill") {
                NavigationStack { ProfessionalTasksView() }
            }
            Tab(appState.locale.text(he: "צ׳אטים", ru: "Чаты", en: "Chats"), systemImage: "bubble.left.and.bubble.right.fill") {
                NavigationStack { ProfessionalChatsView() }
            }
            Tab(appState.locale.text(he: "פרופיל", ru: "Анкета", en: "Profile"), systemImage: "person.crop.circle.fill") {
                NavigationStack { ProfessionalProfileHubView() }
            }
            .badge(appState.unreadCount)
        }
    }
}

struct ProfessionalNotificationDestinationView: View {
    @Environment(AppState.self) private var appState
    let destination: NotificationDestination
    @State private var task: RepairTask?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let conversation = conversation {
                ConversationView(conversation: conversation)
            } else if let proposal = proposal {
                ProfessionalTaskDetailView(proposal: proposal)
            } else if let task {
                ProfessionalLeadDetailView(lead: ProfessionalLead(
                    id: task.id,
                    title: task.title,
                    categoryID: task.categoryID,
                    city: task.city,
                    clientName: task.client?.name,
                    createdAt: task.createdAt,
                    description: task.description ?? "",
                    budget: task.budget,
                    urgent: task.whenNeeded == "urgent",
                    attachmentURLs: task.attachmentURLs,
                    location: task.location
                ))
            } else if didLoad {
                ContentUnavailableView(
                    appState.locale.text(he: "העדכון אינו זמין", ru: "Обновление недоступно", en: "Update unavailable"),
                    systemImage: "bell.slash"
                )
            } else {
                ProgressView()
            }
        }
        .task(id: destination.id) {
            async let proposals: Void = appState.loadProfessionalProposals(force: true)
            async let conversations: Void = appState.loadProfessionalConversations(force: true)
            task = await appState.loadTask(id: destination.taskID)
            _ = await (proposals, conversations)
            didLoad = true
        }
    }

    private var conversation: ProfessionalConversation? {
        guard let id = destination.conversationID else { return nil }
        return appState.professionalConversations.first { $0.id == id }
    }

    private var proposal: ProfessionalProposal? {
        appState.professionalProposals.first { $0.taskID == destination.taskID }
    }
}

struct AvailableLeadsView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var filter = LeadFilter.all

    private enum LeadFilter: String, CaseIterable, Identifiable {
        case all, today, urgent
        var id: String { rawValue }
    }

    private var leads: [ProfessionalLead] {
        let submittedTaskIDs = Set(appState.professionalProposals.map(\.taskID))
        return appState.professionalLeads.filter { lead in
            let matchesQuery = query.isEmpty
                || lead.title.localizedCaseInsensitiveContains(query)
                || lead.city.localizedCaseInsensitiveContains(query)
                || lead.description.localizedCaseInsensitiveContains(query)
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .today: matchesFilter = Calendar.current.isDateInToday(lead.createdAt)
            case .urgent: matchesFilter = lead.urgent
            }
            return matchesQuery && matchesFilter && !submittedTaskIDs.contains(lead.id)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $filter) {
                Text(appState.locale.text(he: "הכל", ru: "Все", en: "All")).tag(LeadFilter.all)
                Text(appState.locale.text(he: "היום", ru: "Сегодня", en: "Today")).tag(LeadFilter.today)
                Text(appState.locale.text(he: "דחוף", ru: "Срочные", en: "Urgent")).tag(LeadFilter.urgent)
            }
            .pickerStyle(.segmented)
            .padding()

            OfflineFreshnessLabel(
                updatedAt: appState.professionalLeadsUpdatedAt,
                isSavedCopy: appState.professionalLeadsShowingSavedCopy,
                staleAfter: OfflineFreshness.availableJobs,
                locale: appState.locale
            )
            .padding(.horizontal)

            if appState.isLoadingProfessionalLeads, appState.professionalLeads.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if appState.professionalLoadFailed, appState.professionalLeads.isEmpty {
                // A failed request must never be shown as an empty marketplace:
                // the reason and a retry belong on screen.
                ContentUnavailableView {
                    Label(
                        appState.locale.text(he: "לא ניתן לטעון הזמנות", ru: "Не удалось загрузить заказы", en: "Couldn’t load jobs"),
                        systemImage: "wifi.exclamationmark"
                    )
                } description: {
                    Text(appState.professionalLoadErrorMessage ?? appState.locale.text(
                        he: "בדקו את החיבור ונסו שוב.",
                        ru: "Проверьте соединение и попробуйте ещё раз.",
                        en: "Check the connection and try again."
                    ))
                } actions: {
                    Button(appState.locale.text(he: "ניסיון נוסף", ru: "Повторить", en: "Try again")) {
                        Task { await reload(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.red)
                }
            } else if leads.isEmpty {
                ContentUnavailableView(
                    appState.locale.text(he: "אין הזמנות זמינות", ru: "Нет доступных заказов", en: "No available jobs"),
                    systemImage: "tray",
                    description: Text(appState.locale.text(
                        he: "הזמנות אמיתיות מהשרת יופיעו כאן.",
                        ru: "Здесь появятся реальные заявки с сервера.",
                        en: "Real requests from the server will appear here."
                    ))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(leads) { lead in
                            NavigationLink { ProfessionalLeadDetailView(lead: lead) } label: { LeadCard(lead: lead) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Brand.canvas)
        .searchable(text: $query, prompt: appState.locale.text(he: "חיפוש הזמנות", ru: "Поиск заказов", en: "Search jobs"))
        .navigationTitle(appState.locale.text(he: "הזמנות", ru: "Заказы", en: "Jobs"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { WorkspaceNavigationToolbar() }
        .task { await reload(force: false) }
        .refreshable { await reload(force: true) }
    }

    private func reload(force: Bool) async {
        await appState.loadProfessionalProfile(force: force)
        async let leads: Void = appState.loadProfessionalLeads(force: force)
        async let proposals: Void = appState.loadProfessionalProposals(force: force)
        _ = await (leads, proposals)
    }
}

private struct LeadCard: View {
    @Environment(AppState.self) private var appState
    let lead: ProfessionalLead

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(lead.title).font(.headline).foregroundStyle(Brand.ink)
                    Text(categoryTitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if lead.urgent {
                    StatusPill(title: appState.locale.text(he: "דחוף", ru: "Срочно", en: "Urgent"), color: .orange)
                }
            }
            if !lead.description.isEmpty {
                Text(lead.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            }
            HStack(spacing: 7) {
                if !lead.city.isEmpty {
                    Label(
                        IsraelCityCatalog.localizedName(for: lead.city, locale: appState.locale),
                        systemImage: "mappin.and.ellipse"
                    )
                }
                Spacer()
                Text(relativeDate(lead.createdAt)).foregroundStyle(.tertiary)
            }
            .font(.caption).foregroundStyle(.secondary)
            Label(
                taskBudgetText(lead.budget, locale: appState.locale),
                systemImage: lead.budget == nil ? "text.bubble.fill" : "banknote.fill"
            )
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(lead.budget == nil ? Brand.red : .green)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).brandCard()
    }

    private var categoryTitle: String {
        appState.serviceCatalog.first { $0.id == lead.categoryID }?.title.value(for: appState.locale) ?? lead.categoryID
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = appState.locale.locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct ProfessionalLeadDetailView: View {
    @Environment(AppState.self) private var appState
    let lead: ProfessionalLead
    @State private var translatedTitle: String?
    @State private var translatedDescription: String?
    @State private var showsTranslation = true
    @State private var isTranslating = false
    @State private var detailedTask: RepairTask?
    @State private var detailUnavailable = false
    @State private var showsProposalComposer = false
    @State private var hasSubmittedProposal = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(displayedTitle).font(.title2).fontWeight(.bold)
                        Spacer()
                        if lead.urgent { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                    }
                    if !displayedDescription.isEmpty { Text(displayedDescription).foregroundStyle(.secondary) }

                    if needsTranslation || translatedTitle != nil {
                        Button { Task { await toggleTranslation() } } label: {
                            if isTranslating {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Label(
                                    translatedTitle == nil
                                        ? appState.locale.text(he: "תרגום", ru: "Перевести", en: "Translate")
                                        : showsTranslation
                                            ? appState.locale.text(he: "הצגת המקור", ru: "Показать оригинал", en: "Show original")
                                            : appState.locale.text(he: "הצגת תרגום", ru: "Показать перевод", en: "Show translation"),
                                    systemImage: "character.bubble.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.red)
                        .disabled(isTranslating)
                    }
                }
                .padding(18)
                .brandCard()

                VStack(spacing: 13) {
                    if !lead.city.isEmpty {
                        LabeledContent(
                            appState.locale.text(he: "עיר", ru: "Город", en: "City"),
                            value: IsraelCityCatalog.localizedName(for: lead.city, locale: appState.locale)
                        )
                    }
                    LabeledContent(
                        appState.locale.text(he: "תקציב הלקוח", ru: "Бюджет клиента", en: "Client budget"),
                        value: taskBudgetText(detailedTask?.budget ?? lead.budget, locale: appState.locale)
                    )
                }
                .padding(16)
                .brandCard()

                TaskPhotoGallery(urls: attachmentURLs, showsEmptyState: true)

                TaskLocationCard(
                    city: lead.city,
                    address: detailedTask?.address,
                    location: detailedTask?.location ?? lead.location
                )

                TaskIdentifierCard(identifier: lead.id)

                Label(
                    appState.locale.text(
                        he: "הכתובת והקשר המדויקים נשארים מוגנים עד לפתיחת הבקשה לפי כללי KABLAY.",
                        ru: "Точный адрес и контакт защищены до открытия заявки по правилам KABLAY.",
                        en: "The exact address and contact remain protected until the request is unlocked under KABLAY rules."
                    ),
                    systemImage: "lock.shield.fill"
                )
                .font(.footnote).foregroundStyle(.secondary)
                .padding(16)
                .brandCard()
            }
            .padding()
        }
        .background(Brand.canvas)
        .navigationTitle(appState.locale.text(he: "פרטי הזמנה", ru: "Детали заказа", en: "Job details"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: lead.id) { await loadDetail() }
        .refreshable { await loadDetail() }
        .safeAreaInset(edge: .bottom) {
            ProfessionalProposalActionBar(
                state: detailedTask?.responseState,
                hasSubmitted: hasSubmittedProposal,
                detailUnavailable: detailUnavailable
            ) {
                showsProposalComposer = true
            }
        }
        .sheet(isPresented: $showsProposalComposer) {
            ProposalComposerSheet(
                taskID: lead.id,
                taskTitle: displayedTitle,
                responseState: detailedTask?.responseState
            ) {
                hasSubmittedProposal = true
            }
        }
    }

    /// The response bar must never wait forever on the task details. When they
    /// do not arrive, the offer stays reachable and the server keeps deciding
    /// whether it is allowed.
    private func loadDetail() async {
        detailUnavailable = false
        let loaded = await appState.loadTask(id: lead.id)
        detailedTask = loaded
        detailUnavailable = loaded == nil
    }

    private var attachmentURLs: [URL] {
        var seen = Set<String>()
        return (lead.attachmentURLs + (detailedTask?.attachmentURLs ?? [])).filter {
            seen.insert($0.absoluteString).inserted
        }
    }

    private var needsTranslation: Bool {
        guard let detected = AppLocale.detected(in: "\(lead.title) \(lead.description)") else { return false }
        return detected != appState.locale
    }

    private var displayedTitle: String {
        showsTranslation ? (translatedTitle ?? lead.title) : lead.title
    }

    private var displayedDescription: String {
        showsTranslation ? (translatedDescription ?? lead.description) : lead.description
    }

    @MainActor
    private func toggleTranslation() async {
        if translatedTitle != nil {
            withAnimation(.snappy) { showsTranslation.toggle() }
            return
        }
        isTranslating = true
        defer { isTranslating = false }
        var values = [lead.title]
        if !lead.description.isEmpty { values.append(lead.description) }
        guard let result = await appState.translateTexts(values), result.translations.count == values.count else { return }
        withAnimation(.snappy) {
            translatedTitle = result.translations[0]
            translatedDescription = result.translations.count > 1 ? result.translations[1] : nil
            showsTranslation = true
        }
    }
}

private struct ProfessionalProposalActionBar: View {
    @Environment(AppState.self) private var appState
    let state: TaskResponseState?
    let hasSubmitted: Bool
    var detailUnavailable = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if state?.needsVerification == true { verificationNotice }
            Button(action: action) {
                Group {
                    if state == nil, !detailUnavailable {
                        ProgressView()
                    } else {
                        Label(buttonTitle, systemImage: buttonSystemImage)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Brand.red)
            .disabled(!canSubmit)
            .accessibilityIdentifier("professional.task.respond")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    /// An unverified profile reads the whole marketplace but cannot take work.
    /// Saying only "unavailable" would leave the specialist stuck, so the bar
    /// carries the administrator's contact.
    @ViewBuilder private var verificationNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                appState.locale.text(
                    he: "הפרופיל עדיין לא אומת. לאימות פנו למנהל KABLAY.",
                    ru: "Профиль ещё не подтверждён. Для подтверждения обратитесь к администратору KABLAY.",
                    en: "The profile is not verified yet. Contact the KABLAY administrator to get verified."
                ),
                systemImage: "checkmark.shield"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                if let phone = state?.verificationContact?.phoneE164,
                   let url = URL(string: "tel:\(phone)") {
                    Link(destination: url) {
                        Label(
                            (state?.verificationContact?.phoneDisplay ?? phone).ltrIsolated,
                            systemImage: "phone.fill"
                        )
                    }
                }
                if let whatsapp = state?.verificationContact?.whatsappURL {
                    Link(destination: whatsapp) {
                        Label("WhatsApp", systemImage: "message.fill")
                    }
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Brand.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canSubmit: Bool {
        guard !hasSubmitted else { return false }
        // Without the task details the app cannot know the price or the
        // cooldown, but the server validates every offer anyway, so the
        // specialist keeps a working button instead of a stuck spinner.
        guard let state else { return detailUnavailable }
        return state.available
    }

    private var buttonSystemImage: String {
        hasSubmitted || state?.alreadySubmitted == true ? "checkmark.circle.fill" : "paperplane.fill"
    }

    private var buttonTitle: String {
        if hasSubmitted || state?.alreadySubmitted == true {
            return appState.locale.text(he: "ההצעה נשלחה", ru: "Отклик отправлен", en: "Proposal sent")
        }
        guard let state else {
            return detailUnavailable
                ? appState.locale.text(he: "שליחת הצעה", ru: "Откликнуться", en: "Respond")
                : appState.locale.text(he: "טוען…", ru: "Загрузка…", en: "Loading…")
        }
        guard state.available else {
            switch state.blockedReason {
            case "PROFILE_NOT_VERIFIED":
                return appState.locale.text(he: "הפרופיל לא אומת", ru: "Профиль не подтверждён", en: "Profile not verified")
            case "TASK_CLOSED":
                return appState.locale.text(he: "הבקשה נסגרה", ru: "Заявка закрыта", en: "Request closed")
            default:
                return appState.locale.text(he: "לא ניתן לשלוח הצעה", ru: "Отклик недоступен", en: "Response unavailable")
            }
        }
        if let cost = state.costCredits, cost > 0 {
            return appState.locale.text(
                he: "שליחת הצעה · \(cost) נקודות",
                ru: "Откликнуться · \(cost) баллов",
                en: "Respond · \(cost) credits"
            )
        }
        return appState.locale.text(he: "שליחת הצעה", ru: "Откликнуться", en: "Respond")
    }
}

private struct ProposalComposerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let taskID: String
    let taskTitle: String
    let responseState: TaskResponseState?
    let onSubmitted: () -> Void

    @State private var message = ""
    @State private var price = ""
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case message, price }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(taskTitle)
                        .font(.headline)
                }

                Section {
                    TextField(
                        appState.locale.text(
                            he: "כתבו בקצרה כיצד תוכלו לעזור",
                            ru: "Коротко напишите, как вы можете помочь",
                            en: "Briefly explain how you can help"
                        ),
                        text: $message,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                    .focused($focusedField, equals: .message)
                } header: {
                    Text(appState.locale.text(he: "הודעה ללקוח", ru: "Сообщение клиенту", en: "Message to client"))
                } footer: {
                    Text(appState.locale.text(
                        he: "אין לציין טלפון, אימייל או WhatsApp לפני קבלת ההצעה.",
                        ru: "Не указывайте телефон, email или WhatsApp до принятия отклика.",
                        en: "Do not include phone, email, or WhatsApp details before acceptance."
                    ))
                }

                Section {
                    TextField(
                        appState.locale.text(he: "לא חובה, ₪", ru: "Необязательно, ₪", en: "Optional, ₪"),
                        text: $price
                    )
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .price)
                } header: {
                    Text(appState.locale.text(he: "מחיר מוצע", ru: "Предлагаемая цена", en: "Offered price"))
                } footer: {
                    Text(priceFooter)
                }
            }
            .navigationTitle(appState.locale.text(he: "שליחת הצעה", ru: "Отклик", en: "Proposal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await submit() } } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || !isPriceValid)
                    .accessibilityLabel(appState.locale.text(he: "שליחה", ru: "Отправить", en: "Send"))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        Label(
                            appState.locale.text(he: "סיום", ru: "Готово", en: "Done"),
                            systemImage: "keyboard.chevron.compact.down"
                        )
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var parsedPrice: Int? {
        let value = price.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : Int(value)
    }

    private var isPriceValid: Bool {
        price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (parsedPrice ?? 0) > 0
    }

    private var priceFooter: String {
        if let cost = responseState?.costCredits, cost > 0 {
            return appState.locale.text(
                he: "שליחת ההצעה תפתח את פרטי הלקוח ותחייב \(cost) נקודות.",
                ru: "Отклик откроет контакт клиента и спишет \(cost) баллов.",
                en: "Responding unlocks the client contact and uses \(cost) credits."
            )
        }
        if responseState?.viewerPremium == true {
            return appState.locale.text(
                he: "פתיחת פרטי הלקוח כלולה ב-Premium.",
                ru: "Открытие контакта клиента включено в Premium.",
                en: "Client contact unlock is included with Premium."
            )
        }
        return appState.locale.text(
            he: "המחיר אינו חובה וניתן לסיכום מאוחר יותר.",
            ru: "Цену можно не указывать и согласовать позже.",
            en: "The price is optional and can be agreed later."
        )
    }

    @MainActor
    private func submit() async {
        guard isPriceValid else { return }
        focusedField = nil
        isSubmitting = true
        defer { isSubmitting = false }
        let submitted = await appState.submitProposal(
            taskID: taskID,
            message: message,
            price: parsedPrice
        )
        if submitted {
            onSubmitted()
            dismiss()
        }
    }
}

private struct TaskIdentifierCard: View {
    @Environment(AppState.self) private var appState
    let identifier: String
    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 12) {
            Text("ID")
                .font(.subheadline.weight(.semibold))

            Text(identifier.ltrIsolated)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("professional.task.identifier")

            Button { copyIdentifier() } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(didCopy ? .green : Brand.red)
            .accessibilityLabel(
                didCopy
                    ? appState.locale.text(he: "הועתק", ru: "Скопировано", en: "Copied")
                    : appState.locale.text(he: "העתקת מספר הבקשה", ru: "Скопировать ID заявки", en: "Copy request ID")
            )
            .accessibilityIdentifier("professional.task.copyIdentifier")
        }
        .padding(16)
        .brandCard()
        .sensoryFeedback(.success, trigger: didCopy)
    }

    private func copyIdentifier() {
        UIPasteboard.general.string = identifier
        withAnimation(.snappy) { didCopy = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.snappy) { didCopy = false }
        }
    }
}

struct ProfessionalTasksView: View {
    @Environment(AppState.self) private var appState
    @State private var filter = ProposalFilter.active

    private enum ProposalFilter: String, CaseIterable, Identifiable {
        case active, completed, cancelled, archived
        var id: String { rawValue }
    }

    private var proposals: [ProfessionalProposal] {
        appState.professionalProposals.filter { proposal in
            let isArchived = appState.archivedProfessionalProposalIDs.contains(proposal.id)
            switch filter {
            case .active:
                return !isArchived
                    && ["pending", "accepted"].contains(proposal.status)
                    && ["open", "in_progress"].contains(proposal.taskStatus)
            case .completed:
                return !isArchived && ["done", "completed"].contains(proposal.taskStatus)
            case .cancelled:
                return !isArchived && (proposal.status == "rejected" || proposal.taskStatus == "cancelled")
            case .archived:
                return isArchived
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Status", selection: $filter) {
                Text(appState.locale.text(he: "פעילות", ru: "Активные", en: "Active")).tag(ProposalFilter.active)
                Text(appState.locale.text(he: "הושלמו", ru: "Готовые", en: "Done")).tag(ProposalFilter.completed)
                Text(appState.locale.text(he: "בוטלו", ru: "Отменены", en: "Cancelled")).tag(ProposalFilter.cancelled)
                Text(appState.locale.text(he: "ארכיון", ru: "Архив", en: "Archive")).tag(ProposalFilter.archived)
            }
            .pickerStyle(.segmented).padding()

            OfflineFreshnessLabel(
                updatedAt: appState.professionalProposalsUpdatedAt,
                isSavedCopy: appState.professionalProposalsShowingSavedCopy,
                staleAfter: OfflineFreshness.personalTasks,
                locale: appState.locale
            )
            .padding(.horizontal)

            if appState.isLoadingProfessionalProposals, appState.professionalProposals.isEmpty {
                Spacer(); ProgressView(); Spacer()
            } else if proposals.isEmpty {
                ContentUnavailableView(
                    appState.locale.text(he: "אין משימות", ru: "Задач пока нет", en: "No work yet"),
                    systemImage: "archivebox",
                    description: Text(appState.locale.text(he: "ההצעות והמשימות האמיתיות שלך יופיעו כאן.", ru: "Здесь появятся ваши реальные отклики и задачи.", en: "Your real proposals and jobs will appear here."))
                )
            } else {
                List(proposals) { proposal in
                    NavigationLink { ProfessionalTaskDetailView(proposal: proposal) } label: { proposalRow(proposal) }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(appState.locale.text(he: "המשימות שלי", ru: "Мои задачи", en: "My work"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { WorkspaceNavigationToolbar() }
        .task { await appState.loadProfessionalProposals() }
        .refreshable { await appState.loadProfessionalProposals(force: true) }
    }

    private func proposalRow(_ proposal: ProfessionalProposal) -> some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: proposal.taskTitle, size: 46)
            VStack(alignment: .leading, spacing: 7) {
                Text(proposal.taskTitle).font(.headline)
                HStack {
                    StatusPill(title: statusTitle(proposal.status), color: statusColor(proposal.status))
                    if let price = proposal.price { Text("₪\(price)").font(.subheadline.weight(.semibold)) }
                }
            }
        }
        .padding(.vertical, 5)
    }

    private func statusTitle(_ status: String) -> String {
        switch status {
        case "accepted": appState.locale.text(he: "התקבלה", ru: "Принято", en: "Accepted")
        case "rejected": appState.locale.text(he: "נדחתה", ru: "Отклонено", en: "Rejected")
        default: appState.locale.text(he: "ממתינה", ru: "Ожидает", en: "Pending")
        }
    }

    private func statusColor(_ status: String) -> Color {
        status == "accepted" ? .green : (status == "rejected" ? .secondary : .orange)
    }
}

private struct ProfessionalTaskDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let proposal: ProfessionalProposal
    @State private var task: RepairTask?
    @State private var translatedTitle: String?
    @State private var translatedDescription: String?
    @State private var showsTranslation = true
    @State private var isTranslating = false
    @State private var pendingConfirmation: LifecycleConfirmation?
    @State private var showsCompletionSheet = false
    @State private var showsReportSheet = false
    @State private var showsBlockConfirmation = false

    private enum LifecycleConfirmation {
        case start, cancelResponse, archive
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 13) {
                    InitialsAvatar(name: proposal.taskTitle, size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayedTitle).font(.title3).fontWeight(.bold)
                        Text(proposal.createdAt, style: .date).foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .brandCard()

                if let description = displayedDescription, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .brandCard()
                }

                if needsTranslation || translatedTitle != nil {
                    Button { Task { await toggleTranslation() } } label: {
                        if isTranslating {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label(
                                translatedTitle == nil
                                    ? appState.locale.text(he: "תרגום", ru: "Перевести", en: "Translate")
                                    : showsTranslation
                                        ? appState.locale.text(he: "הצגת המקור", ru: "Показать оригинал", en: "Show original")
                                        : appState.locale.text(he: "הצגת תרגום", ru: "Показать перевод", en: "Show translation"),
                                systemImage: "character.bubble.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.red)
                    .disabled(isTranslating)
                }

                VStack(spacing: 13) {
                    LabeledContent(appState.locale.text(he: "סטטוס הצעה", ru: "Статус отклика", en: "Proposal status"), value: localizedProposalStatus)
                    LabeledContent(appState.locale.text(he: "סטטוס משימה", ru: "Статус заявки", en: "Task status"), value: localizedTaskStatus)
                    if let task {
                        LabeledContent(
                            appState.locale.text(he: "תקציב הלקוח", ru: "Бюджет клиента", en: "Client budget"),
                            value: taskBudgetText(task.budget, locale: appState.locale)
                        )
                    }
                    if let price = currentProposal.price { LabeledContent(appState.locale.text(he: "מחיר", ru: "Цена", en: "Price"), value: "₪\(price)") }
                    if let message = currentProposal.message { LabeledContent(appState.locale.text(he: "הודעה", ru: "Сообщение", en: "Message"), value: message) }
                }
                .padding(16)
                .brandCard()

                if let task {
                    if let client = task.client {
                        ProfessionalClientContactCard(client: client)
                    }
                    TaskPhotoGallery(urls: task.attachmentURLs, showsEmptyState: true)
                    if let completion = task.completion, !completion.expenseReceiptURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(appState.locale.text(he: "מסמכי הוצאה", ru: "Чеки и документы", en: "Expense documents"), systemImage: "doc.text.fill")
                                .font(.headline)
                            ForEach(Array(completion.expenseReceiptURLs.enumerated()), id: \.offset) { index, url in
                                Link(destination: url) {
                                    Label(
                                        appState.locale.text(he: "פתיחת מסמך \(index + 1)", ru: "Открыть документ \(index + 1)", en: "Open document \(index + 1)"),
                                        systemImage: "arrow.up.right.square"
                                    )
                                }
                            }
                        }
                        .padding(16)
                        .brandCard()
                    }
                    TaskLocationCard(city: task.city, address: task.address, location: task.location)
                    TaskIdentifierCard(identifier: proposal.taskID)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }

                if let conversationID = task?.viewerConversationID ?? currentProposal.conversationID,
                   let conversation = appState.professionalConversations.first(where: { $0.id == conversationID }) {
                    NavigationLink {
                        ConversationView(conversation: conversation)
                    } label: {
                        Label(appState.locale.text(he: "פתיחת שיחה", ru: "Открыть переписку", en: "Open conversation"), systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.red)
                }

                lifecycleActions
            }
            .padding()
        }
        .background(Brand.canvas)
        .navigationTitle(appState.locale.text(he: "משימה", ru: "Задача", en: "Task"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Brand.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showsReportSheet = true } label: {
                        Label(appState.locale.text(he: "דיווח על הבקשה", ru: "Пожаловаться на заявку", en: "Report task"), systemImage: "exclamationmark.bubble")
                    }
                    Button(role: .destructive) { showsBlockConfirmation = true } label: {
                        Label(appState.locale.text(he: "חסימת הלקוח", ru: "Заблокировать клиента", en: "Block client"), systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 34, height: 34)
                }
            }
        }
        .task(id: proposal.taskID) {
            async let conversations: Void = appState.loadProfessionalConversations()
            task = await appState.loadTask(id: proposal.taskID)
            _ = await conversations
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingConfirmation != nil },
                set: { if !$0 { pendingConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            confirmationButtons
            Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel"), role: .cancel) {
                pendingConfirmation = nil
            }
        } message: {
            Text(confirmationMessage)
        }
        .sheet(isPresented: $showsCompletionSheet) {
            ProfessionalCompletionSheet(taskID: proposal.taskID, suggestedAmount: currentProposal.price) {
                await refreshDetail()
            }
        }
        .sheet(isPresented: $showsReportSheet) {
            ContentModerationSheet(
                targetType: "task",
                targetID: proposal.taskID,
                title: appState.locale.text(he: "דיווח על בקשה", ru: "Жалоба на заявку", en: "Report task")
            )
        }
        .confirmationDialog(
            appState.locale.text(he: "לחסום את הלקוח?", ru: "Заблокировать клиента?", en: "Block this client?"),
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.locale.text(he: "חסימה", ru: "Заблокировать", en: "Block"), role: .destructive) {
                Task {
                    if await appState.blockContent(targetType: "task", targetID: proposal.taskID) { dismiss() }
                }
            }
            Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel"), role: .cancel) { }
        } message: {
            Text(appState.locale.text(
                he: "אינטראקציות חדשות עם הלקוח ייחסמו. היסטוריית העבודה והראיות יישמרו.",
                ru: "Новые взаимодействия с клиентом будут заблокированы. История работы и доказательства сохранятся.",
                en: "New interactions with this client will be blocked. Job history and evidence remain available."
            ))
        }
    }

    private var currentProposal: ProfessionalProposal {
        appState.professionalProposals.first(where: { $0.id == proposal.id }) ?? proposal
    }
    private var sourceTitle: String { task?.title ?? currentProposal.taskTitle }
    private var sourceDescription: String? { task?.description }
    private var displayedTitle: String { showsTranslation ? (translatedTitle ?? sourceTitle) : sourceTitle }
    private var displayedDescription: String? { showsTranslation ? (translatedDescription ?? sourceDescription) : sourceDescription }
    private var needsTranslation: Bool {
        guard let detected = AppLocale.detected(in: "\(sourceTitle) \(sourceDescription ?? "")") else { return false }
        return detected != appState.locale
    }

    private var isArchived: Bool {
        appState.archivedProfessionalProposalIDs.contains(proposal.id)
    }

    private var canStart: Bool {
        currentProposal.status == "pending" && currentProposal.taskStatus == "open"
    }

    private var canComplete: Bool {
        currentProposal.status == "accepted" && currentProposal.taskStatus == "in_progress"
    }

    private var isTerminal: Bool {
        currentProposal.status == "rejected"
            || ["done", "completed", "cancelled"].contains(currentProposal.taskStatus)
    }

    @ViewBuilder
    private var lifecycleActions: some View {
        VStack(spacing: 10) {
            if canStart {
                Button { pendingConfirmation = .start } label: {
                    Label(appState.locale.text(he: "קבלת העבודה", ru: "Взять в работу", en: "Take this job"), systemImage: "briefcase.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Brand.red)
            }

            if canComplete {
                Button { showsCompletionSheet = true } label: {
                    Label(appState.locale.text(he: "סיום העבודה", ru: "Завершить работу", en: "Complete job"), systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
            }

            if currentProposal.status == "pending" {
                Button(role: .destructive) { pendingConfirmation = .cancelResponse } label: {
                    Label(appState.locale.text(he: "ביטול ההצעה", ru: "Отменить отклик", en: "Withdraw response"), systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if isArchived {
                Button {
                    appState.restoreProfessionalProposal(id: proposal.id)
                    dismiss()
                } label: {
                    Label(appState.locale.text(he: "החזרה מהארכיון", ru: "Вернуть из архива", en: "Restore from archive"), systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else if isTerminal {
                Button { pendingConfirmation = .archive } label: {
                    Label(appState.locale.text(he: "העברה לארכיון", ru: "Архивировать", en: "Archive"), systemImage: "archivebox")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .disabled(appState.isWorking)
    }

    @ViewBuilder
    private var confirmationButtons: some View {
        switch pendingConfirmation {
        case .start:
            Button(appState.locale.text(he: "קבלת העבודה", ru: "Взять в работу", en: "Take job")) {
                pendingConfirmation = nil
                Task {
                    if await appState.updateProfessionalProposal(id: proposal.id, status: "accepted") {
                        await refreshDetail()
                    }
                }
            }
        case .cancelResponse:
            Button(appState.locale.text(he: "ביטול ההצעה", ru: "Отменить отклик", en: "Withdraw response"), role: .destructive) {
                pendingConfirmation = nil
                Task {
                    if await appState.updateProfessionalProposal(id: proposal.id, status: "rejected") {
                        await refreshDetail()
                    }
                }
            }
        case .archive:
            Button(appState.locale.text(he: "העברה לארכיון", ru: "Архивировать", en: "Archive")) {
                pendingConfirmation = nil
                appState.archiveProfessionalProposal(id: proposal.id)
                dismiss()
            }
        case nil:
            EmptyView()
        }
    }

    private var confirmationTitle: String {
        switch pendingConfirmation {
        case .start: appState.locale.text(he: "לקבל את העבודה?", ru: "Взять задачу в работу?", en: "Take this job?")
        case .cancelResponse: appState.locale.text(he: "לבטל את ההצעה?", ru: "Отменить отклик?", en: "Withdraw your response?")
        case .archive: appState.locale.text(he: "להעביר לארכיון?", ru: "Архивировать задачу?", en: "Archive this job?")
        case nil: ""
        }
    }

    private var confirmationMessage: String {
        switch pendingConfirmation {
        case .start:
            appState.locale.text(he: "העבודה תתווסף למשימות הפעילות שלכם וייפתח הצ׳אט עם הלקוח.", ru: "Заявка перейдёт в активные задачи, и откроется чат с клиентом.", en: "The job moves to active work and the client chat becomes available.")
        case .cancelResponse:
            appState.locale.text(he: "לא תוכלו לשלוח מחדש הצעה לאותה בקשה.", ru: "Повторно откликнуться на эту заявку не получится.", en: "You will not be able to respond to this request again.")
        case .archive:
            appState.locale.text(he: "המשימה תעבור ללשונית הארכיון וניתן יהיה לשחזר אותה.", ru: "Задача перейдёт во вкладку «Архив», откуда её можно вернуть.", en: "The job moves to Archive, where you can restore it.")
        case nil: ""
        }
    }

    private var localizedProposalStatus: String {
        switch currentProposal.status {
        case "accepted": appState.locale.text(he: "התקבלה", ru: "Принят", en: "Accepted")
        case "rejected": appState.locale.text(he: "בוטלה", ru: "Отменён", en: "Withdrawn")
        default: appState.locale.text(he: "ממתינה", ru: "Ожидает", en: "Pending")
        }
    }

    private var localizedTaskStatus: String {
        switch currentProposal.taskStatus {
        case "in_progress": appState.locale.text(he: "בביצוע", ru: "В работе", en: "In progress")
        case "done", "completed": appState.locale.text(he: "הושלמה", ru: "Выполнена", en: "Completed")
        case "cancelled": appState.locale.text(he: "בוטלה", ru: "Отменена", en: "Cancelled")
        default: appState.locale.text(he: "פתוחה", ru: "Открыта", en: "Open")
        }
    }

    @MainActor
    private func refreshDetail() async {
        task = await appState.loadTask(id: proposal.taskID)
        await appState.loadProfessionalConversations(force: true)
    }

    @MainActor
    private func toggleTranslation() async {
        if translatedTitle != nil {
            withAnimation(.snappy) { showsTranslation.toggle() }
            return
        }
        isTranslating = true
        defer { isTranslating = false }
        var values = [sourceTitle]
        if let sourceDescription, !sourceDescription.isEmpty { values.append(sourceDescription) }
        guard let result = await appState.translateTexts(values), result.translations.count == values.count else { return }
        withAnimation(.snappy) {
            translatedTitle = result.translations[0]
            translatedDescription = result.translations.count > 1 ? result.translations[1] : nil
            showsTranslation = true
        }
    }
}

private struct ProfessionalClientContactCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    let client: TaskClientContact

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                appState.locale.text(he: "פרטי הלקוח", ru: "Клиент", en: "Client"),
                systemImage: "person.crop.circle.fill"
            )
            .font(.headline)

            HStack(alignment: .firstTextBaseline) {
                Text(client.name)
                    .font(.title3.bold())
                Spacer()
                if let rating = client.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if let phone = client.phone, !phone.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        if let url = phoneURL { openURL(url) }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "phone.fill")
                            Text(appState.locale.text(he: "שיחה", ru: "Позвонить", en: "Call"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .allowsTightening(true)
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Brand.red)

                    Button {
                        if let url = whatsappURL { openURL(url) }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "message.fill")
                            Text("WhatsApp")
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .allowsTightening(true)
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                HStack {
                    Label(phone.ltrIsolated, systemImage: "phone")
                        .font(.subheadline)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = phone
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel(appState.locale.text(he: "העתקת מספר", ru: "Скопировать номер", en: "Copy number"))
                }
            }

            if let email = client.email, !email.isEmpty {
                Button {
                    if let url = emailURL { openURL(url) }
                } label: {
                    Label(email, systemImage: "envelope.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Brand.red)
            }

            if !client.hasDirectContact {
                Label(
                    appState.locale.text(
                        he: "פרטי הקשר עדיין מוגנים. הם יופיעו לאחר פתיחת הקשר.",
                        ru: "Контакты пока защищены и появятся после открытия контакта.",
                        en: "Contact details are protected until contact access is unlocked."
                    ),
                    systemImage: "lock.shield.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .brandCard()
    }

    private var normalizedPhone: String {
        let digits = client.phone?.filter(\.isNumber) ?? ""
        if digits.hasPrefix("0") {
            return "972\(digits.dropFirst())"
        }
        return digits
    }

    private var phoneURL: URL? {
        guard let phone = client.phone?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed), !phone.isEmpty else { return nil }
        return URL(string: "tel:\(phone)")
    }

    private var whatsappURL: URL? {
        normalizedPhone.isEmpty ? nil : URL(string: "https://wa.me/\(normalizedPhone)")
    }

    private var emailURL: URL? {
        guard let email = client.email?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "mailto:\(email)")
    }
}

private struct ProfessionalCompletionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let taskID: String
    let onCompleted: () async -> Void
    @State private var amountText: String
    @State private var note = ""
    @State private var expenseText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var selectedReceiptPhotos: [PhotosPickerItem] = []
    @State private var receiptUploads: [CompletionUpload] = []
    @State private var showsReceiptImporter = false
    @State private var shareReceiptsWithClient = false

    init(taskID: String, suggestedAmount: Int?, onCompleted: @escaping () async -> Void) {
        self.taskID = taskID
        self.onCompleted = onCompleted
        _amountText = State(initialValue: suggestedAmount.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("₪", text: $amountText)
                        .keyboardType(.numberPad)
                } header: {
                    Text(appState.locale.text(he: "הסכום הסופי", ru: "Итоговая стоимость", en: "Final amount"))
                } footer: {
                    Text(appState.locale.text(
                        he: "הלקוח יקבל בקשה לאשר את סיום העבודה והסכום.",
                        ru: "Клиент получит запрос подтвердить завершение и итоговую сумму.",
                        en: "The client will be asked to confirm completion and the final amount."
                    ))
                }
                Section(appState.locale.text(he: "מה בוצע", ru: "Что выполнено", en: "What was done")) {
                    TextField(
                        appState.locale.text(he: "תיאור קצר", ru: "Краткое описание", en: "Short completion note"),
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
                Section(appState.locale.text(he: "חומרים והוצאות", ru: "Материалы и расходы", en: "Materials and expenses")) {
                    TextField(appState.locale.text(he: "אופציונלי", ru: "Необязательно", en: "Optional"), text: $expenseText)
                        .keyboardType(.numberPad)
                }
                Section(appState.locale.text(he: "מסמכי הוצאה", ru: "Чеки и документы", en: "Expense documents")) {
                    PhotosPicker(selection: $selectedReceiptPhotos, maxSelectionCount: 4, matching: .images) {
                        Label(receiptPhotoPickerTitle, systemImage: "camera.fill")
                    }
                    Button { showsReceiptImporter = true } label: {
                        Label(appState.locale.text(he: "הוספת PDF", ru: "Добавить PDF", en: "Add PDF"), systemImage: "doc.badge.plus")
                    }
                    if !receiptUploads.isEmpty {
                        ForEach(Array(receiptUploads.enumerated()), id: \.offset) { index, upload in
                            HStack {
                                Label(upload.filename, systemImage: upload.mimeType == "application/pdf" ? "doc.richtext.fill" : "photo.fill")
                                    .lineLimit(1)
                                Spacer()
                                Button(role: .destructive) { receiptUploads.remove(at: index) } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                        Toggle(
                            appState.locale.text(he: "שיתוף עם הלקוח", ru: "Показывать клиенту", en: "Share with client"),
                            isOn: $shareReceiptsWithClient
                        )
                    }
                    Text(appState.locale.text(
                        he: "ברירת המחדל היא פרטית ורק אתם יכולים לצפות במסמך. שתפו רק אם אין בו מידע אישי שאינו קשור לעבודה.",
                        ru: "По умолчанию документ виден только вам. Делитесь с клиентом, только если в нём нет посторонних персональных данных.",
                        en: "Documents are private to you by default. Share only when they contain no unrelated personal information."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Section(appState.locale.text(he: "תמונות אחרי העבודה", ru: "Фото результата", en: "Completion photos")) {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 6,
                        matching: .images
                    ) {
                        Label(photoPickerTitle, systemImage: "photo.badge.plus")
                    }
                    Text(appState.locale.text(
                        he: "התמונות פרטיות למשתתפי העבודה ואינן מתפרסמות אוטומטית.",
                        ru: "Фото доступны только участникам и не публикуются автоматически.",
                        en: "Photos stay private to job participants and are never published automatically."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(appState.locale.text(he: "סיום העבודה", ru: "Завершение работы", en: "Complete job"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel")) { dismiss() }
                        .disabled(appState.isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await complete() }
                    } label: {
                        if appState.isWorking {
                            ProgressView()
                        } else {
                            Text(appState.locale.text(he: "סיום", ru: "Завершить", en: "Complete"))
                        }
                    }
                    .disabled(validAmount == nil || appState.isWorking)
                }
            }
            .interactiveDismissDisabled(appState.isWorking)
            .onChange(of: selectedPhotos) { _, items in
                Task { photoData = await normalizedPhotoData(items) }
            }
            .onChange(of: selectedReceiptPhotos) { _, items in
                Task {
                    let photos = await normalizedReceiptUploads(items)
                    let documents = receiptUploads.filter { $0.mimeType == "application/pdf" }
                    receiptUploads = Array((documents + photos).prefix(6))
                }
            }
            .fileImporter(isPresented: $showsReceiptImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
                guard case let .success(urls) = result else { return }
                var additions: [CompletionUpload] = []
                for url in urls.prefix(6) {
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url), data.count <= 10 * 1024 * 1024 else { continue }
                    additions.append(.init(data: data, filename: url.lastPathComponent, mimeType: "application/pdf"))
                }
                receiptUploads = Array((receiptUploads + additions).prefix(6))
            }
        }
    }

    private var validAmount: Int? {
        guard let amount = Int(amountText), (0...10_000_000).contains(amount) else { return nil }
        return amount
    }

    private var validExpenseAmount: Int? {
        guard !expenseText.isEmpty else { return nil }
        guard let value = Int(expenseText), (0...10_000_000).contains(value) else { return nil }
        return value
    }

    private var photoPickerTitle: String {
        photoData.isEmpty
            ? appState.locale.text(he: "הוספת תמונות", ru: "Добавить фото", en: "Add photos")
            : appState.locale.text(he: "נבחרו \(photoData.count)", ru: "Выбрано: \(photoData.count)", en: "Selected: \(photoData.count)")
    }

    private var receiptPhotoPickerTitle: String {
        appState.locale.text(he: "הוספת צילום קבלה", ru: "Добавить фото чека", en: "Add receipt photo")
    }

    @MainActor
    private func complete() async {
        guard let amount = validAmount else { return }
        if await appState.completeProfessionalTask(
            id: taskID,
            amount: amount,
            note: note,
            expenseAmount: validExpenseAmount,
            photoData: photoData,
            receiptUploads: receiptUploads,
            shareReceiptsWithClient: shareReceiptsWithClient
        ) {
            await onCompleted()
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

    private func normalizedReceiptUploads(_ items: [PhotosPickerItem]) async -> [CompletionUpload] {
        let photos = await normalizedPhotoData(items)
        return photos.enumerated().map { index, data in
            CompletionUpload(data: data, filename: "receipt-\(index + 1).jpg", mimeType: "image/jpeg")
        }
    }
}

struct ProfessionalChatsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isLoadingProfessionalConversations, appState.professionalConversations.isEmpty {
                ProgressView()
            } else if appState.professionalConversations.isEmpty {
                ContentUnavailableView(
                    appState.locale.text(he: "אין שיחות", ru: "Переписок пока нет", en: "No conversations yet"),
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text(appState.locale.text(he: "שיחות אמיתיות יופיעו לאחר קבלת עבודה.", ru: "Реальные переписки появятся после принятия заказа.", en: "Real conversations appear after a job is accepted."))
                )
            } else {
                List {
                    OfflineFreshnessLabel(
                        updatedAt: appState.professionalConversationsUpdatedAt,
                        isSavedCopy: appState.professionalConversationsShowingSavedCopy,
                        staleAfter: OfflineFreshness.personalTasks,
                        locale: appState.locale
                    )
                    ForEach(appState.professionalConversations) { conversation in
                        NavigationLink { ConversationView(conversation: conversation) } label: { chatRow(conversation) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(appState.locale.text(he: "צ׳אטים", ru: "Чаты", en: "Chats"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { WorkspaceNavigationToolbar() }
        .task { await appState.loadProfessionalConversations() }
        .refreshable { await appState.loadProfessionalConversations(force: true) }
    }

    private func chatRow(_ conversation: ProfessionalConversation) -> some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: conversation.partnerName, size: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text(conversation.partnerName).font(.headline)
                Text(conversation.lastMessage ?? conversation.taskTitle ?? "")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.caption2.bold()).foregroundStyle(.white)
                    .padding(6).background(Brand.red, in: .circle)
            }
        }
        .padding(.vertical, 5)
    }
}

struct ConversationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let conversation: ProfessionalConversation
    @AppStorage("chat-auto-translate") private var autoTranslate = true
    @State private var messages: [ProfessionalMessage] = []
    @State private var isLoading = true
    @State private var draft = ""
    @State private var isSending = false
    @State private var translatedMessages: [String: String] = [:]
    @State private var showingOriginal: Set<String> = []
    @State private var isTranslating = false
    @State private var showReport = false
    @State private var showBlockConfirmation = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if isLoading {
                    ProgressView()
                } else if messages.isEmpty {
                    ContentUnavailableView(
                        appState.locale.text(he: "התחילו שיחה", ru: "Начните переписку", en: "Start the conversation"),
                        systemImage: "message.badge"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if autoTranslate {
                                Label(
                                    isTranslating
                                        ? appState.locale.text(he: "מתרגם הודעות…", ru: "Переводим сообщения…", en: "Translating messages…")
                                        : appState.locale.text(he: "תרגום אוטומטי פעיל", ru: "Автоперевод включён", en: "Auto-translate is on"),
                                    systemImage: "character.bubble.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                            }
                            ForEach(messages) { item in
                                messageBubble(item)
                                    .id(item.id)
                            }
                            Color.clear.frame(height: 1).id("chat-bottom")
                        }
                        .padding()
                    }
                }
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.snappy) { proxy.scrollTo("chat-bottom", anchor: .bottom) }
            }
        }
        .background(Brand.canvas)
        .navigationTitle(conversation.partnerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    autoTranslate.toggle()
                    if autoTranslate { Task { await translateIncomingMessages() } }
                } label: {
                    Image(systemName: autoTranslate ? "character.bubble.fill" : "character.bubble")
                        .foregroundStyle(autoTranslate ? Brand.red : .secondary)
                }
                .accessibilityLabel(appState.locale.text(he: "תרגום אוטומטי", ru: "Автоперевод", en: "Auto-translate"))
                .accessibilityValue(autoTranslate ? "On" : "Off")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showReport = true
                    } label: {
                        Label(
                            appState.locale.text(he: "דיווח", ru: "Пожаловаться", en: "Report"),
                            systemImage: "exclamationmark.bubble"
                        )
                    }
                    Button(role: .destructive) {
                        showBlockConfirmation = true
                    } label: {
                        Label(
                            appState.locale.text(he: "חסימה", ru: "Заблокировать", en: "Block"),
                            systemImage: "hand.raised.fill"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(appState.locale.text(he: "אפשרויות", ru: "Действия", en: "Actions"))
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(appState.locale.text(he: "סיום", ru: "Готово", en: "Done")) { composerFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .sheet(isPresented: $showReport) {
            ConversationReportSheet(conversationID: conversation.id, partnerName: conversation.partnerName)
        }
        .confirmationDialog(
            appState.locale.text(he: "לחסום את המשתמש?", ru: "Заблокировать пользователя?", en: "Block this user?"),
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.locale.text(he: "חסימה", ru: "Заблокировать", en: "Block"), role: .destructive) {
                Task {
                    if await appState.blockConversation(id: conversation.id) { dismiss() }
                }
            }
            Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(appState.locale.text(
                he: "הודעות חדשות ייחסמו. היסטוריית העבודה והראיות תישמר.",
                ru: "Новые сообщения будут запрещены. История работы и материалы сохранятся.",
                en: "New messages will be blocked. Job history and evidence stay preserved."
            ))
        }
        .task(id: conversation.id) {
            await reloadMessages()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                await reloadMessages(silently: true)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                appState.locale.text(he: "הודעה", ru: "Сообщение", en: "Message"),
                text: $draft,
                axis: .vertical
            )
            .lineLimit(1...5)
            .textFieldStyle(.plain)
            .focused($composerFocused)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20))

            Button { Task { await send() } } label: {
                if isSending {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: appState.locale == .he ? "arrow.left" : "arrow.up")
                        .font(.headline.bold())
                }
            }
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(Brand.red, in: .circle)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityLabel(appState.locale.text(he: "שליחה", ru: "Отправить", en: "Send"))
        }
        .padding(.horizontal)
        .padding(.vertical, 9)
        .background(.bar)
    }

    private func messageBubble(_ item: ProfessionalMessage) -> some View {
        let outgoing = item.senderID == appState.session?.user.id
        let hasTranslation = !outgoing && translatedMessages[item.id] != nil
        let showsOriginal = showingOriginal.contains(item.id)
        let value = hasTranslation && autoTranslate && !showsOriginal
            ? (translatedMessages[item.id] ?? item.text)
            : item.text

        return VStack(alignment: outgoing ? .trailing : .leading, spacing: 4) {
            HStack {
                if outgoing { Spacer(minLength: 42) }
                Text(value)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(outgoing ? Brand.red : Color(.secondarySystemBackground), in: .rect(cornerRadius: 18))
                    .foregroundStyle(outgoing ? .white : .primary)
                    .textSelection(.enabled)
                if !outgoing { Spacer(minLength: 42) }
            }

            if hasTranslation && autoTranslate {
                Button {
                    if showsOriginal { showingOriginal.remove(item.id) } else { showingOriginal.insert(item.id) }
                } label: {
                    Text(showsOriginal
                        ? appState.locale.text(he: "הצגת תרגום", ru: "Показать перевод", en: "Show translation")
                        : appState.locale.text(he: "מתורגם · הצגת מקור", ru: "Переведено · оригинал", en: "Translated · original"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Brand.red)
                }
            }
        }
    }

    @MainActor
    private func reloadMessages(silently: Bool = false) async {
        if !silently { isLoading = true }
        let loaded = await appState.loadProfessionalMessages(conversationID: conversation.id)
        if loaded != messages { messages = loaded }
        isLoading = false
        if autoTranslate { await translateIncomingMessages() }
    }

    @MainActor
    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        composerFocused = false
        if let message = await appState.sendMessage(conversationID: conversation.id, text: text) {
            draft = ""
            if !messages.contains(where: { $0.id == message.id }) { messages.append(message) }
        }
        isSending = false
    }

    @MainActor
    private func translateIncomingMessages() async {
        guard autoTranslate, !isTranslating else { return }
        let candidates = messages.filter { item in
            item.senderID != appState.session?.user.id
                && translatedMessages[item.id] == nil
                && AppLocale.detected(in: item.text).map { $0 != appState.locale } == true
        }
        guard !candidates.isEmpty else { return }
        isTranslating = true
        defer { isTranslating = false }

        var batch: [ProfessionalMessage] = []
        var characterCount = 0
        for item in candidates {
            let length = min(item.text.count, 800)
            if !batch.isEmpty && (batch.count == 12 || characterCount + length > 2_300) {
                await translate(batch)
                batch = []
                characterCount = 0
            }
            batch.append(item)
            characterCount += length
        }
        if !batch.isEmpty { await translate(batch) }
    }

    @MainActor
    private func translate(_ batch: [ProfessionalMessage]) async {
        guard let result = await appState.translateTexts(batch.map(\.text), reportError: false),
              result.translations.count == batch.count else { return }
        for (item, translation) in zip(batch, result.translations) {
            translatedMessages[item.id] = translation
        }
    }

}

private struct ConversationReportSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let conversationID: String
    let partnerName: String
    @State private var reason = "abuse"
    @State private var details = ""
    @State private var isSubmitting = false

    private var reasons: [(String, String)] {
        [
            ("spam", appState.locale.text(he: "ספאם או פרסום", ru: "Спам или реклама", en: "Spam or advertising")),
            ("fraud", appState.locale.text(he: "חשד להונאה", ru: "Подозрение на мошенничество", en: "Suspected fraud")),
            ("abuse", appState.locale.text(he: "התנהגות פוגענית", ru: "Оскорбительное поведение", en: "Abusive behavior")),
            ("unsafe", appState.locale.text(he: "סכנה או איום", ru: "Опасность или угроза", en: "Safety concern")),
            ("other", appState.locale.text(he: "אחר", ru: "Другое", en: "Other")),
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(appState.locale.text(he: "סיבה", ru: "Причина", en: "Reason")) {
                    Picker("", selection: $reason) {
                        ForEach(reasons, id: \.0) { value, title in Text(title).tag(value) }
                    }
                    .labelsHidden()
                }
                Section(appState.locale.text(he: "פרטים", ru: "Подробности", en: "Details")) {
                    TextField(
                        appState.locale.text(he: "תארו מה קרה", ru: "Опишите, что произошло", en: "Describe what happened"),
                        text: $details,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                }
            }
            .navigationTitle(appState.locale.text(he: "דיווח על \(partnerName)", ru: "Жалоба на \(partnerName)", en: "Report \(partnerName)"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.locale.text(he: "שליחה", ru: "Отправить", en: "Submit")) {
                        Task {
                            isSubmitting = true
                            if await appState.reportConversation(id: conversationID, reason: reason, details: details) {
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

struct ProfessionalProfileHubView: View {
    @Environment(AppState.self) private var appState
    @State private var pendingVisibility: Bool?

    var body: some View {
        List {
            Section {
                // The header is the questionnaire: tapping your own name and
                // photo is the obvious way in, so the list no longer repeats it
                // as a separate row.
                NavigationLink { ProfessionalOnboardingView() } label: {
                    HStack(spacing: 14) {
                        if let specialist = appState.professionalProfile?.specialist {
                            SpecialistAvatar(specialist: specialist, size: 62)
                        } else {
                            InitialsAvatar(name: appState.session?.user.name ?? "K", size: 62)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(appState.professionalProfile?.specialist.name ?? appState.session?.user.name ?? "KABLAY")
                                .font(.title3).fontWeight(.bold)
                            profileStatus
                            Text(appState.locale.text(he: "עריכת השאלון", ru: "Редактировать анкету", en: "Edit profile questionnaire"))
                                .font(.caption)
                                .foregroundStyle(Brand.red)
                        }
                    }
                    .padding(.vertical, 6)
                }
                OfflineFreshnessLabel(
                    updatedAt: appState.professionalProfileUpdatedAt,
                    isSavedCopy: appState.professionalProfileShowingSavedCopy,
                    staleAfter: OfflineFreshness.personalTasks,
                    locale: appState.locale
                )
            }
            Section {
                Toggle(isOn: visibilityBinding) {
                    Label(
                        isProfileVisible
                            ? appState.locale.text(he: "הפרופיל מוצג בקטלוג", ru: "Профиль виден в каталоге", en: "Visible in the catalog")
                            : appState.locale.text(he: "הפרופיל מוסתר מהקטלוג", ru: "Профиль скрыт из каталога", en: "Hidden from the catalog"),
                        systemImage: isProfileVisible ? "eye.fill" : "eye.slash.fill"
                    )
                }
                .tint(Brand.red)
                .disabled(appState.professionalProfile == nil || pendingVisibility != nil)
                .accessibilityIdentifier("professional.profile.visibility")
            } header: {
                Text(appState.locale.text(he: "נראות", ru: "Видимость", en: "Visibility"))
            } footer: {
                Text(
                    isProfileVisible
                        ? appState.locale.text(
                            he: "לקוחות יכולים למצוא את הפרופיל ולשלוח עבודות חדשות.",
                            ru: "Клиенты видят анкету в каталоге и могут присылать новые заказы.",
                            en: "Clients can find the profile and send new jobs."
                        )
                        : appState.locale.text(
                            he: "הפרופיל מוסתר מחיפוש ציבורי ומקבלת עבודות חדשות. העבודות והצ׳אטים הקיימים נשארים פעילים.",
                            ru: "Анкета скрыта из публичного поиска, новые заказы не приходят. Текущие задачи и чаты продолжают работать.",
                            en: "The profile is hidden from public search and new jobs. Current work and chats stay active."
                        )
                )
            }
            Section(appState.locale.text(he: "עבודה", ru: "Работа", en: "Work")) {
                NavigationLink { CreditsView() } label: {
                    menuLabel(
                        "creditcard.fill",
                        appState.locale.text(he: "נקודות", ru: "Баллы", en: "Credits"),
                        trailing: appState.creditAccount.map { String($0.balance) }
                            ?? appState.professionalProfile.map { String($0.creditsBalance) }
                    )
                }
                NavigationLink { PremiumView() } label: {
                    menuLabel(
                        "crown.fill",
                        "KABLAY Premium",
                        trailing: appState.creditAccount?.premium == true
                            ? appState.locale.text(he: "פעיל", ru: "Активен", en: "Active")
                            : nil
                    )
                }
                NavigationLink { ProfessionalStatsView() } label: { menuLabel("chart.bar.xaxis", appState.locale.text(he: "סטטיסטיקה", ru: "Моя статистика", en: "Statistics")) }
                NavigationLink { MonthlyWorkReportView() } label: { menuLabel("square.and.arrow.up.on.square.fill", appState.locale.text(he: "דוח עבודה חודשי", ru: "Месячный отчёт", en: "Monthly work report")) }
                if let specialist = appState.professionalProfile?.specialist {
                    NavigationLink {
                        SpecialistProfileView(specialist: specialist, presentation: .ownerPreview)
                    } label: {
                        menuLabel("eye.fill", appState.locale.text(he: "תצוגה ציבורית", ru: "Публичный профиль", en: "Public profile"))
                    }
                }
            }
            Section(appState.locale.text(he: "עזרה והגדרות", ru: "Помощь и настройки", en: "Help & settings")) {
                NavigationLink { AppSettingsView() } label: { menuLabel("gearshape.fill", appState.locale.text(he: "הגדרות", ru: "Настройки", en: "Settings")) }
                NavigationLink { SupportView() } label: { menuLabel("questionmark.circle.fill", appState.locale.text(he: "תמיכה", ru: "Поддержка", en: "Support")) }
                NavigationLink { LegalDocumentView(document: .responsibility) } label: { menuLabel("shield.lefthalf.filled", appState.locale.text(he: "אחריות וכללים", ru: "Ответственность и правила", en: "Responsibilities & rules")) }
            }
            Section {
                Button(role: .destructive) { Task { await appState.signOutAndRevoke() } } label: { Label(appState.locale.text(he: "התנתקות", ru: "Выйти", en: "Sign out"), systemImage: "rectangle.portrait.and.arrow.right") }
            }
        }
        .navigationTitle(appState.locale.text(he: "פרופיל", ru: "Анкета", en: "Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { WorkspaceNavigationToolbar() }
        .task {
            async let profile: Void = appState.loadProfessionalProfile()
            async let credits: Void = appState.loadCreditAccount()
            _ = await (profile, credits)
        }
        .refreshable {
            async let profile: Void = appState.loadProfessionalProfile(force: true)
            async let credits: Void = appState.loadCreditAccount(force: true)
            _ = await (profile, credits)
        }
    }

    private var isProfileVisible: Bool {
        pendingVisibility ?? appState.professionalProfile?.specialist.availableNow ?? true
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: { isProfileVisible },
            set: { newValue in
                guard newValue != isProfileVisible else { return }
                pendingVisibility = newValue
                Task {
                    _ = await appState.setProfessionalVisibility(newValue)
                    // The reloaded profile is authoritative for both outcomes:
                    // it confirms the switch or restores the stored state.
                    pendingVisibility = nil
                }
            }
        )
    }

    @ViewBuilder private var profileStatus: some View {
        if appState.isLoadingProfessionalProfile, appState.professionalProfile == nil {
            ProgressView().controlSize(.small)
        } else if appState.session?.user.role == .admin {
            Label(
                appState.locale.text(
                    he: "מנהל · גישה לכל הבקשות",
                    ru: "Администратор · доступ ко всем заявкам",
                    en: "Admin · access to every request"
                ),
                systemImage: "checkmark.seal.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.green)
        } else if let profile = appState.professionalProfile {
            Label(
                profile.isComplete
                    ? appState.locale.text(he: "פרופיל מהשרת", ru: "Профиль загружен", en: "Live profile")
                    : appState.locale.text(he: "יש להשלים את הפרופיל", ru: "Заполните профиль", en: "Complete your profile"),
                systemImage: profile.isComplete ? "checkmark.seal.fill" : "exclamationmark.circle.fill"
            )
            .font(.subheadline)
            .foregroundStyle(profile.isComplete ? .green : .orange)
        } else {
            Label(
                appState.locale.text(he: "הפרופיל אינו זמין", ru: "Профиль не загрузился", en: "Profile unavailable"),
                systemImage: "wifi.exclamationmark"
            )
            .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func menuLabel(_ image: String, _ title: String, trailing: String? = nil) -> some View {
        HStack {
            Label(title, systemImage: image)
            Spacer()
            if let trailing { Text(trailing).fontWeight(.bold).foregroundStyle(Brand.red) }
        }
    }
}

private struct MonthlyWorkReportView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedMonth: String
    @State private var exportedFile: ExportedWorkReport?

    init() {
        _selectedMonth = State(initialValue: Self.monthKey(Date()))
    }

    var body: some View {
        List {
            Section(appState.locale.text(he: "חודש", ru: "Месяц", en: "Month")) {
                Picker(appState.locale.text(he: "חודש", ru: "Месяц", en: "Month"), selection: $selectedMonth) {
                    ForEach(monthOptions, id: \.self) { month in
                        Text(monthTitle(month)).tag(month)
                    }
                }
            }
            Section(appState.locale.text(he: "ייצוא", ru: "Экспорт", en: "Export")) {
                exportButton(format: "csv", title: "CSV", icon: "tablecells")
                exportButton(format: "xlsx", title: "XLSX", icon: "tablecells.fill")
                exportButton(format: "pdf", title: "PDF", icon: "doc.richtext.fill")
                exportButton(
                    format: "receipts_zip",
                    title: appState.locale.text(he: "קבלות ZIP", ru: "Чеки ZIP", en: "Receipts ZIP"),
                    icon: "doc.zipper"
                )
            }
            Section {
                Text(appState.locale.text(
                    he: "הדוח הוא יומן עבודה נוח ואינו מסמך מס, חשבונית או מערכת הנהלת חשבונות.",
                    ru: "Это удобный журнал работ, а не налоговый документ, счёт или бухгалтерская система.",
                    en: "This is a practical work journal, not a tax document, invoice, or accounting system."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(appState.locale.text(he: "דוח חודשי", ru: "Месячный отчёт", en: "Monthly report"))
        .sheet(item: $exportedFile) { file in
            ActivityShareView(items: [file.url])
        }
    }

    private var monthOptions: [String] {
        let calendar = Calendar(identifier: .gregorian)
        return (0..<12).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: Date()).map(Self.monthKey)
        }
    }

    private func monthTitle(_ key: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: key) else { return key }
        let formatter = DateFormatter()
        formatter.locale = appState.locale.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    private static func monthKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private func exportButton(format: String, title: String, icon: String) -> some View {
        Button {
            Task {
                if let url = await appState.downloadWorkReport(month: selectedMonth, format: format) {
                    exportedFile = ExportedWorkReport(url: url)
                }
            }
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if appState.isWorking { ProgressView().controlSize(.small) }
                else { Image(systemName: "square.and.arrow.up") }
            }
        }
        .disabled(appState.isWorking)
    }
}

private struct ExportedWorkReport: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

struct CreditsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                if let account = appState.creditAccount {
                    VStack(spacing: 8) {
                        Text("\(account.balance)").font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(appState.locale.text(he: "נקודות זמינות", ru: "доступных баллов", en: "available credits")).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding()
                } else if appState.isLoadingCredits {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else {
                    ContentUnavailableView(
                        appState.locale.text(he: "לא ניתן לטעון יתרה", ru: "Баланс не загрузился", en: "Balance unavailable"),
                        systemImage: "creditcard.trianglebadge.exclamationmark"
                    )
                }
            }
            if let account = appState.creditAccount, !account.transactions.isEmpty {
                Section(appState.locale.text(he: "תנועות", ru: "Операции", en: "Activity")) {
                    ForEach(account.transactions) { transaction in
                        let isDebit = transaction.type == "spend" || transaction.type == "admin_debit"
                        let signedAmount = isDebit ? -abs(transaction.amount) : transaction.amount
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(transactionTitle(transaction))
                                Text(transaction.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(signedAmount > 0 ? "+\(signedAmount)" : "\(signedAmount)")
                                .fontWeight(.semibold)
                                .foregroundStyle(signedAmount >= 0 ? .green : Brand.red)
                        }
                    }
                }
            }
            purchaseSection
            Section {
                NavigationLink { PremiumView() } label: {
                    HStack {
                        Label("KABLAY Premium", systemImage: "crown.fill")
                        Spacer()
                        Text(premiumStatusTitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if appState.store.isAvailable {
                Section {
                    Button {
                        Task { await restore() }
                    } label: {
                    HStack {
                        Label(
                            appState.locale.text(he: "שחזור רכישות", ru: "Восстановить покупки", en: "Restore purchases"),
                            systemImage: "arrow.clockwise.circle"
                        )
                            Spacer()
                            if appState.store.isRestoring { ProgressView().controlSize(.small) }
                        }
                    }
                    .disabled(appState.store.isRestoring)
                } footer: {
                    Text(appState.locale.text(
                        he: "התשלום מבוצע דרך חשבון Apple שלכם. הנקודות אינן מנוי, אינן מתחדשות מאליהן ואינן ניתנות להמרה לכסף.",
                        ru: "Оплата проходит через ваш аккаунт Apple. Баллы — не подписка, сами не продлеваются и не обмениваются на деньги.",
                        en: "Payment is charged to your Apple account. Credits are not a subscription, never renew by themselves, and are not exchangeable for money."
                    ))
                }
            }
        }
        .navigationTitle(appState.locale.text(he: "נקודות", ru: "Баллы", en: "Credits"))
        .task {
            async let account: Void = appState.loadCreditAccount()
            async let products: Void = appState.store.loadProducts()
            _ = await (account, products)
        }
        .refreshable { await appState.loadCreditAccount(force: true) }
    }

    /// The section exists only while the App Store actually offers the packs.
    /// A store that returns nothing means purchases are not available on this
    /// account or in this build, and a dead paywall is worse than no paywall.
    @ViewBuilder private var purchaseSection: some View {
        if appState.store.isLoadingProducts, appState.store.creditProducts.isEmpty {
            Section { HStack { Spacer(); ProgressView(); Spacer() } }
        } else if !appState.store.creditProducts.isEmpty {
            Section {
                ForEach(appState.store.creditProducts, id: \.id) { product in
                    Button { Task { await buy(product) } } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(packTitle(for: product)).font(.headline).foregroundStyle(Brand.ink)
                                Text(product.displayName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if appState.store.purchasingProductID == product.id {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(product.displayPrice).fontWeight(.bold).foregroundStyle(Brand.red)
                            }
                        }
                    }
                    .disabled(appState.store.purchasingProductID != nil)
                }
            } header: {
                Text(appState.locale.text(he: "טעינת נקודות", ru: "Пополнить баллы", en: "Top up credits"))
            } footer: {
                Text(appState.locale.text(
                    he: "נקודות משמשות לפתיחת פרטי קשר. פתיחת קשר אינה מבטיחה הסכם, עבודה או תוצאה.",
                    ru: "Баллы нужны для открытия контактов. Открытие контакта не гарантирует договор, работу или результат.",
                    en: "Credits unlock contact details. Unlocking a contact does not guarantee a contract, a job, or a result."
                ))
            }
        }
    }

    private var premiumStatusTitle: String {
        guard appState.creditAccount?.premium == true else {
            return appState.locale.text(he: "לא פעיל", ru: "Не подключён", en: "Off")
        }
        guard let until = appState.creditAccount?.premiumUntil else {
            return appState.locale.text(he: "פעיל", ru: "Активен", en: "Active")
        }
        return appState.locale.text(
            he: "עד \(until.formatted(date: .abbreviated, time: .omitted))",
            ru: "до \(until.formatted(date: .abbreviated, time: .omitted))",
            en: "until \(until.formatted(date: .abbreviated, time: .omitted))"
        )
    }

    private func packTitle(for product: Product) -> String {
        guard let amount = StoreService.creditAmounts[product.id] else { return product.displayName }
        return appState.locale.text(
            he: "\(amount) נקודות",
            ru: "\(amount) баллов",
            en: "\(amount) credits"
        )
    }

    private func buy(_ product: Product) async {
        guard await appState.purchaseStoreProduct(product) == .completed else { return }
        await appState.loadCreditAccount(force: true)
    }

    private func restore() async {
        _ = await appState.restoreStorePurchases()
        await appState.loadCreditAccount(force: true)
    }

    private func transactionTitle(_ transaction: CreditTransaction) -> String {
        if transaction.id.hasPrefix("apple_reversal:") {
            return appState.locale.text(
                he: "החזר רכישה מ-Apple",
                ru: "Возврат покупки Apple",
                en: "Apple purchase refund"
            )
        }
        return switch transaction.type {
        case "purchase": appState.locale.text(he: "טעינה", ru: "Пополнение", en: "Top up")
        case "refund": appState.locale.text(he: "החזר", ru: "Возврат", en: "Refund")
        case "admin_debit": appState.locale.text(he: "חיוב", ru: "Списание", en: "Debit")
        default: appState.locale.text(he: "שימוש", ru: "Списание", en: "Spent")
        }
    }
}

/// Premium is a monthly auto-renewing App Store subscription. StoreKit supplies
/// the local price and the server applies Apple's actual expiration date.
struct PremiumView: View {
    @Environment(AppState.self) private var appState

    private var product: Product? { appState.store.premiumProduct }
    private var isActive: Bool { appState.creditAccount?.premium == true }

    private var benefits: [String] {
        [
            appState.locale.text(he: "פתיחת פרטי לקוח במשימות ללא חיוב נקודות", ru: "Контакты по задачам без списания баллов", en: "Task contacts without spending credits"),
            appState.locale.text(he: "פתיחת טלפון ו-WhatsApp בפרופיל ללא חיוב", ru: "Открытия телефона и WhatsApp в профиле без списания", en: "Profile phone and WhatsApp opens without charges"),
            appState.locale.text(he: "עבודות פעילות ללא הגבלת המסלול הרגיל", ru: "Без лимита активных работ обычного доступа", en: "No standard active-job limit"),
            appState.locale.text(he: "דירוג הלקוח לפני קבלת החלטה", ru: "Рейтинг клиента до принятия решения", en: "Client rating before you decide"),
            appState.locale.text(he: "קדימות בקטלוג בעלי המקצוע", ru: "Приоритет в каталоге специалистов", en: "Priority in the specialist directory"),
        ]
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("KABLAY Premium", systemImage: "crown.fill")
                        .font(.title2.bold())
                        .foregroundStyle(Brand.red)
                    Text(appState.locale.text(
                        he: "מנוי חודשי לבעלי מקצוע שעובדים באופן קבוע.",
                        ru: "Ежемесячная подписка для специалистов, которые работают регулярно.",
                        en: "A monthly subscription for specialists who work regularly."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if isActive {
                        Label(statusTitle, systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(appState.locale.text(he: "מה נכלל", ru: "Что входит", en: "What is included")) {
                ForEach(benefits, id: \.self) { benefit in
                    Label(benefit, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            Section {
                if appState.store.isLoadingProducts, product == nil {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let product {
                    Button { Task { await buy(product) } } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(appState.locale.text(he: "חודש אחד", ru: "1 месяц", en: "1 month"))
                                    .font(.headline)
                                    .foregroundStyle(Brand.ink)
                                Text(appState.locale.text(
                                    he: "המנוי מתחדש אוטומטית מדי חודש",
                                    ru: "Подписка продлевается автоматически каждый месяц",
                                    en: "Auto-renews every month"
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if appState.store.purchasingProductID == product.id {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(product.displayPrice).fontWeight(.bold).foregroundStyle(Brand.red)
                            }
                        }
                    }
                    .disabled(appState.store.purchasingProductID != nil)
                } else {
                    Text(appState.locale.text(
                        he: "הרכישה אינה זמינה כרגע. נסו שוב מאוחר יותר.",
                        ru: "Покупка сейчас недоступна. Попробуйте позже.",
                        en: "The purchase is unavailable right now. Try again later."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Button {
                    Task {
                        _ = await appState.restoreStorePurchases()
                        await appState.loadCreditAccount(force: true)
                    }
                } label: {
                    HStack {
                        Text(appState.locale.text(he: "שחזור רכישות", ru: "Восстановить покупки", en: "Restore purchases"))
                        Spacer()
                        if appState.store.isRestoring { ProgressView().controlSize(.small) }
                    }
                }
                .disabled(appState.store.isRestoring)
            } header: {
                Text(appState.locale.text(he: "רכישה", ru: "Покупка", en: "Purchase"))
            } footer: {
                Text(appState.locale.text(
                    he: "התשלום מחויב בחשבון Apple שלכם עם האישור, ולאחר מכן מדי חודש עד לביטול. אפשר לבטל בכל עת בהגדרות המינויים של Apple; הגישה נשארת עד סוף התקופה ששולמה. המחיר המקומי מוצג לפני האישור. Premium אינו מבטיח פניות, עבודות או הכנסה.",
                    ru: "Оплата списывается с аккаунта Apple при подтверждении и затем ежемесячно до отмены. Отменить можно в подписках Apple; доступ сохранится до конца оплаченного периода. Итоговая цена показана перед подтверждением. Premium не гарантирует обращения, заказы или доход.",
                    en: "Your Apple account is charged on confirmation and monthly until cancelled. Cancel any time in Apple subscription settings; access continues through the paid period. Your local price appears before confirmation. Premium does not guarantee enquiries, jobs, or income."
                ))
            }

            Section {
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Label(appState.locale.text(
                        he: "ניהול המנוי ב-Apple", ru: "Управлять подпиской Apple", en: "Manage Apple subscription"
                    ), systemImage: "arrow.up.right.square")
                }
            }

            Section(appState.locale.text(he: "מסמכים", ru: "Документы", en: "Documents")) {
                NavigationLink { LegalDocumentView(document: .terms) } label: {
                    Label(appState.locale.text(he: "תנאי שימוש", ru: "Условия использования", en: "Terms of Use"), systemImage: "doc.text.fill")
                }
                NavigationLink { LegalDocumentView(document: .privacy) } label: {
                    Label(appState.locale.text(he: "מדיניות פרטיות", ru: "Политика конфиденциальности", en: "Privacy Policy"), systemImage: "hand.raised.fill")
                }
                NavigationLink { LegalDocumentView(document: .payments) } label: {
                    Label(appState.locale.text(he: "תשלומים, נקודות והחזרים", ru: "Оплата, баллы и возвраты", en: "Payments, credits & refunds"), systemImage: "creditcard.fill")
                }
            }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let account: Void = appState.loadCreditAccount()
            async let products: Void = appState.store.loadProducts()
            _ = await (account, products)
        }
    }

    private var statusTitle: String {
        guard let until = appState.creditAccount?.premiumUntil else {
            return appState.locale.text(he: "פעיל", ru: "Активен", en: "Active")
        }
        let date = until.formatted(date: .abbreviated, time: .omitted)
        return appState.locale.text(he: "פעיל עד \(date)", ru: "Активен до \(date)", en: "Active until \(date)")
    }

    private func buy(_ product: Product) async {
        guard await appState.purchaseStoreProduct(product) == .completed else { return }
        await appState.loadCreditAccount(force: true)
    }
}

struct ProfessionalStatsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            if let stats = appState.professionalStats {
                OfflineFreshnessLabel(
                    updatedAt: appState.professionalStatsUpdatedAt,
                    isSavedCopy: appState.professionalStatsShowingSavedCopy,
                    staleAfter: OfflineFreshness.personalTasks,
                    locale: appState.locale
                )
                Section(appState.locale.text(he: "30 ימים", ru: "За 30 дней", en: "Last 30 days")) {
                    metricRow(appState.locale.text(he: "צפיות בפרופיל", ru: "Просмотры профиля", en: "Profile views"), stats.profileViews.last30, "eye.fill")
                    metricRow(appState.locale.text(he: "פתיחת טלפון", ru: "Открытия телефона", en: "Phone reveals"), stats.phoneReveals.last30, "phone.fill")
                    metricRow(appState.locale.text(he: "פתיחת WhatsApp", ru: "Открытия WhatsApp", en: "WhatsApp opens"), stats.whatsappOpens.last30, "message.fill")
                    metricRow(appState.locale.text(he: "כל אנשי הקשר", ru: "Все открытия контакта", en: "All contact opens"), stats.contactOpens.last30, "person.crop.circle.badge.checkmark")
                }
                Section(appState.locale.text(he: "המרה", ru: "Конверсия", en: "Conversion")) {
                    LabeledContent(appState.locale.text(he: "פתיחת טלפון", ru: "Телефон", en: "Phone"), value: "\(stats.phoneRevealRateLast30)%")
                    LabeledContent(appState.locale.text(he: "כל אנשי הקשר", ru: "Все контакты", en: "All contacts"), value: "\(stats.contactConversionRateLast30)%")
                }
            } else if appState.isLoadingProfessionalStats {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else {
                ContentUnavailableView(
                    appState.locale.text(he: "אין נתוני סטטיסטיקה", ru: "Статистика недоступна", en: "Statistics unavailable"),
                    systemImage: "chart.bar.xaxis"
                )
            }
        }
        .navigationTitle(appState.locale.text(he: "סטטיסטיקה", ru: "Моя статистика", en: "Statistics"))
        .task { await appState.loadProfessionalStats() }
        .refreshable { await appState.loadProfessionalStats(force: true) }
    }

    private func metricRow(_ title: String, _ value: Int, _ image: String) -> some View {
        LabeledContent {
            Text("\(value)").fontWeight(.bold)
        } label: {
            Label(title, systemImage: image)
        }
    }
}
