import SwiftUI

struct PhoneLoginView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var name = ""
    @State private var code = ""
    @State private var codeSent = false
    @FocusState private var focusedField: Field?

    private enum Field { case phone, code, name }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        BrandWordmark()
                        Text(appState.locale.text(he: "כניסה לפי מספר טלפון", ru: "Вход по номеру телефона", en: "Sign in with your phone"))
                            .font(.title2).fontWeight(.bold)
                        Text(appState.locale.text(
                            he: "נשלח קוד חד-פעמי ב-SMS. אין צורך בסיסמה.",
                            ru: "Отправим одноразовый код по SMS. Пароль не нужен.",
                            en: "We’ll send a one-time SMS code. No password is needed."
                        ))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                Section(appState.locale.text(he: "טלפון", ru: "Телефон", en: "Phone")) {
                    TextField("050-000-0000", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .disabled(codeSent)
                        .focused($focusedField, equals: .phone)
                }
                if codeSent {
                    Section(appState.locale.text(he: "קוד מ-SMS", ru: "Код из SMS", en: "SMS code")) {
                        TextField("123456", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($focusedField, equals: .code)
                            .onChange(of: code) { _, value in
                                let digits = String(value.filter(\.isNumber).prefix(6))
                                if code != digits { code = digits }
                            }
                        Button(appState.locale.text(he: "שליחה מחדש", ru: "Отправить ещё раз", en: "Send again")) {
                            Task { _ = await appState.sendOTP(phone: normalizedPhone) }
                        }
                    }
                }
                if appState.otpNameRequired {
                    Section {
                        TextField(appState.locale.text(he: "איך לפנות אליך?", ru: "Как к вам обращаться?", en: "What should we call you?"), text: $name)
                            .textContentType(.name)
                            .focused($focusedField, equals: .name)
                    } header: {
                        Text(appState.locale.text(he: "יצירת חשבון", ru: "Создание аккаунта", en: "Create account"))
                    } footer: {
                        Text(appState.locale.text(
                            he: "המספר עדיין לא רשום. הזינו שם פעם אחת כדי ליצור חשבון.",
                            ru: "Этот номер ещё не зарегистрирован. Укажите имя один раз для создания аккаунта.",
                            en: "This number is not registered yet. Enter a name once to create the account."
                        ))
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Section {
                    Button {
                        submit()
                    } label: {
                        if appState.isWorking {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(codeSent
                                ? appState.locale.text(he: "כניסה", ru: "Войти", en: "Sign in")
                                : appState.locale.text(he: "קבלת קוד", ru: "Получить код", en: "Get code"))
                        }
                    }
                    .buttonStyle(BrandPrimaryButtonStyle())
                    .disabled(!isValid || appState.isWorking)
                }
                Section {
                    Text(appState.locale.text(
                        he: "בהמשך אתם מאשרים את תנאי השימוש ומדיניות הפרטיות.",
                        ru: "Продолжая, вы принимаете условия использования и политику конфиденциальности.",
                        en: "By continuing, you accept the Terms of Use and Privacy Policy."
                    ))
                    .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(appState.locale.text(he: "כניסה", ru: "Вход", en: "Sign in"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        Label(appState.locale.text(he: "סיום", ru: "Готово", en: "Done"), systemImage: "keyboard.chevron.compact.down")
                    }
                }
            }
            .animation(.snappy, value: appState.otpNameRequired)
        }
    }

    private var normalizedPhone: String {
        let digits = phone.filter(\.isNumber)
        if digits.count == 10, digits.hasPrefix("05") {
            return "+972\(digits.dropFirst())"
        }
        if digits.count == 12, digits.hasPrefix("9725") {
            return "+\(digits)"
        }
        return ""
    }

    private var isValid: Bool {
        if appState.otpNameRequired { return code.count == 6 && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return codeSent ? code.count == 6 : !normalizedPhone.isEmpty
    }

    private func submit() {
        Task {
            if codeSent {
                if await appState.verifyOTP(phone: normalizedPhone, code: code, name: appState.otpNameRequired ? name : nil) {
                    dismiss()
                } else if appState.otpNameRequired {
                    focusedField = .name
                }
            } else if await appState.sendOTP(phone: normalizedPhone) {
                withAnimation { codeSent = true }
                focusedField = .code
            }
        }
    }

}
