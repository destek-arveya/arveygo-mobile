import Foundation
import CoreBluetooth
import CoreLocation
import Combine

class BeaconManager: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var isAdvertising = false
    @Published var statusMessage = "Hazır. UUID girin ve yayına başlayın."
    @Published var uuidString = "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"
    @Published var majorValue: UInt16 = 1
    @Published var minorValue: UInt16 = 1
    @Published var identifierLabel = "com.arveya.arveygorider"

    // MARK: - Private
    private var peripheralManager: CBPeripheralManager?
    private var beaconRegion: CLBeaconRegion?
    private var beaconData: [String: Any]?

    override init() {
        super.init()
    }

    // MARK: - Start / Stop
    func startAdvertising() {
        guard let uuid = UUID(uuidString: uuidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            statusMessage = "⛔ Geçersiz UUID formatı."
            return
        }

        let constraint = CLBeaconIdentityConstraint(uuid: uuid, major: majorValue, minor: minorValue)
        beaconRegion = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: identifierLabel)

        beaconData = beaconRegion?.peripheralData(withMeasuredPower: nil) as? [String: Any]

        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        } else if peripheralManager?.state == .poweredOn {
            beginBroadcast()
        } else {
            statusMessage = "⏳ Bluetooth açılıyor…"
        }
    }

    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        isAdvertising = false
        statusMessage = "⏹ Yayın durduruldu."
    }

    private func beginBroadcast() {
        guard let data = beaconData else {
            statusMessage = "⛔ Beacon verisi oluşturulamadı."
            return
        }
        peripheralManager?.startAdvertising(data)
        isAdvertising = true
        statusMessage = "📡 Beacon yayını aktif!"
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BeaconManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if beaconData != nil {
                beginBroadcast()
            } else {
                statusMessage = "✅ Bluetooth açık. Yayına başlayabilirsiniz."
            }
        case .poweredOff:
            isAdvertising = false
            statusMessage = "⛔ Bluetooth kapalı. Lütfen açın."
        case .unauthorized:
            statusMessage = "⛔ Bluetooth izni verilmedi."
        case .unsupported:
            statusMessage = "⛔ Bu cihaz BLE desteklemiyor."
        default:
            statusMessage = "⏳ Bluetooth durumu bilinmiyor."
        }
    }
}
