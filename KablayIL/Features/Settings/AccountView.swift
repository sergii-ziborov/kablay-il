import SwiftUI
import UIKit

struct AccountView: View {
    @Environment(AppState.self) private var appState
    @State private var showLogin = false
    @State private var showJoinAfterLogin = false
    @State private var showJoinOnboarding = false
    @State private var showDeleteAccountFlow = false
    @State private var exportedData: URL?

    var body: some View {
        List {
            if let user = appState.session?.user {
                Section {
                    // The card is the account: tapping your own name and photo
                    // opens the personal details, exactly like the header in the
                    // professional workspace.
                    NavigationLink { ProfileSettingsView() } label: {
                        HStack(spacing: 14) {
                            if let specialist = appState.professionalProfile?.specialist,
                               specialist.displayAvatarURL != nil {
                                SpecialistAvatar(specialist: specialist, size: 60)
                            } else {
                                InitialsAvatar(name: user.name, size: 60)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name).font(.title3).fontWeight(.bold)
                                Text(user.phone?.ltrIsolated ?? "").foregroundStyle(.secondary)
                                Text(roleTitle(user.role)).font(.caption).foregroundStyle(Brand.red)
                                Text(appState.locale.text(he: "עריכת הפרטים", ru: "Редактировать данные", en: "Edit details"))
                                    .font(.caption)
                                    .foregroundStyle(Brand.red)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                Section(appState.locale.text(he: "חשבון", ru: "Кабинет", en: "Account")) {
                    NavigationLink { SecuritySettingsView() } label: {
                        Label(appState.locale.text(he: "אבטחה ו-Face ID", ru: "Безопасность и Face ID", en: "Security & Face ID"), systemImage: "lock.shield.fill")
                    }
                    NavigationLink { NotificationCenterView() } label: {
                        Label(appState.locale.text(he: "התראות", ru: "Уведомления", en: "Notifications"), systemImage: "bell.fill")
                            .badge(appState.unreadCount)
                    }
                    NavigationLink { ProfileSettingsView() } label: { Label(appState.locale.text(he: "פרטים אישיים", ru: "Личные данные", en: "Personal details"), systemImage: "person.text.rectangle") }
                }
                // The client/professional switch lives in the top bar, so the
                // account list only carries the first-time questionnaire for a
                // client who has no professional profile yet.
                Section {
                    Button {
                        Task { exportedData = await appState.exportAccountData() }
                    } label: {
                        HStack {
                            Label(
                                appState.locale.text(he: "הורדת המידע שלי", ru: "Скачать мои данные", en: "Download my data"),
                                systemImage: "square.and.arrow.down"
                            )
                            Spacer()
                            if appState.isWorking { ProgressView().controlSize(.small) }
                        }
                    }
                    .disabled(appState.isWorking)
                } footer: {
                    Text(appState.locale.text(
                        he: "קובץ אחד עם המידע שהחשבון מחזיק: פרטים, בקשות, הצעות, הודעות שכתבתם, נקודות ורכישות. טקסט שאנשים אחרים כתבו אינו נכלל, מפני שהוא המידע האישי שלהם.",
                        ru: "Один файл с данными аккаунта: профиль, заявки, отклики, ваши сообщения, баллы и покупки. Текст, написанный другими людьми, не включается — это их персональные данные.",
                        en: "One file with what the account holds: details, requests, proposals, messages you wrote, credits, and purchases. Text other people wrote is not included, because it is their personal data."
                    ))
                }
                if user.role == .client {
                    Section {
                        NavigationLink { ProfessionalOnboardingView() } label: {
                            Label(appState.locale.text(he: "הצטרפות כבעל מקצוע", ru: "Стать мастером", en: "Join as a professional"), systemImage: "wrench.and.screwdriver.fill")
                        }
                    } footer: {
                        Text(appState.locale.text(he: "מלאו שאלון קצר והתחילו לקבל בקשות מתאימות.", ru: "Заполните короткую анкету и получайте подходящие заявки.", en: "Complete a short profile to start receiving matching requests."))
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        BrandWordmark()
                        Text(appState.locale.text(he: "כניסה לחשבון", ru: "Вход в кабинет", en: "Sign in to your account")).font(.title2).fontWeight(.bold)
                        Text(appState.locale.text(he: "בקשות, הצעות, צ׳אטים והתראות נשמרים לפי מספר הטלפון.", ru: "Заявки, предложения, чаты и уведомления привязаны к номеру телефона.", en: "Requests, offers, chats, and notifications are linked to your phone number."))
                            .foregroundStyle(.secondary)
                        Button(appState.locale.text(he: "כניסה לפי טלפון", ru: "Войти по телефону", en: "Sign in by phone")) { showLogin = true }
                            .buttonStyle(BrandPrimaryButtonStyle())
                        Button {
                            showJoinAfterLogin = true
                            showLogin = true
                        } label: {
                            Label(
                                appState.locale.text(he: "הצטרפות כבעל מקצוע", ru: "Стать мастером", en: "Join as a professional"),
                                systemImage: "wrench.and.screwdriver.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                        Text(appState.locale.text(
                            he: "אמתו את מספר הטלפון, בחרו תחום ועיר — והפרופיל שלכם מוכן.",
                            ru: "Подтвердите номер, выберите направления и город — профиль готов.",
                            en: "Verify your phone, choose your trades and city, and your profile is ready."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }

            Section(appState.locale.text(he: "האפליקציה", ru: "Приложение", en: "App")) {
                NavigationLink { AppSettingsView() } label: { Label(appState.locale.text(he: "הגדרות", ru: "Настройки", en: "Settings"), systemImage: "gearshape.fill") }
                NavigationLink { FAQView() } label: { Label(appState.locale.text(he: "שאלות נפוצות", ru: "Частые вопросы", en: "FAQ"), systemImage: "questionmark.circle.fill") }
                NavigationLink { SupportView() } label: { Label(appState.locale.text(he: "תמיכה", ru: "Поддержка", en: "Support"), systemImage: "headphones") }
            }
            Section(appState.locale.text(he: "משפטי ובטיחות", ru: "Правила и безопасность", en: "Legal & safety")) {
                NavigationLink { LegalCenterView() } label: {
                    Label(appState.locale.text(he: "מרכז מידע משפטי", ru: "Юридический центр", en: "Legal center"), systemImage: "building.columns.fill")
                }
                NavigationLink { LegalDocumentView(document: .limitation) } label: {
                    Label(appState.locale.text(he: "הגבלת אחריות KABLAY", ru: "Ответственность KABLAY", en: "KABLAY liability"), systemImage: "shield.lefthalf.filled")
                }
            }
            if appState.isAuthenticated {
                Section {
                    Button(role: .destructive) { Task { await appState.signOutAndRevoke() } } label: {
                        Label(appState.locale.text(he: "התנתקות", ru: "Выйти", en: "Sign out"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                if appState.session?.user.role != .admin {
                    Section {
                        Button(role: .destructive) { showDeleteAccountFlow = true } label: {
                            Label(appState.locale.text(he: "מחיקת חשבון", ru: "Удалить аккаунт", en: "Delete account"), systemImage: "person.crop.circle.badge.minus")
                        }
                    } footer: {
                        Text(appState.locale.text(
                            he: "החשבון יושבת מיד והמחיקה תעובד בתוך 30 יום. היסטוריית עסקאות הנדרשת לבטיחות ולחוק עשויה להישמר.",
                            ru: "Аккаунт будет сразу отключён, а удаление обработано в течение 30 дней. История сделок, необходимая для безопасности и закона, может сохраняться.",
                            en: "The account is disabled immediately and deletion is processed within 30 days. Transaction evidence required for safety or law may be retained."
                        ))
                    }
                }
            }
        }
        .navigationTitle(appState.locale.text(he: "חשבון", ru: "Кабинет", en: "Account"))
        .toolbar { WorkspaceNavigationToolbar() }
        .task { if appState.isProfessional { await appState.loadProfessionalProfile() } }
        .navigationDestination(isPresented: $showJoinOnboarding) { ProfessionalOnboardingView() }
        .sheet(isPresented: $showLogin, onDismiss: {
            if showJoinAfterLogin, appState.session?.user.role == .client {
                showJoinOnboarding = true
            }
            showJoinAfterLogin = false
        }) { PhoneLoginView() }
        .sheet(isPresented: $showDeleteAccountFlow) { AccountDeletionView() }
        .sheet(item: $exportedData) { file in ExportedDataShareView(url: file) }
    }

    private func roleTitle(_ role: UserRole) -> String {
        switch role {
        case .client: appState.locale.text(he: "לקוח", ru: "Клиент", en: "Client")
        case .specialist: appState.locale.text(he: "בעל מקצוע", ru: "Специалист", en: "Professional")
        case .admin: appState.locale.text(he: "מנהל", ru: "Администратор", en: "Administrator")
        }
    }
}

private struct AccountDeletionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var phoneHint: String?
    @State private var didSendCode = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        appState.locale.text(he: "נדרש אימות נוסף", ru: "Нужно повторное подтверждение", en: "Re-verification required"),
                        systemImage: "checkmark.shield.fill"
                    )
                    Text(appState.locale.text(
                        he: "כדי להגן על החשבון, נשלח קוד חד-פעמי למספר הטלפון המחובר.",
                        ru: "Для защиты аккаунта мы отправим одноразовый код на привязанный номер.",
                        en: "To protect your account, we will send a one-time code to the linked phone number."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if didSendCode {
                    Section(appState.locale.text(he: "קוד אימות", ru: "Код подтверждения", en: "Verification code")) {
                        TextField("123456", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: code) { _, value in
                                code = String(value.filter(\.isNumber).prefix(6))
                            }
                        if let phoneHint = phoneHint?.ltrIsolated {
                            Text(appState.locale.text(he: "הקוד נשלח אל \(phoneHint)", ru: "Код отправлен на \(phoneHint)", en: "Code sent to \(phoneHint)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    if didSendCode {
                        Button(role: .destructive) {
                            Task {
                                if await appState.deleteAccount(code: code) { dismiss() }
                            }
                        } label: {
                            if appState.isWorking { ProgressView().frame(maxWidth: .infinity) }
                            else { Text(appState.locale.text(he: "אימות ומחיקת החשבון", ru: "Подтвердить и удалить", en: "Verify and delete account")) }
                        }
                        .disabled(code.count != 6 || appState.isWorking)
                    } else {
                        Button {
                            Task {
                                if let hint = await appState.sendAccountDeletionCode() {
                                    phoneHint = hint
                                    didSendCode = true
                                }
                            }
                        } label: {
                            if appState.isWorking { ProgressView().frame(maxWidth: .infinity) }
                            else { Text(appState.locale.text(he: "שליחת קוד", ru: "Отправить код", en: "Send code")) }
                        }
                        .disabled(appState.isWorking)
                    }
                } footer: {
                    Text(appState.locale.text(
                        he: "החשבון יושבת מיד. המחיקה תעובד בתוך 30 יום; ראיות עסקה הנדרשות לבטיחות או לחוק עשויות להישמר.",
                        ru: "Аккаунт будет отключён сразу. Удаление обработается в течение 30 дней; данные сделки, необходимые для безопасности или закона, могут сохраняться.",
                        en: "The account is disabled immediately. Deletion is processed within 30 days; transaction evidence required for safety or law may be retained."
                    ))
                }
            }
            .navigationTitle(appState.locale.text(he: "מחיקת חשבון", ru: "Удаление аккаунта", en: "Delete account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel")) { dismiss() }
                        .disabled(appState.isWorking)
                }
            }
            .interactiveDismissDisabled(appState.isWorking)
        }
    }
}

struct ProfileSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var name = ""
    @State private var city = ""
    @State private var didSave = false

    var body: some View {
        Form {
            Section {
                TextField(appState.locale.text(he: "שם", ru: "Имя", en: "Name"), text: $name)
                CitySelectionRow(
                    value: $city,
                    title: appState.locale.text(he: "עיר מועדפת", ru: "Предпочитаемый город", en: "Preferred city"),
                    allowsClear: true
                )
                LabeledContent(appState.locale.text(he: "טלפון", ru: "Телефон", en: "Phone")) {
                    Text(appState.session?.user.phone?.ltrIsolated ?? "—").foregroundStyle(.secondary)
                }
            } header: {
                Text(appState.locale.text(he: "פרטים", ru: "Данные", en: "Details"))
            } footer: {
                Text(
                    appState.isProfessional
                        ? appState.locale.text(
                            he: "השם הזה מוצג גם בפרופיל בעל המקצוע. הטלפון הוא מספר הכניסה ומשתנה רק דרך התמיכה.",
                            ru: "Это же имя показывается в профиле специалиста. Телефон — номер входа, меняется только через поддержку.",
                            en: "This name also appears on your professional profile. The phone is your sign-in number and is changed only through support."
                        )
                        : appState.locale.text(
                            he: "הטלפון הוא מספר הכניסה ומשתנה רק דרך התמיכה.",
                            ru: "Телефон — номер входа, меняется только через поддержку.",
                            en: "The phone is your sign-in number and is changed only through support."
                        )
                )
            }
            Section {
                Button {
                    Task { didSave = await appState.updateAccount(name: name, preferredCity: city) }
                } label: {
                    if appState.isWorking { ProgressView().frame(maxWidth: .infinity) }
                    else { Text(appState.locale.text(he: "שמירה", ru: "Сохранить", en: "Save")) }
                }
                    .buttonStyle(BrandPrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isWorking)
                if didSave {
                    Label(appState.locale.text(he: "נשמר", ru: "Сохранено", en: "Saved"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle(appState.locale.text(he: "פרטים אישיים", ru: "Личные данные", en: "Personal details"))
        .onAppear {
            name = appState.session?.user.name ?? ""
            city = appState.session?.user.preferredCity ?? ""
        }
        .onChange(of: city) { _, _ in didSave = false }
    }
}

struct AppSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var taskUpdates = true
    @State private var chatUpdates = true
    @State private var nearbyJobs = true

    var body: some View {
        @Bindable var notifications = appState.notificationService
        Form {
            Section {
                Picker(appState.locale.text(he: "שפה", ru: "Язык", en: "Language"), selection: Binding(
                    get: { appState.languagePreference },
                    set: { appState.languagePreference = $0 }
                )) {
                    ForEach(AppLanguagePreference.allCases) { preference in
                        Text(preference.title(in: appState.locale)).tag(preference)
                    }
                }
            } header: {
                Text(appState.locale.text(he: "שפה", ru: "Язык", en: "Language"))
            } footer: {
                Text(appState.locale.text(
                    he: "במצב iPhone האפליקציה משתמשת בעברית, אנגלית או רוסית לפי שפת המכשיר. בחירה ידנית נשמרת.",
                    ru: "В режиме iPhone приложение выбирает русский, английский или иврит по языку телефона. Ручной выбор сохраняется.",
                    en: "In iPhone mode, the app follows the device language when it is Hebrew, English, or Russian. A manual choice is saved."
                ))
            }
            Section {
                Toggle(isOn: Binding(
                    get: { appState.hasSmartSearchAIConsent },
                    set: { $0 ? appState.grantSmartSearchAIConsent() : appState.revokeSmartSearchAIConsent() }
                )) {
                    Label(
                        appState.locale.text(he: "חיפוש חכם עם AI", ru: "Умный поиск с ИИ", en: "Smart Search with AI"),
                        systemImage: "sparkles"
                    )
                }
                .tint(Brand.red)
            } header: {
                Text(appState.locale.text(he: "בינה מלאכותית ופרטיות", ru: "ИИ и приватность", en: "AI and privacy"))
            } footer: {
                Text(appState.locale.text(
                    he: "כשהאפשרות פעילה, טקסט החיפוש נשלח לשירות בינה מלאכותית של Cloudflare לצורך שיוך לקטגוריה. טלפונים, כתובות דוא״ל, קישורים ומספרי בית מוסרים לפני השליחה. בכיבוי, הקטלוג והבקשות ממשיכים לעבוד במלואם.",
                    ru: "Когда включено, текст поиска отправляется в сервис искусственного интеллекта Cloudflare для отнесения к категории. Телефоны, адреса почты, ссылки и номера домов удаляются до отправки. Если выключить, каталог и заявки продолжают работать полностью.",
                    en: "When on, the search text is sent to an AI service provided by Cloudflare to match a service category. Phone numbers, email addresses, links, and house numbers are removed before sending. When off, the catalog and requests keep working in full."
                ))
            }
            Section(appState.locale.text(he: "התראות", ru: "Уведомления", en: "Notifications")) {
                Toggle(appState.locale.text(he: "עדכוני בקשות והצעות", ru: "Заявки и предложения", en: "Requests and offers"), isOn: preferenceBinding(\.taskUpdates))
                Toggle(appState.locale.text(he: "הודעות בצ׳אט", ru: "Сообщения в чате", en: "Chat messages"), isOn: preferenceBinding(\.chatMessages))
                if appState.isProfessional {
                    Toggle(appState.locale.text(he: "עבודות חדשות באזור", ru: "Новые заявки рядом", en: "New nearby jobs"), isOn: preferenceBinding(\.nearbyJobs))
                }
                if notifications.permission != .allowed {
                    Button(appState.locale.text(he: "הפעלת התראות מערכת", ru: "Разрешить push-уведомления", en: "Enable push notifications")) {
                        Task { await notifications.requestPermission() }
                    }
                } else {
                    Label(appState.locale.text(he: "התראות מערכת מופעלות", ru: "Push-уведомления включены", en: "Push notifications enabled"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            Section(appState.locale.text(he: "פרטיות", ru: "Конфиденциальность", en: "Privacy")) {
                NavigationLink { SecuritySettingsView() } label: {
                    Label(
                        appState.locale.text(he: "אבטחה ו-Face ID", ru: "Безопасность и Face ID", en: "Security & Face ID"),
                        systemImage: "lock.shield.fill"
                    )
                }
                Text(appState.locale.text(he: "כתובת מדויקת ופרטי קשר אינם מוצגים בקטלוג הפומבי.", ru: "Точный адрес и контактные данные не показываются в открытом каталоге.", en: "Exact addresses and contact details are not shown in the public catalog."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(appState.locale.text(he: "הגדרות", ru: "Настройки", en: "Settings"))
        .task {
            await notifications.refreshStatus()
            await appState.loadNotificationPreferences()
            taskUpdates = appState.notificationPreferences.taskUpdates
            chatUpdates = appState.notificationPreferences.chatMessages
            nearbyJobs = appState.notificationPreferences.nearbyJobs
        }
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: {
                switch keyPath {
                case \.taskUpdates: taskUpdates
                case \.chatMessages: chatUpdates
                default: nearbyJobs
                }
            },
            set: { value in
                switch keyPath {
                case \.taskUpdates: taskUpdates = value
                case \.chatMessages: chatUpdates = value
                default: nearbyJobs = value
                }
                let preferences = NotificationPreferences(
                    taskUpdates: taskUpdates,
                    chatMessages: chatUpdates,
                    nearbyJobs: nearbyJobs
                )
                Task { await appState.saveNotificationPreferences(preferences) }
            }
        )
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Hands the exported file to the system share sheet so the person can keep it
/// wherever they want — Files, mail, another device.
private struct ExportedDataShareView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct ProfessionalOnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var categories: Set<String> = []
    @State private var categorySearch = ""
    @State private var city = ""
    @State private var bio = ""
    @State private var step = 0
    @State private var didLoad = false
    @State private var didSave = false

    private var isEditingExistingProfile: Bool { appState.isProfessional }
    private var filteredCategories: [ServiceCategory] {
        let query = categorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.serviceCatalog }
        return appState.serviceCatalog.filter {
            $0.title.value(for: appState.locale).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: isEditingExistingProfile ? "person.crop.circle.badge.checkmark" : "wrench.and.screwdriver.fill")
                        .font(.title2)
                        .foregroundStyle(Brand.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isEditingExistingProfile
                            ? appState.locale.text(he: "עריכת הפרופיל", ru: "Редактировать профиль", en: "Edit profile")
                            : appState.locale.text(he: "פרופיל בעל מקצוע", ru: "Профиль мастера", en: "Professional profile"))
                            .font(.title2.bold())
                        if !isEditingExistingProfile {
                            Text(appState.locale.text(
                                he: "שלב \(step + 1) מתוך 2 · כשתי דקות",
                                ru: "Шаг \(step + 1) из 2 · около двух минут",
                                en: "Step \(step + 1) of 2 · about two minutes"
                            ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                if !isEditingExistingProfile {
                    ProgressView(value: Double(step + 1), total: 2)
                        .tint(Brand.red)
                }
            }

            if step == 0 || isEditingExistingProfile {
                Section {
                    Text(appState.locale.text(
                        he: "בחרו את סוגי העבודות שאתם באמת מבצעים. אפשר לשנות אחר כך.",
                        ru: "Выберите работы, которые действительно выполняете. Позже список можно изменить.",
                        en: "Choose the work you actually do. You can change this later."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    TextField(appState.locale.text(he: "חיפוש תחום", ru: "Найти направление", en: "Find a trade"), text: $categorySearch)
                        .textInputAutocapitalization(.never)
                    ForEach(filteredCategories) { category in
                        Button {
                            if categories.contains(category.id) {
                                categories.remove(category.id)
                            } else if categories.count < SpecialistProfileLimits.maxCategories {
                                categories.insert(category.id)
                            }
                        } label: {
                            HStack {
                                Label(category.title.value(for: appState.locale), systemImage: category.systemImage)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if categories.contains(category.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.red)
                                }
                            }
                        }
                        .disabled(!categories.contains(category.id) && categories.count >= SpecialistProfileLimits.maxCategories)
                    }
                } header: {
                    Text(appState.locale.text(
                        he: "תחומים · \(categories.count)/\(SpecialistProfileLimits.maxCategories)",
                        ru: "Направления · \(categories.count)/\(SpecialistProfileLimits.maxCategories)",
                        en: "Trades · \(categories.count)/\(SpecialistProfileLimits.maxCategories)"
                    ))
                }
            }

            if step == 1 || isEditingExistingProfile {
                Section(appState.locale.text(he: "אזור העבודה", ru: "Город работы", en: "Service city")) {
                    CitySelectionRow(value: $city, title: appState.locale.text(he: "עיר", ru: "Город", en: "City"))
                    Text(appState.locale.text(
                        he: "בחרו עיר ראשית. תוכלו להרחיב אזור שירות בפרופיל אחר כך.",
                        ru: "Выберите основной город. Зону работы можно расширить в профиле позже.",
                        en: "Choose your main city. You can expand your service area later."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Section(appState.locale.text(he: "עליכם", ru: "О вас", en: "About you")) {
                    TextField(
                        appState.locale.text(he: "ניסיון, סוגי עבודות והתמחות", ru: "Опыт, виды работ и специализация", en: "Experience, work and specialties"),
                        text: $bio, axis: .vertical
                    )
                    .lineLimit(3...7)
                    Text(appState.locale.text(
                        he: "אפשר להשלים תיאור, תמונות ותיק עבודות גם אחרי ההרשמה.",
                        ru: "Описание, фото и портфолио можно дополнить после регистрации.",
                        en: "You can add a description, photos and a portfolio after joining."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    NavigationLink { ProfileSettingsView() } label: {
                        Label(appState.locale.text(he: "בדיקת שם וטלפון", ru: "Проверить имя и телефон", en: "Check name and phone"), systemImage: "person.text.rectangle")
                    }
                }
            }
            if didSave {
                Section {
                    Label(appState.locale.text(he: "הפרופיל נשמר", ru: "Профиль сохранён", en: "Profile saved"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    if step == 1 && !isEditingExistingProfile {
                        Button(appState.locale.text(he: "חזרה", ru: "Назад", en: "Back")) { step = 0 }
                            .buttonStyle(.bordered)
                    }
                    Button {
                        if step == 0 && !isEditingExistingProfile {
                            step = 1
                        } else {
                            Task {
                                let saved = await appState.saveProfessionalQuestionnaire(
                                    categories: Array(categories), city: city, bio: bio
                                )
                                didSave = saved
                                if saved { dismiss() }
                            }
                        }
                    } label: {
                        if appState.isWorking {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(isEditingExistingProfile
                                ? appState.locale.text(he: "שמירה", ru: "Сохранить", en: "Save")
                                : step == 0
                                    ? appState.locale.text(he: "המשך", ru: "Продолжить", en: "Continue")
                                    : appState.locale.text(he: "יצירת פרופיל", ru: "Создать профиль", en: "Create profile"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(BrandPrimaryButtonStyle())
                    .disabled(categories.isEmpty || ((step == 1 || isEditingExistingProfile) && city.isEmpty) || appState.isWorking)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(.regularMaterial)
        }
        .navigationTitle(isEditingExistingProfile
            ? appState.locale.text(he: "שאלון", ru: "Анкета", en: "Questionnaire")
            : appState.locale.text(he: "הצטרפות כבעל מקצוע", ru: "Стать мастером", en: "Join as a professional"))
        .task {
            guard !didLoad else { return }
            if isEditingExistingProfile {
                await appState.loadProfessionalProfile()
                if let specialist = appState.professionalProfile?.specialist {
                    categories = Set(specialist.categories)
                    city = specialist.city.value(for: appState.locale)
                    bio = specialist.bio.value(for: appState.locale)
                }
            }
            didLoad = true
        }
        .onChange(of: categories) { _, _ in didSave = false }
    }
}
