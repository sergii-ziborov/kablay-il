import CoreLocation
import MapKit
import Observation

struct LocationSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    fileprivate let completion: MKLocalSearchCompletion

    static func == (lhs: LocationSuggestion, rhs: LocationSuggestion) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ResolvedLocation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let city: String
    let address: String

    init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        city: String,
        address: String
    ) {
        self.id = id
        self.coordinate = coordinate
        self.city = city
        self.address = address
    }
}

@MainActor
@Observable
final class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate, CLLocationManagerDelegate {
    var suggestions: [LocationSuggestion] = []
    var selectedLocation: ResolvedLocation?
    var isLocating = false
    var errorMessage: String?

    private let completer = MKLocalSearchCompleter()
    private let locationManager = CLLocationManager()
    private var bestLocation: CLLocation?
    private var locationTimeoutTask: Task<Void, Never>?
    private let israelRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 31.6, longitude: 34.85),
        span: MKCoordinateSpan(latitudeDelta: 5.1, longitudeDelta: 3.4)
    )

    override init() {
        super.init()
        completer.delegate = self
        completer.region = israelRegion
        completer.resultTypes = [.address, .pointOfInterest]
        locationManager.delegate = self
        // A task address must use the actual device position. Hundred-meter
        // accuracy is not sufficient in dense Israeli streets.
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func update(query: String) {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count < 2 {
            suggestions = []
            completer.queryFragment = ""
        } else {
            completer.queryFragment = value
        }
    }

    func select(_ suggestion: LocationSuggestion) async {
        cancelLocationUpdates()
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        request.region = israelRegion
        do {
            guard let item = try await MKLocalSearch(request: request).start().mapItems.first else { return }
            selectedLocation = resolvedLocation(from: item)
            suggestions = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Selects the exact coordinate shown by the pin, then resolves a readable
    /// address without replacing that coordinate with a nearby search result.
    func select(coordinate: CLLocationCoordinate2D) async {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        cancelLocationUpdates()

        let selectionID = UUID()
        selectedLocation = ResolvedLocation(
            id: selectionID,
            coordinate: coordinate,
            city: "",
            address: ""
        )
        suggestions = []
        errorMessage = nil

        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let resolved: ResolvedLocation?
            if #available(iOS 26.0, *) {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    throw LocationResolutionError.unavailable
                }
                let mapItems = try await request.mapItems
                resolved = mapItems.first.map { resolvedLocation(from: $0, coordinate: coordinate) }
            } else {
                let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first
                resolved = placemark.map { resolvedLocation(from: $0, coordinate: coordinate) }
            }
            guard selectedLocation?.id == selectionID, let resolved else {
                throw LocationResolutionError.unavailable
            }
            selectedLocation = resolved
        } catch {
            // The coordinate is still valid and remains selected even if Apple
            // cannot provide a street name for the point.
            guard selectedLocation?.id == selectionID else { return }
            errorMessage = "address_unavailable"
        }
    }

    func requestCurrentLocation() {
        errorMessage = nil
        isLocating = true
        Task { [weak self] in
            let servicesEnabled = await Task.detached(priority: .userInitiated) {
                CLLocationManager.locationServicesEnabled()
            }.value
            guard let self, self.isLocating else { return }
            guard servicesEnabled else {
                self.isLocating = false
                self.errorMessage = "location_services_disabled"
                return
            }
            self.continueCurrentLocationRequest()
        }
    }

    private func continueCurrentLocationRequest() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            beginLocationUpdates()
        case .denied, .restricted:
            isLocating = false
            errorMessage = "location_permission_denied"
        @unknown default:
            errorMessage = "location_unavailable"
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let values = completer.results.prefix(6).map { result in
            LocationSuggestion(
                id: "\(result.title)|\(result.subtitle)",
                title: result.title,
                subtitle: result.subtitle,
                completion: result
            )
        }
        Task { @MainActor in suggestions = values }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in errorMessage = error.localizedDescription }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleAuthorizationChange(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            self?.consumeLocationUpdates(locations)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let locationError = error as? CLError
        guard locationError?.code != .locationUnknown else { return }
        Task { @MainActor [weak self] in
            self?.cancelLocationUpdates()
            self?.errorMessage = locationError?.code == .denied
                ? "location_permission_denied"
                : "location_unavailable"
        }
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if isLocating { beginLocationUpdates() }
        case .denied, .restricted:
            cancelLocationUpdates()
            errorMessage = "location_permission_denied"
        case .notDetermined:
            break
        @unknown default:
            cancelLocationUpdates()
            errorMessage = "location_unavailable"
        }
    }

    /// `requestLocation()` can return an old cached coordinate. Keep listening
    /// briefly and prefer a fresh, accurate sample before resolving the address.
    private func beginLocationUpdates() {
        locationTimeoutTask?.cancel()
        bestLocation = nil
        errorMessage = nil
        isLocating = true
        locationManager.startUpdatingLocation()
        locationTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.finishLocationUpdates()
        }
    }

    private func consumeLocationUpdates(_ locations: [CLLocation]) {
        let now = Date()
        let freshLocations = locations.filter {
            $0.horizontalAccuracy >= 0
                && abs($0.timestamp.timeIntervalSince(now)) <= 30
                && CLLocationCoordinate2DIsValid($0.coordinate)
        }
        for location in freshLocations where bestLocation == nil || location.horizontalAccuracy < bestLocation!.horizontalAccuracy {
            bestLocation = location
        }
        if let bestLocation, bestLocation.horizontalAccuracy <= 65 {
            finishLocationUpdates(using: bestLocation)
        }
    }

    private func finishLocationUpdates(using location: CLLocation? = nil) {
        let chosenLocation = location ?? bestLocation
        cancelLocationUpdates()
        guard let chosenLocation else {
            errorMessage = "location_timeout"
            return
        }
        Task { [weak self] in
            await self?.select(coordinate: chosenLocation.coordinate)
        }
    }

    private func cancelLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil
        bestLocation = nil
        isLocating = false
    }

    private func resolvedLocation(
        from item: MKMapItem,
        coordinate: CLLocationCoordinate2D? = nil
    ) -> ResolvedLocation {
        let placemark = item.placemark
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? ""
        let addressParts = [placemark.name, placemark.locality]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return ResolvedLocation(
            coordinate: coordinate ?? placemark.coordinate,
            city: city,
            address: Array(NSOrderedSet(array: addressParts)).compactMap { $0 as? String }.joined(separator: ", ")
        )
    }

    private func resolvedLocation(from placemark: CLPlacemark, coordinate: CLLocationCoordinate2D) -> ResolvedLocation {
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? ""
        let street = [placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let fallbackName = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let addressParts = [street.isEmpty ? fallbackName : street, city].filter { !$0.isEmpty }

        return ResolvedLocation(
            coordinate: coordinate,
            city: city,
            address: Array(NSOrderedSet(array: addressParts)).compactMap { $0 as? String }.joined(separator: ", ")
        )
    }
}

private enum LocationResolutionError: Error {
    case unavailable
}
