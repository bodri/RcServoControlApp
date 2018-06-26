//
//  ViewController.swift
//  RcServoControl
//
//  Created by Varadi, Gyorgy on 25/06/2018.
//  Copyright © 2018 Varadi, Gyorgy. All rights reserved.
//

import UIKit
import Network
import NetworkExtension
import CoreMotion

class ViewController: UIViewController {

    private let motionManager = CMMotionManager()
    private let refreshRate = 1.0 / 50.0 // 20 ms servo update rate
    private var timer: Timer?
    
    @IBOutlet private weak var joystickView: UIView! {
        didSet {
            joystickView.layer.cornerRadius = joystickView.frame.size.width / 2
            joystickView.layer.masksToBounds = true
        }
    }
    @IBOutlet private weak var horisontalContraint: NSLayoutConstraint!
    @IBOutlet private weak var verticalContraint: NSLayoutConstraint!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.connectToControllerBoard()
//        self.startCommunication()
    }

    private func connectToControllerBoard() {
        let configuration = NEHotspotConfiguration.init(ssid: "RcServoControllerBoard", passphrase: "SomethingDifficult_77", isWEP: false)
        configuration.joinOnce = true
        
        NEHotspotConfigurationManager.shared.apply(configuration) { (error) in
            if let nonNilError = error {
                if nonNilError.localizedDescription == "already associated." {
                    self.startCommunication()
                } else {
                    print("Cannot connect to RcServoControllerBoard: \(nonNilError.localizedDescription)")
                }
            } else {
                self.startCommunication()
            }
        }
    }

    private func startCommunication()  {
        let myQueue = DispatchQueue(label: "myQueue")
        let parameters = NWParameters.udp
        
        // Exclude cellular connnection
        parameters.prohibitedInterfaceTypes = [ .cellular ]
        
        // Restrict connections based on address family
        if let ipOptions = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .any
        }
        
        // Avoid proxies
        parameters.preferNoProxies = true
        
        let connection = NWConnection(host: "192.168.4.1", port: 4473, using: parameters)
        connection.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .ready:
                print("Ready to start sending servo positions...")
                self.startSendingServoPositions(connection)
            case .waiting(let error):
                // Handle connection waiting for network
                print("Waiting to connect to RcServoControllerBoard: \(error.localizedDescription)")
            case .failed(let error):
                // Handle fatal connection error
                print("Cannot connect to RcServoControllerBoard: \(error.localizedDescription)")
            default:
                break
            }
        }
        
        connection.start(queue: myQueue)
    }
    
    private func startSendingServoPositions(_ connection: NWConnection) {
        if self.motionManager.isDeviceMotionAvailable {
            self.motionManager.deviceMotionUpdateInterval = refreshRate
            self.motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            
            // Configure a timer to fetch the motion data
            let timer = Timer(fire: Date(), interval: (refreshRate), repeats: true, block: { [weak self] (timer) in
                if let data = self?.motionManager.deviceMotion {
                    // Get the attitude in degrees
                    let pitchDegree = Int(data.attitude.pitch * 180 / .pi)
                    let rollDegree = Int(data.attitude.roll * 180 / .pi)
                    
                    // Update servro positions over UDP
                    self?.sendPacket(connection, pitchDegree: pitchDegree, rollDegree: rollDegree)
                    
                    //  Move the joystick on the screen
                    if let screenWidth = self?.view.frame.width, let screenHeight = self?.view.frame.height {
                        self?.horisontalContraint.constant = CGFloat(data.attitude.roll) * screenWidth / 4
                        self?.verticalContraint.constant = CGFloat(data.attitude.pitch) * screenHeight / 4
                    }
                }
            })
            
            // Add the timer to the current run loop
            self.timer = timer
            RunLoop.main.add(timer, forMode: .defaultRunLoopMode)
        }
    }
    
    private func sendPacket(_ connection: NWConnection, pitchDegree: Int, rollDegree: Int) {
        // Convert degrees to servo positions: [1000, 2000] us
        var pitchMicroSecond = UInt16(1500 + pitchDegree * 10) // Simple math 50 degrees is 500 us
        var rollMicroSecond = UInt16(1500 + rollDegree * 10)
        
        // Normalize servo positions
        pitchMicroSecond = min(2000, max(1000, pitchMicroSecond))
        rollMicroSecond = min(2000, max(1000, rollMicroSecond))

        // Create UDP packets: [servoIndex, servoPos MSB, servoPos LSB]
        let pitchData = Data(bytes: [UInt8(1), UInt8(pitchMicroSecond >> 8 & 0xFF), UInt8(pitchMicroSecond & 0xFF)])
        let rollData = Data(bytes: [UInt8(2), UInt8(rollMicroSecond >> 8 & 0xFF), UInt8(rollMicroSecond & 0xFF)])
        
        // Send UDP packets
        connection.send(content: pitchData, completion: .idempotent)
        connection.send(content: rollData, completion: .idempotent)
    }
}

