import SwiftUI

struct AppLockSetupView: View {
    enum Mode { case initial, change }
    private enum Stage { case create, confirm }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let mode: Mode

    @State private var stage: Stage = .create
    @State private var pin = ""
    @State private var firstPIN = ""
    @State private var enableBiometrics = true
    @State private var haloExpanded = false
    @State private var errorPulse = 0

    init(mode: Mode = .initial) {
        self.mode = mode
    }

    var body: some View {
        ZStack {
            SecurityBackdrop(expanded: haloExpanded)

            GeometryReader { geometry in
                let compact = geometry.size.height < 760
                ScrollView {
                    VStack(spacing: compact ? 9 : 16) {
                        Spacer(minLength: compact ? 6 : 20)
                        SecurityMark(
                            systemImage: stage == .create ? "lock.shield.fill" : "checkmark.shield.fill",
                            size: compact ? 58 : 78
                        )

                        VStack(spacing: compact ? 4 : 7) {
                            BrandWordmark()
                            Text(title)
                                .font(compact ? .title2 : .largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            Text(subtitle)
                                .font(compact ? .footnote : .body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(compact ? 3 : nil)
                                .minimumScaleFactor(0.88)
                        }

                        PINDots(count: pin.count, errorPulse: errorPulse)
                            .padding(.vertical, compact ? 1 : 4)

                        PINPad(pin: $pin, compact: compact)
                            .frame(maxWidth: 380)

                        if stage == .confirm, appState.appLock.biometricsAvailable {
                            Toggle(isOn: $enableBiometrics) {
                                Label(
                                    appState.locale.text(he: "פתיחה עם Face ID", ru: "Разблокировать через Face ID", en: "Unlock with Face ID"),
                                    systemImage: appState.appLock.biometricSymbol
                                )
                                .font(compact ? .subheadline.weight(.semibold) : .headline)
                            }
                            .padding(compact ? 10 : 14)
                            .background(.regularMaterial, in: .rect(cornerRadius: 16))
                        }

                        Button(action: advance) {
                            Text(stage == .create
                                 ? appState.locale.text(he: "המשך", ru: "Продолжить", en: "Continue")
                                 : appState.locale.text(he: "שמירה", ru: "Сохранить PIN", en: "Save PIN"))
                        }
                        .buttonStyle(BrandPrimaryButtonStyle())
                        .disabled(pin.count != 6)

                        if mode == .initial {
                            Button(role: .destructive) { Task { await appState.signOutAndRevoke() } } label: {
                                Text(appState.locale.text(he: "יציאה מהחשבון", ru: "Выйти из аккаунта", en: "Sign out instead"))
                                    .font(compact ? .footnote : .body)
                            }
                        }
                        Spacer(minLength: compact ? 6 : 18)
                    }
                    .padding(.horizontal, compact ? 20 : 24)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .navigationBarBackButtonHidden(mode == .initial)
        .sensoryFeedback(.error, trigger: errorPulse)
        .onAppear {
            enableBiometrics = mode == .change
                ? appState.appLock.biometricsEnabled
                : appState.appLock.biometricsAvailable
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                haloExpanded = true
            }
        }
    }

    private var title: String {
        if mode == .change {
            return appState.locale.text(he: "קוד PIN חדש", ru: "Новый PIN", en: "New app PIN")
        }
        return stage == .create
            ? appState.locale.text(he: "הגנו על החשבון", ru: "Защитите кабинет", en: "Protect your account")
            : appState.locale.text(he: "אישור הקוד", ru: "Повторите PIN", en: "Confirm your PIN")
    }

    private var subtitle: String {
        stage == .create
            ? appState.locale.text(
                he: "צרו קוד בן 6 ספרות. הוא נשמר רק ב-Keychain במכשיר הזה.",
                ru: "Создайте 6-значный PIN. Он защищён Keychain и остаётся только на этом устройстве.",
                en: "Create a six-digit PIN. It stays protected in Keychain on this device."
            )
            : appState.locale.text(
                he: "הזינו שוב את אותו הקוד והפעילו Face ID לפתיחה מהירה.",
                ru: "Введите тот же PIN ещё раз и включите Face ID для быстрого входа.",
                en: "Enter the same PIN again and enable Face ID for quick access."
            )
    }

    private func advance() {
        guard pin.count == 6 else { return }
        if stage == .create {
            firstPIN = pin
            pin = ""
            withAnimation(.snappy) { stage = .confirm }
            return
        }
        guard pin == firstPIN else {
            pin = ""
            errorPulse += 1
            appState.errorMessage = appState.locale.text(
                he: "הקודים אינם תואמים. נסו שוב.",
                ru: "PIN-коды не совпадают. Попробуйте ещё раз.",
                en: "The PINs do not match. Try again."
            )
            return
        }
        do {
            try appState.appLock.configure(pin: pin, biometricsEnabled: enableBiometrics)
            if mode == .change { dismiss() }
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

struct AppUnlockView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pin = ""
    @State private var haloExpanded = false
    @State private var errorPulse = 0
    @State private var requestedBiometrics = false

    var body: some View {
        ZStack {
            SecurityBackdrop(expanded: haloExpanded)
            VStack(spacing: 22) {
                Spacer()
                SecurityMark(systemImage: appState.appLock.biometricSymbol, size: 104)
                BrandWordmark()
                Text(appState.locale.text(he: "ברוכים השבים", ru: "С возвращением", en: "Welcome back"))
                    .font(.largeTitle).fontWeight(.bold)
                Text(appState.locale.text(
                    he: "השתמשו ב-Face ID או בקוד ה-PIN שלכם.",
                    ru: "Используйте Face ID или PIN приложения.",
                    en: "Use Face ID or your app PIN."
                ))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                PINDots(count: pin.count, errorPulse: errorPulse)

                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    if appState.appLock.remainingDelay > 0 {
                        Text(appState.locale.text(
                            he: "נסו שוב בעוד \(appState.appLock.remainingDelay) שניות",
                            ru: "Повторите через \(appState.appLock.remainingDelay) сек.",
                            en: "Try again in \(appState.appLock.remainingDelay)s"
                        ))
                        .font(.footnote).foregroundStyle(Brand.red)
                    }
                }

                PINPad(
                    pin: $pin,
                    biometricSymbol: appState.appLock.biometricsEnabled ? appState.appLock.biometricSymbol : nil,
                    biometricAction: authenticate
                )
                .frame(maxWidth: 380)
                .disabled(appState.appLock.remainingDelay > 0)

                Button(role: .destructive) { Task { await appState.signOutAndRevoke() } } label: {
                    Text(appState.locale.text(he: "יציאה מהחשבון", ru: "Выйти из аккаунта", en: "Sign out"))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .sensoryFeedback(.error, trigger: errorPulse)
        .onChange(of: pin) { _, value in
            if value.count == 6 { verifyPIN() }
        }
        .task {
            guard !requestedBiometrics else { return }
            requestedBiometrics = true
            authenticate()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                haloExpanded = true
            }
        }
    }

    private func verifyPIN() {
        guard appState.appLock.verify(pin: pin) else {
            pin = ""
            errorPulse += 1
            return
        }
        pin = ""
    }

    private func authenticate() {
        Task {
            _ = await appState.appLock.unlockWithBiometrics(reason: appState.locale.text(
                he: "פתיחת החשבון הפרטי ב-KABLAY",
                ru: "Открыть личный кабинет KABLAY",
                en: "Unlock your private KABLAY workspace"
            ))
        }
    }
}

struct SecuritySettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: appState.appLock.isConfigured ? "lock.shield.fill" : "lock.open.fill")
                        .font(.title2).foregroundStyle(Brand.red)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.appLock.isConfigured
                            ? appState.locale.text(he: "החשבון מוגן", ru: "Кабинет защищён", en: "Account protected")
                            : appState.locale.text(he: "הגנה אופציונלית", ru: "Дополнительная защита", en: "Optional protection"))
                            .font(.headline)
                        Text(appState.appLock.isConfigured
                            ? appState.locale.text(he: "PIN בן 6 ספרות ב-Keychain", ru: "6-значный PIN сохранён в Keychain", en: "Six-digit PIN saved in Keychain")
                            : appState.locale.text(he: "הגדירו PIN ו-Face ID במכשיר זה", ru: "Настройте PIN и Face ID на этом устройстве", en: "Set up a PIN and Face ID on this device"))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            if !appState.appLock.isConfigured {
                Section {
                    NavigationLink { AppLockSetupView(mode: .change) } label: {
                        Label(
                            appState.locale.text(he: "הגדרת PIN ו-Face ID", ru: "Настроить PIN и Face ID", en: "Set up PIN and Face ID"),
                            systemImage: "faceid"
                        )
                    }
                } footer: {
                    Text(appState.locale.text(
                        he: "ה-PIN נשמר רק ב-Keychain במכשיר. לאחר מכן ניתן לפתוח את KABLAY באמצעות Face ID.",
                        ru: "PIN сохраняется только в Keychain этого iPhone. После этого KABLAY можно разблокировать через Face ID.",
                        en: "The PIN is saved only in this iPhone’s Keychain. You can then unlock KABLAY with Face ID."
                    ))
                }
            }

            if appState.appLock.isConfigured, appState.appLock.biometricsAvailable {
                Section(appState.locale.text(he: "ביומטריה", ru: "Биометрия", en: "Biometrics")) {
                    Toggle(isOn: Binding(
                        get: { appState.appLock.biometricsEnabled },
                        set: { value in
                            do { try appState.appLock.setBiometricsEnabled(value) }
                            catch { appState.errorMessage = error.localizedDescription }
                        }
                    )) {
                        Label("Face ID", systemImage: appState.appLock.biometricSymbol)
                    }
                }
            }

            if appState.appLock.isConfigured {
                Section {
                    NavigationLink { AppLockSetupView(mode: .change) } label: {
                        Label(appState.locale.text(he: "שינוי קוד PIN", ru: "Изменить PIN", en: "Change app PIN"), systemImage: "number.square.fill")
                    }
                    Button {
                        appState.appLock.lock()
                    } label: {
                        Label(appState.locale.text(he: "נעילה עכשיו", ru: "Заблокировать сейчас", en: "Lock now"), systemImage: "lock.fill")
                    }
                } footer: {
                    Text(appState.locale.text(
                        he: "KABLAY לעולם לא מבקשת מכם למסור את קוד ה-PIN בצ׳אט או בטלפון.",
                        ru: "KABLAY никогда не просит сообщать PIN в чате или по телефону.",
                        en: "KABLAY will never ask for this PIN in chat or by phone."
                    ))
                }
            }
        }
        .navigationTitle(appState.locale.text(he: "אבטחה ו-Face ID", ru: "Безопасность и Face ID", en: "Security & Face ID"))
    }
}

private struct SecurityBackdrop: View {
    let expanded: Bool

    var body: some View {
        ZStack {
            Brand.canvas.ignoresSafeArea()
            Circle()
                .fill(Brand.red.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 65)
                .scaleEffect(expanded ? 1.12 : 0.86)
                .offset(y: -240)
            Circle()
                .fill(Color.blue.opacity(0.10))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: -180, y: 310)
        }
    }
}

private struct SecurityMark: View {
    let systemImage: String
    var size: CGFloat = 88

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Brand.red)
            .frame(width: size, height: size)
            .background(.regularMaterial, in: .circle)
            .overlay { Circle().stroke(Brand.red.opacity(0.22)) }
            .shadow(color: Brand.red.opacity(0.16), radius: 24, y: 10)
    }
}

private struct PINDots: View {
    let count: Int
    let errorPulse: Int

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < count ? Brand.red : Color(.tertiarySystemFill))
                    .frame(width: 14, height: 14)
                    .overlay { Circle().stroke(Brand.red.opacity(index < count ? 0 : 0.25)) }
                    .scaleEffect(index < count ? 1.12 : 1)
            }
        }
        .animation(.snappy, value: count)
        .keyframeAnimator(initialValue: CGFloat.zero, trigger: errorPulse) { content, value in
            content.offset(x: value)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-10, duration: 0.07)
                CubicKeyframe(10, duration: 0.07)
                CubicKeyframe(-7, duration: 0.07)
                CubicKeyframe(0, duration: 0.07)
            }
        }
        .accessibilityLabel("PIN: \(count) of 6 digits entered")
    }
}

private struct PINPad: View {
    @Binding var pin: String
    var biometricSymbol: String?
    var biometricAction: (() -> Void)?
    var compact = false

    private let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: compact ? 8 : 12), count: 3)
    }
    private var keyHeight: CGFloat { compact ? 40 : 50 }

    var body: some View {
        LazyVGrid(columns: columns, spacing: compact ? 7 : 12) {
            ForEach(digits, id: \.self) { digit in digitButton(digit) }
            if let biometricSymbol {
                Button(action: { biometricAction?() }) {
                    Image(systemName: biometricSymbol)
                        .font(.system(size: compact ? 25 : 34, weight: .semibold, design: .rounded))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Brand.red)
                        .frame(maxWidth: .infinity, minHeight: keyHeight)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Face ID")
            } else {
                Color.clear.frame(height: keyHeight)
            }
            digitButton("0")
            Button {
                if !pin.isEmpty { pin.removeLast() }
            } label: {
                Image(systemName: "delete.backward.fill").font(.title3)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 18))
            .frame(maxWidth: .infinity, minHeight: keyHeight)
            .disabled(pin.isEmpty)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func digitButton(_ digit: String) -> some View {
        Button {
            guard pin.count < 6 else { return }
            pin.append(digit)
        } label: {
            Text(digit)
                .font(compact ? .headline : .title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: keyHeight)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 18))
    }
}
