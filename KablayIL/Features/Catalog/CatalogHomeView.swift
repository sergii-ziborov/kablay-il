import SwiftUI
import UIKit

struct CatalogHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var triage: TriageResult?
    @State private var showAllCategories = false
    @State private var smartSearchCompleted = false
    @State private var showsAIConsent = false
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var visibleCategories: [ServiceCategory] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !smartSearchCompleted, !normalized.isEmpty else { return Array(appState.serviceCatalog.prefix(6)) }
        return appState.serviceCatalog.filter { category in
            category.title.value(for: appState.locale).lowercased().contains(normalized)
                || category.groups.flatMap(\.services).contains { $0.value(for: appState.locale).lowercased().contains(normalized) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                hero
                categorySection
                specialistsSection
                trustSection
            }
            .padding()
        }
        .background(Brand.canvas)
        .overlay(alignment: .bottomTrailing) {
            if searchFocused {
                Button {
                    dismissKeyboard()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Brand.navy, in: .circle)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                }
                .accessibilityLabel(appState.locale.text(he: "סגירת המקלדת", ru: "Свернуть клавиатуру", en: "Dismiss keyboard"))
                .padding(20)
                .transition(.scale(scale: 0.75).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: searchFocused)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            WorkspaceNavigationToolbar()
        }
        .navigationDestination(isPresented: $showAllCategories) { CategoryCatalogView() }
        .sheet(isPresented: $showsAIConsent) {
            SmartSearchAIConsentSheet { granted in
                showsAIConsent = false
                if granted {
                    appState.grantSmartSearchAIConsent()
                    classify()
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $triage) { result in
            TriageSuggestionSheet(result: result)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task { await appState.loadSpecialists() }
        .refreshable { await appState.loadSpecialists(force: true) }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appState.locale.text(
                he: "מוצאים בעל מקצוע לבית",
                ru: "Найдём мастера для дома",
                en: "Find the right home specialist"
            ))
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(Brand.ink)

            Text(appState.locale.text(
                he: "תארו מה קרה — החיפוש החכם יבחר את הקטגוריה המתאימה.",
                ru: "Опишите, что случилось — умный поиск подберёт категорию.",
                en: "Describe what happened and smart search will route the request."
            ))
            .font(.body)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .foregroundStyle(Brand.red)
                TextField(
                    appState.locale.text(he: "לדוגמה: יש נזילה מתחת לכיור", ru: "Например: течёт под раковиной", en: "For example: water under the sink"),
                    text: $query,
                    axis: .vertical
                )
                .lineLimit(1...3)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit { classify() }
                .onChange(of: query) { _, value in
                    if value.count > 600 { query = String(value.prefix(600)) }
                    smartSearchCompleted = false
                }
                if appState.isWorking { ProgressView().controlSize(.small) }
            }
            .padding()
            .background(Color(.systemBackground), in: .rect(cornerRadius: 17))
            .overlay { RoundedRectangle(cornerRadius: 17).stroke(Brand.border) }

            Text("\(query.count)/600")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Button {
                classify()
            } label: {
                Label(appState.locale.text(he: "חיפוש חכם", ru: "Умный поиск", en: "Smart search"), systemImage: "sparkles")
            }
            .buttonStyle(BrandPrimaryButtonStyle())
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 8 || appState.isWorking)
        }
        .padding()
        .background(
            LinearGradient(colors: [Color(.systemBackground), Brand.softRed], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 26)
        )
        .overlay { RoundedRectangle(cornerRadius: 26).stroke(Brand.border) }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                appState.locale.text(he: "קטגוריות", ru: "Категории", en: "Categories"),
                action: { showAllCategories = true }
            )
            OfflineFreshnessLabel(
                updatedAt: appState.serviceCatalogUpdatedAt,
                isSavedCopy: false,
                staleAfter: OfflineFreshness.serviceCatalog,
                locale: appState.locale
            )
            if visibleCategories.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleCategories) { category in
                        NavigationLink { CategoryDetailView(category: category) } label: {
                            CategoryTile(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var specialistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink { SpecialistDirectoryView() } label: {
                sectionHeader(appState.locale.text(he: "בעלי מקצוע מומלצים", ru: "Проверенные мастера", en: "Recommended specialists"))
            }
            .buttonStyle(.plain)
            OfflineFreshnessLabel(
                updatedAt: appState.specialistsUpdatedAt,
                isSavedCopy: appState.specialistsShowingSavedCopy,
                staleAfter: OfflineFreshness.specialists,
                locale: appState.locale
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(appState.specialists.prefix(8)) { specialist in
                        NavigationLink { SpecialistProfileView(specialist: specialist) } label: {
                            CompactSpecialistCard(specialist: specialist)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if appState.isLoadingSpecialists {
                ProgressView().frame(maxWidth: .infinity)
            } else if appState.specialists.isEmpty {
                ContentUnavailableView(
                    appState.specialistsLoadFailed
                        ? appState.locale.text(he: "אין בעלי מקצוע שמורים", ru: "Нет сохранённых мастеров", en: "No saved specialists")
                        : appState.locale.text(he: "אין בעלי מקצוע פעילים", ru: "Пока нет активных мастеров", en: "No active specialists yet"),
                    systemImage: "person.2.slash",
                    description: Text(appState.locale.text(
                        he: appState.specialistsLoadFailed ? "התחברו פעם אחת כדי לשמור את הקטלוג במכשיר." : "בעלי מקצוע יופיעו כאן כשהפרופילים שלהם יהיו פעילים.",
                        ru: appState.specialistsLoadFailed ? "Подключитесь один раз, чтобы сохранить каталог на устройстве." : "Мастера появятся здесь, когда их профили станут активными.",
                        en: appState.specialistsLoadFailed ? "Connect once to save the catalog on this device." : "Specialists appear here when their profiles become active."
                    ))
                )
            }
        }
    }

    private var trustSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(appState.locale.text(he: "למה KABLAY", ru: "Почему KABLAY", en: "Why KABLAY"), systemImage: "checkmark.shield.fill")
                .font(.title2).fontWeight(.bold)
            trustRow("person.badge.shield.checkmark", appState.locale.text(he: "פרופילים עם בדיקות ברורות", ru: "Понятные статусы проверки профиля", en: "Clear profile verification statuses"))
            trustRow("star.bubble.fill", appState.locale.text(he: "ביקורות רק אחרי עבודה", ru: "Отзывы только после выполненной работы", en: "Reviews only after completed work"))
            trustRow("bubble.left.and.bubble.right.fill", appState.locale.text(he: "הצעות ושיחה במקום אחד", ru: "Предложения и чат в одном месте", en: "Offers and chat in one place"))
        }
        .padding()
        .brandCard()
    }

    private func sectionHeader(_ title: String, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title).font(.title2).fontWeight(.bold).foregroundStyle(Brand.ink)
            Spacer()
            if let action {
                Button(appState.locale.text(he: "הכל", ru: "Все", en: "All"), action: action)
                    .font(.subheadline).fontWeight(.semibold)
            } else {
                Image(systemName: appState.locale.layoutDirection == .rightToLeft ? "chevron.left" : "chevron.right")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }

    private func trustRow(_ image: String, _ text: String) -> some View {
        Label(text, systemImage: image)
            .font(.body)
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.hierarchical)
    }

    private func classify() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 8 else { return }
        // Smart Search is the only feature that hands text to a third-party AI
        // service, so the first use explains that and asks. The catalog works
        // exactly the same either way.
        guard appState.hasSmartSearchAIConsent else {
            dismissKeyboard()
            showsAIConsent = true
            return
        }
        dismissKeyboard()
        smartSearchCompleted = false
        appState.taskDraft = TaskDraft()
        appState.taskDraft.title = text
        appState.requestEntryMode = .direct
        withAnimation(.easeOut(duration: 0.14)) { triage = nil }
        Task {
            let result = await appState.classifyTask(text)
            smartSearchCompleted = result != nil
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) { triage = result }
            if result != nil { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
    }

    private func dismissKeyboard() {
        searchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// The disclosure Apple 5.1.2 expects before personal data reaches a third
/// party, including a third-party AI service. It is shown once, before the
/// first Smart Search, and can be withdrawn later in Settings.
private struct SmartSearchAIConsentSheet: View {
    @Environment(AppState.self) private var appState
    let onDecision: (Bool) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label(
                        appState.locale.text(he: "חיפוש חכם ובינה מלאכותית", ru: "Умный поиск и ИИ", en: "Smart Search and AI"),
                        systemImage: "sparkles"
                    )
                    .font(.title2.bold())
                    .foregroundStyle(Brand.red)

                    Text(appState.locale.text(
                        he: "החיפוש החכם שולח את הטקסט שכתבתם לשירות בינה מלאכותית של Cloudflare, רק כדי לשייך אותו לקטגוריית שירות. אותו אישור חל גם על כפתור התרגום של תיאור עבודה או הודעה.",
                        ru: "Умный поиск отправляет написанный вами текст в сервис искусственного интеллекта Cloudflare — только чтобы отнести его к категории услуги. Это же разрешение распространяется на кнопку перевода описания заявки или сообщения.",
                        en: "Smart Search sends the text you write to an AI service provided by Cloudflare, only to match it to a service category. The same permission covers the button that translates a job description or a message."
                    ))
                    .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        bullet(
                            "text.alignleft",
                            appState.locale.text(
                                he: "נשלח רק הטקסט שהקלדתם. לא נשלחים שם, טלפון, חשבון או מיקום מדויק.",
                                ru: "Отправляется только введённый текст. Имя, телефон, аккаунт и точная геопозиция не отправляются.",
                                en: "Only the text you typed is sent. Name, phone, account, and exact location are not."
                            )
                        )
                        bullet(
                            "eraser",
                            appState.locale.text(
                                he: "מספרי טלפון, כתובות דוא״ל, קישורים ומספרי בית מוסרים מהטקסט לפני השליחה.",
                                ru: "Телефоны, адреса почты, ссылки и номера домов удаляются из текста до отправки.",
                                en: "Phone numbers, email addresses, links, and house numbers are removed before sending."
                            )
                        )
                        bullet(
                            "square.grid.2x2",
                            appState.locale.text(
                                he: "אם תבחרו לא להסכים, הקטלוג והבקשות עובדים במלואם.",
                                ru: "Если не согласиться, каталог и заявки работают полностью.",
                                en: "If you decline, the catalog and requests keep working in full."
                            )
                        )
                        bullet(
                            "arrow.uturn.backward",
                            appState.locale.text(
                                he: "אפשר לבטל את ההסכמה בכל רגע בהגדרות.",
                                ru: "Согласие можно отозвать в любой момент в настройках.",
                                en: "You can withdraw this at any time in Settings."
                            )
                        )
                    }

                    NavigationLink { LegalDocumentView(document: .privacy) } label: {
                        Label(
                            appState.locale.text(he: "מדיניות פרטיות", ru: "Политика конфиденциальности", en: "Privacy Policy"),
                            systemImage: "hand.raised.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                    }

                    VStack(spacing: 10) {
                        Button(appState.locale.text(he: "הסכמה והמשך", ru: "Согласиться и продолжить", en: "Agree and continue")) {
                            onDecision(true)
                        }
                        .buttonStyle(BrandPrimaryButtonStyle())

                        Button(appState.locale.text(he: "לא עכשיו", ru: "Не сейчас", en: "Not now")) {
                            onDecision(false)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Brand.canvas)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func bullet(_ image: String, _ text: String) -> some View {
        Label(text, systemImage: image)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.hierarchical)
    }
}

private struct CategoryTile: View {
    @Environment(AppState.self) private var appState
    let category: ServiceCategory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CategoryCoverImage(category: category)
                .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                .clipped()

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.12), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: category.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 9))
                Text(category.title.value(for: appState.locale))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(appState.locale == .he ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            }
            .padding(13)
        }
        .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156, alignment: .bottomLeading)
        .background(Brand.card)
        .clipShape(.rect(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Brand.border) }
        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
    }
}

private struct CompactSpecialistCard: View {
    @Environment(AppState.self) private var appState
    let specialist: Specialist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                SpecialistAvatar(specialist: specialist, size: 44)
                    .overlay(alignment: .bottomTrailing) {
                        if specialist.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .background(Color(.systemBackground), in: .circle)
                        }
                    }
                Spacer()
                if specialist.premium {
                    Label("Premium", systemImage: "crown.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Brand.red)
                        .labelStyle(.titleAndIcon)
                }
            }
            Text(specialist.name)
                .font(.headline)
                .foregroundStyle(Brand.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(specialist.profession.value(for: appState.locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                Text(String(format: "%.1f", specialist.rating)).monospacedDigit()
                Text("·")
                Text("\(specialist.reviewCount)")
                    .monospacedDigit()
                Image(systemName: "text.bubble")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.orange)
        }
        .padding(14)
        .frame(width: 172, alignment: .topLeading)
        .brandCard()
    }
}

private struct TriageSuggestionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let result: TriageResult

    private var category: ServiceCategory? { appState.serviceCatalog.first { $0.id == result.category } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Brand.red, in: .rect(cornerRadius: 16))
                        .symbolEffect(.bounce, value: result.id)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.locale.text(he: "מצאנו את השירות", ru: "Мы нашли нужную услугу", en: "We found the right service"))
                            .font(.title2.weight(.bold))
                        Text(appState.locale.text(
                            he: "בדקו את הבחירה והמשיכו לבקשה שכבר מולאה.",
                            ru: "Проверьте выбор и продолжите к уже заполненной заявке.",
                            en: "Review the match and continue to the pre-filled request."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    if let category {
                        Label(category.title.value(for: appState.locale), systemImage: category.systemImage)
                            .font(.headline)
                            .foregroundStyle(Color(hex: category.tintHex))
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .foregroundStyle(.secondary)
                        Text(result.serviceTitle ?? result.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Brand.ink)
                    }
                    StatusPill(title: result.confident ? appState.locale.text(he: "התאמה טובה", ru: "Точное совпадение", en: "Good match") : appState.locale.text(he: "כדאי לבדוק", ru: "Проверьте выбор", en: "Review match"))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20))

                if let safety = result.safety {
                    Label(safety, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.orange)
                }

                Spacer(minLength: 0)

                Button {
                    appState.requestEntryMode = .routed
                    appState.clientTab = .request
                    dismiss()
                } label: {
                    Label(appState.locale.text(he: "המשך לבקשה", ru: "Перейти к заявке", en: "Continue to request"), systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(BrandPrimaryButtonStyle())

                Button {
                    appState.requestEntryMode = .routed
                    appState.clientTab = .request
                    dismiss()
                } label: {
                    Text(appState.locale.text(he: "שינוי קטגוריה או שירות", ru: "Изменить категорию или услугу", en: "Change category or service"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(22)
            .background(Brand.canvas)
            .navigationTitle(appState.locale.text(he: "הצעת חיפוש", ru: "Результат поиска", en: "Search result"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }
}
