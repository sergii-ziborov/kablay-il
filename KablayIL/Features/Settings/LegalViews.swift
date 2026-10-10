import SwiftUI

struct LegalSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

struct LegalLink: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

enum LegalDocument: String, CaseIterable, Identifiable {
    case about, platformRole, terms, privacy, responsibility, reviews, payments, disputes, safety, deletion, limitation

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .about: "info.circle.fill"
        case .platformRole: "person.2.badge.gearshape.fill"
        case .terms: "doc.text.fill"
        case .privacy: "hand.raised.fill"
        case .responsibility: "checklist.checked"
        case .reviews: "star.bubble.fill"
        case .payments: "creditcard.fill"
        case .disputes: "bubble.left.and.exclamationmark.bubble.right.fill"
        case .safety: "exclamationmark.shield.fill"
        case .deletion: "trash.slash.fill"
        case .limitation: "shield.lefthalf.filled"
        }
    }

    func title(locale: AppLocale) -> String {
        switch self {
        case .about: locale.text(he: "אודות KABLAY", ru: "О KABLAY", en: "About KABLAY")
        case .platformRole: locale.text(he: "תפקיד הפלטפורמה", ru: "Роль платформы", en: "Platform role")
        case .terms: locale.text(he: "תנאי שימוש", ru: "Условия использования", en: "Terms of Use")
        case .privacy: locale.text(he: "מדיניות פרטיות", ru: "Политика конфиденциальности", en: "Privacy Policy")
        case .responsibility: locale.text(he: "אחריות הצדדים", ru: "Ответственность сторон", en: "Responsibilities")
        case .reviews: locale.text(he: "חוות דעת ותגי פרופיל", ru: "Отзывы и отметки профиля", en: "Reviews & profile badges")
        case .payments: locale.text(he: "תשלומים, נקודות והחזרים", ru: "Оплата, баллы и возвраты", en: "Payments, points & refunds")
        case .disputes: locale.text(he: "תלונות ומחלוקות", ru: "Жалобы и споры", en: "Complaints & disputes")
        case .safety: locale.text(he: "בטיחות ורישיונות", ru: "Безопасность и лицензии", en: "Safety & licenses")
        case .deletion: locale.text(he: "מחיקת חשבון ומידע", ru: "Удаление аккаунта и данных", en: "Account & data deletion")
        case .limitation: locale.text(he: "הגבלת אחריות KABLAY", ru: "Ограничение ответственности KABLAY", en: "KABLAY liability limits")
        }
    }

    func summary(locale: AppLocale) -> String {
        switch self {
        case .about: locale.text(he: "מי אנחנו ואיך הזירה עובדת", ru: "Кто мы и как работает сервис", en: "Who we are and how the marketplace works")
        case .platformRole: locale.text(he: "זירה מקוונת, לא חברת תיקונים", ru: "Площадка, а не ремонтная компания", en: "A marketplace, not a repair company")
        case .terms: locale.text(he: "כללי חשבון, תוכן והתקשרות", ru: "Правила аккаунта, контента и сделок", en: "Account, content, and contracting rules")
        case .privacy: locale.text(he: "מידע, מטרות, ספקים וזכויות", ru: "Данные, цели, подрядчики и права", en: "Data, purposes, providers, and rights")
        case .responsibility: locale.text(he: "מה הלקוח ובעל המקצוע חייבים לבדוק", ru: "Что обязаны проверить клиент и мастер", en: "What clients and professionals must check")
        case .reviews: locale.text(he: "מקורות, מודרציה ומשמעות הבדיקה", ru: "Источники, модерация и смысл отметок", en: "Sources, moderation, and badge meaning")
        case .payments: locale.text(he: "תשלום ישיר וכללי שירותים דיגיטליים", ru: "Прямая оплата и цифровые услуги", en: "Direct payment and digital-service rules")
        case .disputes: locale.text(he: "תיעוד, תמיכה ורשויות מוסמכות", ru: "Документы, поддержка и органы", en: "Evidence, support, and authorities")
        case .safety: locale.text(he: "מצבי חירום ומאגרים רשמיים", ru: "Аварии и официальные реестры", en: "Emergencies and official registries")
        case .deletion: locale.text(he: "בקשה, אימות ומה עשוי להישמר", ru: "Запрос, проверка и сроки хранения", en: "Request, verification, and retention")
        case .limitation: locale.text(he: "מה KABLAY אינה מבטיחה", ru: "Что KABLAY не гарантирует", en: "What KABLAY does not guarantee")
        }
    }

    func sections(locale: AppLocale) -> [LegalSection] {
        switch self {
        case .about:
            return [
                section(locale, "מה זה KABLAY", "Что такое KABLAY", "What KABLAY is",
                        "KABLAY היא זירה מקוונת לתיקוני בית ושיפוצים בישראל. היא מחברת לקוחות עם בעלי מקצוע עצמאיים באמצעות קטלוג, משימות, הצעות, צ׳אט ופרופילים.",
                        "KABLAY — израильский онлайн-маркетплейс домашнего ремонта. Он связывает клиентов с независимыми мастерами через каталог, задачи, предложения, чат и профили.",
                        "KABLAY is an Israeli online marketplace for home repair and renovation. It connects clients with independent specialists through a catalog, tasks, offers, chat, and profiles."),
                section(locale, "איך זה עובד", "Как это работает", "How it works",
                        "הלקוח מתאר משימה ובוחר בעל מקצוע. הצדדים מסכמים ישירות היקף, מחיר, חומרים, לוחות זמנים, תשלום ואחריות. KABLAY מספקת את הכלים הדיגיטליים אך אינה מבצעת את העבודה.",
                        "Клиент описывает задачу и выбирает мастера. Стороны напрямую согласуют объём, цену, материалы, сроки, оплату и гарантию. KABLAY предоставляет цифровые инструменты, но не выполняет ремонт.",
                        "The client describes a task and selects a specialist. The parties directly agree scope, price, materials, timing, payment, and warranty. KABLAY provides digital tools but does not perform the work."),
                section(locale, "ישראל ושלוש שפות", "Израиль и три языка", "Israel and three languages",
                        "השירות מיועד לישראל וזמין בעברית, רוסית ואנגלית. עברית היא שפת ברירת המחדל ומוצגת מימין לשמאל.",
                        "Сервис предназначен для Израиля и доступен на иврите, русском и английском. Иврит используется по умолчанию с полноценным RTL-интерфейсом.",
                        "The service is designed for Israel and available in Hebrew, Russian, and English. Hebrew is the default with full right-to-left layout."),
                section(locale, "מפעיל ויצירת קשר", "Оператор и контакты", "Operator and contact",
                        "KABLAY הוא שם השירות. מפעיל השירות ובעל השליטה במאגר הוא איוון קמנצה. לפניות: support@kablay.co.il.",
                        "KABLAY — название сервиса. Оператор сервиса и владелец контроля над базой — Иван Каменца. Контакт: support@kablay.co.il.",
                        "KABLAY is the service name. The service operator and database controller is Ivan Kamenca. Contact: support@kablay.co.il.")
            ]
        case .platformRole:
            return [
                section(locale, "לא חברת תיקונים", "Не ремонтная компания", "Not a repair company",
                        "KABLAY אינה בוחרת בעל מקצוע עבור הלקוח, אינה מנהלת, מעסיקה או מפקחת על בעלי המקצוע ואינה מקבלת את העבודה בסיומה.",
                        "KABLAY не выбирает мастера за клиента, не руководит, не нанимает и не контролирует мастеров и не принимает работу после выполнения.",
                        "KABLAY does not select a specialist for the client, direct, employ, or supervise specialists, or accept completed work."),
                section(locale, "בעלי מקצוע עצמאיים", "Независимые мастера", "Independent specialists",
                        "הופעה בפרופיל אינה יוצרת יחסי עבודה, שליחות, שותפות או קבלנות משנה עם KABLAY. כל בעל מקצוע אחראי למצגיו, להצעתו, לעובדיו ולעבודתו.",
                        "Профиль не создаёт трудовых, агентских, партнёрских или субподрядных отношений с KABLAY. Каждый мастер отвечает за свои заявления, предложение, работников и работу.",
                        "A profile does not create employment, agency, partnership, or subcontracting with KABLAY. Each specialist is responsible for their statements, quote, workers, and work."),
                section(locale, "איוון הוא אחד מבעלי המקצוע", "Иван — один из мастеров", "Ivan is one of the specialists",
                        "איוון קמנצה אינו בעל המקצוע היחיד ביישום. הקטלוג כולל בעלי מקצוע פעילים שונים. אם לקוח בוחר באיוון או בכל בעל מקצוע אחר, ההסכם נכרת ישירות עם בעל המקצוע שנבחר והוא אחראי לעבודתו.",
                        "Иван Каменца не является единственным мастером приложения. В каталоге участвуют разные активные специалисты. Если клиент выбирает Ивана или любого другого мастера, договор заключается напрямую с выбранным исполнителем, и именно он отвечает за свою работу.",
                        "Ivan Kamenca is not the app's only specialist. The catalog contains different active specialists. If a client selects Ivan or any other specialist, the contract is directly with the selected contractor, who is responsible for that work."),
                section(locale, "מי מוצג ביישום", "Кто отображается в приложении", "Who appears in the app",
                        "ביישום מוצגים רק בעלי מקצוע שנכנסו לחשבונם לפחות פעם אחת. מנויי Premium מוצגים תחילה; לאחריהם בעלי מקצוע פעילים אחרים לפי ביקורות ודירוג. מנוי Premium אינו אישור איכות או רישיון.",
                        "В приложении показываются только мастера, которые хотя бы один раз вошли в свой кабинет. Сначала идут Premium-мастера, затем остальные активные мастера по отзывам и рейтингу. Premium не означает проверку качества или наличие лицензии.",
                        "The app shows only specialists who have signed in at least once. Premium specialists appear first, followed by other active specialists ranked by reviews and rating. Premium is not a quality verification or a license."),
                section(locale, "אין המלצה או ערבות", "Нет рекомендации или гарантии", "No endorsement or guarantee",
                        "תוצאות חיפוש, דירוג, תג או הופעה בקטלוג אינם המלצה, אישור איכות או הבטחה להתאמה. הלקוח חייב לבצע בדיקה עצמאית.",
                        "Поиск, рейтинг, отметка или наличие в каталоге не являются рекомендацией, подтверждением качества или обещанием пригодности. Клиент обязан провести собственную проверку.",
                        "Search order, ratings, badges, or catalog presence are not endorsements, quality approval, or promises of suitability. The client must perform an independent check.")
            ]
        case .terms:
            return [
                section(locale, "זכאות וחשבון", "Право использования и аккаунт", "Eligibility and account",
                        "המשתמש חייב להיות בגיר וכשיר משפטית או לפעול באישור נציג חוקי. הוא אחראי לטלפון, לקוד החד-פעמי, ל-PIN המקומי ולכל פעולה בחשבון. ניתן להגביל גישה בשל הפרת דין, זכויות אחרים או כללי בטיחות.",
                        "Пользователь должен быть совершеннолетним и дееспособным либо действовать с разрешения законного представителя. Он отвечает за телефон, одноразовый код, локальный PIN и действия аккаунта. Доступ может быть ограничен при нарушении закона, прав других лиц или правил безопасности.",
                        "A user must be an adult with legal capacity or act with a lawful representative’s permission. They are responsible for the phone, one-time code, local PIN, and account activity. Access may be limited for violations of law, others’ rights, or safety rules."),
                section(locale, "הסכם העבודה", "Договор на работу", "The work contract",
                        "הסכם התיקון נכרת רק בין הלקוח לבעל המקצוע שנבחר. לפני תחילת העבודה יש לתעד בכתב היקף, מחיר ומע״מ, חומרים, זמנים, גישה, היתרים, ביטוח, תשלומים ואחריות.",
                        "Договор на ремонт заключается только между клиентом и выбранным мастером. До начала работ письменно закрепите объём, цену и НДС, материалы, сроки, доступ, разрешения, страховку, платежи и гарантию.",
                        "The repair contract is only between the client and selected specialist. Before work starts, record scope, price and VAT, materials, timing, access, permits, insurance, payments, and warranty in writing."),
                section(locale, "תוכן והתנהגות", "Контент и поведение", "Content and conduct",
                        "אין לפרסם תוכן שקרי, בלתי חוקי, מסוכן, פוגעני, מפר זכויות או מידע אישי מיותר. אין להשתמש בפרטי קשר לספאם, למכירת מידע או למטרה שאינה קשורה למשימה.",
                        "Запрещены ложные, незаконные, опасные, оскорбительные материалы, нарушения прав и лишние персональные данные. Контакты нельзя использовать для спама, продажи данных или целей вне задачи.",
                        "False, unlawful, dangerous, abusive, rights-infringing content and unnecessary personal data are prohibited. Contacts may not be used for spam, data resale, or purposes unrelated to the task."),
                section(locale, "שירותים דיגיטליים", "Цифровые услуги", "Digital services",
                        "מחיר ותכולת נקודות או Premium מוצגים לפני רכישה. גישה לפרטי קשר היא שירות דיגיטלי ואינה מבטיחה הסכם או עבודה מוצלחת. רכישה ביישום מתבצעת דרך Apple ובכפוף גם לתנאי Apple. זכויות ביטול והחזר שלא ניתן לוותר עליהן נשמרות.",
                        "Цена и состав баллов или Premium показываются до покупки. Доступ к контакту — цифровая услуга и не гарантирует договор или успешную работу. Покупка в приложении проходит через Apple и подчиняется также условиям Apple. Неотменяемые права на отказ и возврат сохраняются.",
                        "The price and contents of points or Premium are shown before purchase. Contact access is a digital service and does not guarantee a contract or successful work. A purchase made in the app goes through Apple and is also subject to Apple’s terms. Non-waivable cancellation and refund rights remain."),
                section(locale, "שינויים ואכיפה", "Изменения и меры", "Changes and enforcement",
                        "KABLAY רשאית למתן תוכן, להשהות חשבון ולעדכן תנאים עם תאריך חדש והודעה נוספת כאשר הדין דורש זאת. שינויים אינם מפחיתים זכויות חובה שכבר נוצרו.",
                        "KABLAY может модерировать контент, приостанавливать аккаунт и обновлять условия с новой датой и дополнительным уведомлением, когда это требуется законом. Изменения не уменьшают уже возникшие обязательные права.",
                        "KABLAY may moderate content, suspend accounts, and update terms with a new date and additional notice where required. Changes do not reduce mandatory rights already accrued."),
                section(locale, "דין חל", "Применимое право", "Applicable law",
                        "על השירות חל דין מדינת ישראל. אין בתנאים כדי לבטל זכויות צרכן, פרטיות או הגנות אחרות שלא ניתן להתנות עליהן. הוראה בלתי תקפה לא תפגע ביתר התנאים.",
                        "К сервису применяется право Государства Израиль. Условия не отменяют права потребителя, конфиденциальность и иные гарантии, от которых нельзя отказаться. Недействительность одного пункта не затрагивает остальные.",
                        "The laws of the State of Israel apply. These terms do not waive consumer, privacy, or other protections that cannot lawfully be excluded. If one term is invalid, the others remain effective.")
            ]
        case .privacy:
            return [
                section(locale, "מידע שאנו מעבדים", "Какие данные обрабатываются", "Data we process",
                        "המידע עשוי לכלול שם, טלפון, שפה, תפקיד, עיר וכתובת משימה, תיאורים, תמונות, פרופיל, מסמכי רישיון, הצעות, צ׳אטים, חוות דעת, פניות, מזהי תשלום ורכישות App Store, IP, נתוני מכשיר ומינוי push.",
                        "Данные могут включать имя, телефон, язык, роль, город и адрес задачи, описания, фото, профиль, документы лицензий, предложения, чаты, отзывы, обращения, идентификаторы платежей и покупок App Store, IP, данные устройства и push-токен.",
                        "Data may include name, phone, language, role, task city and address, descriptions, photos, profile, license records, offers, chats, reviews, support requests, payment and App Store purchase identifiers, IP, device data, and push tokens."),
                section(locale, "מטרות ובחירה", "Цели и добровольность", "Purposes and choice",
                        "המידע משמש להפעלת ואבטחת החשבון, פרסום והתאמת משימות, תקשורת, תשלום עבור תכונות דיגיטליות, מודרציה, תמיכה, מניעת הונאה, ניתוח, קיום דין והגנת זכויות. ללא שדה חובה לא ניתן לספק את התכונה המתאימה.",
                        "Данные нужны для работы и защиты аккаунта, публикации и подбора задач, связи, оплаты цифровых функций, модерации, поддержки, предотвращения мошенничества, аналитики, соблюдения закона и защиты прав. Без обязательного поля функция может быть недоступна.",
                        "Data is used to operate and secure accounts, publish and match tasks, communicate, process digital-feature payments, moderate, support, prevent fraud, analyze, comply with law, and protect rights. A feature may be unavailable without a required field."),
                section(locale, "מידע ציבורי ופרטי קשר", "Публичность и контакты", "Public data and contacts",
                        "מידע שפורסם בפרופיל בעל מקצוע עשוי להיות גלוי לציבור ולמנועי חיפוש. כתובת מדויקת של לקוח אינה מיועדת לקטלוג; פרטי קשר נפתחים לפי כללי המשימה. אין לפרסם מסמכים או מידע רגיש שאינם נחוצים.",
                        "Опубликованные данные профиля мастера могут быть видны посетителям и поисковикам. Точный адрес клиента не предназначен для каталога; контакты раскрываются по правилам задачи. Не загружайте ненужные документы или чувствительные данные.",
                        "Published specialist-profile data may be visible to visitors and search engines. A client’s exact address is not intended for the catalog; contacts are disclosed under task rules. Do not upload unnecessary documents or sensitive data."),
                section(locale, "עותקים לא מקוונים", "Сохранённые данные на устройстве", "Offline copies on the device",
                        "היישום שומר במכשיר עותקים של קטלוג, מאמרים, תמונות, משימות ושיחות כדי לאפשר קריאה ללא חיבור. מוצג מועד העדכון האחרון; ייתכן שהעותק אינו עדכני. מידע אישי שמור מופרד לפי חשבון ונמחק בהתנתקות.",
                        "Приложение сохраняет на устройстве каталог, статьи, изображения, задачи и переписку для просмотра без сети. Показано время последнего обновления; сохранённые данные могут устареть. Личные копии разделены по аккаунтам и удаляются при выходе.",
                        "The app saves catalog, articles, images, tasks, and conversations on the device for offline reading. It shows the last update time; saved data may become outdated. Personal copies are separated by account and removed on sign-out."),
                section(locale, "ספקים והעברה", "Подрядчики и передача", "Providers and transfers",
                        "אנו עשויים למסור את המינימום הדרוש לספקי ענן, SMS, תשלום, אחסון, מפות, ניתוח, תמיכה ויועצים, וכן לרשויות מוסמכות. חלק מהעיבוד עשוי להתבצע מחוץ לישראל בכפוף לדין. איננו מוכרים מידע אישי.",
                        "Минимально необходимые данные могут передаваться облачным, SMS-, платёжным, файловым, картографическим, аналитическим и техническим подрядчикам, консультантам и компетентным органам. Часть обработки может происходить за пределами Израиля по закону. Мы не продаём персональные данные.",
                        "We may share the minimum necessary data with cloud, SMS, payment, file, mapping, analytics, support providers, advisers, and competent authorities. Some processing may occur outside Israel subject to law. We do not sell personal data."),
                section(locale, "חיפוש חכם ו-AI", "Умный поиск и AI", "Smart search and AI",
                        "החיפוש החכם שולח טקסט ל-Cloudflare Workers AI, ספק צד שלישי, לצורך סיווג לקטגוריה סגורה בלבד — ורק לאחר הסכמה מפורשת שניתנת לביטול בהגדרות. לפני השליחה מוסרים מהטקסט מספרי טלפון, כתובות דוא״ל, קישורים ומספרי בית ודירה; שם, מזהה חשבון ומיקום מדויק אינם נשלחים. ללא הסכמה הקטלוג והבקשות עובדים במלואם. אין להזין מספרי זהות, פרטי תשלום או מידע רפואי.",
                        "Умный поиск передаёт текст стороннему сервису Cloudflare Workers AI только для классификации по закрытому списку категорий — и только после явного согласия, которое можно отозвать в настройках. Перед отправкой из текста удаляются телефоны, адреса почты, ссылки, номера домов и квартир; имя, идентификатор аккаунта и точная геопозиция не передаются. Без согласия каталог и заявки работают полностью. Не вводите номера документов, платёжные или медицинские данные.",
                        "Smart Search sends text to Cloudflare Workers AI, a third-party processor, solely for closed-list category classification, and only after explicit consent that can be withdrawn in Settings. Phone numbers, email addresses, links, and house or apartment numbers are removed before sending; name, account identifier, and exact location are never sent. Without consent the catalog and requests work in full. Do not enter identity, payment, or medical data."),
                section(locale, "אבטחה ושמירה", "Безопасность и хранение", "Security and retention",
                        "KABLAY נוקטת אמצעים סבירים והגבלות גישה, אך אין מערכת בטוחה לחלוטין. מידע נשמר כל עוד דרוש לשירות, אבטחה, מניעת הונאה, מחלוקות, חשבונאות וציות; גיבויים נדרסים במחזור המתוכנן.",
                        "KABLAY применяет разумные меры и разграничение доступа, но абсолютной безопасности не существует. Данные хранятся для сервиса, безопасности, предотвращения мошенничества, споров, учёта и закона; резервные копии удаляются по плановому циклу.",
                        "KABLAY uses reasonable controls and access restrictions, but no system is absolutely secure. Data is kept for service, security, fraud prevention, disputes, accounting, and legal compliance; backups expire on their scheduled cycle."),
                section(locale, "הזכויות שלכם", "Ваши права", "Your rights",
                        "בכפוף לחוק הגנת הפרטיות בישראל ניתן לבקש עיון, ובמקרים הקבועים בדין תיקון או מחיקה של מידע שגוי, חסר, לא ברור או לא מעודכן, וכן מחיקת חשבון או חזרה מהסכמה אופציונלית. אנו רשאים לאמת זהות.",
                        "По Закону Израиля о защите конфиденциальности можно запросить доступ, а в предусмотренных случаях исправление или удаление неверных, неполных, неясных или устаревших данных, удаление аккаунта или отзыв необязательного согласия. Мы вправе безопасно проверить личность.",
                        "Under Israel’s Protection of Privacy Law, you may request access and, where provided by law, correction or deletion of incorrect, incomplete, unclear, or outdated data, account deletion, or withdrawal of optional consent. We may securely verify identity.")
            ]
        case .responsibility:
            return [
                section(locale, "אחריות הלקוח", "Ответственность клиента", "Client responsibility",
                        "למסור מידע מדויק, לאפשר גישה בטוחה, לבדוק בעלות והרשאות בנכס, לבחור בעל מקצוע, לבדוק רישיון וביטוח, לאשר הצעה ולשלם לפי ההסכם.",
                        "Дать точные сведения, обеспечить безопасный доступ, проверить право распоряжаться объектом, выбрать мастера, проверить лицензию и страховку, согласовать предложение и оплатить по договору.",
                        "Provide accurate details, safe access, authority over the property, select a specialist, check licensing and insurance, approve the quote, and pay under the agreement."),
                section(locale, "אחריות בעל המקצוע", "Ответственность мастера", "Specialist responsibility",
                        "לשמור מידע עדכני, לבצע רק עבודה המותרת לו, למסור הצעה ברורה, להשתמש בעובדים וחומרים מתאימים, לשמור על בטיחות, למנוע נזק ולהנפיק חשבונית ומסמכים כנדרש.",
                        "Поддерживать актуальные сведения, выполнять только разрешённые работы, дать понятную смету, использовать подходящих работников и материалы, соблюдать безопасность, предотвращать ущерб и выдавать требуемые документы.",
                        "Keep details current, perform only authorized work, provide a clear quote, use suitable workers and materials, follow safety rules, prevent damage, and issue required invoices and records."),
                section(locale, "רישיונות וביטוח", "Лицензии и страховка", "Licensing and insurance",
                        "בעל המקצוע אחראי לרישיון תקף ובסיווג מתאים. הלקוח חייב לבדוק את המספר, התוקף והיקף ההרשאה במאגר הרשמי. תג KABLAY אינו מחליף את הבדיקה.",
                        "Мастер отвечает за действующую лицензию подходящей категории. Клиент должен проверить номер, срок и полномочия в официальном реестре. Отметка KABLAY не заменяет проверку.",
                        "The specialist is responsible for a current license with the correct scope. The client must verify number, validity, and authorization in the official registry. A KABLAY badge does not replace that check."),
                section(locale, "נזק ואחריות לעבודה", "Ущерб и гарантия работы", "Damage and workmanship warranty",
                        "הצדדים צריכים לקבוע מראש מי אחראי לחומרים, הגנת הרכוש, נזק לצד שלישי, פינוי פסולת ותנאי אחריות לתיקון. KABLAY אינה צד להסכמה זו.",
                        "Стороны заранее определяют ответственность за материалы, защиту имущества, ущерб третьим лицам, вывоз мусора и гарантию на работу. KABLAY не является стороной этой договорённости.",
                        "The parties should agree responsibility for materials, property protection, third-party damage, waste removal, and workmanship warranty. KABLAY is not a party to that arrangement."),
                section(locale, "תיעוד", "Документы", "Documentation",
                        "שמרו תיאור, תמונות לפני ואחרי, הצעה, שינויים, חשבוניות, קבלות, אישורי תשלום, תכתובות ותנאי אחריות. תיעוד מפחית מחלוקות ומסייע אם נדרש בירור.",
                        "Храните описание, фото до и после, смету, изменения, счета, чеки, подтверждения оплаты, переписку и гарантию. Документы снижают риск спора и помогают при разбирательстве.",
                        "Keep the description, before-and-after photos, quote, changes, invoices, receipts, payment confirmations, messages, and warranty terms. Records reduce disputes and help any review.")
            ]
        case .reviews:
            return [
                section(locale, "דעת הכותב", "Мнение автора", "Author opinion",
                        "חוות דעת מבטאת את דעת הכותב ואינה קביעה של KABLAY. מקור חוות הדעת מסומן כאשר הוא ידוע; דירוג או טקסט מיובאים עשויים להשתנות או להתיישן.",
                        "Отзыв выражает мнение автора, а не позицию KABLAY. Источник указывается, когда известен; импортированные рейтинги и тексты могут измениться или устареть.",
                        "A review is its author’s opinion, not a KABLAY finding. The source is labelled where known; imported ratings and text may change or become stale."),
                section(locale, "חוות דעת לאחר עבודה", "Отзыв после работы", "Review after work",
                        "חוות דעת פנימית נועדה להתפרסם לאחר משימה שהושלמה או התקשרות מתועדת. אין לפרסם ביקורת מזויפת, נקמנית, סחטנית או מטעם אדם שלא השתתף בעבודה.",
                        "Внутренний отзыв предназначен для завершённой задачи или подтверждённого взаимодействия. Запрещены поддельные, мстительные, вымогательские отзывы и отзывы лиц, не участвовавших в работе.",
                        "An internal review is intended for a completed task or documented engagement. Fake, retaliatory, extortionate, or non-participant reviews are prohibited."),
                section(locale, "מודרציה", "Модерация", "Moderation",
                        "KABLAY רשאית לבקש חומר, לסמן מקור, לעכב, להסתיר או להסיר תוכן לפי כללי השירות והדין, אך אינה מאמתת כל טענה ואינה מבטיחה את דיוק חוות הדעת.",
                        "KABLAY может запросить материалы, отметить источник, задержать, скрыть или удалить контент по правилам и закону, но не проверяет каждое утверждение и не гарантирует точность отзывов.",
                        "KABLAY may request records, label a source, delay, hide, or remove content under service rules and law, but does not verify every statement or guarantee review accuracy."),
                section(locale, "תגי פרופיל", "Отметки профиля", "Profile badges",
                        "כל תג מעיד רק על בדיקה מוגדרת במועד מסוים. הוא אינו המלצה, רישיון, בדיקת רקע מלאה, ערבות לביטוח או הבטחה לאיכות עתידית.",
                        "Каждая отметка означает только конкретную проверку на определённую дату. Это не рекомендация, лицензия, полная проверка биографии, гарантия страховки или будущего качества.",
                        "Each badge reflects only a defined check at a point in time. It is not an endorsement, license, full background check, insurance guarantee, or promise of future quality."),
                section(locale, "פרופילים מיובאים", "Импортированные профили", "Imported profiles",
                        "פרופיל המסומן ״מיובא״ או ״לא נתבע״ עשוי להגיע ממקור ציבורי ואינו מעיד שהעסק הצטרף ל-KABLAY. בעל הפרופיל יכול לבקש מקור, תיקון, גישה או הסרה.",
                        "Профиль с отметкой «импортирован» или «не заявлен» может происходить из публичного источника и не означает, что бизнес присоединился к KABLAY. Владелец может запросить источник, исправление, доступ или удаление.",
                        "An “imported” or “unclaimed” profile may come from a public source and does not mean the business joined KABLAY. The owner may request source details, correction, access, or removal.")
            ]
        case .payments:
            return [
                section(locale, "תשלום עבור העבודה", "Оплата ремонта", "Payment for work",
                        "ברירת המחדל היא תשלום ישיר מהלקוח לבעל המקצוע. KABLAY אינה מחזיקה את כספי העבודה ואינה צד לחיוב, אלא אם תכונה נפרדת קובעת במפורש אחרת.",
                        "По умолчанию клиент платит мастеру напрямую. KABLAY не хранит деньги за ремонт и не является стороной платежа, если отдельная функция прямо не говорит обратное.",
                        "By default, the client pays the specialist directly. KABLAY does not hold repair funds or become a party to that payment unless a separate feature expressly states otherwise."),
                section(locale, "נקודות ו-Premium", "Баллы и Premium", "Points and Premium",
                        "נקודות הן יחידת גישה פנימית ולא כסף, פיקדון או השקעה. חיוב עבור פתיחת קשר מעניק את הגישה המתוארת בלבד ואינו מבטיח תשובה, הסכם או הכנסה. נקודות בונוס אינן ניתנות למשיכה.",
                        "Баллы — внутренняя единица доступа, а не деньги, депозит или инвестиция. Списание за контакт даёт только описанный доступ и не гарантирует ответ, договор или доход. Бонусные баллы нельзя вывести.",
                        "Points are an internal access unit, not money, a deposit, or an investment. A contact-access charge grants only the described access and does not guarantee a reply, contract, or income. Bonus points cannot be withdrawn."),
                section(locale, "רכישה באפליקציה", "Покупка в приложении", "Buying inside the app",
                        "רכישת נקודות ו-Premium ביישום ל-iPhone מתבצעת דרך Apple. החיוב מבוצע בחשבון Apple של המשתמש בעת האישור, ו-KABLAY אינה רואה ואינה שומרת פרטי אמצעי תשלום. המחיר והתכולה מוצגים לפני האישור.",
                        "Покупка баллов и Premium в приложении для iPhone проходит через Apple. Списание выполняется с аккаунта Apple в момент подтверждения; KABLAY не видит и не хранит платёжные реквизиты. Цена и состав показываются до подтверждения.",
                        "Buying points or Premium in the iPhone app is processed by Apple. The charge is made to the user’s Apple account on confirmation, and KABLAY neither sees nor stores payment details. Price and contents are shown before confirmation."),
                section(locale, "מנוי Premium", "Подписка Premium", "Premium subscription",
                        "Premium הוא מנוי חודשי המתחדש אוטומטית דרך Apple עד לביטול. המחיר המקומי מוצג לפני אישור הרכישה. אפשר לבטל בהגדרות המינויים של Apple; הגישה נמשכת עד סוף התקופה ששולמה. תקופות של 30 יום שנרכשו בעבר נשארות בתוקף עד לסיומן. Premium אינו מבטיח פניות, עבודות או הכנסה.",
                        "Premium — ежемесячная подписка Apple с автопродлением до отмены. Итоговая цена показана перед покупкой. Отмена доступна в настройках подписок Apple; доступ сохраняется до конца оплаченного периода. Ранее купленные разовые периоды на 30 дней действуют до своего окончания. Premium не гарантирует обращения, заказы или доход.",
                        "Premium is a monthly Apple subscription that renews until cancelled. The local price appears before purchase. Cancel in Apple subscription settings; access continues through the paid period. Previously purchased 30-day passes remain valid until they end. Premium does not guarantee enquiries, jobs, or income."),
                section(locale, "החזר על רכישה באפליקציה", "Возврат покупки в приложении", "Refunds for in-app purchases",
                        "בקשת החזר על רכישה שבוצעה דרך Apple מוגשת ל-Apple ב-reportaproblem.apple.com ומוכרעת על ידה. KABLAY אינה יכולה לבטל חיוב של Apple. אם Apple מחזירה תשלום, ההטבה המתאימה מוסרת מהחשבון.",
                        "Возврат покупки, совершённой через Apple, запрашивается у Apple на reportaproblem.apple.com и решается Apple. KABLAY не может отменить списание Apple. Если Apple вернула платёж, соответствующая выгода снимается с аккаунта.",
                        "A refund for a purchase made through Apple is requested from Apple at reportaproblem.apple.com and decided by Apple. KABLAY cannot reverse an Apple charge. If Apple refunds a payment, the matching benefit is removed from the account."),
                section(locale, "מחיר, מסים ומסמכים", "Цена, налоги и документы", "Price, tax, and records",
                        "כל צד אחראי למסיו ולמסמכים הנדרשים ממנו. מחיר שירות דיגיטלי, מע״מ אם חל ותכולתו מוצגים לפני רכישה. מחיר תיקון, חומרים ומע״מ מסוכמים בנפרד עם בעל המקצוע.",
                        "Каждая сторона отвечает за свои налоги и документы. Цена цифровой услуги, применимый НДС и состав показываются до покупки. Цена ремонта, материалов и НДС отдельно согласуются с мастером.",
                        "Each party is responsible for its own taxes and required records. A digital service’s price, applicable VAT, and contents are shown before purchase. Repair price, materials, and VAT are separately agreed with the specialist."),
                section(locale, "ביטול והחזרים", "Отмена и возвраты", "Cancellation and refunds",
                        "כללי זיכוי אוטומטי, אם קיימים, מוצגים לפני הרכישה או באזור היתרה. זכויות צרכן מחייבות נשמרות. בקשת ביטול יש לשלוח דרך הכלי המתאים או support@kablay.co.il; מחיקת חשבון אינה הודעת ביטול.",
                        "Правила автоматического возврата, если они есть, показываются до покупки или в балансе. Обязательные права потребителя сохраняются. Запрос направляется через соответствующий инструмент или support@kablay.co.il; удаление аккаунта не считается отменой покупки.",
                        "Automatic credit rules, if any, are shown before purchase or in the balance. Mandatory consumer rights remain. Send cancellation through the relevant tool or support@kablay.co.il; account deletion is not purchase cancellation.")
            ]
        case .disputes:
            return [
                section(locale, "פנייה ישירה", "Сначала к другой стороне", "Contact the other party first",
                        "בנושאי מחיר, איחור, ביקור חוזר, תיקון או אחריות פנו תחילה לצד השני בצ׳אט ובטלפון וציינו את העובדות והפתרון המבוקש.",
                        "По цене, задержке, повторному визиту, исправлению или гарантии сначала обратитесь ко второй стороне в чате и по телефону, изложив факты и желаемое решение.",
                        "For price, delay, repeat visits, correction, or warranty, contact the other party first by chat and phone, stating the facts and requested resolution."),
                section(locale, "מה לשמור", "Что сохранить", "What to preserve",
                        "שמרו את המשימה, ההצעה, צילומים, סרטון קצר, תאריכים, תכתובות, חשבוניות, קבלות, אישורי תשלום וחוות דעת טכנית עצמאית אם נדרשת.",
                        "Сохраните задачу, смету, фото, короткое видео, даты, переписку, счета, чеки, подтверждения оплаты и независимое техническое заключение, если оно нужно.",
                        "Keep the task, quote, photos, a short video, dates, messages, invoices, receipts, payment proof, and independent technical opinion if needed."),
                section(locale, "מה KABLAY רשאית לעשות", "Что может KABLAY", "What KABLAY may do",
                        "KABLAY רשאית לעיין במידע הזמין לה, לבקש מסמכים, להעביר תלונה, למתן תוכן או להגביל חשבון. היא אינה בית משפט, בוררת, מומחית הנדסית, מבטחת או נציגת צד.",
                        "KABLAY может изучить доступные данные, запросить документы, передать жалобу, модерировать контент или ограничить аккаунт. Она не является судом, арбитром, техническим экспертом, страховщиком или представителем стороны.",
                        "KABLAY may review available data, request records, forward a complaint, moderate content, or restrict an account. It is not a court, arbitrator, technical expert, insurer, or party representative."),
                section(locale, "אין התחייבות לתוצאה", "Результат не гарантируется", "No guaranteed outcome",
                        "התמיכה אינה מתחייבת למועד תגובה, לתגובת הצד השני, לביקור, לתיקון, להחזר, לפיצוי או להסדר. סיוע בתקשורת אינו הודאה באחריות או אישור לגרסה כלשהי.",
                        "Поддержка не гарантирует срок ответа, ответ другой стороны, визит, исправление, возврат, компенсацию или соглашение. Помощь в общении не означает признания ответственности или подтверждения чьей-либо версии.",
                        "Support does not guarantee response timing, the other party’s reply, a visit, correction, refund, compensation, or settlement. Communication assistance is not an admission of liability or confirmation of either account."),
                section(locale, "רשויות וזכויות", "Органы и права", "Authorities and rights",
                        "הצדדים רשאים לפנות לבית משפט, לרשות להגנת הצרכן, למשטרה, לרשות רישוי או לייעוץ משפטי לפי העניין. פנייה ל-KABLAY אינה עוצרת מועד חוקי.",
                        "Стороны могут обратиться в суд, Управление защиты потребителей, полицию, лицензирующий орган или за юридической помощью. Обращение в KABLAY не приостанавливает законные сроки.",
                        "Parties may contact a court, Consumer Protection Authority, police, licensing authority, or legal adviser as appropriate. Contacting KABLAY does not suspend legal deadlines.")
            ]
        case .safety:
            return [
                section(locale, "סכנה מיידית", "Немедленная опасность", "Immediate danger",
                        "בריח גז, עשן, אש, ניצוצות, מים ליד חשמל, קריסה או הצפה: התרחקו, אל תגעו בציוד וצרו קשר עם שירות החירום המתאים. משטרה 100, מד״א 101, כבאות 102.",
                        "При запахе газа, дыме, огне, искрении, воде возле электричества, обрушении или затоплении уйдите из зоны риска, не трогайте оборудование и вызовите службу: полиция 100, скорая 101, пожарные 102.",
                        "For gas smell, smoke, fire, sparking, water near electricity, collapse, or flooding, leave the area, do not touch equipment, and call the appropriate service: police 100, ambulance 101, fire 102."),
                section(locale, "עבודות חשמל", "Электромонтажные работы", "Electrical work",
                        "עבודות חשמל ותכנון יבוצעו רק בידי בעל רישיון מתאים לסוג העבודה ולהיקף הנכס. בדקו רישיון דיגיטלי וסמכויות במאגר משרד העבודה לפני התחלה.",
                        "Электромонтаж и проектирование выполняет только специалист с лицензией нужного типа и полномочий для объекта. До начала проверьте цифровую лицензию в реестре Министерства труда.",
                        "Electrical work and design must be done by a license holder with the correct type and scope for the property. Verify the digital license in the Ministry of Labor registry before work starts."),
                section(locale, "קבלנים ושיפוץ גדול", "Подрядчики и большой ремонт", "Contractors and major renovation",
                        "עבודות הנדסה בנאיות מסוימות לפי סוג או היקף חייבות להתבצע בידי קבלן רשום. בדקו ענף, קבוצה, סיווג, תוקף והיקף מותר בפנקס הקבלנים.",
                        "Некоторые строительные работы по виду или объёму обязаны выполнять зарегистрированные подрядчики. Проверяйте отрасль, группу, класс, статус и разрешённый объём в Реестре подрядчиков.",
                        "Certain construction works by type or scale must be performed by a registered contractor. Check branch, group, classification, status, and permitted scope in the Contractors Registry."),
                section(locale, "גז, גובה ומבנה", "Газ, высота и конструкция", "Gas, height, and structure",
                        "אל תנסו עבודת גז, לוח חשמל, גג לא מוגן, פיר, קיר נושא או שינוי מבני ללא בעל מקצוע מורשה, ציוד מגן והיתרים נדרשים. אל תסתמכו על ייעוץ מרחוק במצב מסוכן.",
                        "Не выполняйте самостоятельно газовые работы, щит, неограждённую крышу, шахту, несущую стену или конструктивные изменения без лицензированного специалиста, защиты и разрешений. При опасности не полагайтесь на дистанционный совет.",
                        "Do not attempt gas work, an electrical panel, unprotected roof, shaft, load-bearing wall, or structural change without licensed expertise, protective equipment, and required permits. Do not rely on remote advice during a hazard."),
                section(locale, "בדיקה עצמאית", "Самостоятельная проверка", "Independent verification",
                        "קטגוריה חכמה, דירוג, תג או מסמך שהועלה לפרופיל הם נקודת התחלה בלבד. KABLAY אינה רשות רישוי ואינה מבטיחה שהמידע מלא, עדכני או מתאים למשימה.",
                        "Умная категория, рейтинг, отметка или загруженный документ — только отправная точка. KABLAY не является лицензирующим органом и не гарантирует полноту, актуальность или пригодность данных.",
                        "Smart category, rating, badge, or uploaded document is only a starting point. KABLAY is not a licensing authority and does not guarantee that information is complete, current, or suitable for the task.")
            ]
        case .deletion:
            return [
                section(locale, "איך מגישים בקשה", "Как подать запрос", "How to request deletion",
                        "שלחו בקשה מתוך החשבון או ל-support@kablay.co.il מהטלפון או הדוא״ל המקושרים. ציינו אם הבקשה היא למחיקת חשבון, עיון, תיקון או מחיקת מידע מסוים.",
                        "Отправьте запрос из аккаунта или на support@kablay.co.il с привязанного телефона или email. Укажите: удаление аккаунта, доступ, исправление или удаление конкретных данных.",
                        "Send the request from the account or to support@kablay.co.il using the linked phone or email. State whether you seek account deletion, access, correction, or deletion of specific data."),
                section(locale, "אימות זהות", "Проверка личности", "Identity verification",
                        "כדי להגן על החשבון אנו רשאים לאמת זהות באופן מידתי ולא נבקש PIN של האפליקציה. אין לשלוח תעודת זהות מלאה אלא אם התמיכה הסבירה מדוע היא נחוצה ונתנה ערוץ מאובטח.",
                        "Для защиты аккаунта мы можем соразмерно проверить личность, но не просим PIN приложения. Не отправляйте полный документ личности, если поддержка не объяснила необходимость и не дала защищённый канал.",
                        "To protect the account, we may proportionately verify identity but will not ask for the app PIN. Do not send a full identity document unless support explains why it is needed and provides a secure channel."),
                section(locale, "מה נמחק", "Что удаляется", "What is deleted",
                        "החשבון יושבת ומידע יימחק או יעבור אנונימיזציה במידה החלה. פרופיל ציבורי עשוי להיות מוסר או מסומן כלא פעיל בהתאם למקור ולזכויות צדדים אחרים.",
                        "Аккаунт деактивируется, а данные удаляются или обезличиваются в применимой части. Публичный профиль может быть удалён или отмечен неактивным с учётом источника и прав других лиц.",
                        "The account is deactivated and data is deleted or de-identified to the applicable extent. A public profile may be removed or marked inactive subject to its source and others’ rights."),
                section(locale, "מה עשוי להישמר", "Что может сохраниться", "What may be retained",
                        "רשומות עשויות להישמר כאשר הדבר דרוש לפי דין, חשבונאות, מניעת הונאה, אבטחה, טיפול במחלוקת או הגנת זכויות. עותקי גיבוי נשמרים עד למחזור הדריסה המתוכנן.",
                        "Записи могут храниться для соблюдения закона, учёта, предотвращения мошенничества, безопасности, споров или защиты прав. Резервные копии сохраняются до плановой перезаписи.",
                        "Records may be retained for law, accounting, fraud prevention, security, disputes, or protection of rights. Backup copies remain until scheduled overwrite."),
                section(locale, "מחיקה אינה ביטול רכישה", "Удаление не отменяет покупку", "Deletion is not purchase cancellation",
                        "בקשת מחיקה אינה כשלעצמה בקשת ביטול או החזר ואינה מבטלת חוב, תביעה או אחריות שנוצרו קודם. שלחו בקשת ביטול נפרדת כאשר נדרש.",
                        "Удаление само по себе не является запросом отмены или возврата и не прекращает ранее возникший долг, требование или ответственность. При необходимости подайте отдельную заявку на отмену.",
                        "Deletion alone is not a cancellation or refund request and does not extinguish a prior debt, claim, or responsibility. Submit a separate cancellation request where needed.")
            ]
        case .limitation:
            return [
                section(locale, "השירות כפי שהוא", "Сервис «как есть»", "Service as available",
                        "KABLAY שואפת לזמינות ודיוק אך אינה מבטיחה פעולה רציפה, ללא שגיאות, ללא אובדן, ללא גישה לא מורשית או התאמה מלאה לכל צורך. ייתכנו תחזוקה, תקלות ושירותי צד שלישי.",
                        "KABLAY стремится к доступности и точности, но не гарантирует непрерывную работу, отсутствие ошибок, потерь, несанкционированного доступа или полное соответствие каждой цели. Возможны обслуживание, сбои и зависимость от третьих сервисов.",
                        "KABLAY aims for availability and accuracy but does not guarantee uninterrupted, error-free operation, absence of loss or unauthorized access, or fitness for every purpose. Maintenance, outages, and third-party dependencies may occur."),
                section(locale, "עבודת משתמשים וצדדים שלישיים", "Работа пользователей и третьих лиц", "Users and third parties",
                        "KABLAY אינה מתחייבת לזהות, זמינות, כישורים, רישיון, ביטוח, מחיר, בטיחות, איכות, זמן או תוצאה של בעל מקצוע עצמאי; לתגובה של לקוח; או לדיוק תוכן, ביקורת, קישור או שירות חיצוני.",
                        "KABLAY не гарантирует личность, доступность, квалификацию, лицензию, страховку, цену, безопасность, качество, сроки или результат независимого мастера; ответ клиента; точность контента, отзыва, ссылки или внешнего сервиса.",
                        "KABLAY does not guarantee an independent specialist’s identity, availability, qualifications, license, insurance, price, safety, quality, timing, or outcome; a client reply; or external content, reviews, links, or services."),
                section(locale, "אין קרן פיצוי", "Нет компенсационного фонда", "No compensation fund",
                        "אלא אם הצעה נפרדת ובכתב קובעת במפורש אחרת, KABLAY אינה מספקת ביטוח, נאמנות כספים, ערבות עבודה, קרן פיצוי או התחייבות להחזר, ביקור חוזר או תיקון של עבודת בעל מקצוע.",
                        "Если отдельное письменное предложение прямо не говорит обратное, KABLAY не предоставляет страховку, эскроу, гарантию ремонта, компенсационный фонд и не обещает возврат, повторный визит или исправление работы мастера.",
                        "Unless a separate written offer expressly states otherwise, KABLAY does not provide insurance, escrow, workmanship guarantee, compensation fund, or a promise of refund, repeat visit, or correction of specialist work."),
                section(locale, "היקף ההגבלה", "Предел ограничения", "Scope of limitation",
                        "במידה המרבית המותרת בדין, המפעיל אינו אחראי למעשה או למחדל של משתמש אחר או לנזק עקיף, תוצאתי או בלתי צפוי שנובע מהתקשרות עצמאית. אין בכך לגרוע מאחריות המבצע הישיר לעבודתו.",
                        "В максимально допустимой законом степени оператор не отвечает за действие или бездействие другого пользователя либо косвенный, последующий или непредвидимый ущерб из независимой сделки. Это не уменьшает ответственность непосредственного исполнителя за свою работу.",
                        "To the maximum extent permitted by law, the operator is not liable for another user’s act or omission or indirect, consequential, or unforeseeable loss from an independent engagement. This does not reduce a direct contractor’s responsibility for their own work."),
                section(locale, "זכויות שלא ניתן לבטל", "Неотменяемые права", "Non-waivable rights",
                        "שום נוסח אינו שולל אחריות או זכות שלא ניתן לשלול לפי דין, לרבות זכויות צרכן ופרטיות או אחריות של אדם לעבודתו הישירה. במקרה של סתירה גובר הדין החל.",
                        "Никакая формулировка не исключает ответственность или право, которые нельзя исключить законом, включая обязательные права потребителя и конфиденциальности и ответственность лица за собственную работу. При конфликте применяется закон.",
                        "Nothing excludes liability or rights that cannot lawfully be excluded, including mandatory consumer and privacy rights and a person’s responsibility for their direct work. Applicable law prevails in a conflict.")
            ]
        }
    }

    func links(locale: AppLocale) -> [LegalLink] {
        switch self {
        case .terms:
            return [legalLink(locale, "התנאים המלאים באתר KABLAY", "Полные условия на сайте KABLAY", "Full Terms on KABLAY", localizedPath(locale, "terms"))]
        case .privacy:
            return [
                legalLink(locale, "המדיניות המלאה באתר KABLAY", "Полная политика KABLAY", "Full KABLAY Privacy Policy", localizedPath(locale, "privacy")),
                legalLink(locale, "הרשות להגנת הפרטיות", "Управление защиты конфиденциальности Израиля", "Israel Privacy Protection Authority", "https://www.gov.il/en/departments/the_privacy_protection_authority/govil-landing-page")
            ]
        case .disputes:
            return [legalLink(locale, "הגשת תלונה לרשות להגנת הצרכן", "Жалоба в Управление защиты потребителей", "Consumer Protection complaint", "https://www.gov.il/en/service/filing_a_complaint_to_fair_trade_authority")]
        case .safety:
            return [
                legalLink(locale, "פנקס הקבלנים הרשומים", "Реестр зарегистрированных подрядчиков", "Registered Contractors Registry", "https://www.gov.il/apps/moch/rasham/home"),
                legalLink(locale, "רישוי חשמלאים — משרד העבודה", "Лицензирование электриков", "Electricians Licensing Department", "https://www.gov.il/en/Departments/Units/electricity-licensing-unit"),
                legalLink(locale, "מספרי חירום בישראל", "Экстренные номера Израиля", "Israel emergency numbers", "https://www.gov.il/BlobFolder/generalpage/be-prepared-for-emergency-situations/en/9134_Emergency%20Preparedness.pdf")
            ]
        case .about, .platformRole, .responsibility, .reviews, .payments, .deletion, .limitation:
            return []
        }
    }
}

struct LegalCenterView: View {
    @Environment(AppState.self) private var appState

    private let serviceDocuments: [LegalDocument] = [.about, .platformRole, .terms, .privacy]
    private let marketplaceDocuments: [LegalDocument] = [.responsibility, .reviews, .payments, .disputes]
    private let protectionDocuments: [LegalDocument] = [.safety, .deletion, .limitation]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "building.columns.fill").font(.title).foregroundStyle(Brand.red)
                    Text(appState.locale.text(he: "מרכז מידע משפטי", ru: "Юридический центр", en: "Legal center"))
                        .font(.title2).fontWeight(.bold)
                    Text(appState.locale.text(
                        he: "הסברים ברורים על תפקיד הזירה, זכויות, בטיחות ונתונים.",
                        ru: "Понятно о роли платформы, правах, безопасности и данных.",
                        en: "Clear explanations of the platform role, rights, safety, and data."
                    ))
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            documentSection(appState.locale.text(he: "השירות והתנאים", ru: "Сервис и условия", en: "Service & terms"), documents: serviceDocuments)
            documentSection(appState.locale.text(he: "התקשרות בין משתמשים", ru: "Сделка между пользователями", en: "User engagement"), documents: marketplaceDocuments)
            documentSection(appState.locale.text(he: "הגנה וסיום שימוש", ru: "Защита и прекращение", en: "Protection & leaving"), documents: protectionDocuments)
            Section {
                Text(appState.locale.text(
                    he: "המסכים מסכמים את הכללים בשפה פשוטה. התנאים והמדיניות המלאים באתר והדין הישראלי החל גוברים במקרה של סתירה.",
                    ru: "Эти экраны объясняют правила простым языком. При расхождении применяются полные документы на сайте и законодательство Израиля.",
                    en: "These screens explain the rules in plain language. The full website documents and applicable Israeli law prevail in a conflict."
                ))
                .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(appState.locale.text(he: "משפטי ובטיחות", ru: "Правила и безопасность", en: "Legal & safety"))
    }

    @ViewBuilder
    private func documentSection(_ title: String, documents: [LegalDocument]) -> some View {
        Section(title) {
            ForEach(documents) { document in
                NavigationLink { LegalDocumentView(document: document) } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.title(locale: appState.locale))
                            Text(document.summary(locale: appState.locale)).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: document.systemImage).foregroundStyle(Brand.red)
                    }
                }
            }
        }
    }
}

struct LegalDocumentView: View {
    @Environment(AppState.self) private var appState
    let document: LegalDocument

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: document.systemImage).font(.largeTitle).foregroundStyle(Brand.red)
                    Text(document.title(locale: appState.locale)).font(.largeTitle).fontWeight(.bold)
                    Text(document.summary(locale: appState.locale)).font(.body).foregroundStyle(.secondary)
                    Text(appState.locale.text(he: "עודכן: 28 באוגוסט 2026", ru: "Обновлено: 28 августа 2026", en: "Updated: 28 August 2026"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.softRed, in: .rect(cornerRadius: 24))

                ForEach(document.sections(locale: appState.locale)) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(.title3).fontWeight(.bold)
                        Text(section.body).font(.body).lineSpacing(5).textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !document.links(locale: appState.locale).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(appState.locale.text(he: "מקורות וקישורים", ru: "Источники и ссылки", en: "Sources and links"))
                            .font(.title3).fontWeight(.bold)
                        ForEach(document.links(locale: appState.locale)) { link in
                            Link(destination: link.url) {
                                Label(link.title, systemImage: "arrow.up.right.square")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Text(appState.locale.text(
                    he: "לשאלות משפטיות, פרטיות או ביטול: support@kablay.co.il. מומלץ לקבל ייעוץ משפטי עצמאי לפני התקשרות מהותית.",
                    ru: "По юридическим вопросам, конфиденциальности и отмене: support@kablay.co.il. Перед существенной сделкой рекомендуется независимая юридическая консультация.",
                    en: "For legal, privacy, or cancellation questions: support@kablay.co.il. Independent legal advice is recommended before a material engagement."
                ))
                .font(.footnote).foregroundStyle(.secondary).padding(.top)
            }
            .padding()
        }
        .navigationTitle(document.title(locale: appState.locale))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func section(
    _ locale: AppLocale,
    _ heTitle: String, _ ruTitle: String, _ enTitle: String,
    _ heBody: String, _ ruBody: String, _ enBody: String
) -> LegalSection {
    LegalSection(
        title: locale.text(he: heTitle, ru: ruTitle, en: enTitle),
        body: locale.text(he: heBody, ru: ruBody, en: enBody)
    )
}

private func legalLink(
    _ locale: AppLocale,
    _ he: String, _ ru: String, _ en: String,
    _ url: String
) -> LegalLink {
    LegalLink(title: locale.text(he: he, ru: ru, en: en), url: URL(string: url)!)
}

private func localizedPath(_ locale: AppLocale, _ path: String) -> String {
    "https://kablay.co.il/\(locale.rawValue)/\(path)"
}
