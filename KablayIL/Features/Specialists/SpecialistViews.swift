import SwiftUI

enum SpecialistProfilePresentation: String, Hashable {
    case directory
    case ownerPreview

    var loadsPublicDetails: Bool { self == .directory }
    var allowsDirectRequest: Bool { self == .directory }
}

struct SpecialistDirectoryView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var selectedCategory: String?

    init(categoryID: String? = nil) {
        _selectedCategory = State(initialValue: categoryID)
    }

    private var specialists: [Specialist] {
        appState.specialists.filter { specialist in
            let categoryMatches = selectedCategory == nil || specialist.categories.contains(selectedCategory!)
            let queryMatches = query.isEmpty
                || specialist.name.localizedCaseInsensitiveContains(query)
                || specialist.profession.value(for: appState.locale).localizedCaseInsensitiveContains(query)
                || specialist.city.value(for: appState.locale).localizedCaseInsensitiveContains(query)
            return categoryMatches && queryMatches
        }
    }

    var body: some View {
        List {
            if appState.specialistsUpdatedAt != nil {
                OfflineFreshnessLabel(
                    updatedAt: appState.specialistsUpdatedAt,
                    isSavedCopy: appState.specialistsShowingSavedCopy,
                    staleAfter: OfflineFreshness.specialists,
                    locale: appState.locale
                )
                .listRowSeparator(.hidden)
            }
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        categoryButton(nil, title: appState.locale.text(he: "הכל", ru: "Все", en: "All"))
                        ForEach(appState.serviceCatalog) { category in
                            categoryButton(category.id, title: category.title.value(for: appState.locale))
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            ForEach(specialists) { specialist in
                NavigationLink { SpecialistProfileView(specialist: specialist) } label: {
                    SpecialistRow(specialist: specialist)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: appState.locale.text(he: "שם, מקצוע או עיר", ru: "Имя, профессия или город", en: "Name, trade, or city"))
        .navigationTitle(appState.locale.text(he: "בעלי מקצוע", ru: "Мастера", en: "Specialists"))
        .overlay {
            if appState.isLoadingSpecialists, appState.specialists.isEmpty {
                ProgressView()
            } else if specialists.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .task { await appState.loadSpecialists() }
        .refreshable { await appState.loadSpecialists(force: true) }
    }

    private func categoryButton(_ id: String?, title: String) -> some View {
        Button(title) { selectedCategory = id }
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(selectedCategory == id ? Color.white : Brand.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selectedCategory == id ? Brand.navy : Color(.systemBackground), in: .capsule)
            .overlay { Capsule().stroke(Brand.border) }
    }
}

private struct SpecialistRow: View {
    @Environment(AppState.self) private var appState
    let specialist: Specialist

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SpecialistAvatar(specialist: specialist)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(specialist.name).font(.headline)
                    if specialist.verified { Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue) }
                    if specialist.premium { StatusPill(title: "Premium", color: Brand.red) }
                }
                Text(specialist.profession.value(for: appState.locale)).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Label(String(format: "%.1f", specialist.rating), systemImage: "star.fill").foregroundStyle(.orange)
                    Text("\(specialist.reviewCount) " + appState.locale.text(he: "ביקורות", ru: "отзывов", en: "reviews"))
                    if specialist.availableNow {
                        StatusPill(title: appState.locale.text(he: "זמין", ru: "Свободен", en: "Available"), color: .green)
                    }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 6)
    }
}

struct SpecialistProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    let specialist: Specialist
    let presentation: SpecialistProfilePresentation
    @State private var showTask = false
    @State private var details: SpecialistProfileDetails?
    @State private var isLoadingDetails = false
    @State private var revealedPhone: String?
    @State private var selectedPhoto: GalleryPhoto?
    @State private var selectedProject: SpecialistProject?
    @State private var showReport = false
    @State private var showBlockConfirmation = false

    init(
        specialist: Specialist,
        presentation: SpecialistProfilePresentation = .directory
    ) {
        self.specialist = specialist
        self.presentation = presentation
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if presentation == .ownerPreview {
                    ownerPreviewNotice
                }
                header
                verification
                if presentation == .directory {
                    contacts
                }
                about
                portfolio
                services
                reviews
                responsibility
            }
            .padding()
        }
        .background(Brand.canvas)
        .navigationTitle(specialist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentation == .directory {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showReport = true } label: {
                            Label(appState.locale.text(he: "דיווח", ru: "Пожаловаться", en: "Report"), systemImage: "exclamationmark.bubble")
                        }
                        Button(role: .destructive) { showBlockConfirmation = true } label: {
                            Label(appState.locale.text(he: "חסימה", ru: "Заблокировать", en: "Block"), systemImage: "hand.raised.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel(appState.locale.text(he: "אפשרויות", ru: "Действия", en: "Actions"))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if presentation.allowsDirectRequest {
                Button {
                    appState.taskDraft.categoryID = specialist.categories.first ?? "handyman"
                    appState.taskDraft.answers["targetSpecialistId"] = specialist.id
                    showTask = true
                } label: {
                    Text(appState.locale.text(he: "שליחת בקשה לבעל המקצוע", ru: "Отправить заявку мастеру", en: "Send request to specialist"))
                }
                .buttonStyle(BrandPrimaryButtonStyle())
                .padding()
                .background(.bar)
            }
        }
        .navigationDestination(isPresented: $showTask) { TaskWizardView(targetSpecialist: specialist) }
        .sheet(item: $selectedProject) { project in
            ProjectGallerySheet(project: project, locale: appState.locale)
        }
        .sheet(isPresented: $showReport) {
            SpecialistReportSheet(specialistID: specialist.id, specialistName: specialist.name)
        }
        .confirmationDialog(
            appState.locale.text(he: "לחסום את בעל המקצוע?", ru: "Заблокировать специалиста?", en: "Block this specialist?"),
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.locale.text(he: "חסימה", ru: "Заблокировать", en: "Block"), role: .destructive) {
                Task {
                    if await appState.blockSpecialist(id: specialist.id) { dismiss() }
                }
            }
            Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(appState.locale.text(
                he: "לא תוכלו ליצור קשר או להחליף הודעות חדשות. היסטוריית עבודות וראיות תישמר.",
                ru: "Новые контакты и сообщения будут запрещены. История работ и материалы сохранятся.",
                en: "New contact and messages will be blocked. Job history and evidence stay preserved."
            ))
        }
        .fullScreenCover(item: $selectedPhoto) { item in
            NavigationStack {
                ZoomablePortfolioPhoto(url: item.url)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(appState.locale.text(he: "סגירה", ru: "Закрыть", en: "Close")) {
                                selectedPhoto = nil
                            }
                        }
                    }
            }
        }
        .task(id: "\(specialist.id)-\(presentation.rawValue)") {
            guard presentation.loadsPublicDetails else { return }
            isLoadingDetails = true
            // The list card is already valid content. A stale replica or a
            // profile being paused while this screen opens must not cover it
            // with a global error alert; optional details degrade in place.
            details = await appState.loadSpecialistDetails(
                id: specialist.id,
                reportFailure: false
            )
            isLoadingDetails = false
        }
    }

    private var ownerPreviewNotice: some View {
        Label {
            Text(appState.locale.text(
                he: "זוהי תצוגה מקדימה של הפרופיל שלך. פעולות יצירת קשר ושליחת בקשה מוסתרות עבורך ומופיעות ללקוחות בהתאם להגדרות הפרסום.",
                ru: "Это предпросмотр вашего профиля. Контакты и отправка заявки скрыты для владельца и показываются клиентам согласно настройкам публикации.",
                en: "This is your profile preview. Contact and request actions are hidden from the owner and shown to clients according to publishing settings."
            ))
        } icon: {
            Image(systemName: "eye.fill")
        }
        .font(.subheadline)
        .foregroundStyle(Brand.ink)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.red.opacity(0.1), in: .rect(cornerRadius: 18))
        .accessibilityIdentifier("specialist-owner-preview-notice")
    }

    private var header: some View {
        VStack(spacing: 14) {
            SpecialistAvatar(specialist: specialist, size: 88)
            HStack(spacing: 6) {
                Text(specialist.name).font(.title).fontWeight(.bold)
                if specialist.verified { Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue) }
            }
            if specialist.premium { StatusPill(title: "Premium", color: Brand.red) }
            Text(specialist.profession.value(for: appState.locale)).foregroundStyle(.secondary)
            if specialist.availableNow {
                StatusPill(title: appState.locale.text(he: "מקבל עבודות עכשיו", ru: "Принимает заказы сейчас", en: "Accepting jobs now"), color: .green)
            }
            HStack(spacing: 0) {
                stat(String(format: "%.1f", specialist.rating), appState.locale.text(he: "דירוג", ru: "Рейтинг", en: "Rating"))
                Rectangle().fill(Color(.separator)).frame(width: 1, height: 38)
                stat("\(specialist.reviewCount)", appState.locale.text(he: "ביקורות", ru: "Отзывы", en: "Reviews"))
                Rectangle().fill(Color(.separator)).frame(width: 1, height: 38)
                stat("\(specialist.completedJobs)", appState.locale.text(he: "עבודות", ru: "Работ", en: "Jobs"))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .brandCard()
    }

    private var verification: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.locale.text(he: "בדיקות", ru: "Проверки", en: "Verification")).font(.headline)
            trustRow(
                specialist.trust.phoneVerified,
                appState.locale.text(he: "מספר טלפון אומת", ru: "Телефон подтверждён", en: "Phone verified"),
                appState.locale.text(he: "מספר טלפון לא אומת", ru: "Телефон не подтверждён", en: "Phone not verified")
            )
            trustRow(
                specialist.trust.portfolioVerified,
                appState.locale.text(he: "תיק עבודות נבדק", ru: "Портфолио проверено", en: "Portfolio reviewed"),
                appState.locale.text(he: "תיק עבודות לא נבדק", ru: "Портфолио не проверено", en: "Portfolio not reviewed")
            )
            trustRow(
                specialist.trust.reviewsVerified,
                appState.locale.text(he: "ביקורות נבדקו", ru: "Отзывы проверены", en: "Reviews verified"),
                appState.locale.text(he: "ביקורות לא נבדקו", ru: "Отзывы не проверены", en: "Reviews not verified")
            )
            trustRow(
                specialist.trust.licenseVerified,
                appState.locale.text(he: "רישיון אומת", ru: "Лицензия проверена", en: "License verified"),
                appState.locale.text(he: "רישיון לא אומת", ru: "Лицензия не проверена", en: "License not verified")
            )
            trustRow(
                specialist.trust.insuranceVerified,
                appState.locale.text(he: "ביטוח אומת", ru: "Страховка проверена", en: "Insurance verified"),
                appState.locale.text(he: "ביטוח לא אומת", ru: "Страховка не проверена", en: "Insurance not verified")
            )
            Text(appState.locale.text(
                he: "תגים מתארים רק את הבדיקה המוצגת ואינם ערובה לאיכות. לעבודות מוסדרות יש לבדוק רישיון תקף במרשם הרשמי.",
                ru: "Бейджи отражают только указанную проверку и не гарантируют качество. Для регулируемых работ проверьте действующую лицензию в официальном реестре.",
                en: "Badges describe only the check shown and do not guarantee quality. For regulated work, verify a current license in the official register."
            ))
            .font(.footnote).foregroundStyle(.secondary)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).brandCard()
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(Brand.ink)
    }

    private func trustRow(_ verified: Bool, _ verifiedTitle: String, _ unverifiedTitle: String) -> some View {
        Label(verified ? verifiedTitle : unverifiedTitle, systemImage: verified ? "checkmark.circle.fill" : "minus.circle")
            .foregroundStyle(verified ? Color.green : Color.secondary)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.locale.text(he: "על בעל המקצוע", ru: "О мастере", en: "About")).font(.title3).fontWeight(.bold)
            Text(specialist.bio.value(for: appState.locale)).foregroundStyle(.secondary)
            if specialist.yearsExperience > 0 {
                Label("\(specialist.yearsExperience) " + appState.locale.text(he: "שנות ניסיון", ru: "лет опыта", en: "years of experience"), systemImage: "briefcase.fill")
                    .font(.subheadline)
            }
            Label(specialist.city.value(for: appState.locale), systemImage: "mappin.and.ellipse")
                .font(.subheadline)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).brandCard()
    }

    @ViewBuilder
    private var contacts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.locale.text(he: "יצירת קשר", ru: "Контакты", en: "Contact"))
                .font(.title3).fontWeight(.bold)
            if isLoadingDetails {
                ProgressView()
            } else if details?.contactAvailable == true || details?.whatsappAvailable == true {
                if let revealedPhone {
                    Text(revealedPhone)
                        .font(.title3.monospacedDigit()).fontWeight(.semibold)
                        .textSelection(.enabled)
                    HStack {
                        if let callURL = telephoneURL(revealedPhone) {
                            Link(destination: callURL) {
                                Label(appState.locale.text(he: "שיחה", ru: "Позвонить", en: "Call"), systemImage: "phone.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            openWhatsApp(phone: revealedPhone)
                        } label: {
                            Label("WhatsApp", systemImage: "message.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                } else {
                    Button {
                        revealContact(forWhatsApp: false)
                    } label: {
                        Label(appState.locale.text(he: "הצגת מספר", ru: "Показать телефон", en: "Reveal phone"), systemImage: "phone.badge.checkmark")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        revealContact(forWhatsApp: true)
                    } label: {
                        Label(appState.locale.text(he: "פתיחה ב-WhatsApp", ru: "Открыть WhatsApp", en: "Open WhatsApp"), systemImage: "message.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    Text(appState.locale.text(
                        he: "המספר נפתח רק לאחר לחיצה ונרשמת פנייה לבעל המקצוע.",
                        ru: "Номер раскрывается только по нажатию; обращение учитывается мастеру.",
                        en: "The number is revealed only after you tap; the contact is recorded for the specialist."
                    ))
                    .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Label(
                    appState.locale.text(he: "בעל המקצוע לא פתח אנשי קשר ישירים.", ru: "Мастер не открыл прямые контакты.", en: "The specialist has not enabled direct contact."),
                    systemImage: "lock.fill"
                )
                .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).brandCard()
    }

    @ViewBuilder
    private var portfolio: some View {
        let projects = details?.portfolioProjects ?? specialist.portfolioProjects
        let allPhotos = details?.portfolioURLs ?? specialist.portfolioURLs
        let projectPhotoIDs = Set(projects.flatMap(\.photoURLs).map(\.absoluteString))
        let loosePhotos = allPhotos.filter { !projectPhotoIDs.contains($0.absoluteString) }
        if !projects.isEmpty || !loosePhotos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(appState.locale.text(he: "גלריית פרויקטים", ru: "Галерея проектов", en: "Project gallery"))
                        .font(.title3).fontWeight(.bold)
                    Spacer()
                    Text(projects.isEmpty
                         ? "\(loosePhotos.count)"
                         : "\(projects.count) " + appState.locale.text(he: "פרויקטים", ru: "проектов", en: "projects"))
                        .font(.caption).foregroundStyle(.secondary)
                }

                if !projects.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(projects) { project in
                                Button { selectedProject = project } label: {
                                    OfflineImage(url: project.displayCoverURL) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else if phase.error != nil || project.displayCoverURL == nil {
                                            Image(systemName: "photo.on.rectangle.angled")
                                                .font(.largeTitle)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            ProgressView()
                                        }
                                    }
                                    .frame(width: 244, height: 164)
                                    .background(Color(.tertiarySystemBackground))
                                    .overlay(alignment: .bottomLeading) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(project.title)
                                                .font(.headline)
                                                .lineLimit(2)
                                            Label(
                                                "\(project.photoURLs.count) " + appState.locale.text(he: "תמונות", ru: "фото", en: "photos"),
                                                systemImage: "photo.stack.fill"
                                            )
                                            .font(.caption)
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                colors: [.clear, .black.opacity(0.82)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    }
                                    .clipShape(.rect(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(project.title)
                                .accessibilityHint(appState.locale.text(he: "פתיחת הפרויקט", ru: "Открыть проект", en: "Open project"))
                                .accessibilityIdentifier("specialist-project-\(project.id)")
                            }
                        }
                    }
                }

                if !loosePhotos.isEmpty {
                    if !projects.isEmpty {
                        Text(appState.locale.text(he: "עבודות נוספות", ru: "Другие работы", en: "Other work"))
                            .font(.headline)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(loosePhotos, id: \.absoluteString) { url in
                                Button { selectedPhoto = GalleryPhoto(url: url) } label: {
                                    PortfolioThumbnail(url: url)
                                        .frame(width: 164, height: 124)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
            .brandCard()
            .accessibilityIdentifier("specialist-project-gallery")
        }
    }

    private var services: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.locale.text(he: "שירותים", ru: "Услуги", en: "Services")).font(.title3).fontWeight(.bold)
            FlowLayout(layoutDirection: appState.locale.layoutDirection) {
                ForEach(specialist.categories, id: \.self) { id in
                    if let category = appState.serviceCatalog.first(where: { $0.id == id }) {
                        Label(category.title.value(for: appState.locale), systemImage: category.systemImage)
                            .font(.subheadline).padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground), in: .capsule)
                    }
                }
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).brandCard()
    }

    private var reviews: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.locale.text(he: "ביקורות לקוחות", ru: "Отзывы клиентов", en: "Client reviews")).font(.title3).fontWeight(.bold)
            if let reviews = details?.reviews, !reviews.isEmpty {
                ForEach(Array(reviews.prefix(5).enumerated()), id: \.element.id) { index, review in
                    if index > 0 { Divider() }
                    ReviewQuote(review: review)
                }
            } else if presentation == .ownerPreview, specialist.reviewCount > 0 {
                Label(
                    "\(specialist.reviewCount) " + appState.locale.text(he: "ביקורות בדירוג הציבורי", ru: "отзывов учтено в публичном рейтинге", en: "reviews included in the public rating"),
                    systemImage: "star.bubble.fill"
                )
                .foregroundStyle(.secondary)
            } else if !isLoadingDetails {
                Text(appState.locale.text(he: "עדיין אין ביקורות מאומתות.", ru: "Проверенных отзывов пока нет.", en: "No verified reviews yet."))
                    .foregroundStyle(.secondary)
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).brandCard()
    }

    private var responsibility: some View {
        Label {
            Text(appState.locale.text(he: "KABLAY היא פלטפורמת חיבור ואינה צד להסכם העבודה.", ru: "KABLAY — площадка для связи и не является стороной договора на работы.", en: "KABLAY is a connection platform and is not a party to the work agreement."))
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote).foregroundStyle(.secondary).padding()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack { Text(value).font(.headline); Text(label).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity)
    }

    private func revealContact(forWhatsApp: Bool) {
        Task {
            guard let phone = await appState.revealSpecialistContact(id: specialist.id, forWhatsApp: forWhatsApp) else { return }
            revealedPhone = phone
            if forWhatsApp { openWhatsApp(phone: phone) }
        }
    }

    private func telephoneURL(_ phone: String) -> URL? {
        URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })")
    }

    private func openWhatsApp(phone: String) {
        let digits = phone.filter(\.isNumber)
        guard let url = URL(string: "https://wa.me/\(digits)") else { return }
        openURL(url)
    }
}

private struct ReviewQuote: View {
    @Environment(AppState.self) private var appState
    let review: SpecialistReview
    @State private var showReport = false
    @State private var showBlockConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(review.author).font(.headline)
                Spacer()
                Label(String(format: "%.1f", review.rating), systemImage: "star.fill").foregroundStyle(.orange).font(.caption)
                if appState.isAuthenticated {
                    Menu {
                        Button { showReport = true } label: {
                            Label(appState.locale.text(he: "דיווח", ru: "Пожаловаться", en: "Report"), systemImage: "exclamationmark.bubble")
                        }
                        Button(role: .destructive) { showBlockConfirmation = true } label: {
                            Label(appState.locale.text(he: "חסימת המחבר", ru: "Заблокировать автора", en: "Block author"), systemImage: "hand.raised.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel(appState.locale.text(he: "פעולות ביקורת", ru: "Действия с отзывом", en: "Review actions"))
                }
            }
            Text(review.text).foregroundStyle(.secondary)
            if let createdAt = review.createdAt {
                Text(createdAt, style: .date).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $showReport) {
            ContentModerationSheet(
                targetType: "review",
                targetID: review.id,
                title: appState.locale.text(he: "דיווח על ביקורת", ru: "Жалоба на отзыв", en: "Report review")
            )
        }
        .confirmationDialog(
            appState.locale.text(he: "לחסום את מחבר הביקורת?", ru: "Заблокировать автора отзыва?", en: "Block the review author?"),
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.locale.text(he: "חסימה", ru: "Заблокировать", en: "Block"), role: .destructive) {
                Task { _ = await appState.blockContent(targetType: "review", targetID: review.id) }
            }
            Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel"), role: .cancel) { }
        }
    }
}

private struct SpecialistReportSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let specialistID: String
    let specialistName: String
    @State private var reason = "spam"
    @State private var details = ""
    @State private var isSubmitting = false

    private var reasons: [(String, String)] {
        [
            ("spam", appState.locale.text(he: "ספאם או פרסום", ru: "Спам или реклама", en: "Spam or advertising")),
            ("fraud", appState.locale.text(he: "חשד להונאה", ru: "Подозрение на мошенничество", en: "Suspected fraud")),
            ("abuse", appState.locale.text(he: "התנהגות פוגענית", ru: "Оскорбительное поведение", en: "Abusive behavior")),
            ("unsafe", appState.locale.text(he: "סכנה או עבודה לא בטוחה", ru: "Опасность или небезопасная работа", en: "Safety concern")),
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
                Section {
                    Text(appState.locale.text(
                        he: "הדיווח ייבדק על ידי צוות KABLAY ולא יוצג לבעל המקצוע.",
                        ru: "Команда KABLAY проверит жалобу; мастеру она не показывается.",
                        en: "KABLAY will review the report. It is not shown to the specialist."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(appState.locale.text(he: "דיווח על \(specialistName)", ru: "Жалоба на \(specialistName)", en: "Report \(specialistName)"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.locale.text(he: "שליחה", ru: "Отправить", en: "Submit")) {
                        Task {
                            isSubmitting = true
                            if await appState.reportSpecialist(id: specialistID, reason: reason, details: details) {
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

private struct GalleryPhoto: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct PortfolioThumbnail: View {
    let url: URL

    var body: some View {
        OfflineImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else if phase.error != nil {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.tertiarySystemBackground))
        .clipShape(.rect(cornerRadius: 14))
        .contentShape(.rect)
    }
}

private struct ProjectGallerySheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: SpecialistProject
    let locale: AppLocale
    @State private var selectedPhoto: GalleryPhoto?

    private let columns = [
        GridItem(.adaptive(minimum: 136, maximum: 220), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(project.photoURLs.enumerated()), id: \.element.absoluteString) { index, url in
                        Button { selectedPhoto = GalleryPhoto(url: url) } label: {
                            PortfolioThumbnail(url: url)
                                .frame(maxWidth: .infinity)
                                .frame(height: 132)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            locale.text(
                                he: "תמונה \(index + 1) מתוך \(project.photoURLs.count)",
                                ru: "Фото \(index + 1) из \(project.photoURLs.count)",
                                en: "Photo \(index + 1) of \(project.photoURLs.count)"
                            )
                        )
                        .accessibilityIdentifier("project-photo-\(index)")
                    }
                }
                .padding()
            }
            .background(Brand.canvas)
            .navigationTitle(project.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(locale.text(he: "סגירה", ru: "Закрыть", en: "Close"))
                }
            }
        }
        .fullScreenCover(item: $selectedPhoto) { item in
            NavigationStack {
                ZoomablePortfolioPhoto(url: item.url)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(locale.text(he: "סגירה", ru: "Закрыть", en: "Close")) {
                                selectedPhoto = nil
                            }
                        }
                    }
            }
        }
    }
}

struct ZoomablePortfolioPhoto: View {
    let url: URL

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                OfflineImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        ContentUnavailableView("Photo unavailable", systemImage: "photo.badge.exclamationmark")
                    } else {
                        ProgressView()
                    }
                }
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            }
        }
        .background(Color.black)
    }
}
