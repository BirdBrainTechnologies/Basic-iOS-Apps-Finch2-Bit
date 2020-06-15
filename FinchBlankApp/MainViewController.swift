/* Bambi Brewer, BirdBrain Technologies, June 2020 */
/* This is a blank view controller ready for you to write your own Finch app! */

import UIKit
import BirdbrainBLE

/* Custom type to tell us whether or not the Finch is connected. */
enum DeviceStatus {
    case connected(voltage: Float)
    case disconnected
}


class MainViewController: UIViewController {
    
    /* These two variables are initialized by prepare() in the previous view controller. */
    var finchManager: FinchManager?             // Required by BirdBrainBLE
    var finch: Finch?                           // Represents the Finch
    
    var finchSensorState: Finch.SensorState?    // Contains Finch sensor data
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the Finch delegates
        self.finchManager?.delegate = self
        self.finch?.delegate = self
        
        // listen for disconnections
        let _ = finch?.startStateChangeNotifications()
        
    }
    
    
    /* This function can be used if you want to make the UI indicate when the Finch has been disconnected.  */
    private func updateDeviceStatus(_ deviceStatus: DeviceStatus) {
        // TODO: show/hide device status view as appropriate, display icons/button, etc.
        switch deviceStatus {
        case .connected:
            print("Connected")
        case .disconnected:
            print("Disconnected")
        }
    }
}

//MARK: - UARTDeviceManagerDelegate
/* These are the function that are required by the BirdBrain BLE package. You use these if you want to discover devices, connect, etc.  */
extension MainViewController: FinchManagerDelegate {
    /* This function is called when we start or stop scanning. */
    func didUpdateState(to state: FinchManagerState) {
        // nothing to do, handled elsewhere
    }
    
    /* This function is called when we discover a Bluetooth device. */
    func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        // not doing anything here, but if you lost a connection and decided to scan again for devices you would use this.
    }
    
    /* This function is called when a device you connected to previously is rediscovered. */
    func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        // not doing anything here, but if you lost a connection and decided to scan to rediscover your device you would use this.
    }
    
    /* This function is called when we connect to a device. */
    func didConnectTo(uuid: UUID) {
        // nothing to do here but you would use this if you want to automatically handle reconnection
    }
    
    /* This function is called when you disconnect from a device. */
    func didDisconnectFrom(uuid: UUID, error: Error?) {
        print("didDisconnectFrom(\(uuid))")
        // Handle anything you want to do when you disconnect
    }
    
    /* This function is called when you fail to connect to a device. */
    func didFailToConnectTo(uuid: UUID, error: Error?) {
        print("didFailToConnectTo(\(uuid))")
        // nothing to do here
    }
}

/* These are the functions you are required to implement to use the Finch. */
extension MainViewController: FinchDelegate {
    
    /* This function is called when the Finch changes whether or not it is sending Bluetooth data. */
    func finch(_ finch: Finch, isSendingStateChangeNotifications: Bool) {
        // Handle what you want to do if the Finch stops sending notifications
    }
    
    /* This is the function that is called when the Finch has new sensor data. That data is in the state variable. */
    func finch(_ finch: Finch, sensorState: Finch.SensorState) {
        self.finchSensorState = sensorState
    }
    
    /* This function is called when the Finch can't get the state due to an error. */
    func finch(_ finch: Finch, errorGettingState error: Error) {
        // Handle what you want to do if the Finch has an error getting the state
    }
    
    
}


