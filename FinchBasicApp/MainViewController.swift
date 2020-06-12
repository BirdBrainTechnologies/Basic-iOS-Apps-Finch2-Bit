/* Bambi Brewer, BirdBrain Technologies, 6/10/2020 */
/* This view controller demonstrates how you can use ARkit with the Finch. The app uses ARKit to track an object that is defined in the Images folder in Assets.xcassets. Here, that obect is a book cover named monster. ARKit and SceneKit can be used to tell you where that object is located within the view of the camera, and then the Finch moves to follow the object. */
/* This app assumes that the device (most likely an iPhone) running the project is mounted to the top of the Finch with the back camera pointed out over the Finch's beak. */

import UIKit
import BirdbrainBLE
import SceneKit
import ARKit

/* Custom type to tell us whether or not the Finch is connected. */
enum DeviceStatus {
    case connected(voltage: Float)
    case disconnected
}

class MainViewController: UIViewController {
    
    @IBOutlet weak var sceneView: ARSCNView!    // The view we use to track the object
    
    @IBOutlet weak var trackingButton: UIButton!    // Used to toggle tracking on/off
    
    @IBOutlet weak var statusLabel: UILabel!    // Tells you whether or not the Finch is connected
    
    /* These two variables are initialized by prepare() in the previous view controller. */
    var finchManager: FinchManager? // Required by BirdBrainBLE
    var finch: Finch?               // Represents the Finch
    
    var finchSensorState: Finch.SensorState?   // Contains Finch sensor data
    
    var finchTimer: Timer?      // Timer to control the Finch's movements based on the position of the tracked object
    
    var trackedObjectNode: SCNNode?     // Node that represents the position of the tracked object
    
    var tracking = false    // Indicates whether or not the robot is currently tracking the object
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the Finch delegates
        self.finchManager?.delegate = self
        self.finch?.delegate = self
        
        // listen for disconnections
        let _ = finch?.startStateChangeNotifications()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        
        
    }

    @IBAction func trackingButtonPressed(_ sender: UIButton) {
        tracking = !tracking

        if (tracking) {
            trackingButton.setTitle("STOP TRACKING", for: .normal)
            /* We set up a timer that will call itself repeatedly and update the Finch based on whether or not the object we are tracking is currently in the scene. */
            finchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if let node = self.trackedObjectNode { // if the object node is defined
                    if let imageAnchor = self.sceneView.anchor(for: node) as? ARImageAnchor { // if node has anchor
                        if imageAnchor.isTracked {  // if we can currently see the image on the screen.
                            // Turn the beak green to show that it can follow the object. This Bluetooth command many occasionally be overwritten by the motor commands.
                            self.finch?.setBeak(red: 0, green: 100, blue: 0)
                            
                            // Find the position of the tracked object on the screen of the device (coordinates in pixels) and the distance of the object from the camera (z)
                            let nodePositionOnScreen = self.sceneView.projectPoint(node.presentation.worldPosition)
                            
                            // Normalize the x-position by the width of the device. Now x = 0.5 is the center of the screen.
                            let x = nodePositionOnScreen.x/Float(UIScreen.main.bounds.width)
                            
                            /* If the tracked object is on the left of the screen, Finch needs to turn left. If the tracked object is on the right of the screen, Finch needs to turn right. Within a narrow band in the center, we want the Finch to move forward. If the object is outside the bounds of the screen, we want to stop. */
                            if ((x < 0) || (x > 1)) {
                                self.finch?.stop()
                            } else if (x < 0.45) {
                                print("left")
                                self.finch?.setMotors(leftSpeed: 0, rightSpeed: 20)
                            } else if (x > 0.55) {
                                print("right")
                                self.finch?.setMotors(leftSpeed: 20, rightSpeed: 0)
                            } else {
                                self.finch?.setMotors(leftSpeed: 20, rightSpeed: 20)
                            }
                        } else {    // We can't see the image, so we stop and turn the beak red
                            self.finch?.setBeak(red: 100, green: 0, blue: 0)
                            self.finch?.stop()
                        }
                    } else { // Something is undefined, so we stop and turn the beak red.
                        self.finch?.setBeak(red: 100, green: 0, blue: 0)
                        self.finch?.stop()
                    }
                }
            }
        } else {    // turn everything off when they toggle to stop the tracking
            trackingButton.setTitle("START TRACKING", for: .normal)
            self.finch?.stopAll()
            finchTimer?.invalidate()
        }
    }
    
    /* This function updates the label on the screen to tell us if the Finch has become disconnected. */
    private func updateDeviceStatus(_ deviceStatus: DeviceStatus) {
        switch deviceStatus {
        case .connected:
            self.statusLabel.text = "Connected"
        case .disconnected:
            self.statusLabel.text = "Disconnected"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration - in this app, we will track images
        let configuration = ARImageTrackingConfiguration()
        
        // Set up the image to track
        if let imageToTrack = ARReferenceImage.referenceImages(inGroupNamed: "Images", bundle: Bundle.main)  {//Bundle.main means look in this project
            configuration.trackingImages = imageToTrack
            configuration.maximumNumberOfTrackedImages = 1
            print("Images successfully added")
        }

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
}

// MARK: - ARSCNViewDelegate

extension MainViewController: ARSCNViewDelegate {
    // Override to create and configure nodes for anchors added to the view's session. Here, the anchor is the image detected on the screen, and we will use its position to control the Finch
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        
        if let imageAnchor = anchor as? ARImageAnchor {
            let plane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
            plane.firstMaterial?.diffuse.contents = UIColor(white: 1.0, alpha: 0.5)
            let planeNode = SCNNode(geometry: plane)
            planeNode.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0)
            trackedObjectNode = planeNode
            node.addChildNode(planeNode)
            
        }
        return node
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
        // Not doing anything with the sensor info in this app
    }
    
    /* This function is called when the Finch can't get the state due to an error. */
    func finch(_ finch: Finch, errorGettingState error: Error) {
        // Handle what you want to do if the Finch has an error getting the state
    }
    
    
}
