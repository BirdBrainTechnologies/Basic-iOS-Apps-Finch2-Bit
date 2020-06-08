import UIKit
import BirdbrainBLE

/* Custom type to tell us whether or not the Finch is connected. */
enum DeviceStatus {
    case connected(voltage: Float)
    case disconnected
}

class MainViewController: UIViewController {
    
    /* These two variables are initialized by prepare() in the previous view controller. */
    var finchManager: FinchManager? // Required by BirdBrainBLE
    var finch: Finch?               // Represents the Finch
    
    var finchSensorState: Finch.SensorState?   // Contains Finch sensor data
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var lightLabel: UILabel!
    @IBOutlet weak var lineLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the Finch delegates
        self.finchManager?.delegate = self
        self.finch?.delegate = self
        
        // listen for disconnections
        let _ = finch?.startStateChangeNotifications()
        
    }
    
    /* This function changes the color of the Finch beak and tail when the user adjusts the color slider. */
    @IBAction func
        colorSliderChanged(_ sender: UISlider) {
        
        var colors: Array<Int>
        
        switch (sender.value) {
        case 0..<1: colors = [100,100,100]
        case 1..<2: colors = [100,100,0]
        case 2..<3: colors = [0,100,100]
        case 3..<4: colors = [0,100,0]
        case 4..<5: colors = [100,0,100]
        case 5..<6: colors = [100,0,0]
        case 6..<7: colors = [0,0,100]
        default: colors = [0,0,0]
        }
        self.finch?.setBeak(red: colors[0],green: colors[1],blue: colors[2])
        self.finch?.setTail(port: "all",red: colors[0],green: colors[1],blue: colors[2])
    }
    
    /* The next four functions are called when the user taps the buttons to make the Finch move. */
    @IBAction func forwardButtonPressed(_ sender: UIButton) {
        self.finch?.setMove(direction: "F", distance: 20, speed: 50)
    }
    
    @IBAction func backButtonPressed(_ sender: UIButton) {
        self.finch?.setMove(direction: "B", distance: 20, speed: 50)
    }
    
    @IBAction func leftButtonPressed(_ sender: UIButton) {
        self.finch?.setTurn(direction: "L", angle: 90, speed: 50)
    }
    
    @IBAction func rightButtonPressed(_ sender: UIButton) {
        self.finch?.setTurn(direction: "R", angle: 90, speed: 50)
    }
    
    private func updateDeviceStatus(_ deviceStatus: DeviceStatus) {
        // TODO: show/hide device status view as appropriate, display icons/button, etc.
        switch deviceStatus {
        case .connected:
            self.statusLabel.text = "Connected"
        case .disconnected:
            self.statusLabel.text = "Disconnected"
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
        self.distanceLabel.text = String(sensorState.distance)
        
        /* The Finch light sensors are affected by the light from the beak, so we are going to correct them. This is only a small correction, so you can just use state.leftLight and state.rightLight if you don't care or you know the beak is off. No corrections are necessary for other Finch sensors. */
        let correctedLightSensors = finch.correctLightSensorValues()
        if let correctLeft = correctedLightSensors[0], let correctRight = correctedLightSensors[1] {
            self.lightLabel.text = "(" + String(correctLeft) + ", " + String(correctRight) + ")"
        }
        
        self.lineLabel.text = "(" + String(sensorState.leftLine) + ", " + String(sensorState.rightLine) + ")"
        
    }
    
    /* This function is called when the Finch can't get the state due to an error. */
    func finch(_ finch: Finch, errorGettingState error: Error) {
        // Handle what you want to do if the Finch has an error getting the state
    }
    
    
}
