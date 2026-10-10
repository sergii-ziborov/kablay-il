import SwiftUI

struct ContentModerationSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let targetType: String
    let targetID: String
    let title: String
    @State private var reason = "spam"
    @State private var details = ""
    @State private var isSubmitting = false

    private var reasons: [(String, String)] {
        [
            ("spam", appState.locale.text(he: "ספאם או פרסום", ru: "Спам или реклама", en: "Spam or advertising")),
            ("fraud", appState.locale.text(he: "חשד להונאה", ru: "Подозрение на мошенничество", en: "Suspected fraud")),
            ("abuse", appState.locale.text(he: "תוכן או התנהגות פוגעניים", ru: "Оскорбительный контент или поведение", en: "Abusive content or behavior")),
            ("unsafe", appState.locale.text(he: "סכנה או עבודה לא בטוחה", ru: "Опасность или небезопасная работа", en: "Safety concern")),
            ("privacy", appState.locale.text(he: "פגיעה בפרטיות", ru: "Нарушение приватности", en: "Privacy concern")),
            ("other", appState.locale.text(he: "אחר", ru: "Другое", en: "Other")),
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(appState.locale.text(he: "סיבה", ru: "Причина", en: "Reason")) {
                    Picker("", selection: $reason) {
                        ForEach(reasons, id: \.0) { value, label in Text(label).tag(value) }
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
                        he: "הדיווח נשלח לצוות KABLAY ואינו מוצג למשתמש האחר.",
                        ru: "Жалоба отправляется команде KABLAY и не показывается другому пользователю.",
                        en: "The report is sent to KABLAY and is not shown to the other user."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.locale.text(he: "ביטול", ru: "Отмена", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.locale.text(he: "שליחה", ru: "Отправить", en: "Submit")) {
                        Task {
                            isSubmitting = true
                            if await appState.reportContent(
                                targetType: targetType,
                                targetID: targetID,
                                reason: reason,
                                details: details
                            ) { dismiss() }
                            isSubmitting = false
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }
}
