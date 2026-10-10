import SwiftUI

enum AppLocale: String, CaseIterable, Codable, Identifiable {
    case he
    case ru
    case en

    var id: String { rawValue }

    var title: String {
        switch self {
        case .he: "עברית"
        case .ru: "Русский"
        case .en: "English"
        }
    }

    var shortTitle: String { rawValue.uppercased() }
    var layoutDirection: LayoutDirection { self == .he ? .rightToLeft : .leftToRight }
    var locale: Locale { Locale(identifier: rawValue) }

    func text(he: String, ru: String, en: String) -> String {
        switch self {
        case .he: he
        case .ru: ru
        case .en: en
        }
    }

    static func detected(in text: String) -> AppLocale? {
        var hebrew = 0
        var cyrillic = 0
        var latin = 0
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0590...0x05FF, 0xFB1D...0xFB4F: hebrew += 1
            case 0x0400...0x052F: cyrillic += 1
            case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F: latin += 1
            default: break
            }
        }
        let scores: [(AppLocale, Int)] = [(.he, hebrew), (.ru, cyrillic), (.en, latin)]
        guard let result = scores.max(by: { $0.1 < $1.1 }), result.1 > 0 else { return nil }
        return result.0
    }

    static func preferred(from languageIdentifiers: [String]) -> AppLocale {
        for identifier in languageIdentifiers {
            let fallbackCode = identifier
                .replacingOccurrences(of: "_", with: "-")
                .split(separator: "-")
                .first
                .map(String.init)?
                .lowercased()
            let languageCode = Locale(identifier: identifier)
                .language.languageCode?.identifier.lowercased() ?? fallbackCode

            switch languageCode {
            case "he", "iw": return .he
            case "ru": return .ru
            case "en": return .en
            default: continue
            }
        }
        // The app is available in App Store regions well beyond Israel, because
        // many people living in Israel keep an Apple Account from the country
        // they came from. A French or German iPhone must not open in Hebrew.
        return .en
    }
}

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case he
    case en
    case ru

    var id: String { rawValue }

    var manualLocale: AppLocale? {
        switch self {
        case .system: nil
        case .he: .he
        case .en: .en
        case .ru: .ru
        }
    }

    func title(in locale: AppLocale) -> String {
        switch self {
        case .system:
            locale.text(he: "כמו ב-iPhone", ru: "Как на iPhone", en: "iPhone language")
        case .he: "עברית"
        case .en: "English"
        case .ru: "Русский"
        }
    }
}

private struct IsraelCityNames {
    let he: String
    let ru: String
    let en: String

    func value(for locale: AppLocale) -> String {
        locale.text(he: he, ru: ru, en: en)
    }
}

/// The native app mirrors the canonical city catalog in `packages/types/src/israelGeo.ts`.
/// Tasks store a stable slug, while people should always see a localized city name.
enum IsraelCityCatalog {
    struct CityOption: Identifiable {
        let slug: String
        let he: String
        let ru: String
        let en: String

        var id: String { slug }

        func name(for locale: AppLocale) -> String {
            locale.text(he: he, ru: ru, en: en)
        }

        fileprivate var aliases: [String] { [slug, he, ru, en] }
    }

    private static let cities: [String: IsraelCityNames] = [
        "ashkelon": .init(he: "אשקלון", ru: "Ашкелон", en: "Ashkelon"),
        "ashdod": .init(he: "אשדוד", ru: "Ашдод", en: "Ashdod"),
        "kiryat-gat": .init(he: "קריית גת", ru: "Кирьят-Гат", en: "Kiryat Gat"),
        "gedera": .init(he: "גדרה", ru: "Гедера", en: "Gedera"),
        "rehovot": .init(he: "רחובות", ru: "Реховот", en: "Rehovot"),
        "nes-ziona": .init(he: "נס ציונה", ru: "Нес-Циона", en: "Nes Ziona"),
        "rishon-lezion": .init(he: "ראשון לציון", ru: "Ришон ле-Цион", en: "Rishon LeZion"),
        "yavne": .init(he: "יבנה", ru: "Явне", en: "Yavne"),
        "lod": .init(he: "לוד", ru: "Лод", en: "Lod"),
        "ramla": .init(he: "רמלה", ru: "Рамла", en: "Ramla"),
        "bat-yam": .init(he: "בת ים", ru: "Бат-Ям", en: "Bat Yam"),
        "holon": .init(he: "חולון", ru: "Холон", en: "Holon"),
        "tel-aviv": .init(he: "תל אביב-יפו", ru: "Тель-Авив", en: "Tel Aviv"),
        "ramat-gan": .init(he: "רמת גן", ru: "Рамат-Ган", en: "Ramat Gan"),
        "givatayim": .init(he: "גבעתיים", ru: "Гиватаим", en: "Givatayim"),
        "bnei-brak": .init(he: "בני ברק", ru: "Бней-Брак", en: "Bnei Brak"),
        "petah-tikva": .init(he: "פתח תקווה", ru: "Петах-Тиква", en: "Petah Tikva"),
        "or-yehuda": .init(he: "אור יהודה", ru: "Ор-Иехуда", en: "Or Yehuda"),
        "kiryat-ono": .init(he: "קריית אונו", ru: "Кирьят-Оно", en: "Kiryat Ono"),
        "modiin": .init(he: "מודיעין", ru: "Модиин", en: "Modi'in"),
        "jerusalem": .init(he: "ירושלים", ru: "Иерусалим", en: "Jerusalem"),
        "herzliya": .init(he: "הרצליה", ru: "Герцлия", en: "Herzliya"),
        "ramat-hasharon": .init(he: "רמת השרון", ru: "Рамат-ха-Шарон", en: "Ramat HaSharon"),
        "raanana": .init(he: "רעננה", ru: "Раанана", en: "Ra'anana"),
        "kfar-saba": .init(he: "כפר סבא", ru: "Кфар-Саба", en: "Kfar Saba"),
        "hod-hasharon": .init(he: "הוד השרון", ru: "Ход-ха-Шарон", en: "Hod HaSharon"),
        "netanya": .init(he: "נתניה", ru: "Нетания", en: "Netanya"),
        "even-yehuda": .init(he: "אבן יהודה", ru: "Эвен-Иехуда", en: "Even Yehuda"),
        "hadera": .init(he: "חדרה", ru: "Хадера", en: "Hadera"),
        "haifa": .init(he: "חיפה", ru: "Хайфа", en: "Haifa"),
        "beer-sheva": .init(he: "באר שבע", ru: "Беэр-Шева", en: "Beer Sheva"),
        "kiryat-ata": .init(he: "קריית אתא", ru: "Кирьят-Ата", en: "Kiryat Ata"),
        "beit-shemesh": .init(he: "בית שמש", ru: "Бейт-Шемеш", en: "Beit Shemesh"),
        "tiberias": .init(he: "טבריה", ru: "Тверия", en: "Tiberias"),
        "afula": .init(he: "עפולה", ru: "Афула", en: "Afula"),
        "akko": .init(he: "עכו", ru: "Акко", en: "Acre"),
        "pardes-hanna-karkur": .init(he: "פרדס חנה-כרכור", ru: "Пардес-Хана-Каркур", en: "Pardes Hanna-Karkur"),
        "kiryat-motzkin": .init(he: "קריית מוצקין", ru: "Кирьят-Моцкин", en: "Kiryat Motzkin"),
        "rosh-haayin": .init(he: "ראש העין", ru: "Рош-ха-Аин", en: "Rosh HaAyin"),
        "ofakim": .init(he: "אופקים", ru: "Офаким", en: "Ofakim"),
        "ariel": .init(he: "אריאל", ru: "Ариэль", en: "Ariel"),
        "kiryat-malakhi": .init(he: "קריית מלאכי", ru: "Кирьят-Малахи", en: "Kiryat Malakhi"),
        "eilat": .init(he: "אילת", ru: "Эйлат", en: "Eilat"),
        "nahariya": .init(he: "נהריה", ru: "Нагария", en: "Nahariya"),
        "tirat-carmel": .init(he: "טירת כרמל", ru: "Тират-Кармель", en: "Tirat Carmel"),
        "binyamina": .init(he: "בנימינה", ru: "Биньямина", en: "Binyamina"),
        "yokneam": .init(he: "יקנעם", ru: "Йокнеам", en: "Yokneam"),
        "sderot": .init(he: "שדרות", ru: "Сдерот", en: "Sderot"),
        "safed": .init(he: "צפת", ru: "Цфат", en: "Safed"),
        "nesher": .init(he: "נשר", ru: "Нешер", en: "Nesher"),
        "maale-adumim": .init(he: "מעלה אדומים", ru: "Маале-Адумим", en: "Ma'ale Adumim"),
        "netivot": .init(he: "נתיבות", ru: "Нетивот", en: "Netivot"),
        "caesarea": .init(he: "קיסריה", ru: "Кесария", en: "Caesarea"),
        "karmiel": .init(he: "כרמיאל", ru: "Кармиэль", en: "Karmiel"),
        "atlit": .init(he: "עתלית", ru: "Атлит", en: "Atlit"),
        "dimona": .init(he: "דימונה", ru: "Димона", en: "Dimona"),
        "kafr-qasim": .init(he: "כפר קאסם", ru: "Кафр-Касем", en: "Kafr Qasim"),
        "or-akiva": .init(he: "אור עקיבא", ru: "Ор-Акива", en: "Or Akiva"),
        "ganei-tikva": .init(he: "גני תקווה", ru: "Ганей-Тиква", en: "Ganei Tikva"),
        "rekhasim": .init(he: "רכסים", ru: "Рехасим", en: "Rekhasim"),
        "pardesia": .init(he: "פרדסיה", ru: "Пардесия", en: "Pardesia"),
        "nazareth": .init(he: "נצרת", ru: "Назарет", en: "Nazareth"),
        "zikhron-yaakov": .init(he: "זכרון יעקב", ru: "Зихрон-Яаков", en: "Zikhron Ya'akov"),
        "gan-yavne": .init(he: "גן יבנה", ru: "Ган-Явне", en: "Gan Yavne"),
        "shefaram": .init(he: "שפרעם", ru: "Шфарам", en: "Shefa-Amr"),
        "arad": .init(he: "ערד", ru: "Арад", en: "Arad"),
        "tira": .init(he: "טירה", ru: "Тира", en: "Tira"),
        "elad": .init(he: "אלעד", ru: "Эльад", en: "El'ad"),
        "shoham": .init(he: "שוהם", ru: "Шохам", en: "Shoham"),
        "migdal-haemek": .init(he: "מגדל העמק", ru: "Мигдаль-ха-Эмек", en: "Migdal HaEmek"),
        "beitar-illit": .init(he: "ביתר עילית", ru: "Бейтар-Илит", en: "Beitar Illit"),
        "beer-yaakov": .init(he: "באר יעקב", ru: "Беэр-Яаков", en: "Be'er Ya'akov"),
        "tel-mond": .init(he: "תל מונד", ru: "Тель-Монд", en: "Tel Mond"),
        "sakhnin": .init(he: "סחנין", ru: "Сахнин", en: "Sakhnin"),
        "kfar-yona": .init(he: "כפר יונה", ru: "Кфар-Йона", en: "Kfar Yona"),
        "ramat-yishai": .init(he: "רמת ישי", ru: "Рамат-Ишай", en: "Ramat Yishai"),
        "kiryat-shmona": .init(he: "קריית שמונה", ru: "Кирьят-Шмона", en: "Kiryat Shmona"),
        "qalansawe": .init(he: "קלנסווה", ru: "Калансуа", en: "Qalansawe"),
        "nof-hagalil": .init(he: "נוף הגליל", ru: "Ноф-ха-Галиль", en: "Nof HaGalil"),
        "yeruham": .init(he: "ירוחם", ru: "Иерухам", en: "Yeruham"),
        "givat-shmuel": .init(he: "גבעת שמואל", ru: "Гиват-Шмуэль", en: "Givat Shmuel"),
    ]

    static var allCities: [CityOption] {
        cities.map { slug, names in
            CityOption(slug: slug, he: names.he, ru: names.ru, en: names.en)
        }
    }

    static func matching(_ query: String, locale: AppLocale) -> [CityOption] {
        let needle = normalize(query)
        return allCities
            .filter { city in
                needle.isEmpty || city.aliases.contains { normalize($0).contains(needle) }
            }
            .sorted { left, right in
                if !needle.isEmpty {
                    let leftStarts = left.aliases.contains { normalize($0).hasPrefix(needle) }
                    let rightStarts = right.aliases.contains { normalize($0).hasPrefix(needle) }
                    if leftStarts != rightStarts { return leftStarts }
                }
                return left.name(for: locale).compare(
                    right.name(for: locale),
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: locale.locale
                ) == .orderedAscending
            }
    }

    static func slug(for rawValue: String) -> String? {
        let rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else { return nil }
        let normalizedValue = normalize(rawValue)
        return cities.first(where: { slug, names in
            normalize(slug) == normalizedValue
                || normalize(names.he) == normalizedValue
                || normalize(names.ru) == normalizedValue
                || normalize(names.en) == normalizedValue
        })?.key
    }

    static func localizedName(for rawValue: String, locale: AppLocale) -> String {
        let rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else { return "" }
        if let slug = slug(for: rawValue), let names = cities[slug] {
            return names.value(for: locale)
        }
        return rawValue.replacingOccurrences(of: "-", with: " ").capitalized
    }

    static func localizingCity(in text: String, city rawCity: String, locale: AppLocale) -> String {
        let localizedCity = localizedName(for: rawCity, locale: locale)
        guard !rawCity.isEmpty, rawCity != localizedCity else { return text }
        return text.replacingOccurrences(of: rawCity, with: localizedCity, options: .caseInsensitive)
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
