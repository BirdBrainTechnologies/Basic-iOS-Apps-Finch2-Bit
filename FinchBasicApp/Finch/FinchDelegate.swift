/* This protocol defines the functions that your view controller must implement to be a Finch delegate. Leave this file alone, but make sure that you provide implementations for these functions in any view controller that uses the Finch. */
import Foundation

public protocol FinchDelegate {
    
    /* This function is called when the Finch changes whether or not it is sending Bluetooth data. */
   func finch(_ finch: Finch, isSendingStateChangeNotifications: Bool)
    
    /* This is the function that is called when the Finch has new sensor data. That data is in the state variable. */
   func finch(_ finch: Finch, sensorState: Finch.SensorState)
    
    /* This function is called when the Finch can't get the state due to an error. */
   func finch(_ finch: Finch, errorGettingState error: Error)
}

