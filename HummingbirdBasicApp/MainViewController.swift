import UIKit
import BirdbrainBLE

/* Custom type to tell us whether or not the Finch is connected. */
enum DeviceStatus {
    case connected(voltage: Float)
    case disconnected
}

class MainViewController: UIViewController {
    
    /* These two variables are initialized by prepare() in the previous view controller. */
    var hummingbirdManager: HummingbirdManager? // Required by BirdBrainBLE
    var hummingbird: Hummingbird?               // Represents the Finch
    
    var hummingbirdSensorState: Hummingbird.SensorState?   // Contains Finch sensor data
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var lightLabel: UILabel!
    @IBOutlet weak var dialLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the Finch delegates
        self.hummingbirdManager?.delegate = self
        self.hummingbird?.delegate = self
        
        // listen for disconnections
        let _ = hummingbird?.startStateChangeNotifications()
    
        
    }
    
    @IBAction func lightsOn(_ sender: UIButton) {
        hummingbird?.setLED(port: 1, intensity: 100)
        hummingbird?.setLED(port: 2, intensity: 100)
        hummingbird?.setLED(port: 3, intensity: 100)
        
        var pattern: [Int] = []
        for _ in 0..<25 {
            pattern.append([0,1].randomElement()!)
        }
        print(pattern)
        hummingbird?.setDisplay(pattern: pattern)
    }
    
    
    @IBAction func lightsOff(_ sender: UIButton) {
        hummingbird?.setLED(port: 1, intensity: 0)
        hummingbird?.setLED(port: 2, intensity: 0)
        hummingbird?.setLED(port: 3, intensity: 0)
        
        var pattern: [Int] = []
        for _ in 0..<25 {
            pattern.append(0)
        }
        hummingbird?.setDisplay(pattern: pattern)
    }
    
    @IBAction func playSound(_ sender: UIButton) {
        hummingbird?.playNote(note: (50...100).randomElement()!, beats: 1)
    }
    
    @IBAction func servo1SliderChanged(_ sender: UISlider) {
        self.hummingbird?.setPositionServo(port: 1, angle: Int(round(sender.value)))
    }
    @IBAction func servo2SliderChanged(_ sender: UISlider) {
        self.hummingbird?.setPositionServo(port: 2, angle: Int(round(sender.value)))
    }
    @IBAction func servo3SliderChanged(_ sender: UISlider) {
        self.hummingbird?.setPositionServo(port: 3, angle: Int(round(sender.value)))
    }
    @IBAction func servo4SliderChanged(_ sender: UISlider) {
        self.hummingbird?.setPositionServo(port: 4, angle: Int(round(sender.value)))
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
        self.hummingbird?.setTriLED(port: 1, red: colors[0],green: colors[1], blue: colors[2])
        self.hummingbird?.setTriLED(port: 2, red: colors[0],green: colors[1], blue: colors[2])
        self.hummingbird?.setPositionServo(port: 1, angle: Int(sender.value)*10)
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

/* These are the functions you are required to implement to use the Finch. */
extension MainViewController: HummingbirdDelegate {
    
    /* This function is called when the Finch changes whether or not it is sending Bluetooth data. */
    func hummingbird(_ hummingbird: Hummingbird, isSendingStateChangeNotifications: Bool) {
        // Handle what you want to do if the Finch stops sending notifications
    }
    
    /* This is the function that is called when the Hummingbird has new sensor data. That data is in the state variable. */
    func hummingbird(_ hummingbird: Hummingbird, sensorState: Hummingbird.SensorState) {
        self.hummingbirdSensorState = sensorState
        self.distanceLabel.text = String(sensorState.sensor1.distance) + " cm"

        self.lightLabel.text = String(sensorState.sensor2.light)
        self.dialLabel.text = String(sensorState.sensor3.dial)
    }
    
    /* This function is called when the Finch can't get the state due to an error. */
    func hummingbird(_ hummingbird: Hummingbird, errorGettingState error: Error) {
        // Handle what you want to do if the Finch has an error getting the state
    }
    
    
}
