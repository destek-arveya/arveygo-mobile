import SwiftUI
import MapKit

// MARK: - Geofences View
struct GeofencesView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var showSideMenu: Bool
    @StateObject private var vm = GeofencesViewModel()

    @State private var selectedGeofence: Geofence?
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9, longitude: 32.8),
            span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
        )
    )

    var body: some View {
        NavigationStack {
            ZStack {
                // Map with geofence overlays
                mapContent

                // Bottom panel — list of geofences
                VStack {
                    Spacer()
                    geofenceListPanel
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) { showSideMenu.toggle() }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Geofence")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text("Bölge Takibi")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    AvatarCircle(
                        initials: authVM.currentUser?.avatar ?? "A",
                        size: 30
                    )
                }
            }
            .onAppear {
                vm.loadGeofences()
            }
        }
    }

    // MARK: - Map Content
    var mapContent: some View {
        Map(position: $mapCameraPosition) {
            ForEach(vm.geofences) { geofence in
                if geofence.isCircle, let cLat = geofence.centerLat, let cLng = geofence.centerLng, let r = geofence.radius {
                    // Circle geofence
                    MapCircle(center: CLLocationCoordinate2D(latitude: cLat, longitude: cLng), radius: r)
                        .foregroundStyle(geofence.swiftUIColor.opacity(0.2))
                        .stroke(geofence.swiftUIColor, lineWidth: 2)

                    // Center label
                    Annotation(geofence.name, coordinate: CLLocationCoordinate2D(latitude: cLat, longitude: cLng)) {
                        geofenceLabel(geofence)
                    }
                } else if !geofence.points.isEmpty {
                    // Polygon geofence
                    let coords = geofence.points.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                    }
                    MapPolygon(coordinates: coords)
                        .foregroundStyle(geofence.swiftUIColor.opacity(0.2))
                        .stroke(geofence.swiftUIColor, lineWidth: 2)

                    // Centroid label
                    let centroid = polygonCentroid(coords)
                    Annotation(geofence.name, coordinate: centroid) {
                        geofenceLabel(geofence)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    func geofenceLabel(_ geofence: Geofence) -> some View {
        Button(action: {
            selectedGeofence = geofence
            focusGeofence(geofence)
        }) {
            HStack(spacing: 4) {
                Image(systemName: geofence.isCircle ? "circle.dashed" : "hexagon.fill")
                    .font(.system(size: 10))
                Text(geofence.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(geofence.swiftUIColor.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }

    // MARK: - Geofence List Panel
    var geofenceListPanel: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 8)

            if vm.isLoading {
                ProgressView()
                    .padding(.vertical, 30)
            } else if vm.geofences.isEmpty {
                emptyState
            } else {
                // Header
                HStack {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.indigo)
                    Text("Bölgeler")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                    Spacer()
                    Text("\(vm.geofences.count) bölge")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.geofences) { geofence in
                            geofenceRow(geofence)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: 250)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hexagon")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.textFaint)
            Text("Henüz bölge tanımlanmamış")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textMuted)
            Text("Bölge eklemek için web panelini kullanın")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textFaint)
        }
        .padding(.vertical, 30)
    }

    @ViewBuilder
    func geofenceRow(_ geofence: Geofence) -> some View {
        let isSelected = selectedGeofence?.id == geofence.id
        Button(action: {
            selectedGeofence = geofence
            focusGeofence(geofence)
        }) {
            HStack(spacing: 12) {
                // Color indicator
                Circle()
                    .fill(geofence.swiftUIColor)
                    .frame(width: 10, height: 10)

                // Icon
                Image(systemName: geofence.isCircle ? "circle.dashed" : "hexagon.fill")
                    .font(.system(size: 16))
                    .foregroundColor(geofence.swiftUIColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(geofence.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.navy)

                    HStack(spacing: 4) {
                        Text(geofence.isCircle ? "Daire" : "Poligon")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                        if geofence.isCircle, let r = geofence.radius {
                            Text("· \(Int(r))m")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        if !geofence.isCircle {
                            Text("· \(geofence.points.count) nokta")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textFaint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? geofence.swiftUIColor.opacity(0.08) : Color(UIColor.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? geofence.swiftUIColor : Color.clear, lineWidth: 1.5)
            )
        }
    }

    // MARK: - Helpers

    private func focusGeofence(_ geofence: Geofence) {
        if geofence.isCircle, let cLat = geofence.centerLat, let cLng = geofence.centerLng {
            let span = max((geofence.radius ?? 500) / 50000.0, 0.01)
            withAnimation(.easeInOut(duration: 0.6)) {
                mapCameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: cLat, longitude: cLng),
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                ))
            }
        } else if !geofence.points.isEmpty {
            let lats = geofence.points.map { $0.lat }
            let lngs = geofence.points.map { $0.lng }
            guard let minLat = lats.min(), let maxLat = lats.max(),
                  let minLng = lngs.min(), let maxLng = lngs.max() else { return }
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
                longitudeDelta: max((maxLng - minLng) * 1.5, 0.01)
            )
            withAnimation(.easeInOut(duration: 0.6)) {
                mapCameraPosition = .region(MKCoordinateRegion(center: center, span: span))
            }
        }
    }

    private func polygonCentroid(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coords.isEmpty else {
            return CLLocationCoordinate2D(latitude: 39.9, longitude: 32.8)
        }
        let lat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
        let lng = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - ViewModel
class GeofencesViewModel: ObservableObject {
    @Published var geofences: [Geofence] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadGeofences() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task {
            do {
                let result = try await APIService.shared.fetchGeofences()
                await MainActor.run {
                    self.geofences = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
                print("[Geofences] Error: \(error)")
            }
        }
    }
}

#Preview {
    GeofencesView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
