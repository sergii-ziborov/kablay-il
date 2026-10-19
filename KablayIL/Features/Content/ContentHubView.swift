import SwiftUI

struct ContentHubView: View {
    private enum SectionMode: String, CaseIterable {
        case guides
        case blog
    }

    @Environment(AppState.self) private var appState
    @State private var mode: SectionMode = .guides
    @State private var visibleArticleCount = 12

    var body: some View {
        List {
            Section {
                Picker("", selection: $mode) {
                    Text(appState.locale.text(he: "מדריכים", ru: "Гайды", en: "Guides")).tag(SectionMode.guides)
                    Text(appState.locale.text(he: "בלוג", ru: "Блог", en: "Blog")).tag(SectionMode.blog)
                }
                .pickerStyle(.segmented)
            }

            if mode == .guides {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.locale.text(he: "תיקון בית בלי הפתעות", ru: "Ремонт без неприятных сюрпризов", en: "Home repair without surprises"))
                            .font(.title2).fontWeight(.bold)
                        Text(appState.locale.text(
                            he: "מדריכים מפורטים לפי מקצוע: בטיחות, אבחון, מחירים וקבלת עבודה.",
                            ru: "Подробные гайды по профессиям: безопасность, диагностика, цены и приёмка работ.",
                            en: "Detailed trade guides covering safety, diagnosis, prices, and job handover."
                        ))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section(appState.locale.text(he: "מדריכים לפי תחום", ru: "Гайды по направлениям", en: "Guides by trade")) {
                    ForEach(RepairGuide.catalog) { guide in
                        NavigationLink {
                            RepairGuideView(guide: guide)
                        } label: {
                            RepairGuideRow(guide: guide)
                        }
                    }
                }
            } else {
                Section(appState.locale.text(he: "מאמרים חדשים", ru: "Новые статьи", en: "Latest articles")) {
                    OfflineFreshnessLabel(
                        updatedAt: appState.blogUpdatedAt,
                        isSavedCopy: appState.blogShowingSavedCopy,
                        staleAfter: OfflineFreshness.articles,
                        locale: appState.locale
                    )
                    ForEach(Array(appState.blogArticles.prefix(visibleArticleCount))) { article in
                        NavigationLink { ArticleView(article: article) } label: { ArticleRow(article: article) }
                    }
                    if appState.blogArticles.count > visibleArticleCount || appState.blogLoadedPage < appState.blogPages {
                        Button(appState.locale.text(he: "עוד מאמרים", ru: "Ещё статьи", en: "More articles")) {
                            Task {
                                await appState.loadMoreBlogArticles()
                                visibleArticleCount += 12
                            }
                        }
                        .disabled(appState.isLoadingBlog)
                    }
                }
            }
            Section(appState.locale.text(he: "עזרה", ru: "Помощь", en: "Help")) {
                NavigationLink { FAQView() } label: { Label(appState.locale.text(he: "שאלות נפוצות", ru: "Частые вопросы", en: "Frequently asked questions"), systemImage: "questionmark.bubble.fill") }
                NavigationLink { SupportView() } label: { Label(appState.locale.text(he: "תמיכה", ru: "Поддержка", en: "Support"), systemImage: "headphones") }
            }
        }
        .navigationTitle(appState.locale.text(he: "מדריכים ובלוג", ru: "Гайды и блог", en: "Guides & blog"))
        .overlay {
            if mode == .blog, appState.isLoadingBlog, appState.blogArticles.isEmpty {
                ProgressView()
            } else if mode == .blog, appState.blogArticles.isEmpty {
                ContentUnavailableView(
                    appState.locale.text(he: "המאמרים אינם זמינים", ru: "Статьи сейчас недоступны", en: "Articles unavailable"),
                    systemImage: "wifi.exclamationmark"
                )
            }
        }
        .task { await appState.loadBlogArticles() }
        .refreshable { await appState.loadBlogArticles(force: true) }
    }
}

private struct RepairGuide: Identifiable, Hashable {
    let categoryID: String
    let summary: LocalizedValue
    let safety: LocalizedValue
    let handover: LocalizedValue

    var id: String { categoryID }
    var category: ServiceCategory {
        ServiceCategory.catalog.first(where: { $0.id == categoryID }) ?? ServiceCategory.catalog[0]
    }
    var title: LocalizedValue {
        .init(
            he: "מדריך \(category.title.he)",
            ru: "Гайд: \(category.title.ru)",
            en: "\(category.title.en) guide"
        )
    }

    static let catalog: [RepairGuide] = [
        .init(
            categoryID: "plumbing",
            summary: .init(he: "איך לתאר נזילה, להכין תמונות ולהשוות הצעות בלי לפספס חלקים ועבודה.", ru: "Как описать протечку, подготовить фото и сравнить предложения с учётом деталей и работы.", en: "Describe a leak, prepare useful photos, and compare quotes that separate parts from labour."),
            safety: .init(he: "בנזילה פעילה סגרו ברז מקומי או ראשי רק אם הגישה בטוחה. מים ליד חשמל הם מצב חירום.", ru: "При активной течи перекройте местный или главный кран, только если доступ безопасен. Вода рядом с электричеством — аварийная ситуация.", en: "For an active leak, close the local or main valve only when safely accessible. Water near electricity is an emergency."),
            handover: .init(he: "הפעילו מים במשך כמה דקות, בדקו את כל החיבורים עם נייר יבש וקבלו פירוט של החלקים שהוחלפו.", ru: "Пустите воду на несколько минут, проверьте соединения сухой салфеткой и получите список заменённых деталей.", en: "Run water for several minutes, check every joint with a dry tissue, and get a list of replaced parts.")
        ),
        .init(
            categoryID: "electrician",
            summary: .init(he: "מה למסור לחשמלאי, מתי דרוש רישיון ואיך לקבל עבודה בלוח, שקעים ותאורה.", ru: "Что сообщить электрику, когда нужна лицензия и как принимать работы со щитом, розетками и светом.", en: "Know what to tell an electrician, when licensing matters, and how to inspect panel, socket, and lighting work."),
            safety: .init(he: "ריח שרוף, ניצוצות או לוח חם: הפסיקו שימוש ונתקו את המעגל אם ניתן בבטחה. אל תפתחו לוח לבד.", ru: "Запах гари, искры или горячий щит: прекратите использование и отключите линию, если это безопасно. Не вскрывайте щит сами.", en: "For burning smells, sparks, or a hot panel, stop use and isolate the circuit if safe. Never open the panel yourself."),
            handover: .init(he: "בדקו מפסק פחת, כל שקע ומתג ששונו, ובקשו סימון מעגלים וחשבונית עם פרטי החשמלאי.", ru: "Проверьте УЗО, каждую изменённую розетку и выключатель; попросите маркировку линий и счёт с данными электрика.", en: "Test the RCD and every changed socket or switch; request circuit labels and an invoice naming the electrician.")
        ),
        .init(
            categoryID: "tiler",
            summary: .init(he: "בחירת תשתית, איטום, פריסת אריחים והגדרה ברורה של חיתוכים, רובה ושיפועים.", ru: "Основание, гидроизоляция, раскладка плитки и чёткий объём по подрезке, затирке и уклонам.", en: "Plan the substrate, waterproofing, tile layout, cuts, grout, and drainage slopes before work starts."),
            safety: .init(he: "אל תדרכו על ריצוף טרי ואל תפעילו אזור רטוב לפני זמני הייבוש שהוגדרו לחומר.", ru: "Не ходите по свежей плитке и не мочите зону до истечения времени высыхания материалов.", en: "Do not walk on fresh tile or wet the area before the specified curing times have passed."),
            handover: .init(he: "בדקו מישקים ישרים, הפרשי גובה, שיפוע לניקוז, רובה מלאה ואריחים חלולים בהקשה עדינה.", ru: "Проверьте ровность швов, перепады, уклон к сливу, заполнение затирки и пустоты лёгким простукиванием.", en: "Inspect joint alignment, lippage, drainage slope, full grout lines, and hollow spots with a gentle tap test.")
        ),
        .init(
            categoryID: "painter",
            summary: .init(he: "איך להגדיר הכנת קיר, מספר שכבות, סוג צבע והגנה על הבית כדי לקבל הצעות זהות.", ru: "Как зафиксировать подготовку стен, число слоёв, тип краски и защиту квартиры для сопоставимых предложений.", en: "Define wall preparation, coat count, paint system, and protection so every quote covers the same scope."),
            safety: .init(he: "דרשו אוורור, הגנה על שקעים ורצפה ושימוש בחומרים המתאימים לחדרים רטובים או לעובש.", ru: "Нужны вентиляция, защита розеток и пола, а для влажных помещений или плесени — подходящие материалы.", en: "Require ventilation, protected sockets and floors, and suitable products for wet rooms or mould remediation."),
            handover: .init(he: "בדקו באור יום אחידות, סימני רולר, פינות, תיקוני סדקים וניקיון מסגרות ושקעים.", ru: "При дневном свете проверьте равномерность, следы валика, углы, трещины, рамы и розетки.", en: "Use daylight to inspect uniform colour, roller marks, corners, repaired cracks, frames, and sockets.")
        ),
        .init(
            categoryID: "drywall",
            summary: .init(he: "תכנון קונסטרוקציה, בידוד, נקודות חיזוק וגמר לפני שסוגרים את הקיר.", ru: "Каркас, изоляция, закладные и уровень отделки — всё, что нужно согласовать до закрытия стены.", en: "Agree framing, insulation, reinforcement points, and finish level before the wall is closed."),
            safety: .init(he: "ודאו מיקום חשמל וצנרת לפני הברגה, והשתמשו בלוחות מתאימים ללחות ולאש לפי האזור.", ru: "До зашивки уточните электрику и трубы; для влажных и огнестойких зон нужны соответствующие листы.", en: "Locate wiring and pipes before fastening, and use moisture- or fire-rated boards where required."),
            handover: .init(he: "בדקו מישור עם סרגל, פינות ישרות, ברגים שקועים, תפרים ללא סדקים והכנות לתלייה כבדה.", ru: "Проверьте плоскость правилом, углы, утопленные саморезы, швы без трещин и закладные под тяжёлый монтаж.", en: "Check flatness, square corners, recessed screws, crack-free joints, and reinforcement for heavy fixtures.")
        ),
        .init(
            categoryID: "handyman",
            summary: .init(he: "איך לאחד תיקונים קטנים לרשימה אחת, לצלם קירות ולוודא שהמחיר כולל מחברים וחומרים.", ru: "Как собрать мелкие работы в один список, снять стены и уточнить, входят ли крепёж и материалы.", en: "Bundle small jobs into one list, photograph mounting surfaces, and clarify whether fixings and materials are included."),
            safety: .init(he: "ציינו מראש אם יש קיר בטון, גבס, אריחים או קווי חשמל סמויים. עבודות חשמל וגז דורשות בעל רישיון מתאים.", ru: "Укажите бетон, гипсокартон, плитку и скрытую проводку. Электрика и газ требуют профильного лицензированного мастера.", en: "Identify concrete, drywall, tile, and concealed services. Electrical and gas work needs the appropriate licensed trade."),
            handover: .init(he: "בדקו שכל פריט מפולס, מקובע ללא תנועה ושלא נגרם נזק לצבע, לאריחים או לריהוט.", ru: "Проверьте уровень и жёсткость крепления каждого предмета, а также отсутствие повреждений краски, плитки и мебели.", en: "Check that every item is level and rigid, with no damage to paint, tile, or furniture.")
        ),
        .init(
            categoryID: "stretch-ceilings",
            summary: .init(he: "מדידה, בחירת בד, תאורה, פרופיל והכנת החדר לפני התקנת תקרה מתוחה.", ru: "Замер, полотно, свет, профиль и подготовка комнаты до монтажа натяжного потолка.", en: "Plan measurement, membrane, lighting, perimeter profile, and room preparation before installation."),
            safety: .init(he: "סמנו צנרת וחיווט בקירות ובתקרה. התקנה בחום או בגובה חייבת ציוד מקצועי ואזור עבודה פנוי.", ru: "Отметьте трубы и проводку. Нагрев и высотные работы требуют профессионального оборудования и свободной зоны.", en: "Mark concealed pipes and wiring. Heat and overhead work require professional equipment and a clear work zone."),
            handover: .init(he: "בדקו משטח מתוח ואחיד, קווים ישרים, טבעות חיזוק בגופי תאורה והיעדר סימנים או רווחים בהיקף.", ru: "Проверьте натяжение без волн, ровный периметр, термокольца светильников и отсутствие следов или щелей.", en: "Inspect even tension, a straight perimeter, reinforced light openings, and no marks or gaps.")
        ),
        .init(
            categoryID: "renovation",
            summary: .init(he: "בניית מפרט, אבני דרך, לוח תשלומים וסדר בעלי מקצוע לשיפוץ דירה בישראל.", ru: "Техническое задание, этапы, график оплат и последовательность мастеров для ремонта квартиры в Израиле.", en: "Build a written scope, milestones, payment schedule, and trade sequence for an apartment renovation in Israel."),
            safety: .init(he: "שינויי מבנה, חשמל, גז ואיטום דורשים תכנון ובעלי מקצוע מוסמכים. אל תתחילו הריסה ללא בדיקות.", ru: "Конструктив, электрика, газ и гидроизоляция требуют проекта и профильных специалистов. Не начинайте демонтаж без проверок.", en: "Structural, electrical, gas, and waterproofing changes need planning and qualified trades. Do not demolish before checks."),
            handover: .init(he: "קבלו כל שלב לפני כיסויו, שמרו תמונות תשתיות, בדקו מידות וגמר והשאירו יתרה עד תיקון ליקויים.", ru: "Принимайте скрытые этапы до закрытия, храните фото коммуникаций, сверяйте размеры и удерживайте остаток до устранения дефектов.", en: "Inspect concealed stages before closure, keep service photos, verify dimensions and finishes, and retain a balance until defects are fixed.")
        ),
        .init(
            categoryID: "cleaning",
            summary: .init(he: "הגדרת ניקיון אחרי שיפוץ, חלונות, ארונות ושאריות קשות בלי הפתעות במחיר.", ru: "Как определить объём уборки после ремонта, окон, шкафов и сложных загрязнений без доплат-сюрпризов.", en: "Define post-renovation cleaning, windows, cabinets, and hard residue without surprise extras."),
            safety: .init(he: "אין לערבב אקונומיקה עם חומצה או מסיר אבנית. ציינו אבן טבעית, פרקט ואלומיניום לפני בחירת חומר.", ru: "Нельзя смешивать хлор с кислотой или средством от извести. Заранее укажите камень, паркет и алюминий.", en: "Never mix bleach with acid or limescale remover. Identify natural stone, parquet, and aluminium before products are chosen."),
            handover: .init(he: "עברו באור יום על מסילות, פנלים, מדפים ומשטחים, ובדקו שלא נותרו אבק דק, סימנים או מים עומדים.", ru: "При дневном свете проверьте направляющие, плинтусы, полки и поверхности: без мелкой пыли, разводов и стоячей воды.", en: "In daylight, inspect tracks, skirting, shelves, and surfaces for fine dust, streaks, and standing water.")
        ),
    ]
}

private struct RepairGuideRow: View {
    @Environment(AppState.self) private var appState
    let guide: RepairGuide

    var body: some View {
        HStack(spacing: 13) {
            CategoryCoverImage(category: guide.category)
                .frame(width: 92, height: 76)
                .clipShape(.rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(guide.title.value(for: appState.locale)).font(.headline)
                Text(guide.summary.value(for: appState.locale))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Label(appState.locale.text(he: "צ׳ק-ליסט מעשי", ru: "Практический чек-лист", en: "Practical checklist"), systemImage: "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: guide.category.tintHex))
            }
        }
        .padding(.vertical, 5)
    }
}

private struct RepairGuideView: View {
    @Environment(AppState.self) private var appState
    let guide: RepairGuide

    private var comparisonChecklist: [String] {
        [
            appState.locale.text(he: "אותו היקף עבודה כתוב בכל הצעה", ru: "Одинаковый письменный объём во всех предложениях", en: "The same written scope in every quote"),
            appState.locale.text(he: "חומרים, מע״מ ופינוי מצוינים בנפרד", ru: "Материалы, НДС и вывоз указаны отдельно", en: "Materials, VAT, and disposal listed separately"),
            appState.locale.text(he: "תאריך התחלה, משך ואחריות", ru: "Дата начала, срок и гарантия", en: "Start date, duration, and warranty"),
            appState.locale.text(he: "רישיון וביטוח כאשר הם נדרשים", ru: "Лицензия и страховка, если они требуются", en: "License and insurance where required"),
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                CategoryCoverImage(category: guide.category)
                    .frame(height: 230)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 24))
                    .overlay(alignment: .bottomLeading) {
                        Label(guide.category.title.value(for: appState.locale), systemImage: guide.category.systemImage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.58), in: .capsule)
                            .padding(14)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(guide.title.value(for: appState.locale)).font(.largeTitle.bold())
                    Text(guide.summary.value(for: appState.locale)).font(.body).foregroundStyle(.secondary)
                }

                guideSection(
                    title: appState.locale.text(he: "לפני שמפרסמים", ru: "До публикации заявки", en: "Before posting"),
                    systemImage: "camera.metering.center.weighted",
                    text: appState.locale.text(
                        he: "צלמו תמונה רחבה ותקריב, ציינו מידות או קנה מידה, תארו מה כבר ניסיתם וכתבו מתי נדרש השירות.",
                        ru: "Снимите общий план и крупный план, укажите размеры или масштаб, что уже пробовали и когда нужна работа.",
                        en: "Take a wide photo and close-up, include dimensions or scale, say what you already tried, and when the work is needed."
                    )
                )

                VStack(alignment: .leading, spacing: 12) {
                    Label(appState.locale.text(he: "מה כלול בתחום", ru: "Что входит в направление", en: "What this trade covers"), systemImage: "square.grid.2x2.fill")
                        .font(.title3.bold())
                    ForEach(guide.category.groups) { group in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(group.title.value(for: appState.locale)).font(.headline)
                            Text(group.services.map { $0.value(for: appState.locale) }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
                    }
                }

                guideSection(
                    title: appState.locale.text(he: "בטיחות", ru: "Безопасность", en: "Safety"),
                    systemImage: "exclamationmark.shield.fill",
                    text: guide.safety.value(for: appState.locale),
                    tint: .orange
                )

                VStack(alignment: .leading, spacing: 11) {
                    Label(appState.locale.text(he: "איך להשוות הצעות", ru: "Как сравнивать предложения", en: "Compare quotes"), systemImage: "list.bullet.clipboard.fill")
                        .font(.title3.bold())
                    ForEach(comparisonChecklist, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                guideSection(
                    title: appState.locale.text(he: "קבלת העבודה", ru: "Приёмка работы", en: "Job handover"),
                    systemImage: "checkmark.seal.fill",
                    text: guide.handover.value(for: appState.locale),
                    tint: .green
                )

                Button {
                    appState.taskDraft = TaskDraft()
                    appState.taskDraft.categoryID = guide.categoryID
                    appState.requestEntryMode = .direct
                    appState.clientTab = .request
                } label: {
                    Label(appState.locale.text(he: "יצירת בקשה", ru: "Создать заявку", en: "Create a request"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(BrandPrimaryButtonStyle())
            }
            .padding()
        }
        .background(Brand.canvas)
        .navigationTitle(guide.category.title.value(for: appState.locale))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideSection(title: String, systemImage: String, text: String, tint: Color = Brand.red) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
                .foregroundStyle(tint)
            Text(text).font(.body).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Brand.border) }
    }
}

private struct ArticleRow: View {
    @Environment(AppState.self) private var appState
    let article: BlogArticle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            OfflineImage(url: article.coverURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    let category = appState.serviceCatalog.first { $0.id == article.categoryID }
                    Image(systemName: category?.systemImage ?? "house.fill")
                        .font(.title2)
                        .foregroundStyle(category.map { Color(hex: $0.tintHex) } ?? Brand.red)
                }
            }
            .frame(width: 64, height: 64)
            .background(Color(.tertiarySystemBackground))
            .clipShape(.rect(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(article.title.value(for: appState.locale)).font(.headline)
                Text(article.summary.value(for: appState.locale)).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 10) {
                    Label("\(article.readingMinutes) min", systemImage: "clock")
                    if let publishedAt = article.publishedAt {
                        Text(publishedAt, format: .dateTime.day().month().year())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// The article reads like a built-in guide: the editorial HTML from the
/// published catalog is parsed once and drawn with native views, so it follows
/// Dynamic Type, dark mode, and RTL instead of embedding the website.
private struct ArticleView: View {
    @Environment(AppState.self) private var appState
    let article: BlogArticle

    private var category: ServiceCategory? {
        appState.serviceCatalog.first { $0.id == article.categoryID }
    }

    private var blocks: [ArticleBlock] {
        ArticleContent.blocks(
            from: article.content.value(for: appState.locale),
            baseURL: AppConfiguration.webBaseURL
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                cover
                header
                if blocks.isEmpty {
                    ContentUnavailableView(
                        appState.locale.text(he: "המאמר אינו זמין", ru: "Статья недоступна", en: "Article unavailable"),
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(appState.locale.text(
                            he: "משכו לרענון כדי לטעון את הבלוג מחדש.",
                            ru: "Потяните вниз на списке статей, чтобы обновить блог.",
                            en: "Pull to refresh the article list to reload the blog."
                        ))
                    )
                } else {
                    ForEach(blocks) { block in
                        ArticleBlockView(block: block)
                    }
                }
                requestCallToAction
            }
            .padding()
        }
        .background(Brand.canvas)
        .navigationTitle(article.title.value(for: appState.locale))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = articleURL { ShareLink(item: url) }
            }
        }
    }

    private var articleURL: URL? {
        URL(
            string: "\(appState.locale.rawValue)/blog/\(article.id)",
            relativeTo: AppConfiguration.webBaseURL
        )?.absoluteURL
    }

    @ViewBuilder private var cover: some View {
        OfflineImage(url: article.coverURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else if phase.error != nil || article.coverURL == nil {
                coverPlaceholder
            } else {
                coverPlaceholder.overlay { ProgressView() }
            }
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(.rect(cornerRadius: 24))
        .overlay(alignment: .bottomLeading) {
            if let category {
                Label(category.title.value(for: appState.locale), systemImage: category.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.58), in: .capsule)
                    .padding(14)
            }
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .overlay {
                Image(systemName: category?.systemImage ?? "doc.text.fill")
                    .font(.largeTitle)
                    .foregroundStyle(category.map { Color(hex: $0.tintHex) } ?? Brand.red)
            }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(article.title.value(for: appState.locale)).font(.largeTitle.bold())
            HStack(spacing: 12) {
                if let publishedAt = article.publishedAt {
                    Label(publishedAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                }
                Label(
                    appState.locale.text(
                        he: "\(article.readingMinutes) דק׳ קריאה",
                        ru: "\(article.readingMinutes) мин чтения",
                        en: "\(article.readingMinutes) min read"
                    ),
                    systemImage: "clock"
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(article.summary.value(for: appState.locale))
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var requestCallToAction: some View {
        Button {
            appState.taskDraft = TaskDraft()
            appState.taskDraft.categoryID = article.categoryID
            appState.requestEntryMode = .direct
            appState.clientTab = .request
        } label: {
            Label(appState.locale.text(he: "יצירת בקשה", ru: "Создать заявку", en: "Create a request"), systemImage: "plus.circle.fill")
        }
        .buttonStyle(BrandPrimaryButtonStyle())
        .padding(.top, 4)
    }
}

private struct ArticleBlockView: View {
    let block: ArticleBlock

    var body: some View {
        switch block {
        case let .heading(level, text):
            Text(text)
                .font(level <= 2 ? .title2.bold() : .title3.bold())
                .foregroundStyle(Brand.ink)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .paragraph(text):
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .tint(Brand.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .bullets(items):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(Brand.red)
                        Text(item).font(.subheadline).foregroundStyle(.secondary).tint(Brand.red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case let .numbered(items):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text("\(index + 1).").font(.subheadline.weight(.bold)).foregroundStyle(Brand.red)
                        Text(item).font(.subheadline).foregroundStyle(.secondary).tint(Brand.red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case let .quote(text):
            Text(text)
                .font(.callout.italic())
                .foregroundStyle(.secondary)
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Capsule().fill(Brand.red).frame(width: 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .callout(text):
            Label { Text(text).font(.subheadline).foregroundStyle(.secondary).tint(Brand.red) } icon: {
                Image(systemName: "info.circle.fill").foregroundStyle(Brand.red)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(Brand.border) }
        case let .table(headers, rows):
            ArticleTableView(headers: headers, rows: rows)
        case let .image(url):
            OfflineImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Rectangle().fill(Color(.tertiarySystemBackground)).frame(height: 160)
                }
            }
            .clipShape(.rect(cornerRadius: 18))
        }
    }
}

/// Editorial tables stay readable on a phone by scrolling sideways inside their
/// own card instead of squeezing every column into the screen width.
private struct ArticleTableView: View {
    let headers: [AttributedString]
    let rows: [[AttributedString]]

    private var columnCount: Int {
        max(headers.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if !headers.isEmpty {
                    row(headers, isHeader: true)
                    Divider()
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                    row(cells, isHeader: false)
                    if index < rows.count - 1 { Divider() }
                }
            }
            .padding(14)
        }
        .background(Color(.systemBackground), in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Brand.border) }
    }

    private func row(_ cells: [AttributedString], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(0..<columnCount, id: \.self) { column in
                Text(column < cells.count ? cells[column] : AttributedString(""))
                    .font(isHeader ? .subheadline.weight(.bold) : .subheadline)
                    .foregroundStyle(isHeader ? Brand.ink : .secondary)
                    .frame(width: 190, alignment: .leading)
            }
        }
        .padding(.vertical, 9)
    }
}

struct FAQView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(FAQItem.samples) { item in
            DisclosureGroup {
                Text(item.answer.value(for: appState.locale)).foregroundStyle(.secondary).padding(.vertical, 6)
            } label: {
                Text(item.question.value(for: appState.locale)).font(.headline)
            }
        }
        .navigationTitle(appState.locale.text(he: "שאלות נפוצות", ru: "Частые вопросы", en: "FAQ"))
    }
}

struct SupportView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section {
                Label("support@kablay.co.il", systemImage: "envelope.fill")
                Link(destination: URL(string: "tel:+972503669369")!) {
                    Label("+972 50-366-9369".ltrIsolated, systemImage: "phone.fill")
                }
            }
            Section(appState.locale.text(he: "לפני הפנייה", ru: "Перед обращением", en: "Before contacting us")) {
                Text(appState.locale.text(he: "ציינו מספר בקשה וצירפו צילום מסך. במקרה חירום פנו לשירותי החירום — התמיכה אינה מוקד חירום.", ru: "Укажите номер заявки и приложите снимок экрана. При экстренной ситуации звоните в аварийные службы — поддержка не является экстренной линией.", en: "Include the request number and a screenshot. For emergencies, contact emergency services—support is not an emergency line."))
            }
        }
        .navigationTitle(appState.locale.text(he: "תמיכה", ru: "Поддержка", en: "Support"))
    }
}
