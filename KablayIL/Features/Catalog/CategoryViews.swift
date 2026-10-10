import SwiftUI

struct CategoryCatalogView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""

    private var categories: [ServiceCategory] {
        guard !query.isEmpty else { return appState.serviceCatalog }
        return appState.serviceCatalog.filter { $0.title.value(for: appState.locale).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(categories) { category in
            NavigationLink {
                CategoryDetailView(category: category)
            } label: {
                Label {
                    Text(category.title.value(for: appState.locale)).font(.headline)
                } icon: {
                    Image(systemName: category.systemImage)
                        .foregroundStyle(Color(hex: category.tintHex))
                        .frame(width: 32)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: appState.locale.text(he: "חיפוש קטגוריה", ru: "Поиск категории", en: "Search categories"))
        .navigationTitle(appState.locale.text(he: "קטלוג שירותים", ru: "Каталог услуг", en: "Service catalog"))
    }
}

struct CategoryDetailView: View {
    @Environment(AppState.self) private var appState
    let category: ServiceCategory

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: category.systemImage)
                        .font(.title)
                        .foregroundStyle(Color(hex: category.tintHex))
                        .frame(width: 56, height: 56)
                        .background(Color(hex: category.tintHex).opacity(0.12), in: .rect(cornerRadius: 16))
                    VStack(alignment: .leading) {
                        Text(category.title.value(for: appState.locale)).font(.title2).fontWeight(.bold)
                        NavigationLink {
                            SpecialistDirectoryView(categoryID: category.id)
                        } label: {
                            Text(appState.locale.text(he: "הצגת בעלי מקצוע", ru: "Показать мастеров", en: "Show specialists"))
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.vertical, 6)
            }
            ForEach(category.groups) { group in
                Section(group.title.value(for: appState.locale)) {
                    ForEach(group.services, id: \.self) { service in
                        Button {
                            let title = service.value(for: appState.locale)
                            appState.taskDraft.categoryID = category.id
                            appState.taskDraft.title = title
                            appState.taskDraft.answers["selectedService"] = title
                            appState.taskDraft.answers.removeValue(forKey: "selectedServiceId")
                            appState.taskDraft.relatedServices = []
                            appState.requestEntryMode = .routed
                            appState.clientTab = .request
                        } label: {
                            HStack {
                                Text(service.value(for: appState.locale)).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle.fill").foregroundStyle(Brand.red)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if category.groups.isEmpty {
                Section {
                    ContentUnavailableView(
                        appState.locale.text(he: "שירותים נוספים בדרך", ru: "Список услуг пополняется", en: "More services are coming"),
                        systemImage: category.systemImage,
                        description: Text(appState.locale.text(he: "אפשר כבר לתאר את העבודה בבקשה חופשית.", ru: "Уже сейчас можно описать работу своими словами.", en: "You can already describe the work in your own words."))
                    )
                }
            }
            Section {
                Button {
                    appState.taskDraft.categoryID = category.id
                    appState.taskDraft.title = ""
                    appState.taskDraft.answers.removeValue(forKey: "selectedService")
                    appState.taskDraft.answers.removeValue(forKey: "selectedServiceId")
                    appState.taskDraft.relatedServices = []
                    appState.requestEntryMode = .direct
                    appState.clientTab = .request
                } label: {
                    Label(appState.locale.text(he: "יצירת בקשה", ru: "Создать заявку", en: "Create request"), systemImage: "plus.circle.fill")
                        .font(.headline).foregroundStyle(Brand.red)
                }
            }
        }
        .navigationTitle(category.title.value(for: appState.locale))
        .navigationBarTitleDisplayMode(.inline)
    }
}
