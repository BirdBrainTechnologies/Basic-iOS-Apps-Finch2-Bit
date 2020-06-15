/* This controls the main screen of the app that allows you to control the lights and servo motors of the Hummingbird. It also displays the Hummingbird sensor values and the connection status. */

import UIKit
import BirdbrainBLE

/* Custom type to tell us whether or not the Hummingbird is connected. */
enum DeviceStatus {
    case connected(voltage: Float)
    case disconnected
}

class MainViewController: UIViewController {
    
    /* These two variables are initialized by prepare() in the previous view controller. */
    var hummingbirdManager: HummingbirdManager? // Required by BirdBrainBLE
    var hummingbird: Hummingbird?               // Represents the Hummingbird
    
    var hummingbirdSensorState: Hummingbird.SensorState?   // Contains Hummingbird sensor data
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the Hummingbird delegates
        self.hummingbirdManager?.delegate = self
        self.hummingbird?.delegate = self
        
        // listen for disconnections
        let _ = hummingbird?.startStateChangeNotifications()
    
        
    }
    
}

//MARK: - UARTDeviceManagerDelegate
/* These are the function that are required by the BirdBrain BLE package. You use these if you want to discover devices, connect, etc.  */
extension MainViewController: HummingbirdManagerDelegate {
    /* This function is called when we start or stop scanning. */
    func didUpdateState(to state: HummingbirdManagerState) {
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

/* These are the functions you are required to implement to use the Hummingbird. */
extension MainViewController: HummingbirdDelegate {
    
    /* This function is called when the Hummingbird changes whether or not it is sending Bluetooth data. */
    func hummingbird(_ hummingbird: Hummingbird, isSendingStateChangeNotifications: Bool) {
        // Handle what you want to do if the Hummingbird stops sending notifications
    }
    
    /* This is the function that is called when the Hummingbird has new sensor data. That data is in the state variable. */
    func hummingbird(_ hummingbird: Hummingbird, sensorState: Hummingbird.SensorState) {
        self.hummingbirdSensorState = sensorState
        // Do whatever you want with the sensor data here
    }
    
    /* This function is called when the Hummingbird can't get the state due to an error. */
    func hummingbird(_ hummingbird: Hummingbird, errorGettingState error: Error) {
        // Handle what you want to do if the Hummingbird has an error getting the state
    }
    
    
}
