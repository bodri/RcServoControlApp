# RcServoControlApp

This is a Swift app which connects to an RC Servo controller board wirelessly and controls pitch and roll servos based on the iPhone motion data. The controller board creates a Wifi Access Point and listens for upcomming UDP packets which contains the servo position information as a stream of bytes with the following general format:

`Servo index | Position MSB | Position LSB`

The servo index is either 1 - pitch or 2 - roll. The servo position is calculated from the phone x, y tilt degrees and converted to microseconds between 1000 and 2000. The refresh rate is 20 milliseconds.

The app is using the new Network.framework to establish the UDP connection, so it is only running on iOS 12 and above. This is a POC app to demostrate how easy to use UDP connection in iOS 12.

The accompanying ESP8266 controller board project can be found here:

[Github repository](https://github.com/bodri/UdpRcServoController)

Please also look at the video how it works:

Needs a link
