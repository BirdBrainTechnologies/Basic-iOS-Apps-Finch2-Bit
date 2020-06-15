/* June 1, 2020, Bambi Brewer, BirdBrain Technologies */
/* This is the class that represents the Hummingbird. It includes a data structure that the user can use to access the values of the Hummingbird sensors, as well as public functions that can be used to control the Hummingbird motors, lights, and buzzer. */

import Foundation
import os
import BirdbrainBLE

fileprivate struct Constants {
    static let expectedRawStateByteCount = 14   // Number of bytes in a Hummingbird data packet
    
    static let batteryVoltageConversionFactor: Float = 55.6
    
    /* This structure contains the indices thst identify different values in a Bluetooth data packet sent by the Hummingbird. */
    fileprivate struct ByteIndex {
        static let sensor1 = 0      // MSB = most significant byte
        static let sensor2 = 1      // LSB = least significant byte
        static let sensor3 = 2
        static let battery = 3
        static let accX = 4           // 3 bytes
        static let buttonShake = 7     // Contains bits for both micro:bit buttons and the shake
        static let magX = 8            // 3 bytes
        
    }
}

public class Hummingbird: ManageableUARTDevice {
    
    //MARK: - Public Static Properties
    
    static public let scanFilter: UARTDeviceScanFilter = AdvertisedNamePrefixScanFilter(prefix: "BB") // required by Bluetooth package
    
    //MARK: - Structures for Hummingbird Data
    
    /* This structure contains the raw bytes sent by the Hummingbird over Bluetooth, along with a timestamp for the data. */
    public struct RawInputState {
        public let timestamp: Date
        public let data: Data
        public fileprivate(set) var isStale: Bool   // is the data old?
        
        init?(data: Data) {
            if data.count == Constants.expectedRawStateByteCount {
                self.timestamp = Date()
                self.data = data
                self.isStale = false
            }
            else {
                return nil
            }
        }
    }
    
    /* Each of the Hummingbird sensor ports supports different types of sensors, and we don't know what the user is plugging into each one. This data type computes all of the possibilities for each port. */
    public struct HummingbirdSensor {
        public let distance: Int
        public let light: Int
        public let dial: Int
        public let voltage: Double
        
        fileprivate init(sensor: UInt8) {
            self.distance = Int(round(Double(sensor) * (117/100)))
            
            self.light = Int( round(Double(sensor) * (100 / 255)))
            
            var dialTemp = Int( round(Double(sensor) * (100 / 230)))
            if dialTemp > 100 { dialTemp = 100 }
            self.dial = dialTemp
            
            self.voltage = Double(sensor) * (3.3 / 255)
        }
    }
    
    /* This structure contains the processed values of the Hummingbird sensors. This is the data type that you will use in your program to hold the state of the Hummingbird inputs. */
    public struct SensorState {
        
        /* These functions are used to transform the raw Hummingbird data into values the user can understand. This may involve scaling, converting the data, or manipulating bytes to deal with values that are encoded in more that one byte in the raw data. Do not change these functions unless you are very sure that you understand the Bluetooth protocol. */
        
        static fileprivate func parseBatteryVoltage(rawStateData: Data) -> Float {
            let battery: UInt8 = rawStateData[Constants.ByteIndex.battery]
            return Float(battery) //Float(battery) / Constants.batteryVoltageConversionFactor
        }
        
        static fileprivate func parseAccelerationMagnetometerCompass(rawStateData: Data) -> (Array<Double>, Array<Double>, Int?) {
            let rawAcc = Array(rawStateData[Constants.ByteIndex.accX...(Constants.ByteIndex.accX + 2)])
            let accValues = [rawToAccelerometer(rawAcc[0]), rawToAccelerometer(rawAcc[1]), rawToAccelerometer(rawAcc[2])]
            
            let rawMagX = rawToMagnetometer(rawStateData[Constants.ByteIndex.magX],rawStateData[Constants.ByteIndex.magX + 1])
            let rawMagY = rawToMagnetometer(rawStateData[Constants.ByteIndex.magX + 2],rawStateData[Constants.ByteIndex.magX + 3])
            let rawMagZ = rawToMagnetometer(rawStateData[Constants.ByteIndex.magX + 4],rawStateData[Constants.ByteIndex.magX + 5])
            
            let magnetometer = Array(arrayLiteral: Double(rawMagX), Double(rawMagY), Double(rawMagZ))
            
            var compass:Int? = nil
            if let rawCompass = DoubleToCompass(acc: accValues, mag: magnetometer) {
                //turn it around so that the finch beak points north at 0
                let compassScaled = (rawCompass + 180) % 360
                compass =  Int(round(Double(compassScaled)))
            }
            
            return (accValues, magnetometer, compass)
        }
        
        
             
        /* These are the variables that hold the sensor values that you will use in your programs. */
        public let timestamp: Date
        public let batteryVoltage: Float
        public let isStale: Bool
        public let sensor1: HummingbirdSensor
        public let sensor2: HummingbirdSensor
        public let sensor3: HummingbirdSensor
        public let acceleration: Array<Double>
        public let magnetometer: Array<Double>
        public let compass: Int?    // Undefined in the case of 0 z direction acceleration
        public let buttonA: Bool
        public let buttonB: Bool
        public let shake: Bool
        
        /* This struct is initiallized based on the raw sensor data. */
        fileprivate init(rawState: RawInputState) {
            self.timestamp = rawState.timestamp
            
            self.batteryVoltage = SensorState.parseBatteryVoltage(rawStateData: rawState.data)
            
            self.sensor1 = HummingbirdSensor(sensor: rawState.data[Constants.ByteIndex.sensor1])
            self.sensor2 = HummingbirdSensor(sensor: rawState.data[Constants.ByteIndex.sensor2])
            self.sensor3 = HummingbirdSensor(sensor: rawState.data[Constants.ByteIndex.sensor3])
            
            (self.acceleration, self.magnetometer, self.compass) = SensorState.parseAccelerationMagnetometerCompass(rawStateData: rawState.data)
            
            let bsBitValues = byteToBits(rawState.data[Constants.ByteIndex.buttonShake])
            self.buttonA = (bsBitValues[4] == 0)
            self.buttonB = (bsBitValues[5] == 0)
            self.shake = (bsBitValues[0] == 1)
                        
            self.isStale = rawState.isStale
        }
    }
    
    /* This structure keeps track of the current values of the Hummingbird outputs. These values are all sent at one time, so we have to keep track to make sure they are not overwritten when we send the next command. */
    private struct OutputState {
        var triLED1: Array<UInt8> = [0,0,0]
        var triLED2: Array<UInt8> = [0,0,0]
        var singleLED1: UInt8 = 0
        var singleLED2: UInt8 = 0
        var singleLED3: UInt8 = 0
        var servo1: UInt8 = 255
        var servo2: UInt8 = 255
        var servo3: UInt8 = 255
        var servo4: UInt8 = 255
    }
    
    //MARK: - Public Properties
    
    public var uuid: UUID {         // Used by the Bluetooth package
        uartDevice.uuid
    }
    
    public var advertisementSignature: AdvertisementSignature? {    // Used by the Bluetooth package
        uartDevice.advertisementSignature
    }
    
    public var delegate: HummingbirdDelegate?     // The class using the Hummingbird
    
    
    //MARK: - Private Properties
    
    private var uartDevice: UARTDevice      // Required by the Bluetooth package
    
    private var outputState = OutputState()   /* Remembers what the HB outputs are set to. */
    
    /* This is the sensor data as it comes from the Hummingbird in a 14-byte packet. It has to be decoded to provide meaningful information to the user. */
    private var rawInputState: RawInputState?
    
    /* This is a computed property that calculates the values of the Hummingbird sensors based on the raw sensor data. */
    public var inputState: Hummingbird.SensorState? {
        get {
            if let rawState = rawInputState {
                return SensorState(rawState: rawState)
            }
            return nil
        }
    }
    
    //MARK: - Initializers
    /* Initiallizes Bluetooth */
    required public init(blePeripheral: BLEPeripheral) {
        uartDevice = BaseUARTDevice(blePeripheral: blePeripheral)
        uartDevice.delegate = self
    }
    
    //MARK: - Bluetooth Methods for Outputs
    /* These functions implement the Bluetooth commands that are required to control the Hummingbird motors, lights, and buzzer. Do not change them unless you are REALLY sure that you understand the Hummingbird Bluetooth protocol. */
    
    /* This function sends a Bluetooth command to set the lights, motors, and buzzer of the Hummingbird. The lights and motors are set from the Hummingbird output state so that they remain unchanged until the user sets them to something different. The buzzer, on the other hand, is set from input parameters, because we only want to play each note once. */
    private func setAllOutputs(buzzerPeriod: UInt16, buzzerDuration: UInt16) {
        
        let letter: UInt8 = 0xCA
        
        var buzzerArray: [UInt8] = []
        // Time_us_MSB, Time_us_LSB, Time_ms_MSB, Time_ms_LSB
        buzzerArray.append( UInt8(buzzerPeriod >> 8) )
        buzzerArray.append( UInt8(buzzerPeriod & 0x00ff) )
        buzzerArray.append( UInt8(buzzerDuration >> 8) )
        buzzerArray.append( UInt8(buzzerDuration & 0x00ff) )
        
        let array: [UInt8] = [letter,
                              self.outputState.singleLED1,
                              0xFF, // reserved for future use
                              self.outputState.triLED1[0],
                              self.outputState.triLED1[1],
                              self.outputState.triLED1[2],
                              self.outputState.triLED2[0],
                              self.outputState.triLED2[1],
                              self.outputState.triLED2[2],
                              self.outputState.servo1,
                              self.outputState.servo2,
                              self.outputState.servo3,
                              self.outputState.servo4,
                              self.outputState.singleLED2,
                              self.outputState.singleLED3,
                              buzzerArray[0],
                              buzzerArray[1],
                              buzzerArray[2],
                              buzzerArray[3]]

        uartDevice.writeWithoutResponse(bytes: array)
        
    }

    /* This function turns off all the Hummingbird motors, lights, and buzzer. */
    private func sendStopAllCommand() {
        let command: [UInt8] = [0xCB]

        uartDevice.writeWithoutResponse(bytes: command)
    }

    /* This function sends a Bluetooth command to print a string on the micro:bit LED display. */
    private func sendPrintCommand(_ stringToPrint: String) {

        let letter: UInt8 = 0xCC
        let ledStatusChars = Array(stringToPrint)
        var length = ledStatusChars.count
        if (length > 18) { // can't send strings longer than 18 characters
            length = 18
            print("Error: Cannot print strings longer than 18 characters.")
        }
        let flash = UInt8(64 + length)
        var commandArray = [letter, flash]
        for i in 0 ..< length {
            commandArray.append(getUnicode(ledStatusChars[i]))
        }

        uartDevice.writeWithoutResponse(bytes: commandArray)
    }

    /* This function send the Bluetooth command to display a particular pattern on the micro:bit array. */
    private func sendLEDArrayCommand(pattern: String) {
        if (pattern.count != 25) {
            print("Error: LED Array pattern must contain 25 characters")
        } else {
            let ledStatusChars = Array(pattern)
            var led8to1String = ""
            for i in 0 ..< 8 {
                led8to1String = String(ledStatusChars[i]) + led8to1String
            }

            var led16to9String = ""
            for i in 8 ..< 16 {
                led16to9String = String(ledStatusChars[i]) + led16to9String
            }

            var led24to17String = ""
            for i in 16 ..< 24 {
                led24to17String = String(ledStatusChars[i]) + led24to17String
            }

            guard let leds8to1 = UInt8(led8to1String, radix: 2),
                let led16to9 = UInt8(led16to9String, radix: 2),
                let led24to17 = UInt8(led24to17String, radix: 2),
                let led25 = UInt8(String(ledStatusChars[24])) else {
                    return
            }

            let ledArrayCommand = [0xCC,0x80,led25, led24to17, led16to9, leds8to1]
            uartDevice.writeWithoutResponse(bytes: ledArrayCommand)
        }

    }
    
    //MARK: - Public Methods
    /* These are the functions that you will usually use to control the Hummingbird. Most of these call a Bluetooth command that sets up the array that is sent over Bluetooth to the Finch. */
    
    /* State change notifications start automatically, but you can use this if you need to restart them. */
    public func startStateChangeNotifications() -> Bool {
        return uartDevice.startStateChangeNotifications()
    }
    
    /* Use this if you need to turn off state change notifications. This will stop the Hummingbird getting new data, so don't do it unless you are very sure that is what you want. */
    public func stopStateChangeNotifications() -> Bool {
        return uartDevice.stopStateChangeNotifications()
    }
    
    /* This function send a Bluetooth command to calibrate the compass. When the Hummingbird receives this command, it will place dots on the micro:bit screen as it waits for you to tilt the Finch in different directions. If the calibration is successful, you will then see a check on the micro:bit screen. Otherwise, you will see an X. */
    public func calibrateCompass() {
        let command: [UInt8] = [0xCE, 0xFF, 0xFF, 0xFF]
        
        uartDevice.writeWithoutResponse(bytes: command)
    }
    
    
    /* This function sets the color of a tricolor LED on either port 1 or port 2. The red, green, and blue parameters must be between 0 and 100. */
    public func setTriLED(port: Int, red: Int, green: Int, blue: Int) {

        let portBound = clampToBounds(num: port, minBound: 1, maxBound: 2)
        if (portBound == 1) {
            self.outputState.triLED1 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
        } else {
            self.outputState.triLED2 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
        }

        // Want to change outputs without playing the buzzer
        setAllOutputs(buzzerPeriod: 0, buzzerDuration: 0)
    }
    
    /* This function sets the brightness of a single color LED on port 1, 2, or 3. The intensity must be between 0 and 100. */
    public func setLED(port: Int, intensity: Int) {

        let portBound = clampToBounds(num: port, minBound: 1, maxBound: 3)
        switch (portBound) {
        case 1: self.outputState.singleLED1 = UInt8(clampToBounds(num: intensity, minBound: 0, maxBound: 100))
        case 2: self.outputState.singleLED2 = UInt8(clampToBounds(num: intensity, minBound: 0, maxBound: 100))
        case 3: self.outputState.singleLED3 = UInt8(clampToBounds(num: intensity, minBound: 0, maxBound: 100))
        default: print("Error")
        }
        
        // Want to change outputs without playing the buzzer
        setAllOutputs(buzzerPeriod: 0, buzzerDuration: 0)
    }
    
    /* This function sets the value of a position servo on port 1-4 to a value between 0° and 180°. */
    public func setPositionServo(port: Int, angle: Int) {
        let boundedPort = clampToBounds(num: port, minBound: 1, maxBound: 4)
        let boundedAngle = clampToBounds(num: angle, minBound: 0, maxBound: 180)
        let realAngle = UInt8(floor(Double(boundedAngle)*254/180))
        switch (boundedPort) {
        case 1: self.outputState.servo1 = realAngle
        case 2: self.outputState.servo2 = realAngle
        case 3: self.outputState.servo3 = realAngle
        case 4: self.outputState.servo4 = realAngle
        default: print("Error")
        }
        
        // Want to change outputs without playing the buzzer
        setAllOutputs(buzzerPeriod: 0, buzzerDuration: 0)
    }
    
    /* This function sets the value of a rotation servo on port 1-4 to a speed between -100 and 100. */
    public func setRotationServo(port: Int, speed: Int) {
        let boundedPort = clampToBounds(num: port, minBound: 1, maxBound: 4)
        let boundedSpeed = clampToBounds(num: speed, minBound: -100, maxBound: 100)
        
        var realSpeed: UInt8 = 255
        if ((boundedSpeed < -10) || (boundedSpeed > 10)) {
            realSpeed = UInt8(round(abs((Double(boundedSpeed) * 23.0 / 100.0) + 122)))
        }

        switch (boundedPort) {
        case 1: self.outputState.servo1 = realSpeed
        case 2: self.outputState.servo2 = realSpeed
        case 3: self.outputState.servo3 = realSpeed
        case 4: self.outputState.servo4 = realSpeed
        default: print("Error")
        }
        
        // Want to change outputs without playing the buzzer
        setAllOutputs(buzzerPeriod: 0, buzzerDuration: 0)
    }
    
    /* This function plays a note on the Hummingbird buzzer. We do not save this to the output state of the Finch, because we want it to play just once. Notes are MIDI notes (32-135) and beats must be between 0-16. Each beat is 1 second. */
    public func playNote(note: Int, beats: Double) {
        let noteInBounds = clampToBounds(num: note, minBound: 32, maxBound: 135)
        let beatsInBounds = clampToBounds(num: beats, minBound: 0, maxBound: 16)

        //duration of buzz in ms - 60bpm, so each beat is 1 s
        let duration = UInt16(1000*beatsInBounds)

        if let period = noteToPeriod(UInt8(noteInBounds)) { //the period of the note in us
            // Want to set the lights and the buzzer. Lights will be set based on the Finch output state
            setAllOutputs(buzzerPeriod: period, buzzerDuration: duration)
        }

    }
    
    /* This function can be used to print a string on the Hummingbird micro:bit. This function can only print strings up to 18 characters long. */
    public func printString(_ stringToPrint: String) {
        sendPrintCommand(stringToPrint)
    }

    /* This function sets the LED array of the micro:bit to display a pattern defined by a list of length 25. Each value in the list must be 0 (off) or 1 (on). The first five values in the array correspond to the five LEDs in the first row, the next five values to the second row, etc. */
    public func setDisplay(pattern: Array<Int>) {
        if (pattern.count != 25) {
            print("Error: The array must contain 25 values.")
        } else {
            var stringPattern = ""
            for value in pattern {
                if (value == 0) {
                    stringPattern.append("0")
                } else {
                    stringPattern.append("1")
                }
            }
            sendLEDArrayCommand(pattern: stringPattern)
        }
    }

    /* This function turns off all the Hummingbird motors, lights, and buzzer. */
    public func stopAll() {
        outputState = OutputState()
        sendStopAllCommand()
    }
   
}

// MARK: - UARTDeviceDelegate
/* These are the functions the Hummingbird class must implement to be a UARTDeviceDelegate. You will not need to change these for the vast majority of project. */
extension Hummingbird: UARTDeviceDelegate {
    
    /* This function determines what happens when the Bluetooth device changes whether or not it is sending notifications. */
    public func uartDevice(_ device: UARTDevice, isSendingStateChangeNotifications: Bool) {
        delegate?.hummingbird(self, isSendingStateChangeNotifications: isSendingStateChangeNotifications)
    }
    
    /* This function determines what happens when the Bluetooth device has new data. */
    public func uartDevice(_ device: UARTDevice, newState stateData: Data) {
        if let rawState = RawInputState(data: stateData) {
            self.rawInputState = rawState
            
            /* Every time we get a new Bluetooth notification with sensor data, we create a new value of InputState() and pass it to the Hummingbird delegate. */
            if let delegate = delegate {
                delegate.hummingbird(self, sensorState: SensorState(rawState: rawState))
                
            }
        } else {
            /* If we have an error, pass that to the Hummingbird delegate. */
            self.rawInputState?.isStale = true
            delegate?.hummingbird(self, errorGettingState: "invalid raw state" as! Error)
        }
        
        
    }
    
    /* This function determines what happens when the Bluetooth devices gets an error instead of data. */
    public func uartDevice(_ device: UARTDevice, errorGettingState error: Error) {
        self.rawInputState?.isStale = true
        delegate?.hummingbird(self, errorGettingState: error)
    }
}


