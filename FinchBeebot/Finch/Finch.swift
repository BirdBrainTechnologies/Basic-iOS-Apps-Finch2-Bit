/* June 1, 2020, Bambi Brewer, BirdBrain Technologies */
/* This is the class that represents the Finch. It includes a data structure that the user can use to access the values of the Finch sensors, as well as public functions that can be used to control the Finch motors, lights, and buzzer. */

import Foundation
import os
import BirdbrainBLE

fileprivate struct Constants {
    static let expectedRawStateByteCount = 20   // Number of bytes in a Finch data packet
    
    static let batteryVoltageConversionFactor: Float = 0.00937
    static let cmPerDistance = 0.0919   // Converting encoder ticks to distance in cm
    static let ticksPerCM = 49.7        // Converting distance in cm to encoder ticks
    static let ticksPerDegree = 4.335   // For converting encoder ticks to the angle the Finch has turned
    static let ticksPerRotation = 792.0 // For converting encoder ticks to the number of rotations of the Finch wheel
    
    /* This structure contains the indices thst identify different values in a Bluetooth data packet sent by the Finch. */
    fileprivate struct ByteIndex {
        static let distanceMSB = 0      // MSB = most significant byte
        static let distanceLSB = 1      // LSB = least significant byte
        static let leftLight = 2
        static let rightLight = 3
        static let leftLine = 4     // Byte 4 contains two things
        static let movementFlag = 4
        static let rightLine = 5
        static let battery = 6
        static let leftEncoder = 7      // 3 bytes
        static let rightEncoder = 10    // 3 bytes
        static let accX = 13            // 3 bytes
        static let buttonShake = 16     // Contains bits for both micro:bit buttons and the shake
        static let magX = 17            // 3 bytes
        
    }
}

public class Finch: ManageableUARTDevice {
    
    //MARK: - Public Static Properties
    
    static public let scanFilter: UARTDeviceScanFilter = AdvertisedNamePrefixScanFilter(prefix: "FN") // required by Bluetooth package
    
    //MARK: - Structures for Finch Data
    
    /* This structure contains the raw bytes sent by the Finch over Bluetooth, along with a timestamp for the data. */
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
    
    /* This structure contains the processed values of the Finch sensors. This is the data type that you will use in your program to hold the state of the Finch inputs. */
    public struct SensorState {
        
        /* These functions are used to transform the raw Finch data into values the user can understand. This may involve scaling, converting the data, or manipulating bytes to deal with values that are encoded in more that one byte in the raw data. Do not change these functions unless you are very sure that you understand the Bluetooth protocol. */
        
        static fileprivate func parseBatteryVoltage(rawStateData: Data) -> Float {
            let battery: UInt8 = rawStateData[Constants.ByteIndex.battery]
            return (Float(battery) + 320)*Constants.batteryVoltageConversionFactor
        }
        
        static fileprivate func parseAccelerationMagnetometerCompass(rawStateData: Data) -> (Array<Double>, Array<Double>, Int?) {
            let rawAcc = Array(rawStateData[Constants.ByteIndex.accX...(Constants.ByteIndex.accX + 2)])
            let rawFinchAcc = rawToRawFinchAccelerometer(rawAcc)
            let accValues = [rawToAccelerometer(rawFinchAcc[0]), rawToAccelerometer(rawFinchAcc[1]), rawToAccelerometer(rawFinchAcc[2])]
            
            let rawMag = Array(rawStateData[Constants.ByteIndex.magX...(Constants.ByteIndex.magX + 2)])
            let finchMag = rawToFinchMagnetometer(rawMag)
            
            var compass:Int? = nil
            if let finchRawCompass = DoubleToCompass(acc: accValues, mag: finchMag) {
                //turn it around so that the finch beak points north at 0
                let finchCompass = (finchRawCompass + 180) % 360
                compass =  Int(round(Double(finchCompass)))
            }
            
            return (accValues, finchMag, compass)
        }
        
        static fileprivate func parseEncoders(rawStateData: Data) -> Array<Double> {
            let leftValues = Array(rawStateData[Constants.ByteIndex.leftEncoder...(Constants.ByteIndex.leftEncoder + 2)])
            let rightValues = Array(rawStateData[Constants.ByteIndex.rightEncoder...(Constants.ByteIndex.rightEncoder + 2)])
            
            //3 bytes is a 24bit int which is not a type in swift. Therefore, we shove the bytes over such that the sign will be carried over correctly when converted and then divide to go back to 24bit.
            let uNumLeft = (UInt32(leftValues[0]) << 24) + (UInt32(leftValues[1]) << 16) + (UInt32(leftValues[2]) << 8)
            let leftNum = Int32(bitPattern: uNumLeft) / 256
            
            let uNumRight = (UInt32(rightValues[0]) << 24) + (UInt32(rightValues[1]) << 16) + (UInt32(rightValues[2]) << 8)
            let rightNum = Int32(bitPattern: uNumRight) / 256
            
            let leftRotations = Double(leftNum)/Constants.ticksPerRotation
            let rightRotations = Double(rightNum)/Constants.ticksPerRotation
            
            return [leftRotations, rightRotations]
            
        }
        
        static fileprivate func parseLine(rawStateData: Data) -> Array<Int> {
            let rightLineDouble = (Double(rawStateData[Constants.ByteIndex.rightLine])-6.0)*100.0/121.0
            let rightLineInt = Int(100 - round(rightLineDouble))
            
            var leftLineDouble = Double(rawStateData[Constants.ByteIndex.leftLine])
            //the value for the left line sensor also contains the move flag
            if leftLineDouble > 127 { leftLineDouble -= 128 }
            leftLineDouble = (leftLineDouble - 6.0)*100.0/121.0
            let leftLineInt = Int(100 - round(leftLineDouble))
            
            return [leftLineInt, rightLineInt]
        }
        
        static fileprivate func parseMovementFlag(rawStateData: Data) -> Bool {
            
            let dataValue = Double(rawStateData[Constants.ByteIndex.movementFlag])
            // If this value is greater than 127, it means that the Finch is still
            // running a position control movement
            return (dataValue > 127)
        }
        
        static fileprivate func parseDistance(rawStateData: Data) -> Int {
            let msb = Int(rawStateData[Constants.ByteIndex.distanceMSB])
            let lsb = Int(rawStateData[Constants.ByteIndex.distanceLSB])
            let distance = (msb << 8) + lsb
            return Int(round(Double(distance)*Constants.cmPerDistance))
        }
        
        /* These are the variables that hold the sensor values that you will use in your programs. */
        public let timestamp: Date
        public let batteryVoltage: Float
        public let isStale: Bool
        public let distance: Int
        public var leftLight: Int
        public let rightLight: Int
        public let leftLine: Int
        public let rightLine: Int
        public let leftEncoder: Double
        public let rightEncoder: Double
        public let acceleration: Array<Double>
        public let magnetometer: Array<Double>
        public let compass: Int?    // Undefined in the case of 0 z direction acceleration
        public let buttonA: Bool
        public let buttonB: Bool
        public let shake: Bool
        public let movementFlag: Bool // True when the Finch is executing a movement command. You need to watch this flag if you don't want to start another Finch movement until the first one is finished.
        
        /* This struct is initiallized based on the raw sensor data. */
        fileprivate init(rawState: RawInputState) {
            self.timestamp = rawState.timestamp
            
            self.batteryVoltage = SensorState.parseBatteryVoltage(rawStateData: rawState.data)
            
            self.distance = SensorState.parseDistance(rawStateData: rawState.data)
//            self.leftLight = Int(round(0.392*Double(rawState.data[Constants.ByteIndex.leftLight])))
//            self.rightLight = Int(round(0.392*Double(rawState.data[Constants.ByteIndex.rightLight])))
            self.leftLight = Int(rawState.data[Constants.ByteIndex.leftLight])
            self.rightLight = Int(rawState.data[Constants.ByteIndex.rightLight])
            let lineSensors = SensorState.parseLine(rawStateData: rawState.data)
            self.leftLine = lineSensors[0]
            self.rightLine = lineSensors[1]
            (self.acceleration, self.magnetometer, self.compass) = SensorState.parseAccelerationMagnetometerCompass(rawStateData: rawState.data)
            
            let encoders = SensorState.parseEncoders(rawStateData: rawState.data)
            self.leftEncoder = encoders[0]
            self.rightEncoder = encoders[1]
            
            let bsBitValues = byteToBits(rawState.data[Constants.ByteIndex.buttonShake])
            self.buttonA = (bsBitValues[4] == 0)
            self.buttonB = (bsBitValues[5] == 0)
            self.shake = (bsBitValues[0] == 1)
            
            self.movementFlag = SensorState.parseMovementFlag(rawStateData: rawState.data)
            
            self.isStale = rawState.isStale
        }
    }
    
    /* This structure keeps track of the current values of the Finch beak and tail lights. It is used by setLightsAndBuzzer so that the lights don't get turned off when we send a command to the buzzer. */
    private struct LightState {
        var beakColor: Array<UInt8> = [0,0,0]
        var tailColor1: Array<UInt8> = [0,0,0]
        var tailColor2: Array<UInt8> = [0,0,0]
        var tailColor3: Array<UInt8> = [0,0,0]
        var tailColor4: Array<UInt8> = [0,0,0]
    }
    
    //MARK: - Public Properties
    
    public var uuid: UUID {         // Used by the Bluetooth package
        uartDevice.uuid
    }
    
    public var advertisementSignature: AdvertisementSignature? {    // Used by the Bluetooth package
        uartDevice.advertisementSignature
    }
    
    public var delegate: FinchDelegate?     // The class using the Finch
    
    
    //MARK: - Private Properties
    
    private var uartDevice: UARTDevice      // Required by the Bluetooth package
    
    private var lightState = LightState()   /* Remembers what the Finch beak and tail lights are set to. */
    
    /* This is the sensor data as it comes from the Finch in a 20-byte packet. It has to be decoded to provide meaningful information to the user. */
    private var rawInputState: RawInputState?
    
    /* This is a computed property that calculates the values of the Finch sensors based on the raw sensor data. */
    public var inputState: Finch.SensorState? {
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
    /* These functions implement the Bluetooth commands that are required to control the Finch motors, lights, and buzzer. Do not change them unless you are REALLY sure that you understand the Finch Bluetooth protocol. */
    
    /* This function sends a Bluetooth command to set the lights and buzzer of the Finch. The lights are set from the Finch output state so that they remain unchanged until the user sets them to something different. The buzzer, on the other hand, is set from input parameters, because we only want to play each note once. */
    private func setLightsAndBuzzer(buzzerPeriod: UInt16, buzzerDuration: UInt16) {
        
        let letter: UInt8 = 0xD0
        
        var buzzerArray: [UInt8] = []
        // Time_us_MSB, Time_us_LSB, Time_ms_MSB, Time_ms_LSB
        buzzerArray.append( UInt8(buzzerPeriod >> 8) )
        buzzerArray.append( UInt8(buzzerPeriod & 0x00ff) )
        buzzerArray.append( UInt8(buzzerDuration >> 8) )
        buzzerArray.append( UInt8(buzzerDuration & 0x00ff) )
        
        let array: [UInt8] = [letter,
                              self.lightState.beakColor[0],
                              self.lightState.beakColor[1],
                              self.lightState.beakColor[2],
                              self.lightState.tailColor1[0],
                              self.lightState.tailColor1[1],
                              self.lightState.tailColor1[2],
                              self.lightState.tailColor2[0],
                              self.lightState.tailColor2[1],
                              self.lightState.tailColor2[2],
                              self.lightState.tailColor3[0],
                              self.lightState.tailColor3[1],
                              self.lightState.tailColor3[2],
                              self.lightState.tailColor4[0],
                              self.lightState.tailColor4[1],
                              self.lightState.tailColor4[2],
                              buzzerArray[0],
                              buzzerArray[1],
                              buzzerArray[2],
                              buzzerArray[3]]

        uartDevice.writeWithoutResponse(bytes: array)
        
    }
    
    /* This function sends the Bluetooth command to set the Finch to move at particular speeds for the left and right wheels. The Finch will move until each wheel reaches a specified number of ticks. Then it will stop. */
    private func sendPositionControlCommand(leftSpeed: Int, rightSpeed: Int, leftTicks: Int, rightTicks: Int) {
        
        let lTicksMSB = UInt8(leftTicks >> 16)
        let lTicksSSB = UInt8((leftTicks & 0x00ff00) >> 8)
        let lTicksLSB = UInt8(leftTicks & 0x0000ff)
        
        let rTicksMSB = UInt8(rightTicks >> 16)
        let rTicksSSB = UInt8((rightTicks & 0x00ff00) >> 8)
        let rTicksLSB = UInt8(rightTicks & 0x0000ff)
        
        let leftConvertedSpeed1 = Int8(round(Double(36*leftSpeed)/100.0))
        let leftConvertedSpeed2 = convertVelocity(velocity: leftConvertedSpeed1)
        
        let rightConvertedSpeed1 = Int8(round(Double(36*rightSpeed)/100.0))
        let rightConvertedSpeed2 = convertVelocity(velocity: rightConvertedSpeed1)
        
        let array: [UInt8] = [0xD2,0x40,leftConvertedSpeed2,lTicksMSB,lTicksSSB,lTicksLSB,rightConvertedSpeed2,rTicksMSB,rTicksSSB,rTicksLSB]
        uartDevice.writeWithoutResponse(bytes: array)
    }
    
    /* This function sends the Bluetooth command to set the left and right motors to the specified speeds. The motors will stay on at these values until they receive another motor command. */
    private func sendVelocityControlCommand(leftSpeed: Int, rightSpeed: Int) {
        let leftConvertedSpeed1 = Int8(round(Double(36*leftSpeed)/100.0))
        let leftConvertedSpeed2 = convertVelocity(velocity: leftConvertedSpeed1)
        
        let rightConvertedSpeed1 = Int8(round(Double(36*rightSpeed)/100.0))
        let rightConvertedSpeed2 = convertVelocity(velocity: rightConvertedSpeed1)
        
        let array: [UInt8] = [0xD2,0x40,leftConvertedSpeed2,0,0,0,rightConvertedSpeed2,0,0,0]
        uartDevice.writeWithoutResponse(bytes: array)
        
    }
    
    /* This function turns off all the Finch motors, lights, and buzzer. */
    private func sendStopAllCommand() {
        let command: [UInt8] = [0xDF]
        
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
            
            let ledArrayCommand = [0xD2,0x20,led25, led24to17, led16to9, leds8to1]
            uartDevice.writeWithoutResponse(bytes: ledArrayCommand)
        }
        
    }
    
    //MARK: - Public Methods
    /* These are the functions that you will usually use to control the Finch. Most of these call a Bluetooth command that sets up the array that is sent over Bluetooth to the Finch. */
    
    /* State change notifications start automatically, but you can use this if you need to restart them. */
    public func startStateChangeNotifications() -> Bool {
        return uartDevice.startStateChangeNotifications()
    }
    
    /* Use this if you need to turn off state change notifications. This will stop the Finch getting new data, so don't do it unless you are very sure that is what you want. */
    public func stopStateChangeNotifications() -> Bool {
        return uartDevice.stopStateChangeNotifications()
    }
    
    /* This function send a Bluetooth command to calibrate the compass. When the Finch receives this command, it will dots on the micro:bit screen as it waits for you to tilt the Finch in different directions. If the calibration is successful, you will then see a check on the micro:bit screen. Otherwise, you will see an X. */
    public func calibrateCompass() {
        let command: [UInt8] = [0xCE, 0xFF, 0xFF, 0xFF]
        
        uartDevice.writeWithoutResponse(bytes: command)
    }
    
    /* This function sets the right and left encoder values to 0. */
    public func resetEncoders() {
        let command: [UInt8] = [0xD5]
        
        uartDevice.writeWithoutResponse(bytes: command)
    }
    
    /* This function sets the color of the Finch beak. The red, green, and blue parameters must be between 0 and 100. */
    public func setBeak(red: Int, green: Int, blue: Int) {
        
        self.lightState.beakColor = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
        
        // Want to change lights without playing the buzzer
        setLightsAndBuzzer(buzzerPeriod: 0, buzzerDuration: 0)
    }
    
    /* This function sets the color of the Finch tail if you have specified a single tail light (the function is also overloaded to control them all at once). The port is 1, 2, 3, or 4 and red, green, and blue must be between 0 and 100. */
    public func setTail(port: Int, red: Int, green: Int, blue: Int) {
        
        switch (port) {
        case 1: self.lightState.tailColor1 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
        case 2: self.lightState.tailColor2 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
        case 3: self.lightState.tailColor3 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
        case 4: self.lightState.tailColor4 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
        default:
            print("Error: Invalid port for setTail()")
            return
        }
        
        // Want to change lights without playing the buzzer
        setLightsAndBuzzer(buzzerPeriod: 0, buzzerDuration: 0)
    }
    
    /* This function sets the color of the Finch tail if you have specified "all" the tail lights (the function is also overloaded to control individual lights). The red, green, and blue parameters must be between 0 and 100. */
    public func setTail(port: String, red: Int, green: Int, blue: Int) {
        
        if (port == "all") {
            self.lightState.tailColor1 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
            self.lightState.tailColor2 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
            self.lightState.tailColor3 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
            self.lightState.tailColor4 = [UInt8(clampToBounds(num: red, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: green, minBound: 0, maxBound: 100)), UInt8(clampToBounds(num: blue, minBound: 0, maxBound: 100))]
            
            // Want to change lights without playing the buzzer
            setLightsAndBuzzer(buzzerPeriod: 0, buzzerDuration: 0)
        } else {
            print("Error: Invalid input for setTail()")
        }
    }
    
    /* This function plays a note on the Finch buzzer. We do not save this to the output state of the Finch, because we want it to play just once. Notes are MIDI notes (32-135) and beats must be between 0-16. Each beat is 1 second. */
    public func playNote(note: Int, beats: Double) {
        let noteInBounds = clampToBounds(num: note, minBound: 32, maxBound: 135)
        let beatsInBounds = clampToBounds(num: beats, minBound: 0, maxBound: 16)
        
        //duration of buzz in ms - 60bpm, so each beat is 1 s
        let duration = UInt16(1000*beatsInBounds)
        
        if let period = noteToPeriod(UInt8(noteInBounds)) { //the period of the note in us
            // Want to set the lights and the buzzer. Lights will be set based on the Finch output state
            setLightsAndBuzzer(buzzerPeriod: period, buzzerDuration: duration)
        }
        
    }
    
    /* The Finch light sensors are slightly affected by the value of the beak.
     It is a fairly small effect, but if you want, you can use this function to correct them */
    public func correctLightSensorValues() -> Array<Int?> {
        let beak = lightState.beakColor
        let R = Double(beak[0])
        let G = Double(beak[1])
        let B = Double(beak[2])
        var lightLeftCorrected: Int? = nil
        var lightRightCorrected: Int? = nil
        if let currentInputState = inputState {
            var lightLeft = Double(currentInputState.leftLight)
            var lightRight = Double(currentInputState.rightLight)
            
            lightLeft -= 1.06871493e-02*R +  1.94526614e-02*G +  6.12409825e-02*B +  4.01343475e-04*R*G + 4.25761981e-04*R*B +  6.46091068e-04*G*B - 4.41056971e-06*R*G*B
            lightRight -= 6.40473070e-03*R +  1.41015162e-02*G +  5.05547817e-02*B +  3.98301391e-04*R*G +  4.41091223e-04*R*B +  6.40756862e-04*G*B + -4.76971242e-06*R*G*B
            
            if (lightLeft < 0) {lightLeft = 0}
            if (lightRight < 0) {lightRight = 0}
            
            if (lightLeft > 100) {lightLeft = 100}
            if (lightRight > 100) {lightRight = 100}
            
            lightLeftCorrected = Int(round(lightLeft))
            lightRightCorrected = Int(round(lightRight))
            
        }
        
        return [lightLeftCorrected, lightRightCorrected]
    }
    
    /* This function moves the Finch forward or back a given distance (in centimeters) at a given speed (-100 to 100%). */
    public func setMove(direction: String, distance: Double, speed: Int) {
        var speedCorrect = clampToBounds(num: speed, minBound: -100, maxBound: 100)
        if ((direction == "F") || (direction == "B")) {
            if (direction == "B") {
                speedCorrect = -1*speedCorrect
            }
        } else {
            print("Error: Invalid direction for call to setMove()")
        }
        let distanceInTicks = Int(round(abs(distance*Constants.ticksPerCM)))
        
        sendPositionControlCommand(leftSpeed: speedCorrect, rightSpeed: speedCorrect, leftTicks: distanceInTicks, rightTicks: distanceInTicks)
    }
    
    /* This function turns the Finch left or right a given angle (in degrees) at a given speed (-100 to 100%). */
    public func setTurn(direction: String, angle: Double, speed: Int) {
        var speedCorrectLeft = clampToBounds(num: speed, minBound: -100, maxBound: 100)
        var speedCorrectRight = -1*speedCorrectLeft
        if ((direction == "R") || (direction == "L")) {
            if (direction == "L") {
                speedCorrectLeft = -1*speedCorrectLeft
                speedCorrectRight = -1*speedCorrectRight
            }
        } else {
            print("Error: Invalid direction for call to setMove()")
        }
        
        let angleInTicks = Int(round(abs(angle*Constants.ticksPerDegree)))
        
        sendPositionControlCommand(leftSpeed: speedCorrectLeft, rightSpeed: speedCorrectRight, leftTicks: angleInTicks, rightTicks: angleInTicks)
    }
    
    /* This function sets the speed of the left and right motors to values between -100 and 100. The motors will stay on at these values until you stop them with stop() or stopAll() or call setMove(), setTurn(), or set Motors(). */
    public func setMotors(leftSpeed: Int, rightSpeed: Int) {
        sendVelocityControlCommand(leftSpeed: clampToBounds(num: leftSpeed, minBound: -100, maxBound: 100), rightSpeed: clampToBounds(num: rightSpeed, minBound: -100, maxBound: 100))
    }
    
    /* This function can be used to print a string on the Finch micro:bit. This function can only print strings up to 18 characters long. */
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
    
    /* This function stops the Finch motors. */
    public func stop() {
        sendVelocityControlCommand(leftSpeed: 0, rightSpeed: 0)
    }
    
    /* This function turns off all the Finch motors, lights, and buzzer. */
    public func stopAll() {
        lightState = LightState()
        sendStopAllCommand()
    }
   
}

// MARK: - UARTDeviceDelegate
/* These are the function the Finch class must implement to be a UARTDeviceDelegate. You will not need to change these for the vast majority of project. */
extension Finch: UARTDeviceDelegate {
    
    /* This function determines what happens when the Bluetooth device changes whether or not it is sending notifications. */
    public func uartDevice(_ device: UARTDevice, isSendingStateChangeNotifications: Bool) {
        delegate?.finch(self, isSendingStateChangeNotifications: isSendingStateChangeNotifications)
    }
    
    /* This function determines what happens when the Bluetooth device has new data. */
    public func uartDevice(_ device: UARTDevice, newState stateData: Data) {
        if let rawState = RawInputState(data: stateData) {
            self.rawInputState = rawState
            
            /* Every time we get a new Bluetooth notification with sensor data, we create a new value of InputState() and pass it to the Finch delegate. */
            if let delegate = delegate {
                delegate.finch(self, sensorState: SensorState(rawState: rawState))
                
            }
        } else {
            /* If we have an error, pass that to the Finch delegate. */
            self.rawInputState?.isStale = true
            delegate?.finch(self, errorGettingState: "invalid raw state" as! Error)
        }
        
        
    }
    
    /* This function determines what happens when the Bluetooth devices gets an error instead of data. */
    public func uartDevice(_ device: UARTDevice, errorGettingState error: Error) {
        self.rawInputState?.isStale = true
        delegate?.finch(self, errorGettingState: error)
    }
}

