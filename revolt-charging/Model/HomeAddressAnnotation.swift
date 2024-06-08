//
//  HomeAddressAnnotation.swift
//  uber-clone
//
//  Created by Abel John on 5/19/24.
//
import MapKit

class HomeAddressAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var uid: String
    var address: String
    
    init(uid: String, coordinate: CLLocationCoordinate2D, address: String) {
        self.uid = uid
        self.coordinate = coordinate
        self.address = address
    }
    
//    func updateAnnotationPosition(withCoordinate coordinate: CLLocationCoordinate2D) {
//        UIView.animate(withDuration: 0.2) {
//            self.coordinate = coordinate
//        }
//    }
}
