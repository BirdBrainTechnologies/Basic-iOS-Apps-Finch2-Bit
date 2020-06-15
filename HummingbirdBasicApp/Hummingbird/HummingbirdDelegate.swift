/* This protocol defines the functions that your view controller must implement to be a Hummingbird delegate. Leave this file alone, but make sure that you provide implementations for these functions in any view controller that uses the Hummingbird Bit. */
import Foundation

public protocol HummingbirdDelegate {
    
    /* This function is called when the Hummingbird changes whether or not it is sending Bluetooth data. */
   func hummingbird(_ hummingbird: Hummingbird, isSendingStateChangeNotifications: Bool)
    
    /* This is the function that is called when the Hummingbird has new sensor data. That data is in the state variable. */
   func hummingbird(_ finch: Hummingbird, sensorState: Hummingbird.SensorState)
    
    /* This function is called when the Hummingbird can't get the state due to an error. */
   func hummingbird(_ hummingbird: Hummingbird, errorGettingState error: Error)
}
