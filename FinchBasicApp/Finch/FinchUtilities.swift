/* This file contains a lot of small function that are used to process the Finch data or encode values into the form that the Bluetooth protocol requires. You should not need to change anything in this file, though you can add your own utilities if you wish. */

import Foundation
import GLKit

/**
 * Convert a byte of data into an array of bits
 */
func byteToBits(_ byte: UInt8) -> [UInt8] {
    var byte = byte
    var bits = [UInt8](repeating: 0, count: 8)
    for i in 0..<8 {
        let currentBit = byte & 0x01
        if currentBit != 0 {
            bits[i] = 1
        }
        
        byte >>= 1
    }
    
    return bits
}

/* This function is used to make sure Finch output values are within the required bound.*/
func clampToBounds(num: Int, minBound: Int, maxBound: Int) -> Int {
    return min(max(num,minBound),maxBound)
}

/* This function is used to make sure Finch output values are within the required bound.*/
func clampToBounds(num: Double, minBound: Double, maxBound: Double) -> Double {
    return min(max(num,minBound),maxBound)
}

/**
 * Convert raw magnetometer value to magnetometer value in the finch reference frame
 */
public func rawToFinchMagnetometer(_ rawMag: [UInt8]) -> [Double] {
    let x = Double(Int8(bitPattern: rawMag[0]))
    let y = Double(Int8(bitPattern: rawMag[1]))
    let z = Double(Int8(bitPattern: rawMag[2]))
    
    let finchX = x
    let finchY = y * __cospi(40/180) + z * __sinpi(40/180)
    let finchZ = z * __cospi(40/180) - y * __sinpi(40/180)
    
    return [finchX, finchY, finchZ]
}

/**
 * Convert raw value into a scaled accelerometer value
 */
public func rawToAccelerometer(_ raw_val: UInt8) -> Double {
    return rawToAccelerometer(Double(Int8(bitPattern: raw_val)))
    //let intVal = Int8(bitPattern: raw_val) //convert to 2's complement signed int
    //let scaledVal = Double(intVal) * 196/1280 //scaling from bambi
    //return scaledVal
}
public func rawToAccelerometer(_ raw_val: Double) -> Double {
    return raw_val * 196/1280 //scaling from bambi
}

/**
 * Convert raw accelerometer values to raw accelerometer values in finch reference frame.
 * Must still use rawToAccelerometer to scale.
 */
public func rawToRawFinchAccelerometer(_ rawAcc: [UInt8]) -> [Double] {
    let x = Double(Int8(bitPattern: rawAcc[0]))
    let y = Double(Int8(bitPattern: rawAcc[1]))
    let z = Double(Int8(bitPattern: rawAcc[2]))
    
    let finchX = x
    let finchY = y * __cospi(40/180) - z * __sinpi(40/180)
    let finchZ = y * __sinpi(40/180) + z * __cospi(40/180)
    
    return [finchX, finchY, finchZ]
}

public func rawToRawMag(_ msb: UInt8, _ lsb: UInt8) -> Double {
    let uIntVal = (UInt16(msb) << 8) | UInt16(lsb)
    let intVal = Int16(bitPattern: uIntVal)
    return Double(intVal)
}

/**
 * Convert raw sensor values into a compass value
 */
public func rawToCompass(rawAcc: [UInt8], rawMag: [UInt8]) -> Int? {
    let acc = [Double(Int8(bitPattern: rawAcc[0])), Double(Int8(bitPattern: rawAcc[1])), Double(Int8(bitPattern: rawAcc[2]))]
    
    var mag:[Double] = []
    if rawMag.count == 3 { //values have already been converted to uT
        mag = [Double(Int8(bitPattern: rawMag[0])) * 10, Double(Int8(bitPattern: rawMag[1])) * 10, Double(Int8(bitPattern: rawMag[2])) * 10]
    } else {
        mag = [rawToRawMag(rawMag[0], rawMag[1]), rawToRawMag(rawMag[2], rawMag[3]), rawToRawMag(rawMag[4], rawMag[5])]
    }
    
    return DoubleToCompass(acc: acc, mag: mag)
}

/* Finds the value of the compass based on the accelerometer and magnetometer. */
public func DoubleToCompass(acc: [Double], mag: [Double]) -> Int? {
    //Compass value is undefined in the case of 0 z direction acceleration
    if acc[2] == 0 {
        return nil
    }
    
    let ax = acc[0]
    let ay = acc[1]
    let az = acc[2]
    
    let mx = mag[0]
    let my = mag[1]
    let mz = mag[2]
    
    let phi = atan(-ay/az)
    let theta = atan( ax / (ay*sin(phi) + az*cos(phi)) )
    
    let xP = mx
    let yP = my * cos(phi) - mz * sin(phi)
    let zP = my * sin(phi) + mz * cos(phi)
    
    let xPP = xP * cos(theta) + zP * sin(theta)
    let yPP = yP
    
    let angle = 180 + GLKMathRadiansToDegrees(Float(atan2(xPP, yPP)))
    let roundedAngle = Int(angle.rounded())
    
    return roundedAngle
}

/**
 Converts a note number to a period in microseconds (us)
 See: https://newt.phys.unsw.edu.au/jw/notes.html
  fm  =  (2^((m−69)/12))(440 Hz)
 */
public func noteToPeriod(_ note: UInt8) -> UInt16? {
    
    let frequency = 440 * pow(Double(2), Double((Double(note) - 69)/12))
    let period = (1/frequency) * 1000000
    if period > 0 && period <= Double(UInt16.max) {
        return UInt16(period)
    } else {
        return nil
    }
}

/* Converts a velocity into the form it has to have for a Bluetooth command. */
public func convertVelocity(velocity: Int8) -> UInt8 {
    var v = UInt8(abs(velocity))
    if velocity > 0 { v += 128 }
    return v
}

/**
    Gets the unicode value for a character
 */
public func getUnicode(_ char: Character) -> UInt8{
    let scalars = String(char).unicodeScalars
    var val = scalars[scalars.startIndex].value
    if val > 255 {
        NSLog("Unicode for character \(char) not supported.")
        val = 254
    }
    return UInt8(val)
}
