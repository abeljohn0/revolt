//
//  Service.swift
//  uber-clone
//
//  Created by Abel John on 20/10/2020.
//

import Firebase
import CoreLocation
import GeoFire

// MARK: - Database Ref

let DB_REF = Database.database().reference()
let REF_USERS = DB_REF.child("users")
let REF_DRIVER_LOCATION = DB_REF.child("driver-locations")
let REF_TRIPS = DB_REF.child("trips")
let REF_CHARGE_TRIPS = DB_REF.child("charge-trips")
let REF_HOME_ADDRESS = DB_REF.child("home-locations")

// MARK: - Driver Service

struct DriverService {
    static let shared = DriverService()
    
    func observeCharge(completion: @escaping(Charge?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        REF_CHARGE_TRIPS.child(uid).observe(.value) { (snapshot) in
            guard let dictionary = snapshot.value as? [String: Any] else { return }
//            let reqUid = snapshot.key
            let charge = Charge(dictionary: dictionary)
            completion(charge)
        }
    }
    
    func observeTripCancelled(trip: Charge, completion: @escaping() -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        REF_CHARGE_TRIPS.child(uid).observeSingleEvent(of: .childRemoved) { _ in
            completion()
        }
    }
    
    func acceptTrip(trip: Charge, completion: @escaping(Error?, DatabaseReference) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let values = ["driverUid": uid,
                      "state": ChargeState.accepted.rawValue] as [String : Any]
        print("accept trip")
        REF_CHARGE_TRIPS.child(uid).updateChildValues(values, withCompletionBlock: completion)
    }
    
    func updateTripState(trip: Charge, state: ChargeState, completion: @escaping(Error?, DatabaseReference) -> Void) {
//        guard let uid = Auth.auth().currentUser?.uid else { return }
        let uid = trip.homeOwnerUid!
        REF_CHARGE_TRIPS.child(uid).child("state").setValue(state.rawValue, withCompletionBlock: completion)
        print("updated to ")
        print(state.rawValue)
        print(REF_CHARGE_TRIPS.child(uid).child(trip.driverUid))
        if state == .completed {
            REF_CHARGE_TRIPS.child(uid).removeAllObservers()
        }
    }
    
    func updateDriverLocation(location: CLLocation) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let geofire = GeoFire(firebaseRef: REF_DRIVER_LOCATION)
        geofire.setLocation(location, forKey: uid)
    }
    
    func deleteTrip(completion: @escaping(Error?, DatabaseReference) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        REF_CHARGE_TRIPS.child(uid).removeValue(completionBlock: completion)
    }
}

// MARK: - Passenger Service

struct PassengerService {
    static let shared = PassengerService()
    
    func fetchDriver(location: CLLocation, completion: @escaping(User) -> Void) {
        let geofire = GeoFire(firebaseRef: REF_DRIVER_LOCATION)
        
        REF_DRIVER_LOCATION.observe(.value) { (snapshot) in
            geofire.query(at: location, withRadius: 50).observe(.keyEntered, with: { (uid, location) in
                Service.shared.fetchUserData(uid: uid) { (user) in
                    var driver = user
                    driver.location = location
                    completion(driver)
                }
            }
        )}
    }
    
    func uploadTrip(_ pickupCoordinates: CLLocationCoordinate2D, _ homeOwnerUid: String, completion: @escaping(Error?, DatabaseReference) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let driverLocationArray = [pickupCoordinates.latitude, pickupCoordinates.longitude]
//        let destinationArray = [destinationCoordinates.latitude, destinationCoordinates.longitude]
        
        let values = ["driverCoordinates": driverLocationArray,
                      "driverUid": uid,
                      "state": ChargeState.requested.rawValue,
                      "homeOwnerUid": homeOwnerUid] as [String : Any]
        print("upload trip")
//        print(values)
        REF_CHARGE_TRIPS.child(homeOwnerUid).setValue(values, withCompletionBlock: completion)
    }
    
    func observeCurrentTrip(uid homeOwnerUid: String,completion: @escaping(Charge) -> Void) {
//        guard let uid = Auth.auth().currentUser?.uid else { return }

        REF_CHARGE_TRIPS.child(homeOwnerUid).observe(.value) { (snapshot) in
            guard let dictionary = snapshot.value as? [String: Any] else { return }
         
            let trip = Charge(dictionary: dictionary)
            completion(trip)
        }
    }
    
    func deleteTrip(_ uid: String, completion: @escaping(Error?, DatabaseReference) -> Void) {
//        guard let uid = Auth.auth().currentUser?.uid else { return }
        REF_CHARGE_TRIPS.child(uid).removeValue(completionBlock: completion)
    }
    
    func saveLocation(locationString: String, type: LocationType, completion: @escaping(Error?, DatabaseReference) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let key: String = type == .home ? "homeLocation" : "workLocation"
        REF_USERS.child(uid).child(key).setValue(locationString, withCompletionBlock: completion)
    }
}

// MARK: - SharedService

struct Service {
    
    static let shared = Service()
    
    func fetchUserData(uid: String, completion: @escaping(User) -> Void) {
        REF_USERS.child(uid).observeSingleEvent(of: .value) { (snapshot) in
            guard let dictionary = snapshot.value as? [String: Any] else { return }
            let uid = snapshot.key
            let user = User(uid: uid, dictionary: dictionary)
            completion(user)
        }
    }
}
