//
//  User.swift
//  uber-clone
//
//  Created by Abel John on 20/10/2020.
//

import CoreLocation

enum AccountType: Int {
    case passenger
    case driver
}

struct User {
    let fullname: String
    let email: String
    var accountType: AccountType!
    var location: CLLocation?
    let uid: String
    var homeLocation: CLLocationCoordinate2D?
    var address: String?
    
    var firstInitial: String { return String(fullname.prefix(1))}
    
    init(uid: String, dictionary: [String: Any]) {
        self.uid = uid
        self.fullname = dictionary["fullname"] as? String ?? ""
        self.email = dictionary["email"] as? String ?? ""
        
        if let coordinates = dictionary["houseCoordinates"] as? [Double] {
            self.homeLocation = CLLocationCoordinate2D(latitude: coordinates[0], longitude: coordinates[1])
        }
        
        if let address = dictionary["homeAddress"] as? String {
            self.address = address
        }
        
        if let index = dictionary["accountType"] as? Int {
            self.accountType = AccountType(rawValue: index)
        }
    }
}
