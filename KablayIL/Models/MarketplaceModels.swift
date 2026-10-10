import Foundation

struct LocalizedValue: Hashable, Codable {
    let he: String
    let ru: String
    let en: String

    func value(for locale: AppLocale) -> String {
        switch locale {
        case .he: he
        case .ru: ru
        case .en: en
        }
    }
}

struct ServiceGroup: Identifiable, Hashable, Codable {
    let id: String
    let title: LocalizedValue
    let services: [LocalizedValue]
}

struct ServiceCategory: Identifiable, Hashable, Codable {
    let id: String
    let title: LocalizedValue
    let systemImage: String
    let tintHex: String
    let groups: [ServiceGroup]

    static let catalog: [ServiceCategory] = [
        .init(
            id: "plumbing",
            title: .init(he: "אינסטלציה", ru: "Сантехника", en: "Plumbing"),
            systemImage: "wrench.and.screwdriver.fill",
            tintHex: "337CCF",
            groups: [
                .init(id: "diagnostics", title: .init(he: "ייעוץ ואבחון", ru: "Консультация и диагностика", en: "Consultation & diagnostics"), services: [
                    .init(he: "ייעוץ אינסטלטור אונליין", ru: "Онлайн-консультация сантехника", en: "Online plumbing consultation"),
                    .init(he: "אבחון בבית", ru: "Диагностика на месте", en: "On-site diagnostics")
                ]),
                .init(id: "leaks", title: .init(he: "תיקון נזילות", ru: "Устранение протечек", en: "Leak repair"), services: [
                    .init(he: "תיקון נזילה בברז", ru: "Устранение протечки крана", en: "Faucet leak repair"),
                    .init(he: "תיקון נזילה באסלה", ru: "Устранение протечки унитаза", en: "Toilet leak repair"),
                    .init(he: "תיקון נזילת צינור", ru: "Устранение протечки трубы", en: "Pipe leak repair"),
                    .init(he: "איתור נזילה נסתרת", ru: "Устранение скрытой протечки", en: "Hidden leak detection"),
                    .init(he: "תיקון נזילה במקלחת", ru: "Устранение протечки в душевой", en: "Shower leak repair")
                ]),
                .init(id: "drains", title: .init(he: "פתיחת סתימות", ru: "Прочистка канализации", en: "Drain cleaning"), services: [
                    .init(he: "פתיחת סתימה", ru: "Прочистка канализации", en: "Drain cleaning"),
                    .init(he: "פתיחת סתימה מכנית", ru: "Механическая прочистка", en: "Mechanical drain cleaning"),
                    .init(he: "פתיחת סתימה באסלה", ru: "Устранение засора в туалете", en: "Toilet clog removal")
                ]),
                .init(id: "fixtures", title: .init(he: "אביזרי סניטריה", ru: "Сантехнические приборы", en: "Plumbing fixtures"), services: [
                    .init(he: "התקנת כיור", ru: "Установка раковины", en: "Sink installation"),
                    .init(he: "החלפת ברז", ru: "Замена смесителя", en: "Mixer replacement"),
                    .init(he: "תיקון מקלחון", ru: "Ремонт душевой кабины", en: "Shower cabin repair"),
                    .init(he: "התקנת דוד מים", ru: "Установка водонагревателя", en: "Water heater installation"),
                    .init(he: "התקנת מסנן מים", ru: "Установка фильтра для воды", en: "Water filter installation"),
                    .init(he: "החלפת צנרת", ru: "Замена труб", en: "Pipe replacement")
                ])
            ]
        ),
        .init(id: "electrician", title: .init(he: "חשמל", ru: "Электрика", en: "Electrical"), systemImage: "bolt.fill", tintHex: "E5A000", groups: [
            .init(id: "wiring", title: .init(he: "חיווט וחשמל", ru: "Проводка", en: "Wiring"), services: [
                .init(he: "החלפת חיווט בדירה", ru: "Замена проводки", en: "Apartment rewiring"),
                .init(he: "החלפת שקע", ru: "Замена розетки", en: "Outlet replacement"),
                .init(he: "התקנת שקעים ומתגים", ru: "Установка розеток и выключателей", en: "Sockets and switches"),
                .init(he: "חשמל חיצוני", ru: "Наружная электрика", en: "Outdoor wiring")
            ]),
            .init(id: "lighting", title: .init(he: "תאורה", ru: "Освещение", en: "Lighting"), services: [
                .init(he: "התקנת תאורה", ru: "Установка освещения", en: "Lighting installation"),
                .init(he: "התקנת גופי תאורה", ru: "Установка светильников", en: "Light fixture installation"),
                .init(he: "פסי לד", ru: "Монтаж LED-освещения", en: "LED strip installation"),
                .init(he: "תאורת חוץ", ru: "Уличное освещение", en: "Garden lighting")
            ]),
            .init(id: "diagnostics", title: .init(he: "אבחון ותיקון", ru: "Диагностика", en: "Diagnostics"), services: [
                .init(he: "תיקון קצר", ru: "Устранение короткого замыкания", en: "Short-circuit repair"),
                .init(he: "איתור תקלה", ru: "Поиск неисправности", en: "Fault finding"),
                .init(he: "החלפת מפסק", ru: "Замена автомата", en: "Circuit breaker replacement"),
                .init(he: "תיקון לוח חשמל", ru: "Ремонт щитка", en: "Electrical panel repair"),
                .init(he: "בדיקת ריח שרוף", ru: "Проверка запаха гари", en: "Burning smell inspection")
            ]),
            .init(id: "smart-home", title: .init(he: "בית חכם", ru: "Умный дом", en: "Smart home"), services: [
                .init(he: "מתגים חכמים", ru: "Умные выключатели", en: "Smart switches"),
                .init(he: "הגדרת אוטומציה", ru: "Настройка автоматизации", en: "Automation setup"),
                .init(he: "אינטרקום וידאו", ru: "Видеодомофоны", en: "Video doorphone installation"),
                .init(he: "חיישני אבטחה", ru: "Датчики безопасности", en: "Security sensor installation")
            ])
        ]),
        .init(id: "tiler", title: .init(he: "ריצוף וחיפוי", ru: "Плиточники", en: "Tiling"), systemImage: "square.grid.3x3.fill", tintHex: "A76B42", groups: [
            .init(id: "floor-tile", title: .init(he: "ריצוף", ru: "Напольная плитка", en: "Floor tiles"), services: [
                .init(he: "קרמיקה", ru: "Керамическая плитка", en: "Ceramic tile installation"),
                .init(he: "גרניט פורצלן", ru: "Керамогранит", en: "Porcelain tile installation"),
                .init(he: "פורמט גדול", ru: "Крупноформатная плитка", en: "Large-format tiling"),
                .init(he: "פסיפס", ru: "Мозаика", en: "Mosaic installation")
            ]),
            .init(id: "bathroom-tile", title: .init(he: "חדרי אמבטיה", ru: "Ванные комнаты", en: "Bathrooms"), services: [
                .init(he: "ריצוף חדר רחצה", ru: "Укладка плитки в ванной", en: "Bathroom tiling"),
                .init(he: "חיפוי קירות", ru: "Укладка плитки на стены", en: "Wall tiling"),
                .init(he: "איטום וריצוף", ru: "Гидроизоляция и плитка", en: "Waterproofing and tiling"),
                .init(he: "החלפת רובה", ru: "Замена затирки", en: "Grout replacement")
            ]),
            .init(id: "tile-prep", title: .init(he: "הכנה", ru: "Подготовка основания", en: "Preparation"), services: [
                .init(he: "פירוק אריחים", ru: "Демонтаж старой плитки", en: "Old tile removal"),
                .init(he: "יישור משטח", ru: "Выравнивание поверхности", en: "Surface leveling"),
                .init(he: "יציקת מדה", ru: "Стяжка пола", en: "Floor screed"),
                .init(he: "פריימר", ru: "Грунтовка", en: "Surface priming")
            ])
        ]),
        .init(id: "painter", title: .init(he: "צבע וטיח", ru: "Малярные и штукатурные работы", en: "Painting & plaster"), systemImage: "paintbrush.pointed.fill", tintHex: "8A5BB5", groups: [
            .init(id: "interior-paint", title: .init(he: "צביעת פנים", ru: "Внутренняя покраска", en: "Interior painting"), services: [
                .init(he: "צביעת דירה", ru: "Покраска квартиры", en: "Apartment painting"),
                .init(he: "צביעת קירות", ru: "Покраска стен", en: "Wall painting"),
                .init(he: "צביעת תקרה", ru: "Покраска потолка", en: "Ceiling painting"),
                .init(he: "צביעת דלתות", ru: "Покраска дверей", en: "Door painting")
            ]),
            .init(id: "surface-prep", title: .init(he: "הכנת משטח", ru: "Подготовка поверхности", en: "Surface preparation"), services: [
                .init(he: "תיקון סדקים", ru: "Ремонт трещин", en: "Crack repair"),
                .init(he: "שפכטל", ru: "Шпаклевка", en: "Wall putty"),
                .init(he: "פריימר", ru: "Грунтовка", en: "Primer application"),
                .init(he: "הסרת טפט", ru: "Снятие обоев", en: "Wallpaper removal")
            ]),
            .init(id: "plaster", title: .init(he: "עבודות טיח", ru: "Штукатурка", en: "Plaster work"), services: [
                .init(he: "טיח חוץ", ru: "Фасадная штукатурка", en: "Facade plaster"),
                .init(he: "טיח צמנטי", ru: "Цементная штукатурка", en: "Cement plaster"),
                .init(he: "טיח גבס", ru: "Гипсовая штукатурка", en: "Gypsum plaster"),
                .init(he: "יישור קירות", ru: "Выравнивание стен", en: "Wall smoothing")
            ])
        ]),
        .init(id: "drywall", title: .init(he: "גבס", ru: "Гипсокартон", en: "Drywall"), systemImage: "rectangle.split.3x1.fill", tintHex: "C89446", groups: [
            .init(id: "drywall-structures", title: .init(he: "קונסטרוקציות", ru: "Конструкции", en: "Structures"), services: [
                .init(he: "מחיצת גבס", ru: "Перегородка из гипсокартона", en: "Drywall partition"),
                .init(he: "הנמכת תקרה", ru: "Потолок из гипсокартона", en: "Drywall ceiling"),
                .init(he: "נישת גבס", ru: "Ниша из гипсокартона", en: "Drywall niche"),
                .init(he: "ארגז גבס", ru: "Короб из гипсокартона", en: "Drywall box")
            ]),
            .init(id: "drywall-finish", title: .init(he: "גימור", ru: "Отделка", en: "Finishing"), services: [
                .init(he: "סרט וחיבורי לוחות", ru: "Заделка стыков", en: "Joint taping"),
                .init(he: "שפכטל וליטוש", ru: "Шпаклевка и шлифовка", en: "Putty and sanding"),
                .init(he: "תיקון חור בגבס", ru: "Заделка отверстия в гипсокартоне", en: "Drywall hole repair"),
                .init(he: "בידוד אקוסטי", ru: "Звукоизоляция", en: "Soundproofing")
            ])
        ]),
        .init(id: "handyman", title: .init(he: "הנדימן", ru: "Муж на час", en: "Handyman"), systemImage: "hammer.fill", tintHex: "D26A3D", groups: [
            .init(id: "assembly", title: .init(he: "הרכבה", ru: "Сборка и монтаж", en: "Assembly"), services: [
                .init(he: "תליית מדף", ru: "Установка полки", en: "Shelf mounting"),
                .init(he: "הרכבת רהיטים", ru: "Сборка мебели", en: "Furniture assembly"),
                .init(he: "התקנת קרניז", ru: "Монтаж карниза", en: "Curtain rod installation"),
                .init(he: "תליית טלוויזיה", ru: "Монтаж телевизора", en: "TV mounting")
            ]),
            .init(id: "small-repairs", title: .init(he: "תיקונים", ru: "Ремонт и мелкие работы", en: "Small repairs"), services: [
                .init(he: "כיוון דלת", ru: "Регулировка двери", en: "Door adjustment"),
                .init(he: "החלפת מנעול", ru: "Замена замка", en: "Lock replacement"),
                .init(he: "תיקון חלון", ru: "Ремонт окна", en: "Window repair"),
                .init(he: "תיקונים כלליים", ru: "Разные мелкие работы", en: "Miscellaneous fixes")
            ])
        ]),
        .init(id: "stretch-ceilings", title: .init(he: "תקרות מתוחות", ru: "Натяжные потолки", en: "Stretch ceilings"), systemImage: "rectangle.inset.filled", tintHex: "4C79C6", groups: [
            .init(id: "ceiling-installation", title: .init(he: "התקנה", ru: "Монтаж", en: "Installation"), services: [
                .init(he: "תקרת PVC", ru: "ПВХ-потолок", en: "PVC stretch ceiling"),
                .init(he: "תקרת בד", ru: "Тканевый потолок", en: "Fabric stretch ceiling"),
                .init(he: "תקרה רב-מפלסית", ru: "Многоуровневый потолок", en: "Multi-level stretch ceiling"),
                .init(he: "תיקון תקרה", ru: "Ремонт натяжного потолка", en: "Stretch ceiling repair")
            ]),
            .init(id: "ceiling-lighting", title: .init(he: "תאורה", ru: "Подсветка", en: "Lighting"), services: [
                .init(he: "התקנת ספוטים", ru: "Установка точечных светильников", en: "Spotlight installation"),
                .init(he: "היקף לד", ru: "LED-подсветка по периметру", en: "LED perimeter lighting"),
                .init(he: "פתח לנברשת", ru: "Отверстие под люстру", en: "Chandelier opening"),
                .init(he: "תיקון תאורה", ru: "Ремонт подсветки", en: "Ceiling light repair")
            ])
        ]),
        .init(id: "renovation", title: .init(he: "שיפוץ דירות", ru: "Ремонт квартир", en: "Apartment renovation"), systemImage: "building.2.fill", tintHex: "3C8C72", groups: [
            .init(id: "apartment-renovation", title: .init(he: "שיפוץ דירה", ru: "Ремонт квартиры", en: "Apartment renovation"), services: [
                .init(he: "שיפוץ קוסמטי", ru: "Косметический ремонт", en: "Cosmetic renovation"),
                .init(he: "שיפוץ מלא", ru: "Капитальный ремонт", en: "Full renovation"),
                .init(he: "שיפוץ תחת מפתח", ru: "Ремонт под ключ", en: "Turnkey renovation"),
                .init(he: "שיפוץ מטבח", ru: "Ремонт кухни", en: "Kitchen renovation"),
                .init(he: "שיפוץ חדר אמבטיה", ru: "Ремонт ванной комнаты", en: "Bathroom renovation")
            ]),
            .init(id: "commercial-renovation", title: .init(he: "מסחרי", ru: "Коммерческие помещения", en: "Commercial renovation"), services: [
                .init(he: "שיפוץ משרד", ru: "Ремонт офиса", en: "Office renovation"),
                .init(he: "שיפוץ חנות", ru: "Отделка магазина", en: "Retail fit-out"),
                .init(he: "שיפוץ קליניקה", ru: "Ремонт клиники", en: "Clinic renovation"),
                .init(he: "שיקום אחרי שריפה", ru: "Восстановление после пожара", en: "Fire recovery")
            ])
        ]),
        .init(id: "cleaning", title: .init(he: "ניקיון", ru: "Клининг", en: "Cleaning"), systemImage: "sparkles", tintHex: "2F9AA5", groups: [
            .init(id: "home-cleaning", title: .init(he: "ניקיון הבית", ru: "Уборка квартир", en: "Home cleaning"), services: [
                .init(he: "ניקיון דירה שוטף", ru: "Поддерживающая уборка квартиры", en: "Regular apartment cleaning"),
                .init(he: "ניקיון יסודי", ru: "Генеральная уборка", en: "Deep cleaning"),
                .init(he: "ניקיון לפני או אחרי מעבר", ru: "Уборка перед въездом или после выезда", en: "Move-in or move-out cleaning"),
                .init(he: "ניקיון מטבח וחדרי רחצה", ru: "Уборка кухни и санузлов", en: "Kitchen and bathroom cleaning")
            ]),
            .init(id: "special-cleaning", title: .init(he: "ניקיון מקצועי", ru: "Специализированный клининг", en: "Specialized cleaning"), services: [
                .init(he: "ניקיון אחרי שיפוץ", ru: "Уборка после ремонта", en: "Post-renovation cleaning"),
                .init(he: "ניקוי חלונות", ru: "Мытьё окон", en: "Window cleaning"),
                .init(he: "ניקוי ספות וריפודים", ru: "Химчистка диванов и мебели", en: "Sofa and upholstery cleaning"),
                .init(he: "ניקוי שטיחים", ru: "Химчистка ковров", en: "Carpet cleaning")
            ]),
            .init(id: "business-cleaning", title: .init(he: "עסקים ובניינים", ru: "Офисы и здания", en: "Business and buildings"), services: [
                .init(he: "ניקיון משרדים", ru: "Уборка офисов", en: "Office cleaning"),
                .init(he: "ניקיון חדרי מדרגות", ru: "Уборка подъездов", en: "Stairwell cleaning"),
                .init(he: "ניקיון שטחים מסחריים", ru: "Уборка коммерческих помещений", en: "Commercial premises cleaning")
            ])
        ])
    ]
}

struct Specialist: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let avatarURL: URL?
    let profession: LocalizedValue
    let city: LocalizedValue
    let rating: Double
    let reviewCount: Int
    let completedJobs: Int
    let premium: Bool
    let verified: Bool
    let trust: SpecialistTrust
    let availableNow: Bool
    let bio: LocalizedValue
    let categories: [String]
    let yearsExperience: Int
    let portfolioURLs: [URL]
    let portfolioProjects: [SpecialistProject]

    var displayAvatarURL: URL? {
        avatarURL
            ?? portfolioURLs.first
            ?? portfolioProjects.lazy.compactMap(\.displayCoverURL).first
    }

    var hasProfileMedia: Bool { displayAvatarURL != nil }
}

struct SpecialistProject: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let photoURLs: [URL]
    let coverURL: URL?

    var displayCoverURL: URL? { coverURL ?? photoURLs.first }
}

struct SpecialistReview: Identifiable, Hashable, Codable {
    let id: String
    let author: String
    let rating: Double
    let text: String
    let createdAt: Date?
}

struct SpecialistProfileDetails: Hashable, Codable {
    let portfolioURLs: [URL]
    let portfolioProjects: [SpecialistProject]
    let contactAvailable: Bool
    let whatsappAvailable: Bool
    let reviews: [SpecialistReview]
}

enum TaskStatus: String, Codable, CaseIterable {
    case open, proposalReceived, inProgress, completed, cancelled, archived
}

struct RepairTask: Identifiable, Hashable, Codable {
    let id: String
    let orderNumber: Int?
    let title: String
    let categoryID: String
    let description: String?
    let city: String
    let address: String?
    let whenNeeded: String?
    let scheduledFor: Date?
    let status: TaskStatus
    let createdAt: Date
    let proposalCount: Int
    let budget: String?
    let attachmentURLs: [URL]
    let location: TaskMapLocation?
    let responseState: TaskResponseState?
    let client: TaskClientContact?
    let viewerConversationID: String?
    let proposals: [TaskProposal]
    let acceptedSpecialist: AcceptedSpecialistContact?
    let completion: TaskCompletion?
}

struct TaskProposal: Identifiable, Hashable, Codable {
    let id: String
    let specialistID: String
    let specialistName: String
    let specialistAvatarURL: URL?
    let rating: Double?
    let reviewCount: Int?
    let price: Int?
    let message: String?
    let status: String
    let createdAt: Date?
    let trust: SpecialistTrust
}

struct SpecialistTrust: Hashable, Codable {
    let verified: Bool
    let phoneVerified: Bool
    let licenseVerified: Bool
    let insuranceVerified: Bool
    let portfolioVerified: Bool
    let reviewsVerified: Bool
}

struct AcceptedSpecialistContact: Hashable, Codable {
    let specialistID: String
    let userID: String
    let name: String
    let avatarURL: URL?
    let phone: String?
    let whatsapp: String?
    let email: String?
}

struct TaskCompletion: Hashable, Codable {
    let specialistFinalAmount: Int
    let requestedAt: Date
    let confirmedAt: Date?
    let specialistNote: String?
    let clientPaidAmount: Int?
    let clientNote: String?
    let expenseAmount: Int?
    let specialistPhotoURLs: [URL]
    let clientPhotoURLs: [URL]
    let expenseReceiptURLs: [URL]

    var isPendingClientConfirmation: Bool { confirmedAt == nil }
}

struct CompletionUpload: Sendable {
    let data: Data
    let filename: String
    let mimeType: String
}

struct TaskClientContact: Hashable, Codable {
    let id: String
    let name: String
    let phone: String?
    let email: String?
    let rating: Double?
    let reviewCount: Int?

    var hasDirectContact: Bool {
        phone?.isEmpty == false || email?.isEmpty == false
    }
}

struct TaskResponseState: Hashable, Codable {
    let available: Bool
    let blockedReason: String?
    let availableAt: Date?
    let costCredits: Int?
    let viewerProposalID: String?
    let viewerPremium: Bool?
    /// How to reach the KABLAY administrator when the profile still needs to
    /// be verified before it can take work.
    let verificationContact: VerificationContact?

    var alreadySubmitted: Bool {
        viewerProposalID != nil || blockedReason == "ALREADY_PROPOSED"
    }

    var needsVerification: Bool { blockedReason == "PROFILE_NOT_VERIFIED" }
}

struct VerificationContact: Hashable, Codable {
    let phoneDisplay: String?
    let phoneE164: String?
    let whatsappURL: URL?
}

struct TaskMapLocation: Hashable, Codable {
    let latitude: Double
    let longitude: Double
    let approximate: Bool
}

struct ProfessionalLead: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let categoryID: String
    let city: String
    let clientName: String?
    let createdAt: Date
    let description: String
    let budget: String?
    let urgent: Bool
    let attachmentURLs: [URL]
    let location: TaskMapLocation?
}

func taskBudgetText(_ budget: String?, locale: AppLocale) -> String {
    guard let value = budget?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return locale.text(
            he: "הציעו מחיר",
            ru: "Предложите цену",
            en: "Propose a price"
        )
    }

    if value.hasPrefix("≤") {
        let amount = String(value.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        return locale.text(
            he: "תקציב עד \(amount)",
            ru: "Лимит до \(amount)",
            en: "Limit up to \(amount)"
        )
    }

    if value.hasSuffix("+") {
        let amount = String(value.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        return locale.text(
            he: "מ-\(amount)",
            ru: "От \(amount)",
            en: "From \(amount)"
        )
    }

    return value
}

struct ProfessionalProfile: Hashable, Codable {
    let specialist: Specialist
    let creditsBalance: Int

    var isComplete: Bool {
        !specialist.categories.isEmpty
            && !specialist.city.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !specialist.bio.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ProfessionalProposal: Identifiable, Hashable, Codable {
    let id: String
    let taskID: String
    let taskTitle: String
    let taskStatus: String
    let status: String
    let message: String?
    let price: Int?
    let createdAt: Date
    let conversationID: String?
}

struct ProfessionalConversation: Identifiable, Hashable, Codable {
    let id: String
    let taskID: String?
    let taskTitle: String?
    let partnerName: String
    let partnerAvatarURL: URL?
    let lastMessage: String?
    let lastMessageAt: Date?
    let unreadCount: Int
}

struct ProfessionalMessage: Identifiable, Hashable, Codable {
    let id: String
    let senderID: String
    let text: String
    let createdAt: Date
}

struct ProfessionalMetric: Hashable, Codable {
    let total: Int
    let last30: Int
    let last7: Int
    let today: Int
    let uniqueLast30: Int
}

struct ProfessionalStats: Hashable, Codable {
    let profileViews: ProfessionalMetric
    let phoneReveals: ProfessionalMetric
    let whatsappOpens: ProfessionalMetric
    let contactOpens: ProfessionalMetric
    let phoneRevealRateLast30: Int
    let contactConversionRateLast30: Int
}

struct CreditTransaction: Identifiable, Hashable {
    let id: String
    let type: String
    let amount: Int
    let taskID: String?
    let createdAt: Date
}

struct CreditAccount: Hashable {
    let balance: Int
    let transactions: [CreditTransaction]
    let premium: Bool
    /// End of a paid Premium window. Nil means Premium was granted by KABLAY
    /// support and does not expire on its own.
    let premiumUntil: Date?
}

struct BlogArticle: Identifiable, Hashable, Codable {
    let id: String
    let title: LocalizedValue
    let summary: LocalizedValue
    let categoryID: String
    let readingMinutes: Int
    let coverURL: URL?
    let publishedAt: Date?
    /// Editorial body as published HTML, per locale. The app renders it with
    /// native views, so an article never opens as an embedded web page.
    let content: LocalizedValue
}

struct FAQItem: Identifiable, Hashable {
    let id: String
    let question: LocalizedValue
    let answer: LocalizedValue

    static let samples: [FAQItem] = [
        .init(id: "free", question: .init(he: "האם פרסום בקשה עולה כסף?", ru: "Размещение заявки платное?", en: "Does posting a request cost money?"), answer: .init(he: "לא. לקוחות מפרסמים בקשות ומשווים הצעות ללא תשלום.", ru: "Нет. Клиенты бесплатно публикуют заявки и сравнивают предложения.", en: "No. Clients post requests and compare offers for free.")),
        .init(id: "verification", question: .init(he: "איך KABLAY בודקת בעלי מקצוע?", ru: "Как KABLAY проверяет мастеров?", en: "How does KABLAY verify specialists?"), answer: .init(he: "כל תג מציג בדיקה מסוימת. תמיד בדקו רישיון וביטוח רלוונטיים לפני תחילת עבודה.", ru: "Каждый бейдж означает отдельную проверку. Перед работой проверьте актуальные лицензии и страховку.", en: "Each badge represents a specific check. Verify current licenses and insurance before work starts.")),
        .init(id: "review", question: .init(he: "מי יכול לכתוב ביקורת?", ru: "Кто может оставить отзыв?", en: "Who can leave a review?"), answer: .init(he: "רק לקוח עם עבודה שסומנה כהושלמה.", ru: "Только клиент после работы, отмеченной завершенной.", en: "Only a client after the job is marked completed."))
    ]
}

struct AppNotification: Identifiable, Hashable, Codable {
    let id: String
    let title: LocalizedValue
    let body: LocalizedValue
    let systemImage: String
    let createdAt: Date
    var isRead: Bool
    let taskID: String?
    let conversationID: String?
    let kind: String
}

struct NotificationPreferences: Hashable, Codable {
    var taskUpdates: Bool
    var chatMessages: Bool
    var nearbyJobs: Bool

    static let enabled = NotificationPreferences(taskUpdates: true, chatMessages: true, nearbyJobs: true)
}

struct NotificationDestination: Identifiable, Hashable {
    let taskID: String
    let conversationID: String?
    let kind: String

    var id: String { conversationID ?? taskID }
}

struct SpecialistDestination: Identifiable, Hashable {
    let id: String
}
