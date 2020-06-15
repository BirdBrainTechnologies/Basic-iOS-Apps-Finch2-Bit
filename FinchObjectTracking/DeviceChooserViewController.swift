/* This is the view controller that controls the initial screen of the app (Device Chooser Scene), where you choose your Finch. It displays a lit of Bluetooth devices, and when you tap one, it connects and then moves on to the Main View Controller and its corresponding screen. */
import UIKit
import BirdbrainBLE

/* Structure that represents the available Finches. */
fileprivate struct AvailableDevice {
    let uuid: UUID
    let advertisementSignature: AdvertisementSignature
    var rssi: NSNumber
    
    init(uuid: UUID, advertisementSignature: AdvertisementSignature, rssi: NSNumber) {
        self.uuid = uuid
        self.rssi = rssi
        self.advertisementSignature = advertisementSignature
    }
}

class DeviceChooserViewController: UIViewController {
    
    /* To use the BirdBrainBLE package with the Finch, you need a class that represents the Finch and a manager for that class. */
    private let finchManager = FinchManager(scanFilter: Finch.scanFilter)
    private var finch: Finch?
    
    
    @IBOutlet weak var availableDevicesTable: UITableView!
    
    private var availableDevices = [AvailableDevice]()
    private var availableDevicesByUUID = [UUID : AvailableDevice]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the delegates
        finchManager.delegate = self
        availableDevicesTable.dataSource = self
        availableDevicesTable.delegate = self
    }
    
    /* This function updates the Bluetooth devices in the table. */
    private func updateDeviceList() {
        DispatchQueue.main.async {
            self.availableDevicesTable.reloadData()
        }
    }
    
    /* This function is called just before the segue to the Main View Controller Scene. It is VERY IMPORTANT that you set up the finch and finchManager variables for the MainViewController before this segue. Otherwise, your Finch will not work in that scene. You need to override prepare() in the same way for any other segues that are part of your program. */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToMain" {
            let destinationVC = segue.destination as! MainViewController
            destinationVC.finch = finch
            destinationVC.finchManager = finchManager
        }
    }
}

//MARK: - UITableViewDelegate
/* This is the function that is called when you tap a row in the list of Bluetooth devices*/
extension DeviceChooserViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("DeviceChooserViewController: UITableViewDelegate.didSelectRowAt(\(indexPath.row))")
        let _ = finchManager.stopScanning()
        let _ = finchManager.connectToDevice(havingUUID:    availableDevices[indexPath.row].uuid)   // Connect to Finch
    }
}

//MARK: - UITableViewDataSource
/* This is the function that is required to fill in the table of devices. */
extension DeviceChooserViewController: UITableViewDataSource {
    
    /* The onscreen table calls this to figure out how many devices there are to display. */
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableDevices.count
    }
    
    /* This is the function that is called to display each cell of the table.*/
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "Device Cell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        
        let device = availableDevices[indexPath.row]    // device to display
        
        cell.textLabel?.text = device.advertisementSignature.memorableName ?? device.advertisementSignature.advertisedName  // update cell with device
        
        return cell
    }
}

//MARK: - UARTDeviceManagerDelegate
/* These are the function that are required by the BirdBrain BLE package. You use these if you want to discover devices, connect, etc.  */
extension DeviceChooserViewController: UARTDeviceManagerDelegate {
    
    /* This function is called when we start or stop scanning. */
    func didUpdateState(to state: UARTDeviceManagerState) {
        print("UARTDeviceManagerDelegate.didUpdateState: \(state)")
        if (state == .enabled) {
            if finchManager.startScanning() {
                print("Scanning...")
            }
            else {
                print("Failed to start scanning!")
            }
        }
    }
    
    /* This function is called when we discover a Bluetooth device. It is then added to the list of devices. */
    func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        if let advertisementSignature = advertisementSignature {
            let device = AvailableDevice(uuid: uuid, advertisementSignature: advertisementSignature, rssi: rssi)
            availableDevicesByUUID[uuid] = device
            availableDevices.append(device)
            updateDeviceList()
        } else {
            // TODO: do something better
            print("Ignoring device \(uuid) because its advertisement signature is nil")
        }
    }
    
    /* This function is called when a device you connected to previously is rediscovered. */
    func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        // Handle what you want to do if you rediscover a device.
    }
    
    /* This function is called when we connect to a device. It triggers the segue to the Main View Controller. */
    func didConnectTo(uuid: UUID) {
        print("didConnectTo(\(uuid))")
        finch = finchManager.getDevice(uuid: uuid)
        performSegue(withIdentifier: "goToMain", sender: self)
    }
    
    /* This function is called when you disconnect from a device. */
    func didDisconnectFrom(uuid: UUID, error: Error?) {
        print("didDisconnectFrom(\(uuid))")
        // Handle anything you want to do when you disconnect
    }
    
    /* This function is called when you fail to connect to a device. */
    func didFailToConnectTo(uuid: UUID, error: Error?) {
        print("didFailToConnectTo(\(uuid))")
        // Handle anything you want to do if you fail to connect to a device.
    }
}

