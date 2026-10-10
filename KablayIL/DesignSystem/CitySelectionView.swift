import SwiftUI

/// Uses the same city identifiers as the website while showing names in the app language.
struct CitySelectionRow: View {
    @Environment(AppState.self) private var appState
    @Binding var value: String
    let title: String
    var allowsClear = false
    @State private var isPresented = false

    private var displayedCity: String {
        value.isEmpty
            ? appState.locale.text(he: "בחרו עיר", ru: "Выберите город", en: "Choose a city")
            : IsraelCityCatalog.localizedName(for: value, locale: appState.locale)
    }

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 11) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Brand.red)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 12)
                Text(displayedCity)
                    .font(.subheadline)
                    .foregroundStyle(value.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(displayedCity)
        .sheet(isPresented: $isPresented) {
            CitySelectionSheet(value: $value, locale: appState.locale,
                               title: title, allowsClear: allowsClear)
        }
    }
}

private struct CitySelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var value: String
    let locale: AppLocale
    let title: String
    let allowsClear: Bool
    @State private var search = ""

    private let popularSlugs = ["tel-aviv", "jerusalem", "haifa", "beer-sheva", "ashdod", "rishon-lezion"]

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var matches: [IsraelCityCatalog.CityOption] {
        IsraelCityCatalog.matching(query, locale: locale)
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section(locale.text(he: "ערים נפוצות", ru: "Популярные города", en: "Popular cities")) {
                        ForEach(popularSlugs, id: \.self) { slug in
                            if let city = IsraelCityCatalog.allCities.first(where: { $0.slug == slug }) {
                                cityRow(city)
                            }
                        }
                    }
                }

                Section(query.isEmpty
                        ? locale.text(he: "כל הערים", ru: "Все города", en: "All cities")
                        : locale.text(he: "תוצאות חיפוש", ru: "Результаты поиска", en: "Search results")) {
                    ForEach(query.isEmpty
                            ? matches.filter { !popularSlugs.contains($0.slug) }
                            : matches) { city in
                        cityRow(city)
                    }
                    if !query.isEmpty && matches.isEmpty {
                        Button {
                            value = query
                            dismiss()
                        } label: {
                            Label(locale.text(
                                he: "שימוש בשם \"\(query)\"",
                                ru: "Указать «\(query)»",
                                en: "Use “\(query)”"
                            ), systemImage: "text.cursor")
                        }
                        .foregroundStyle(Brand.red)
                    }
                }

                if allowsClear && !value.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            value = ""
                            dismiss()
                        } label: {
                            Label(locale.text(he: "ניקוי העיר", ru: "Убрать город", en: "Clear city"),
                                  systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: locale.text(he: "חיפוש עיר", ru: "Поиск города", en: "Search for a city"))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.text(he: "סגירה", ru: "Закрыть", en: "Close")) { dismiss() }
                }
            }
            .tint(Brand.red)
        }
        .presentationDetents([.large])
    }

    private func cityRow(_ city: IsraelCityCatalog.CityOption) -> some View {
        Button {
            value = city.slug
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(Brand.red)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name(for: locale))
                        .foregroundStyle(.primary)
                    if locale != .en {
                        Text(city.en)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if IsraelCityCatalog.slug(for: value) == city.slug {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Brand.red)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(IsraelCityCatalog.slug(for: value) == city.slug ? .isSelected : [])
    }
}
