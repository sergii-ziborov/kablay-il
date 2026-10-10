import MapKit
import SwiftUI

struct TaskLocationCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    let city: String
    let address: String?
    let location: TaskMapLocation?

    @State private var resolvedLocation: TaskMapLocation?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var resolutionFailed = false

    init(city: String, address: String? = nil, location: TaskMapLocation?) {
        self.city = city
        self.address = address
        self.location = location
    }

    private var displayedLocation: TaskMapLocation? { location ?? resolvedLocation }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                appState.locale.text(he: "מיקום העבודה", ru: "Место работы", en: "Job location"),
                systemImage: "map.fill"
            )
            .font(.headline)

            if !locationLabel.isEmpty {
                Text(locationLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let displayedLocation {
                let coordinate = CLLocationCoordinate2D(
                    latitude: displayedLocation.latitude,
                    longitude: displayedLocation.longitude
                )
                Map(position: $mapPosition, interactionModes: [.pan, .zoom]) {
                    Marker(localizedCity.isEmpty ? "KABLAY" : localizedCity, coordinate: coordinate)
                        .tint(Brand.red)
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .mapControls { MapCompass(); MapScaleView() }
                .frame(height: 220)
                .clipShape(.rect(cornerRadius: 18))

                if displayedLocation.approximate {
                    Label(
                        appState.locale.text(
                            he: "המיקום משוער. הנקודה המדויקת תיפתח לאחר קבלת ההזמנה.",
                            ru: "Место указано приблизительно. Точная точка откроется после принятия заказа.",
                            en: "This is an approximate area. The exact pin unlocks after accepting the job."
                        ),
                        systemImage: "lock.shield.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        openURL(TaskMapLinks.maps(
                            latitude: displayedLocation.latitude,
                            longitude: displayedLocation.longitude
                        ))
                    } label: {
                        routeButtonLabel("Maps", systemImage: "map.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Brand.red)

                    Button {
                        openURL(TaskMapLinks.waze(
                            latitude: displayedLocation.latitude,
                            longitude: displayedLocation.longitude
                        ))
                    } label: {
                        routeButtonLabel("Waze", systemImage: "location.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            } else if resolutionFailed {
                ContentUnavailableView {
                    Label(
                        appState.locale.text(he: "לא נמצאה נקודה", ru: "Точка не определена", en: "Location not resolved"),
                        systemImage: "map"
                    )
                } description: {
                    Text(appState.locale.text(
                        he: "עדיין ניתן לפתוח את הכתובת בחיפוש במפה.",
                        ru: "Адрес всё равно можно открыть через поиск на карте.",
                        en: "You can still open the address in map search."
                    ))
                } actions: {
                    if !locationLabel.isEmpty {
                        Button {
                            openURL(TaskMapLinks.maps(query: locationLabel))
                        } label: {
                            routeButtonLabel("Maps", systemImage: "map.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Brand.red)

                        Button {
                            openURL(TaskMapLinks.waze(query: locationLabel))
                        } label: {
                            routeButtonLabel("Waze", systemImage: "location.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(appState.locale.text(he: "מחפש את האזור…", ru: "Ищем район…", en: "Finding the area…"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            }
        }
        .padding(16)
        .brandCard()
        .task(id: taskIdentity) { await resolveMapLocation() }
    }

    private var taskIdentity: String {
        "\(city)|\(address ?? "")|\(location?.latitude ?? 0)|\(location?.longitude ?? 0)"
    }

    private func routeButtonLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
    }

    private var locationLabel: String {
        let rawAddress = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedAddress = IsraelCityCatalog.localizingCity(
            in: rawAddress,
            city: city,
            locale: appState.locale
        )
        if !normalizedAddress.isEmpty {
            if localizedCity.isEmpty || normalizedAddress.localizedCaseInsensitiveContains(localizedCity) {
                return normalizedAddress
            }
            return "\(normalizedAddress), \(localizedCity)"
        }
        return localizedCity
    }

    private var localizedCity: String {
        IsraelCityCatalog.localizedName(for: city, locale: appState.locale)
    }

    private var searchLocationLabel: String {
        let normalizedAddress = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedAddress.isEmpty {
            if city.isEmpty || normalizedAddress.localizedCaseInsensitiveContains(city) {
                return normalizedAddress
            }
            return "\(normalizedAddress), \(city)"
        }
        return city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func resolveMapLocation() async {
        resolutionFailed = false
        if let location {
            setMapPosition(location)
            return
        }
        guard !searchLocationLabel.isEmpty else {
            resolutionFailed = true
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(searchLocationLabel), Israel"
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.6, longitude: 34.85),
            span: MKCoordinateSpan(latitudeDelta: 5.1, longitudeDelta: 3.4)
        )
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else {
            resolutionFailed = true
            return
        }
        let coordinate = item.placemark.coordinate
        let value = TaskMapLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            approximate: true
        )
        resolvedLocation = value
        setMapPosition(value)
    }

    private func setMapPosition(_ value: TaskMapLocation) {
        mapPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: value.latitude, longitude: value.longitude),
                span: MKCoordinateSpan(
                    latitudeDelta: value.approximate ? 0.08 : 0.015,
                    longitudeDelta: value.approximate ? 0.08 : 0.015
                )
            )
        )
    }

}

enum TaskMapLinks {
    static func maps(latitude: Double, longitude: Double) -> URL {
        make(
            base: "https://maps.apple.com/",
            items: [
                URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "q", value: "KABLAY"),
            ]
        )
    }

    static func waze(latitude: Double, longitude: Double) -> URL {
        make(
            base: "https://www.waze.com/ul",
            items: [
                URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "navigate", value: "yes"),
            ]
        )
    }

    static func maps(query: String) -> URL {
        make(
            base: "https://maps.apple.com/",
            items: [
                URLQueryItem(name: "q", value: query),
            ]
        )
    }

    static func waze(query: String) -> URL {
        make(
            base: "https://www.waze.com/ul",
            items: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "navigate", value: "yes"),
            ]
        )
    }

    private static func make(base: String, items: [URLQueryItem]) -> URL {
        var components = URLComponents(string: base)!
        components.queryItems = items
        return components.url!
    }
}

struct TaskPhotoGallery: View {
    @Environment(AppState.self) private var appState
    let urls: [URL]
    var showsEmptyState = false
    @State private var selectedPhoto: SelectedTaskPhoto?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                appState.locale.text(he: "תמונות מהלקוח", ru: "Фотографии клиента", en: "Client photos"),
                systemImage: "photo.on.rectangle.angled"
            )
            .font(.headline)

            if urls.isEmpty {
                if showsEmptyState {
                    Label(
                        appState.locale.text(
                            he: "הלקוח לא צירף תמונות לבקשה הזו.",
                            ru: "К этой заявке клиент не добавил фотографии.",
                            en: "The client did not add photos to this request."
                        ),
                        systemImage: "photo.badge.exclamationmark"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                            Button {
                                selectedPhoto = SelectedTaskPhoto(urls: urls, initialIndex: index)
                            } label: {
                                OfflineImage(url: url) { phase in
                                    switch phase {
                                    case let .success(image):
                                        image.resizable().scaledToFill()
                                    case .failure:
                                        Image(systemName: "photo.badge.exclamationmark")
                                            .font(.title2).foregroundStyle(.secondary)
                                    default:
                                        ProgressView()
                                    }
                                }
                                .frame(width: 168, height: 124)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(.rect(cornerRadius: 16))
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.caption.bold())
                                        .padding(8)
                                        .background(.ultraThinMaterial, in: .circle)
                                        .padding(7)
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(.rect)
                            .accessibilityLabel(appState.locale.text(he: "פתיחת תמונה", ru: "Открыть фото", en: "Open photo"))
                        }
                    }
                }
            }
        }
        .padding(16)
        .brandCard()
        .fullScreenCover(item: $selectedPhoto) { photo in
            TaskPhotoViewer(urls: photo.urls, initialIndex: photo.initialIndex)
        }
    }
}

private struct SelectedTaskPhoto: Identifiable {
    let id = UUID()
    let urls: [URL]
    let initialIndex: Int
}

private struct TaskPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let urls: [URL]
    @State private var selectedIndex: Int

    init(urls: [URL], initialIndex: Int) {
        self.urls = urls
        _selectedIndex = State(initialValue: min(max(initialIndex, 0), max(urls.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    ZoomableTaskPhoto(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Text("\(selectedIndex + 1) / \(urls.count)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: .capsule)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .tint(.white)
                    .accessibilityLabel("Close")
                }
                Spacer()
            }
            .padding()
        }
    }
}

private struct ZoomableTaskPhoto: View {
    let url: URL
    @State private var scale = 1.0

    var body: some View {
        OfflineImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { scale = min(max($0.magnification, 1), 4) }
                            .onEnded { if $0.magnification < 1.05 { scale = 1 } }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.snappy) { scale = scale > 1 ? 1 : 2.2 }
                    }
            case .failure:
                ContentUnavailableView("Photo unavailable", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.white)
            default:
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
