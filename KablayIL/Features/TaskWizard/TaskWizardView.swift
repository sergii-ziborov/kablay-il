import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct TaskWizardView: View {
    private enum FocusedField: Hashable {
        case title
        case details
        case city
        case address
        case budget
        case question(String)
    }

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    let targetSpecialist: Specialist?
    @State private var step = 0
    @State private var showLogin = false
    @State private var triageQuestions: [String] = []
    @State private var showSmartConfirmation = false
    @State private var showAllServices = false
    @State private var validationMessage: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoPreviews: [TaskPhotoPreview] = []
    @State private var locationSearch = LocationSearchService()
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.6, longitude: 34.85),
            span: MKCoordinateSpan(latitudeDelta: 5.1, longitudeDelta: 3.4)
        )
    )
    @FocusState private var focusedField: FocusedField?

    init(targetSpecialist: Specialist? = nil) {
        self.targetSpecialist = targetSpecialist
    }

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            wizardHeader
            TabView(selection: $step) {
                descriptionStep(state: $state).tag(0)
                locationStep(state: $state).tag(1)
                reviewStep(state: $state).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: step)
        }
        .background(Brand.canvas)
        .navigationTitle(appState.locale.text(he: "בקשה חדשה", ru: "Новая заявка", en: "New request"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actionBar }
        .sheet(isPresented: $showLogin) { PhoneLoginView() }
        .sheet(isPresented: $showAllServices) {
            ServiceAutocompleteView(options: allServiceOptions) { option in
                selectService(option)
                showAllServices = false
            }
            .environment(appState)
        }
        .toolbar {
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
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated, step == 2 { publish() }
        }
        .onChange(of: appState.taskDraft) { _, _ in validationMessage = nil }
        .onChange(of: selectedPhotoItems) { _, items in
            Task { await loadPhotoPreviews(from: items) }
        }
        .onAppear {
            showSmartConfirmation = appState.taskDraft.answers["selectedService"] != nil
            if showSmartConfirmation { appState.requestEntryMode = .routed }
            guard let targetSpecialist else { return }
            appState.taskDraft.categoryID = targetSpecialist.categories.first ?? "handyman"
            appState.taskDraft.answers["targetSpecialistId"] = targetSpecialist.id
        }
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Brand.red : Color(.quaternarySystemFill))
                        .frame(height: 5)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: ["text.bubble.fill", "map.fill", "checklist"][step])
                    .contentTransition(.symbolEffect(.replace))
                Text(appState.locale.text(
                    he: "שלב \(step + 1) מתוך 3",
                    ru: "Шаг \(step + 1) из 3",
                    en: "Step \(step + 1) of 3"
                ))
            }
            .font(.caption).fontWeight(.bold).foregroundStyle(Brand.red)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func descriptionStep(state: Bindable<AppState>) -> some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Brand.red)
                            .frame(width: 46, height: 46)
                            .background(Brand.softRed, in: .rect(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.locale.text(he: "מציאת שירות", ru: "Найдём точную услугу", en: "Find the exact service"))
                                .font(.headline)
                            Text(appState.locale.text(
                                he: "תארו מה קרה. החיפוש החכם יבחר שירות מדויק, או בחרו אותו מההשלמה האוטומטית.",
                                ru: "Опишите, что случилось. Умный поиск выберет точную услугу, либо выберите её из автокомплита.",
                                en: "Describe what happened. Smart Search will pick the exact service, or choose one from autocomplete."
                            ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .id("task-service-foundation")

                    TextField(
                        appState.locale.text(he: "למשל: הברז במטבח דולף", ru: "Например: протекает кран на кухне", en: "For example: the kitchen faucet is leaking"),
                        text: taskSearchBinding,
                        axis: .vertical
                    )
                    .font(.body.weight(.medium))
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.search)
                    .onSubmit { if !selectedServiceExists { smartRoute() } }

                    if selectedServiceExists {
                        selectedServiceCard
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                    } else {
                        Button { smartRoute() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: appState.isWorking ? "sparkles" : "wand.and.stars")
                                    .symbolEffect(.pulse, options: .repeating, isActive: appState.isWorking)
                                Text(appState.isWorking
                                    ? appState.locale.text(he: "מזהה שירות…", ru: "Определяем услугу…", en: "Finding the service…")
                                    : appState.locale.text(he: "חיפוש חכם", ru: "Найти умным поиском", en: "Find with Smart Search"))
                                    .fontWeight(.bold)
                                Spacer()
                                if appState.isWorking { ProgressView().tint(.white) }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .background(Brand.red, in: .rect(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.taskDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 || appState.isWorking)
                        .opacity(appState.taskDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 ? 0.55 : 1)

                        if !inlineServiceMatches.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(appState.locale.text(he: "או בחרו מהרשימה", ru: "Или выберите из автокомплита", en: "Or choose from autocomplete"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                                ForEach(inlineServiceMatches) { option in
                                    serviceAutocompleteRow(option)
                                    if option.id != inlineServiceMatches.last?.id { Divider().padding(.leading, 48) }
                                }
                            }
                        }

                        Button { showAllServices = true } label: {
                            Label(
                                appState.locale.text(he: "כל השירותים", ru: "Все услуги", en: "Browse all services"),
                                systemImage: "magnifyingglass"
                            )
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                } header: {
                    Label(appState.locale.text(he: "שירות", ru: "Услуга", en: "Service"), systemImage: "wand.and.stars")
                }

                if selectedServiceExists, !relatedServiceSuggestions.isEmpty {
                    Section(appState.locale.text(he: "שירותים קשורים", ru: "Похожие услуги", en: "Related services")) {
                        FlowLayout(layoutDirection: appState.locale.layoutDirection) {
                            ForEach(relatedServiceSuggestions, id: \.self) { service in
                                serviceChip(service)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(appState.locale.text(he: "פרטים נוספים", ru: "Дополнительные детали", en: "Additional details")) {
                    TextField(
                        appState.locale.text(
                            he: "מתי התחיל, היכן בדיוק ומה כבר ניסיתם? (לא חובה)",
                            ru: "Когда началось, где именно и что уже пробовали? (необязательно)",
                            en: "When did it start, where exactly, and what have you tried? (optional)"
                        ),
                        text: state.taskDraft.details,
                        axis: .vertical
                    )
                    .lineLimit(3...7)
                    .focused($focusedField, equals: .details)
                    if let safety = appState.lastTriage?.safety {
                        Label(safety, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }

                photoSection

                if !triageQuestions.isEmpty {
                    Section(appState.locale.text(he: "כדאי לציין", ru: "Полезно уточнить", en: "Helpful details")) {
                        ForEach(triageQuestions, id: \.self) { question in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(question)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                TextField(
                                    appState.locale.text(he: "כתבו תשובה", ru: "Введите ответ", en: "Enter an answer"),
                                    text: answerBinding(for: question),
                                    axis: .vertical
                                )
                                .lineLimit(2...5)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .question(question))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: appState.taskDraft.answers["selectedService"]) { _, selectedService in
                guard selectedService != nil else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo("task-service-foundation", anchor: .top)
                }
            }
            .onAppear {
                guard selectedServiceExists else { return }
                proxy.scrollTo("task-service-foundation", anchor: .top)
            }
        }
    }

    private func locationStep(state: Bindable<AppState>) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.locale.text(he: "איפה ומתי?", ru: "Где и когда?", en: "Where and when?"))
                        .font(.title2).fontWeight(.bold)
                    Text(appState.locale.text(he: "כתובת מדויקת תוצג רק לבעל מקצוע שתבחרו.", ru: "Точный адрес увидит только выбранный мастер.", en: "Only the specialist you choose will see the exact address."))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Section(appState.locale.text(he: "מיקום", ru: "Место", en: "Location")) {
                TextField(appState.locale.text(he: "עיר", ru: "Город", en: "City"), text: state.taskDraft.city)
                    .textContentType(.addressCity)
                    .focused($focusedField, equals: .city)
                TextField(
                    appState.locale.text(he: "חיפוש רחוב ובית", ru: "Поиск улицы и дома", en: "Search street and number"),
                    text: Binding(
                        get: { appState.taskDraft.address },
                        set: { value in
                            appState.taskDraft.address = value
                            locationSearch.update(query: value)
                        }
                    )
                )
                    .textContentType(.fullStreetAddress)
                    .focused($focusedField, equals: .address)
                if !locationSearch.suggestions.isEmpty {
                    ForEach(locationSearch.suggestions) { suggestion in
                        Button {
                            Task { await locationSearch.select(suggestion) }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.title).foregroundStyle(.primary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Button {
                    focusedField = nil
                    locationSearch.requestCurrentLocation()
                } label: {
                    HStack {
                        Label(
                            appState.locale.text(he: "שימוש במיקום הנוכחי", ru: "Определить моё место", en: "Use my current location"),
                            systemImage: "location.fill"
                        )
                        Spacer()
                        if locationSearch.isLocating { ProgressView() }
                    }
                }
            }
            Section {
                VStack(spacing: 0) {
                    MapReader { reader in
                        Map(position: $mapPosition) {
                            UserAnnotation()
                            if let location = locationSearch.selectedLocation {
                                Marker(
                                    appState.taskDraft.city.isEmpty
                                        ? appState.locale.text(he: "נקודה שנבחרה", ru: "Выбранная точка", en: "Selected point")
                                        : appState.taskDraft.city,
                                    coordinate: location.coordinate
                                )
                                .tint(Brand.red)
                            }
                        }
                        .mapControls { MapCompass(); MapScaleView() }
                        .simultaneousGesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    guard let coordinate = reader.convert(value.location, from: .local) else { return }
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    Task { await locationSearch.select(coordinate: coordinate) }
                                }
                        )
                        .accessibilityLabel(appState.locale.text(he: "מפת מיקום המשימה", ru: "Карта места заявки", en: "Task location map"))
                    }
                    .frame(height: 210)

                    Label(
                        appState.locale.text(
                            he: "הקישו על המפה כדי להזיז את הסיכה לנקודה המדויקת",
                            ru: "Нажмите на карту, чтобы перенести метку в точное место",
                            en: "Tap the map to move the pin to the exact location"
                        ),
                        systemImage: "hand.tap.fill"
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                }
                .clipShape(.rect(cornerRadius: 16))
                .accessibilityIdentifier("task-location-map")
                .accessibilityLabel(appState.locale.text(he: "מפת מיקום המשימה", ru: "Карта места заявки", en: "Task location map"))
                .accessibilityValue(mapAccessibilityValue)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text(appState.locale.text(
                    he: "הכתובת המדויקת תישאר פרטית עד שתבחרו בעל מקצוע.",
                    ru: "Точный адрес останется скрытым, пока вы не выберете мастера.",
                    en: "The exact address stays private until you choose a specialist."
                ))
            }
            if let error = locationSearch.errorMessage {
                Section {
                    Label(
                        locationErrorText(error),
                        systemImage: "location.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    if error == "location_permission_denied" || error == "location_services_disabled" {
                        Button {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        } label: {
                            Label(
                                appState.locale.text(he: "פתיחת הגדרות", ru: "Открыть настройки", en: "Open Settings"),
                                systemImage: "gearshape.fill"
                            )
                        }
                    }
                }
            }
            Section(appState.locale.text(he: "מועד", ru: "Когда", en: "Timing")) {
                Picker(appState.locale.text(he: "מועד", ru: "Когда", en: "Timing"), selection: state.taskDraft.timing) {
                    Text(appState.locale.text(he: "דחוף", ru: "Срочно", en: "Urgent")).tag("urgent")
                    Text(appState.locale.text(he: "בימים הקרובים", ru: "В ближайшие дни", en: "In the next few days")).tag("soon")
                    Text(appState.locale.text(he: "גמיש", ru: "Можно договориться", en: "Flexible")).tag("flexible")
                }
                .pickerStyle(.segmented)
                if appState.taskDraft.timing == "urgent" {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(
                            appState.locale.text(he: "צריכים עזרה עכשיו?", ru: "Нужна помощь прямо сейчас?", en: "Need help right now?"),
                            systemImage: "phone.badge.waveform.fill"
                        )
                        .font(.headline)
                        Text(appState.locale.text(
                            he: "אפשר לפרסם את הבקשה כרגיל או להתקשר למוקד KABLAY לסיוע דחוף.",
                            ru: "Можно опубликовать заявку как обычно или позвонить в KABLAY для срочной помощи.",
                            en: "Publish normally or call KABLAY for urgent fulfillment support."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        Link(destination: URL(string: "tel:+972503669369")!) {
                            Label(appState.locale.text(he: "שיחה ל-KABLAY", ru: "Позвонить в KABLAY", en: "Call KABLAY"), systemImage: "phone.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.red)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: locationSearch.selectedLocation?.id) { _, _ in
            guard let location = locationSearch.selectedLocation else { return }
            appState.taskDraft.latitude = location.coordinate.latitude
            appState.taskDraft.longitude = location.coordinate.longitude
            // Never keep an address from the previously selected pin while a
            // new exact coordinate is being reverse-geocoded.
            appState.taskDraft.city = location.city
            appState.taskDraft.address = location.address
            mapPosition = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                )
            )
            focusedField = nil
        }
        .onAppear {
            guard locationSearch.selectedLocation == nil,
                  let latitude = appState.taskDraft.latitude,
                  let longitude = appState.taskDraft.longitude else { return }
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            Task { await locationSearch.select(coordinate: coordinate) }
        }
    }

    private func reviewStep(state: Bindable<AppState>) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.locale.text(he: "בדיקה ופרסום", ru: "Проверьте и опубликуйте", en: "Review and publish"))
                        .font(.title2).fontWeight(.bold)
                    Text(appState.locale.text(he: "אחרי הפרסום בעלי מקצוע מתאימים יוכלו לשלוח הצעות.", ru: "После публикации подходящие мастера смогут отправить предложения.", en: "After publishing, matching specialists can send offers."))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Section(appState.locale.text(he: "תקציב משוער", ru: "Ориентировочный бюджет", en: "Estimated budget")) {
                Text(appState.locale.text(
                    he: "אפשר לבחור טווח או להשאיר לבעלי המקצוע להציע מחיר.",
                    ru: "Выберите диапазон или разрешите мастерам предложить цену.",
                    en: "Choose a range or let specialists propose a price."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

                FlowLayout(layoutDirection: appState.locale.layoutDirection) {
                    ForEach(budgetOptions) { option in
                        Button {
                            withAnimation(.snappy) { appState.taskDraft.budget = option.value }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Label(
                                option.title,
                                systemImage: appState.taskDraft.budget == option.value ? "checkmark.circle.fill" : "shekelsign.circle"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appState.taskDraft.budget == option.value ? Brand.red : Brand.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(appState.taskDraft.budget == option.value ? Brand.softRed : Color(.tertiarySystemBackground), in: .capsule)
                            .overlay { Capsule().stroke(appState.taskDraft.budget == option.value ? Brand.red.opacity(0.6) : Brand.border) }
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField(
                    appState.locale.text(he: "או הזינו סכום, למשל 750 ₪", ru: "Или укажите сумму, например 750 ₪", en: "Or enter an amount, for example ₪750"),
                    text: state.taskDraft.budget
                )
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .budget)
            }
            Section(appState.locale.text(he: "הבקשה", ru: "Заявка", en: "Request")) {
                if let targetSpecialist {
                    reviewRow(appState.locale.text(he: "בעל מקצוע", ru: "Мастер", en: "Specialist"), targetSpecialist.name)
                }
                reviewRow(appState.locale.text(he: "קטגוריה", ru: "Категория", en: "Category"), categoryTitle)
                reviewRow(appState.locale.text(he: "שירות", ru: "Услуга", en: "Service"), appState.taskDraft.title)
                if !appState.taskDraft.relatedServices.isEmpty {
                    reviewRow(
                        appState.locale.text(he: "שירותים נוספים", ru: "Дополнительные услуги", en: "Related services"),
                        appState.taskDraft.relatedServices
                            .map { $0.value(for: appState.locale) }
                            .joined(separator: ", ")
                    )
                }
                if !appState.taskDraft.details.isEmpty { reviewRow(appState.locale.text(he: "פרטים", ru: "Детали", en: "Details"), appState.taskDraft.details) }
                if !photoPreviews.isEmpty {
                    reviewRow(
                        appState.locale.text(he: "תמונות", ru: "Фотографии", en: "Photos"),
                        appState.locale.text(he: "\(photoPreviews.count) צורפו", ru: "Прикреплено: \(photoPreviews.count)", en: "\(photoPreviews.count) attached")
                    )
                }
            }
            Section(appState.locale.text(he: "מיקום ומועד", ru: "Место и время", en: "Location and timing")) {
                reviewRow(appState.locale.text(he: "עיר", ru: "Город", en: "City"), appState.taskDraft.city)
                reviewRow(appState.locale.text(he: "מועד", ru: "Когда", en: "Timing"), timingTitle)
                reviewRow(
                    appState.locale.text(he: "תקציב", ru: "Бюджет", en: "Budget"),
                    appState.taskDraft.budget.isEmpty
                        ? appState.locale.text(he: "הצעות מבעלי מקצוע", ru: "Жду предложения мастеров", en: "Open to specialist offers")
                        : appState.taskDraft.budget
                )
            }
            if !appState.isAuthenticated {
                Section {
                    Label(appState.locale.text(he: "לפרסום צריך להיכנס לפי מספר טלפון. הטיוטה תישמר.", ru: "Для публикации войдите по телефону. Черновик сохранится.", en: "Sign in by phone to publish. Your draft will be kept."), systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Text(appState.locale.text(
                    he: "אל תפרסמו מספר טלפון, דוא״ל או כתובת מדויקת בתיאור הפומבי.",
                    ru: "Не публикуйте телефон, email или точный адрес в открытом описании.",
                    en: "Do not put a phone number, email, or exact address in the public description."
                ))
                .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundStyle(Brand.red)
            }
            HStack(spacing: 12) {
                if step > 0 {
                    Button { validationMessage = nil; step -= 1 } label: { Image(systemName: appState.locale == .he ? "chevron.right" : "chevron.left") }
                        .buttonStyle(.bordered).buttonBorderShape(.circle).controlSize(.large)
                }
                Button {
                    continueOrPublish()
                } label: {
                    Text(step < 2
                        ? appState.locale.text(he: "המשך", ru: "Продолжить", en: "Continue")
                        : appState.isAuthenticated
                            ? appState.locale.text(he: "פרסום בקשה", ru: "Опубликовать", en: "Publish request")
                            : appState.locale.text(he: "כניסה ופרסום", ru: "Войти и опубликовать", en: "Sign in and publish"))
                }
                .buttonStyle(BrandPrimaryButtonStyle())
                .disabled(appState.isWorking)
            }
        }
        .padding()
        .background(.bar)
    }

    @ViewBuilder
    private var photoSection: some View {
        let locale = appState.locale
        Section {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 6,
                matching: .images
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Brand.red)
                        .frame(width: 42, height: 42)
                        .background(Brand.softRed, in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(locale.text(he: "הוספת תמונות", ru: "Добавить фотографии", en: "Add photos"))
                            .font(.headline)
                            .foregroundStyle(Brand.ink)
                        Text(locale.text(he: "עד 6 תמונות, 10MB כל אחת", ru: "До 6 фотографий, по 10 МБ", en: "Up to 6 photos, 10 MB each"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if !photoPreviews.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoPreviews) { preview in
                            ZStack(alignment: .topTrailing) {
                                if let image = UIImage(data: preview.data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 104, height: 92)
                                        .clipShape(.rect(cornerRadius: 14))
                                }
                                Button {
                                    withAnimation(.snappy) {
                                        photoPreviews.removeAll { $0.id == preview.id }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.black.opacity(0.58))
                                }
                                .offset(x: 6, y: -6)
                                .accessibilityLabel(appState.locale.text(he: "הסרת תמונה", ru: "Удалить фотографию", en: "Remove photo"))
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        } header: {
            Label(appState.locale.text(he: "תמונות של הבעיה", ru: "Фотографии проблемы", en: "Photos of the issue"), systemImage: "camera.fill")
        } footer: {
            Text(appState.locale.text(
                he: "תמונות עוזרות לבעל המקצוע להבין את העבודה ולהציע מחיר מדויק יותר.",
                ru: "Фотографии помогают мастеру понять объём работы и точнее назвать цену.",
                en: "Photos help specialists understand the job and quote more accurately."
            ))
        }
    }

    private var selectedServiceCard: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedCategory?.systemImage ?? "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(selectedCategory.map { Color(hex: $0.tintHex) } ?? Brand.red)
                .frame(width: 44, height: 44)
                .background((selectedCategory.map { Color(hex: $0.tintHex) } ?? Brand.red).opacity(0.12), in: .rect(cornerRadius: 13))
                .symbolEffect(.bounce, value: showSmartConfirmation)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                    Text(appState.taskDraft.answers["selectedServiceId"] == nil
                        ? appState.locale.text(he: "נבחר", ru: "Выбрано", en: "Selected")
                        : appState.locale.text(he: "נמצא בחיפוש חכם", ru: "Найдено умным поиском", en: "Found by Smart Search"))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                Text(selectedServiceTitle)
                    .font(.headline)
                    .foregroundStyle(Brand.ink)
                Text(categoryTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button {
                withAnimation(.snappy) {
                    appState.taskDraft.answers.removeValue(forKey: "selectedService")
                    appState.taskDraft.answers.removeValue(forKey: "selectedServiceId")
                    appState.taskDraft.relatedServices = []
                    appState.taskDraft.categoryID = ""
                    appState.requestEntryMode = .direct
                    showSmartConfirmation = false
                }
                focusedField = .title
            } label: {
                Text(appState.locale.text(he: "שינוי", ru: "Изменить", en: "Change"))
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .padding(.vertical, 5)
    }

    private func serviceAutocompleteRow(_ option: ServiceSearchOption) -> some View {
        Button { selectService(option) } label: {
            HStack(spacing: 11) {
                Image(systemName: option.category.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: option.category.tintHex))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: option.category.tintHex).opacity(0.11), in: .rect(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.service.value(for: appState.locale))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.ink)
                    Text(option.category.title.value(for: appState.locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: appState.locale == .he ? "chevron.left" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    private func serviceChip(_ service: LocalizedValue) -> some View {
        let title = service.value(for: appState.locale)
        let selected = appState.taskDraft.relatedServices.contains(service)
        return Button {
            dismissKeyboard()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                if selected {
                    appState.taskDraft.relatedServices.removeAll { $0 == service }
                } else {
                    appState.taskDraft.relatedServices.append(service)
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Label(title, systemImage: selected ? "checkmark.circle.fill" : "plus.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Brand.red : Brand.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(selected ? Brand.softRed : Color(.tertiarySystemBackground), in: .capsule)
                .overlay { Capsule().stroke(selected ? Brand.red.opacity(0.65) : Brand.border) }
                .scaleEffect(selected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "selected" : "not-selected")
    }

    private var budgetOptions: [BudgetOption] {
        [
            .init(value: "", title: appState.locale.text(he: "פתוח להצעות", ru: "Жду предложения", en: "Open to offers")),
            .init(value: appState.locale.text(he: "עד 500 ₪", ru: "До 500 ₪", en: "Up to ₪500"), title: appState.locale.text(he: "עד 500 ₪", ru: "До 500 ₪", en: "Up to ₪500")),
            .init(value: "₪500–1,000", title: "₪500–1,000"),
            .init(value: appState.locale.text(he: "מ-1,000 ₪", ru: "От 1 000 ₪", en: "₪1,000+"), title: appState.locale.text(he: "מ-1,000 ₪", ru: "От 1 000 ₪", en: "₪1,000+")),
        ]
    }

    private var categoryTitle: String {
        appState.serviceCatalog.first { $0.id == appState.taskDraft.categoryID }?.title.value(for: appState.locale)
            ?? appState.locale.text(he: "שירות לבית", ru: "Домашние услуги", en: "Home services")
    }

    private var selectedCategory: ServiceCategory? {
        appState.serviceCatalog.first { $0.id == appState.taskDraft.categoryID }
    }

    private var selectedServiceTitle: String {
        appState.taskDraft.answers["selectedService"] ?? appState.taskDraft.title
    }

    private var selectedServiceExists: Bool {
        guard let selected = appState.taskDraft.answers["selectedService"]?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !selected.isEmpty && selectedCategory != nil
    }

    private var taskSearchBinding: Binding<String> {
        Binding(
            get: { appState.taskDraft.title },
            set: { newValue in
                let selected = appState.taskDraft.answers["selectedService"]
                appState.taskDraft.title = String(newValue.prefix(600))
                guard selected?.caseInsensitiveCompare(newValue) != .orderedSame else { return }
                if selected != nil {
                    appState.taskDraft.answers.removeValue(forKey: "selectedService")
                    appState.taskDraft.answers.removeValue(forKey: "selectedServiceId")
                    appState.taskDraft.relatedServices = []
                    appState.taskDraft.categoryID = ""
                    appState.requestEntryMode = .direct
                    showSmartConfirmation = false
                    triageQuestions = []
                }
            }
        )
    }

    private var allServiceOptions: [ServiceSearchOption] {
        appState.serviceCatalog.flatMap { category in
            category.groups.flatMap { group in
                group.services.enumerated().map { index, service in
                    ServiceSearchOption(
                        id: "\(category.id):\(group.id):\(index)",
                        category: category,
                        group: group.title,
                        service: service
                    )
                }
            }
        }
    }

    private var inlineServiceMatches: [ServiceSearchOption] {
        guard !selectedServiceExists else { return [] }
        let query = normalizedSearchText(appState.taskDraft.title)
        guard query.count >= 2 else { return [] }
        let tokens = query.split(separator: " ").map(String.init).filter { $0.count >= 3 }
        return allServiceOptions
            .filter { option in
                let corpus = option.searchCorpus
                return corpus.contains(query) || tokens.contains(where: corpus.contains)
            }
            .sorted { lhs, rhs in
                let leftTitle = normalizedSearchText(lhs.service.value(for: appState.locale))
                let rightTitle = normalizedSearchText(rhs.service.value(for: appState.locale))
                let leftRank = leftTitle.hasPrefix(query) ? 0 : (leftTitle.contains(query) ? 1 : 2)
                let rightRank = rightTitle.hasPrefix(query) ? 0 : (rightTitle.contains(query) ? 1 : 2)
                if leftRank != rightRank { return leftRank < rightRank }
                return leftTitle.localizedCaseInsensitiveCompare(rightTitle) == .orderedAscending
            }
            .prefix(5)
            .map { $0 }
    }

    private var serviceSuggestions: [LocalizedValue] {
        appState.serviceCatalog
            .first(where: { $0.id == appState.taskDraft.categoryID })?
            .groups
            .flatMap(\.services)
            .map { $0 } ?? []
    }

    private var relatedServiceSuggestions: [LocalizedValue] {
        let selected = normalizedSearchText(selectedServiceTitle)
        return serviceSuggestions
            .filter { service in
                ![service.he, service.ru, service.en]
                    .map(normalizedSearchText)
                    .contains(selected)
            }
            .prefix(8)
            .map { $0 }
    }

    private var timingTitle: String {
        switch appState.taskDraft.timing {
        case "urgent": appState.locale.text(he: "דחוף", ru: "Срочно", en: "Urgent")
        case "soon": appState.locale.text(he: "בימים הקרובים", ru: "В ближайшие дни", en: "In the next few days")
        default: appState.locale.text(he: "גמיש", ru: "Можно договориться", en: "Flexible")
        }
    }

    private func locationErrorText(_ error: String) -> String {
        switch error {
        case "location_permission_denied":
            appState.locale.text(
                he: "אפשר להפעיל גישה למיקום בהגדרות iPhone.",
                ru: "Разрешите доступ к геопозиции в настройках iPhone.",
                en: "Enable location access in iPhone Settings."
            )
        case "location_services_disabled":
            appState.locale.text(
                he: "שירותי המיקום כבויים במכשיר.",
                ru: "Службы геолокации выключены на iPhone.",
                en: "Location Services are turned off on this iPhone."
            )
        case "location_timeout":
            appState.locale.text(
                he: "לא התקבל מיקום עדכני. עברו למקום פתוח ונסו שוב.",
                ru: "Не удалось получить свежую геопозицию. Попробуйте ещё раз у окна или на улице.",
                en: "Could not get a fresh location. Try again near a window or outdoors."
            )
        case "address_unavailable":
            appState.locale.text(
                he: "הנקודה נבחרה. הזינו את הרחוב ומספר הבית ידנית.",
                ru: "Точка выбрана. Укажите улицу и номер дома вручную.",
                en: "The point is selected. Enter the street and number manually."
            )
        default:
            appState.locale.text(
                he: "לא ניתן לקבל את המיקום כרגע. נסו שוב.",
                ru: "Сейчас не удалось определить местоположение. Попробуйте ещё раз.",
                en: "Could not determine the location. Please try again."
            )
        }
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.body)
        }
        .padding(.vertical, 2)
    }

    private func answerBinding(for question: String) -> Binding<String> {
        Binding(
            get: { appState.taskDraft.answers[question] ?? "" },
            set: { appState.taskDraft.answers[question] = $0 }
        )
    }

    private func selectService(_ option: ServiceSearchOption) {
        let title = option.service.value(for: appState.locale)
        dismissKeyboard()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            if selectedServiceTitle.caseInsensitiveCompare(title) != .orderedSame {
                appState.taskDraft.relatedServices = []
            }
            appState.taskDraft.categoryID = option.category.id
            appState.taskDraft.title = title
            appState.taskDraft.answers["selectedService"] = title
            appState.taskDraft.answers.removeValue(forKey: "selectedServiceId")
            appState.requestEntryMode = .routed
            triageQuestions = []
            showSmartConfirmation = true
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func smartRoute() {
        let combined = [appState.taskDraft.title, appState.taskDraft.details].filter { !$0.isEmpty }.joined(separator: ". ")
        dismissKeyboard()
        validationMessage = nil
        withAnimation(.easeOut(duration: 0.16)) { showSmartConfirmation = false }
        Task {
            if let result = await appState.classifyTask(combined) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                    triageQuestions = result.questions
                    showSmartConfirmation = true
                    appState.requestEntryMode = .routed
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                validationMessage = appState.locale.text(
                    he: "לא הצלחנו לזהות שירות. נסו לתאר את הבעיה בצורה מפורטת יותר.",
                    ru: "Не удалось определить услугу. Опишите проблему чуть подробнее.",
                    en: "We could not identify the service. Please describe the issue in a little more detail."
                )
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func publish() {
        if let message = validationMessage(for: 2) {
            validationMessage = message
            return
        }
        Task {
            if await appState.publishTask(photoData: photoPreviews.map(\.data)) {
                selectedPhotoItems = []
                photoPreviews = []
                step = 0
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func continueOrPublish() {
        dismissKeyboard()
        if let message = validationMessage(for: step) {
            validationMessage = message
            if step == 0 { focusedField = .title }
            if step == 1 {
                focusedField = appState.taskDraft.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .city : .address
            }
            return
        }
        validationMessage = nil
        if step < 2 {
            step += 1
        } else if appState.isAuthenticated {
            publish()
        } else {
            showLogin = true
        }
    }

    private func validationMessage(for requestedStep: Int) -> String? {
        let title = appState.taskDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = appState.taskDraft.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = appState.taskDraft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        if requestedStep == 0 || requestedStep == 2 {
            guard appState.serviceCatalog.contains(where: { $0.id == appState.taskDraft.categoryID }) else {
                return appState.locale.text(he: "מצאו או בחרו שירות.", ru: "Найдите или выберите услугу.", en: "Find or choose a service.")
            }
            guard title.count >= 4 else {
                return appState.locale.text(he: "תארו את המשימה בארבעה תווים לפחות.", ru: "Опишите задачу минимум четырьмя символами.", en: "Describe the task using at least four characters.")
            }
            guard selectedServiceExists else {
                return appState.locale.text(
                    he: "אשרו את השירות שהחיפוש מצא או בחרו אותו מההשלמה האוטומטית.",
                    ru: "Подтвердите найденную услугу или выберите её из автокомплита.",
                    en: "Confirm the matched service or choose one from autocomplete."
                )
            }
        }
        if requestedStep == 1 || requestedStep == 2 {
            guard city.count >= 2 else {
                return appState.locale.text(he: "ציינו עיר.", ru: "Укажите город.", en: "Enter a city.")
            }
            guard address.count >= 3 else {
                return appState.locale.text(he: "בחרו כתובת מהרשימה או הקלידו רחוב ומספר.", ru: "Выберите адрес из подсказок или укажите улицу и дом.", en: "Choose an address suggestion or enter a street and number.")
            }
        }
        return nil
    }

    private var mapAccessibilityValue: String {
        guard let latitude = appState.taskDraft.latitude,
              let longitude = appState.taskDraft.longitude else { return "not-selected" }
        return String(
            format: "selected|%.6f,%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            latitude,
            longitude
        )
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @MainActor
    private func loadPhotoPreviews(from items: [PhotosPickerItem]) async {
        var previews: [TaskPhotoPreview] = []
        for item in items.prefix(6) {
            guard let original = try? await item.loadTransferable(type: Data.self),
                  let jpeg = normalizedJPEGData(original) else { continue }
            previews.append(TaskPhotoPreview(data: jpeg))
        }
        withAnimation(.snappy) { photoPreviews = previews }
    }

    private func normalizedJPEGData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maximumDimension: CGFloat = 2_000
        let largest = max(image.size.width, image.size.height)
        let scale = largest > maximumDimension ? maximumDimension / largest : 1
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.82) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private struct ServiceSearchOption: Identifiable, Hashable {
    let id: String
    let category: ServiceCategory
    let group: LocalizedValue
    let service: LocalizedValue

    var searchCorpus: String {
        normalizedSearchText([
            category.title.he, category.title.ru, category.title.en,
            group.he, group.ru, group.en,
            service.he, service.ru, service.en,
        ].joined(separator: " "))
    }
}

private struct ServiceAutocompleteView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let options: [ServiceSearchOption]
    let onSelect: (ServiceSearchOption) -> Void
    @State private var query = ""

    private var filteredOptions: [ServiceSearchOption] {
        let normalized = normalizedSearchText(query)
        guard !normalized.isEmpty else { return options }
        let tokens = normalized.split(separator: " ").map(String.init).filter { $0.count >= 2 }
        return options.filter { option in
            option.searchCorpus.contains(normalized) || tokens.allSatisfy(option.searchCorpus.contains)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredOptions) { option in
                Button { onSelect(option) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.category.systemImage)
                            .font(.headline)
                            .foregroundStyle(Color(hex: option.category.tintHex))
                            .frame(width: 40, height: 40)
                            .background(Color(hex: option.category.tintHex).opacity(0.12), in: .rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.service.value(for: appState.locale))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Brand.ink)
                            Text("\(option.category.title.value(for: appState.locale)) · \(option.group.value(for: appState.locale))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .overlay {
                if filteredOptions.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: appState.locale.text(he: "חיפוש בכל השירותים", ru: "Поиск по всем услугам", en: "Search all services")
            )
            .navigationTitle(appState.locale.text(he: "בחירת שירות", ru: "Выбор услуги", en: "Choose a service"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel")) { dismiss() }
                }
            }
        }
    }
}

private func normalizedSearchText(_ value: String) -> String {
    value
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private struct TaskPhotoPreview: Identifiable, Equatable {
    let id = UUID()
    let data: Data
}

private struct BudgetOption: Identifiable {
    let value: String
    let title: String
    var id: String { title }
}
