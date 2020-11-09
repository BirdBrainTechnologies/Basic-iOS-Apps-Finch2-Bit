This is a basic Bluetooth application using the Hummingbird Bit. You can use it as a basis for writing your own apps. 

All of the classes specific to the Hummingbird are in the Hummingbird folder. For most basic apps, you will not need to change anything in this folder. 

The app opens with a screen that enables you to choose your Hummingbird and connect to it. You will need to do this in your app, so you probably want to leave this alone (though you may want to make it more beautiful). Once you are connected, the app uses a segue to move to the MainViewController. Before it does that, it calls prepare() in the DeviceChooserViewController. This sets up the Hummingbird so that it can be used in the MainViewController. It is VERY IMPORTANT that you set up the hummingbird and hummingbirdManager variables for the MainViewController before this segue. Otherwise, your Hummingbird will not work in that scene. You need to override prepare() in the same way for any other segues that are part of your program. 

The MainViewController contains the variables hummingbird: Hummingbird?, hummingbirdManager: HummingbirdManager?, and hummingbirdSensorState: Hummingbird.SensorState?. hummingbirdManager is required by the Bluetooth package. The hummingbird variable has public functions that you can use to control the lights, motors, and buzzer of the Hummingbird. Those public functions are listed below. hummingbirdSensorState is a structure that contains the sensor information for the Hummingbird. The variables inside that structure that contain the Hummingbird data are described below. 


Public Hummingbird Functions:

NOTE: If you issue Bluetooth commands too close together, the last command may overwrite earlier ones. 

Method Signature: setLED(port: Int, intensity: Int) 

Description: Sets an LED to a given intensity value. The method requires the port number of the LED (1-3) and an intensity value from 0-100. An intensity value of 0 turns the LED off.

Example: hummingbird.setLED(port: 1, intensity: 100)

Method Signature: setTriLED(port: Int, red: Int, green: Int, blue: Int)

Description: Sets a tri-color LED to a given color by setting the intensities of the red, green, and blue elements inside it . The method requires the port number of the tri-color LED (1-2) and three intensity values from 0-100. Setting all three intensity values to 0 turns the LED off.

Example: hummingbird.setTriLED(port: 1, red: 75, green: 0, blue: 75)

Method Signature: setPositionServo(port: Int, angle: Int)

Description: Sets a position servo to a given angle. The method requires the port number of the servo (1-4) and an angle from 0°-180°.

Example: hummingbird.setPositionServo(port: 1, angle: 90)

Method Signature: setRotationServo(port: Int, speed: Int)

Description: Sets a rotation servo to spin at a given speed. The method requires the port number of the servo (1-4) and a speed between -100 and 100. A speed of 0 turns the motor off.

Example: hummingbird.setRotationServo(port: 1, speed: 100)

Method Signature: playNote(note: Int, beats: Double)

Description: Plays a note using the buzzer on the Hummingbird. The method requires an integer representing the note (32-135) and a number giving the number of beats (0-16). The number of beats can be a decimal number.

Example: hummingbird.playNote(note: 60 beats: 0.5)

Method Signature: setDisplay(pattern: Array<Int>)

Description: Sets the LED array of the micro:bit to display a pattern defined by an array of length 25. Each value in the list must be 0 (off) or 1 (on). The first five values in the array correspond to the five LEDs in the first row, the next five values to the second row, etc.

Example: hummingbird.setDisplay(pattern: [1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1])

Method Signature: printString(_ stringToPrint: String)

Description: Print a string on the micro:bit LED array. The string must have 15 or fewer characters and should contain only digits and English letters (upper or lower case).

Example: hummingbird.printString("hello")

Method Signature: stopAll()

Description: Stops all outputs. This includes the LED display for the micro:bit and all lights and motors for the Hummingbird.

Example: hummingbird.stopAll()

Method Signature: calibrateCompass()

Description: This function send a Bluetooth command to calibrate the compass. When the Hummingbird receives this command, it will place dots on the micro:bit screen as it waits for you to tilt the Hummingbird in different directions. If the calibration is successful, you will then see a check on the micro:bit screen. Otherwise, you will see an X.

Example: hummingbird.calibrateCompass()

Variables that you can access within hummingbirdSensorState:

timestamp: Date - time of the sensor reading

batteryVoltage: Float - voltage of Hummingbird battery 

isStale: Bool - is the data old?

sensor1: value of the Hummingbird sensor in port 1. Each of the Hummingbird sensor ports supports different types of sensors, and we don't know what the user is plugging into each one. This value has a data type HummingbirdSensor that computes all of the possibilities for each port. Use sensor1.distance (distance in cm - Int) if you are using a distance sensor in port 1, sensor1.dial (Int 0-100) if you are using the dial, sensor1.light (Int 0-100) if you are using the light sensor, and sensor1.voltage if you want the voltage at the port (Double, volts from 0-3.3) 

sensor2: value of the Hummingbird sensor in port 2. Uses the HummingbirdSensor type.

sensor3: value of the Hummingbird sensor in port 3. Uses the HummingbirdSensor type.

acceleration: Array<Double> - acceleration in x, y, z directions in m/s^2

magnetometer: Array<Double> - magnetometer readings in x, y, and z directions in microTesla

compass: Int? - degrees of micro:bit from North; undefined in the case of 0 z direction acceleration

buttonA: Bool - true when button A is pressed

buttonB: Bool - true when button B is pressed

shake: Bool - true when Hummingbird is being shaken

