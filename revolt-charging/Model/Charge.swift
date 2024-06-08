//
//  Trip.swift
//  uber-clone
//
//  Created by Abel John on 22/10/2020.
//

import CoreLocation

enum ChargeState: Int {
    case requested
    case accepted
    case driverArrived
    case inProgress
    case arrivedAtDestination
    case completed
    case cancelled
}

struct Charge {
    var driverCoordinates: CLLocationCoordinate2D!
    var driverUid: String!
    var state: ChargeState!
    var homeOwnerUid: String!
    
    init(dictionary: [String: Any]) {
        print("testCharge")
        print(dictionary)
        self.driverUid = dictionary["driverUid"] as? String ?? ""
        self.homeOwnerUid = dictionary["homeOwnerUid"] as? String ?? ""
        if let driverCoordinates = dictionary["driverCoordinates"] as? NSArray {
            guard let lat = driverCoordinates[0] as? CLLocationDegrees else { return }
            guard let long = driverCoordinates[1] as? CLLocationDegrees else { return }
            self.driverCoordinates = CLLocationCoordinate2D(latitude: lat, longitude: long)
        }
        
        if let state = dictionary["state"] as? Int {
            self.state = ChargeState(rawValue: state)
        }
    }
}
