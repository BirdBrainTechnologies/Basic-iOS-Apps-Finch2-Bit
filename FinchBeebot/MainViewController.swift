/* Bambi Brewer, BirdBrain Technologies, June 2020 */
/* This app lets users push arrow buttons on the screen of the phone or tablet to write a "program" for the Finch. Then the user pressed the green play button to make the Finch run the program. This is similar to how the BeeBot works. */
/*  This file contains the main logic for the app. As the user presses buttons, movements are stored in an array. When the user presses the play button, the app moves through the array and the Finch performs each movement. This app provides a demonstration of how to send a position control movement to the Finch and wait for the Finch to finish that movement before you go on to the next one. */

import UIKit
import BirdbrainBLE

/* Custom type to tell us whether or not the Finch is connected. */
enum DeviceStatus {
    case connected(voltage: Float)
    case disconnected
}

/* Custom type for defining the movements in the array of movements. */
enum FinchMovements {
    case forward
    case backward
    case right
    case left
}

class MainViewController: UIViewController {
    
    /* These two variables are initialized by prepare() in the previous view controller. */
    var finchManager: FinchManager?             // Required by BirdBrainBLE
    var finch: Finch?                           // Represents the Finch
    
    var finchSensorState: Finch.SensorState?    // Contains Finch sensor data
    
    var movements: Array<FinchMovements> = []   // Movements the user has selected
    
    /* These variables are used to monitor the status of the Finch setMove() and setTurn() commands as the user's program plays. This is necessary to make sure one command is complete before the next one is sent. Otherwise, the second command will overwrite the first. */
    var programRunning = false      // Whether the play button is running a program
    var movementSent = false        // Whether a Bluetooth command has been sent
    var movementStarted = false     // Whether a movement has started as a result of the Bluetooth command
    var movementFinished = false    // Whether the movement that was started has finished
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the Finch delegates
        self.finchManager?.delegate = self
        self.finch?.delegate = self
        
        // listen for disconnections
        let _ = finch?.startStateChangeNotifications()
        
    }
    
    
    
    /* The next four functions are called when the user taps the buttons to create their program. We only add a movement to the array when there is not a program running. */
    @IBAction func forwardButtonPressed(_ sender: UIButton) {
        if (!programRunning) {
            movements.append(.forward)
        }
    }
    
    @IBAction func backButtonPressed(_ sender: UIButton) {
        if (!programRunning) {
            movements.append(.backward)
        }
    }
    
    @IBAction func leftButtonPressed(_ sender: UIButton) {
        if (!programRunning) {
            movements.append(.left)
        }
    }
    
    @IBAction func rightButtonPressed(_ sender: UIButton) {
        if (!programRunning) {
            movements.append(.right)
        }
    }
    
    @IBAction func playButtonPressed(_ sender: UIButton) {
        
        if (!programRunning) {    // ignore button press if program already running
            programRunning = true

            /* We set up a timer that will call itself repeatedly until all the movements are complete. */
            Timer.scheduledTimer(withTimeInterval: 0.001, repeats: true) { timer in
                if (!self.movementSent) {   // If we haven't sent a movement that we are waiting to complete
                    if (self.movements.count > 0) { // If there is another movement to send
                        switch (self.movements.first) {     // Send the Bluetooth command
                        case .forward: self.finch?.setMove(direction: "F", distance: 20, speed: 50)
                        case .backward: self.finch?.setMove(direction: "B", distance: 20, speed: 50)
                        case .left: self.finch?.setTurn(direction: "L", angle: 90, speed: 50)
                        case .right: self.finch?.setTurn(direction: "R", angle: 90, speed: 50)
                        default: print("Error: Not a valid direction")
                        }
                        self.movementSent = true
                    } else {    // We have finished running all the movements!
                        self.programRunning = false
                        timer.invalidate()      // This stops the timer from calling itself any more
                    }
                } else if (self.movementSent && !self.movementStarted) {
                    /* Once we have sent a movement, there is a delay before the Finch receives that command and starts to move. We know the Finch has started moving when the movementFlag is ture. Keep resetting movementStarted until the movementFlag is true. */
                    self.movementStarted = (self.finchSensorState?.movementFlag == true)
                } else if (self.movementStarted && !self.movementFinished) {
                    /* Once a movement has started, then we have to wait for the movementFlag to turn back to false to indicate that it has finished. Keep resetting movementFinished until it is true. */
                    self.movementFinished = (self.finchSensorState?.movementFlag == false)
                } else if (self.movementFinished) {     // Current movement has finished
                    // Remove the completed movement from the array and set all our flags back to false.
                    if (self.movements.count > 0) {self.movements.removeFirst()}
                    self.movementSent = false
                    self.movementStarted = false
                    self.movementFinished = false
                }
            }
        }
    }
    
    /* This function stops the Finch and emptys the movement array to end the user's program. */
    @IBAction func stopButtonPressed(_ sender: UIButton) {
        movements = []
        finch?.stop()
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

final class LogDestination: TextOutputStream {
  private let path: String
  init() {
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    path = paths.first!
    print(path)
    //let fileName = "\(documentsDirectory)/textFile.txt"
  }

  func write(_ string: String) {
    if let data = string.data(using: .utf8), let fileHandle = FileHandle(forWritingAtPath: path) {
      defer {
        fileHandle.closeFile()
      }
      fileHandle.seekToEndOfFile()
      fileHandle.write(data)
    }
  }
}

