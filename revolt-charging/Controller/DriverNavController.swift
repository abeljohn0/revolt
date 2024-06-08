//
//  DriverNavController.swift
//  uber-clone
//
//  Created by Abel John on 6/2/24.
//

import UIKit
import MapKit

class DriverNavController: UIViewController {
    
    // MARK: - Properties
    
    private let mapView = MKMapView()
    let trip: Charge
    var homeowner: User? {
        didSet {
            configureMapView()
//            updateETA()
        }
    }
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "baseline_clear_white_36pt_2x").withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(handleDismissal), for: .touchUpInside)
        return button
    }()
    
    private let warningLabel: UILabel = {
        let label = UILabel()
        label.text = "Please note that the homeowner has a 2-minute window (starting now) to cancel the booking if they so choose."
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Charger Reserved!"
        label.font = UIFont.boldSystemFont(ofSize: 40)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let acceptTripButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(handleDirections), for: .touchUpInside)
        button.backgroundColor = .white
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.setTitleColor(.black, for: .normal)
        button.setTitle("GET DIRECTIONS VIA APPLE MAPS", for: .normal)
        button.configuration = .borderedTinted()
        return button
    }()
    
    // MARK: - Lifecycle
    
    init(trip: Charge) {
        self.trip = trip
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        fetchUserData(trip.homeOwnerUid)
    }
    
    // MARK: - Selectors
    
    func openAppleMapsWithCoordinates(latitude: Double, longitude: Double, label: String = "Location") {
        let encodedLabel = label.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(encodedLabel)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @objc func handleDirections() {
        let coords = (homeowner?.homeLocation)!
        let address = (homeowner?.address)!
        openAppleMapsWithCoordinates(latitude: coords.latitude, longitude: coords.longitude, label: address)
        let url = URL(string: "http://maps.apple.com/?ll=\(coords.latitude),\(coords.longitude)")
            if let mapUrl = url {
                UIApplication.shared.open(mapUrl)
            }
    }
    
    @objc func handleDismissal() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - API
    
    // MARK: - Helpers
    
    func configureMapView() {
        let region = MKCoordinateRegion(center: (self.homeowner?.homeLocation)!, latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapView.setRegion(region, animated: false)
        
        mapView.addAnnotationAndSelect(forCoordinate: (self.homeowner?.homeLocation)!)

    }
    
    func configureUI() {
        navigationController?.navigationBar.barStyle = .black
        view.backgroundColor = UIColor(red: 0x2e/255.0, green: 0x47/255.0, blue: 0x5c/255.0, alpha: 1)
        
        view.addSubview(cancelButton)
        cancelButton.anchor(top: view.safeAreaLayoutGuide.topAnchor,
                            left: view.leftAnchor,
                            paddingLeft: 16)
        view.addSubview(titleLabel)
        titleLabel.anchor(top:view.topAnchor, left: view.leftAnchor, right: view.rightAnchor, paddingTop: 20)
        view.addSubview(mapView)
        mapView.setDimensions(height: 270, width: 270)
        mapView.layer.cornerRadius = 270 / 2
        mapView.centerX(inView: view)
        mapView.centerY(inView: view, constant: -175)
        
        view.addSubview(warningLabel)
        warningLabel.centerX(inView: view)
        warningLabel.anchor(top: mapView.bottomAnchor, left: view.leftAnchor, right: view.rightAnchor,
                            paddingTop: 16,
                            paddingLeft: 12,
                            paddingRight: 12,
                            height: 100)
        
        view.addSubview(acceptTripButton)
        acceptTripButton.anchor(top: warningLabel.bottomAnchor,
                                left: view.leftAnchor
                                , right: view.rightAnchor,
                                paddingTop: 8,
                                paddingLeft: 32,
                                paddingRight: 32,
                                height: 50)
    }
    
    private func fetchUserData(_ uid: String) {
            Service.shared.fetchUserData(uid: uid, completion: { user in
                self.homeowner = user
            })
    }
}
