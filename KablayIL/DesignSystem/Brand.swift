import SwiftUI
import UIKit

enum Brand {
    static let red = Color("BrandRed")
    static let navy = Color("BrandNavy")
    /// Primary readable copy. Keep `navy` for brand fills and use the system
    /// semantic color for text so contrast follows Light/Dark appearance.
    static let ink = Color.primary
    static let canvas = Color(.secondarySystemBackground)
    static let card = Color(.systemBackground)
    static let border = Color(.separator).opacity(0.55)
    static let softRed = Color("BrandRed").opacity(0.10)
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

struct BrandWordmark: View {
    var compact = false

    var body: some View {
        Text(compact ? "K" : "KABLAY")
            .font(.title2)
            .fontWeight(.black)
            .fontWidth(.expanded)
            .foregroundStyle(Brand.red)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
            .accessibilityLabel("KABLAY")
    }
}

/// Compact workspace tabs for the top bar. They intentionally avoid a
/// segmented-control background so iOS 26 does not show a nested glass pill.
private struct WorkspaceModeTabs: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 14) {
            tab(
                appState.locale.text(he: "לקוח", ru: "Клиент", en: "Client"),
                mode: .client
            )
            tab(
                appState.locale.text(he: "מקצוען", ru: "Профи", en: "Pro"),
                mode: .professional
            )
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(appState.locale.text(he: "מצב החשבון", ru: "Режим аккаунта", en: "Account mode"))
    }

    private func tab(_ title: String, mode: AppState.WorkspaceMode) -> some View {
        let isSelected = appState.workspaceMode == mode
        return Button {
            withAnimation(.snappy) { appState.workspaceMode = mode }
        } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? Brand.red : Color.primary)
                Capsule()
                    .fill(isSelected ? Brand.red : Color.clear)
                    .frame(width: 22, height: 2)
            }
            .padding(.horizontal, 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Shared chrome for the two marketplace workspaces. On iOS 26 the system
/// toolbar adds Liquid Glass backgrounds automatically; hiding the shared
/// backgrounds keeps the native placements without wrapping any item in a pill.
struct WorkspaceNavigationToolbar: ToolbarContent {
    @Environment(AppState.self) private var appState

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) {
                BrandWordmark()
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .principal) {
                if appState.isProfessional {
                    WorkspaceModeTabs()
                }
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .topBarTrailing) {
                notificationsLink
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) {
                BrandWordmark()
            }
            ToolbarItem(placement: .principal) {
                if appState.isProfessional {
                    WorkspaceModeTabs()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                notificationsLink
            }
        }
    }

    private var notificationsLink: some View {
        NavigationLink { NotificationCenterView() } label: {
            Image(systemName: appState.unreadCount == 0 ? "bell" : "bell.fill")
        }
        .buttonStyle(.plain)
        .badge(appState.unreadCount)
        .accessibilityLabel(appState.locale.text(he: "התראות", ru: "Уведомления", en: "Notifications"))
    }
}

struct BrandPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(configuration.isPressed ? Brand.red.opacity(0.78) : Brand.red, in: .rect(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BrandSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Brand.ink)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16).stroke(Brand.border)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct StatusPill: View {
    let title: String
    var color: Color = Brand.red

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.10), in: .capsule)
            .overlay { Capsule().stroke(color.opacity(0.35)) }
    }
}

struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 52

    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "K"))
            .font(size > 60 ? .title : .headline)
            .fontWeight(.bold)
            .foregroundStyle(Brand.navy)
            .frame(width: size, height: size)
            .background(Color(hex: "E5EAF8"), in: .circle)
            .accessibilityLabel(name)
    }
}

struct SpecialistAvatar: View {
    let specialist: Specialist
    var size: CGFloat = 52

    private var category: ServiceCategory? {
        specialist.categories
            .compactMap { id in ServiceCategory.catalog.first(where: { $0.id == id }) }
            .first
    }

    var body: some View {
        Group {
            if let url = specialist.displayAvatarURL {
                OfflineImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackIcon
                    default:
                        // A photo on its way is not a profile without a photo.
                        // Showing the trade glyph here made a slow download look
                        // like a specialist who never uploaded anything.
                        loadingPlaceholder
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay { Circle().stroke(Brand.border, lineWidth: 1) }
        .accessibilityLabel(specialist.name)
    }

    private var loadingPlaceholder: some View {
        let tint = Color(hex: category?.tintHex ?? "59657A")
        return tint.opacity(0.12)
            .overlay { ProgressView().controlSize(.small).tint(tint) }
    }

    private var fallbackIcon: some View {
        let tint = Color(hex: category?.tintHex ?? "59657A")
        return Image(systemName: category?.systemImage ?? "person.crop.circle.fill")
            .font(.system(size: size * 0.36, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tint.opacity(0.12))
    }
}

struct CategoryCoverImage: View {
    let category: ServiceCategory

    private var bundledImage: UIImage? {
        let nested = Bundle.main.url(
            forResource: category.id,
            withExtension: "webp",
            subdirectory: "CategoryCovers"
        )
        let flattened = Bundle.main.url(forResource: category.id, withExtension: "webp")
        guard let url = nested ?? flattened else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    var body: some View {
        Group {
            if let bundledImage {
                Image(uiImage: bundledImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: category.tintHex).opacity(0.10), Color(hex: category.tintHex).opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: category.systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(hex: category.tintHex))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    func brandCard() -> some View {
        self
            .background(Brand.card, in: .rect(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(Brand.border) }
    }
}
