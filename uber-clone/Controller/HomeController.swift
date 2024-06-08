//
//  HomeController.swift
//  uber-clone
//
//  Created by Abel John on 19/10/2020.
//

import UIKit
import Firebase
import MapKit

private let reuseIdentifier = "LocationCell"
private let annotationIdentifier = "DriverAnnotation"

private enum ActionButtonConfiguration {
    case showMenu
    case dismissActionView
    
    init() {
        self = .showMenu
    }
}

private enum AnnotationType: String {
    case pickup
    case destination
}

protocol HomeControllerDelegate: class {
    func handleMenuToggle()
}

class HomeController: UIViewController {
    
    // MARK: - Properties
    
    private let mapView = MKMapView()
    private let locationManager = LocationHandler.shared.locationManager
    private let rideActionView = RideActionView()
    private let inputActivationView = LocationInputActivationView()
    private let locationInputView = LocationInputView()
    private let bannerView = UIView()
    private let tableView = UITableView()
    private var searchResults = [MKPlacemark]()
    private var savedLocations = [MKPlacemark]()
    private final let locationInputViewHeight: CGFloat = 200
    private final let rideActionViewHeight: CGFloat = 300
    private var actionButtonConfig = ActionButtonConfiguration()
    private var route: MKRoute?
    private var usernameLabel = UILabel()
    private var addressLabel = UILabel()
    private var chargerLabel = UILabel()
    private var currentSelectedAnnotation: HomeAddressAnnotation?
    private var houselocations: [String: [String: Any]]?
    private var availability: [[String]] = [["9","00","A.M."],["5","00", "P.M."]]
    private let uid = Auth.auth().currentUser?.uid
    public var newUser: Bool = false
    weak var delegate: HomeControllerDelegate?
    var slidingPanelView: UIView!
    
    var user: User? {
        didSet {
            locationInputView.user = user
            if user?.accountType == .passenger {
//                fetchDrivers()
//                configureLocationInputActivationView()
//                configureSavedUserLocations()
            } else {
                observeTrips()
            }
            fetchHomeAddresses()
            if newUser {
                let controller = NormsController(user!)
                controller.modalPresentationStyle = .popover
                self.present(controller, animated: true, completion: nil)
            }
        }
    }
    
    private var trip: Charge? {
        didSet {
            guard let user = user else { return }
            guard let trip = trip else { return }
            print("surely OK")
            print(trip)
            if user.accountType == .driver &&  trip.state == .requested {
                configureDriverMapView()
                let controller = ConfirmationController(trip: trip)
                controller.modalPresentationStyle = .popover
                controller.delegate = self
                self.present(controller, animated: true, completion: nil)
            } else if user.accountType == .passenger &&  trip.state == .requested {
//                print(trip)
                let controller = DriverNavController(trip: trip)
                controller.modalPresentationStyle = .popover
                self.present(controller, animated: true, completion: nil)
            }
        }
    }
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "baseline_menu_black_36dp").withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(handleButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "baseline_clear_white_36pt_2x").withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(handleDismissal), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        enableLocationServices()
        configureUI()
        setupSlidingPanel()
    }
    
    // MARK: - Selectors
    
    @objc func handleButtonPressed() {
        switch actionButtonConfig {
        case .showMenu:
            delegate?.handleMenuToggle()
        case .dismissActionView:
            removeAnnotationAndOverlays()
            mapView.showAnnotations(mapView.annotations, animated: true)

            UIView.animate(withDuration: 0.3) {
                self.inputActivationView.alpha = 1
                self.configureActionButton(config: .showMenu)
                self.animateRideActionView(shouldShow: false)
            }
        }
    }
    
    @objc func handleDismissal() {
        mapView.deselectAnnotation(currentSelectedAnnotation, animated: true)
        currentSelectedAnnotation = nil
    }
    
    // MARK: - Passenger API
    
    func observeCurrentTrip(_ uid: String) {
        PassengerService.shared.observeCurrentTrip(uid: uid) { (trip) in
            print("TRIGGERED")
            print(trip)
            self.trip = trip
            guard let state = trip.state else { return }
            guard let driverUid = trip.driverUid else { return }
            
            switch state {
            case .requested:
                break
            case .accepted:
                self.shouldPresentLoadingView(false)
                self.removeAnnotationAndOverlays()
                self.zoomForActiveTrip(withDriverUid: driverUid)
                
//                Service.shared.fetchUserData(uid: driverUid) { (driver) in
//                    self.animateRideActionView(shouldShow: true, config: .tripAccepted, user: driver)
//                }
            case .driverArrived:
                self.rideActionView.config = .driverArrived
            case .inProgress:
                self.rideActionView.config = .tripInProgress
            case .arrivedAtDestination:
                self.rideActionView.config = .endTrip
            case .completed:
                PassengerService.shared.deleteTrip(self.trip!.homeOwnerUid) { (error, ref) in
                    self.animateRideActionView(shouldShow: false)
                    self.centerMapOnUserLocation()
                    self.actionButtonConfig = .showMenu
                    self.configureActionButton(config: .showMenu)
                    self.inputActivationView.alpha = 1
                    self.presentAlertController(withTitle: "Trip Completed", message: "We hope you enjoyed your trip")
                }
            case .cancelled:
                print("CANCELLED")
                self.dismiss(animated: true, completion: nil)
                let alert = UIAlertController(title: "HOMEOWNER HAS CANCELLED SESSION", message: "We apologize for the inconveniece, but it looks as though the homeowner has cancelled their charge within the allowed 2-minute window. Please find another charger.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
                self.cancelTrip()
            }
        }
    }
    
    func startTrip() {
        guard let trip = self.trip else { return }
        DriverService.shared.updateTripState(trip: trip, state: .inProgress) { (err, ref) in
            self.rideActionView.config = .tripInProgress
            self.removeAnnotationAndOverlays()
//            self.mapView.addAnnotationAndSelect(forCoordinate: trip.destinationCoordinates)
            
            let placemark = MKPlacemark(coordinate: trip.driverCoordinates)
            let mapItem = MKMapItem(placemark: placemark)
        
            self.setCustomRegion(withType: .destination, coordinates: trip.driverCoordinates)
            self.generatePolyline(toDestination: mapItem)
            
            self.mapView.zoomToFit(annotations: self.mapView.annotations)
        }
    }
    
    func fetchDrivers() {
        guard let location = locationManager?.location else { return }
        PassengerService.shared.fetchDriver(location: location) { (driver) in
            guard let coordinate = driver.location?.coordinate else { return }
            let annotation = DriverAnnotation(uid: driver.uid, coordinate: coordinate)
            
            var driverIsVisible: Bool {
                return self.mapView.annotations.contains { (annotation) -> Bool in
                    guard let driverAnno = annotation as? DriverAnnotation else { return false }
                    if driverAnno.uid == driver.uid {
                        driverAnno.updateAnnotationPosition(withCoordinate: coordinate)
                        self.zoomForActiveTrip(withDriverUid: driver.uid)
                        return true
                    }
                    return false
                }
            }
            
            if !driverIsVisible {
                self.mapView.addAnnotation(annotation)
            }
        }
    }
    
    func getAnnotation(_ uid: String, _ addressAndCoords: [String: Any]) -> HomeAddressAnnotation {
        let coordinates = addressAndCoords["houseCoordinates"] as! [Double]
        let annotation = HomeAddressAnnotation(uid: uid, coordinate: CLLocationCoordinate2D(latitude: coordinates[0], longitude: coordinates[1]), address: addressAndCoords["address"] as! String)
        return annotation
    }
    
    func fetchHomeAddresses() {
//        print("hi")
        REF_HOME_ADDRESS.observe(.value) { (snapshot) in
            guard let locations = snapshot.value as? [String: [String: Any]] else { return }
            self.houselocations = locations
            for (uid, addressAndCoords) in locations {
                let annotation = self.getAnnotation(uid, addressAndCoords)
                self.mapView.addAnnotation(annotation)
            }
        }
    }

    func geocodeAddressString(_ addressString: String, completion: @escaping(CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(addressString) { placemarks, error in
            if let error = error {
                print("DEBUG: Failed to geocode address \(addressString) with error \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                completion(nil)
                return
            }
            
            completion(location.coordinate)
        }
    }
    
    // MARK: - Drivers API
    
    func observeTrips() {
        DriverService.shared.observeCharge { (trip) in
            self.trip = trip
        }
    }
    
    func observeCancelledTrip(trip: Charge) {
        DriverService.shared.observeTripCancelled(trip: trip) {
            self.removeAnnotationAndOverlays()
            self.animateRideActionView(shouldShow: false)
            self.centerMapOnUserLocation()
            self.presentAlertController(withTitle: "Oops!", message: "The passenger has cancelled this ride. Press OK to continue.")
        }
    }
    
    // MARK: - Helpers
    
    fileprivate func configureActionButton(config: ActionButtonConfiguration) {
        switch config {
        case .showMenu:
            self.actionButton.setImage(#imageLiteral(resourceName: "baseline_menu_black_36dp").withRenderingMode(.alwaysOriginal), for: .normal)
            self.actionButtonConfig = .showMenu
        case .dismissActionView:
            actionButton.setImage(#imageLiteral(resourceName: "baseline_arrow_back_black_36dp").withRenderingMode(.alwaysOriginal), for: .normal)
            actionButtonConfig = .dismissActionView
        }
    }
    
//    func configureSavedUserLocations() {
//        guard let user = user else { return }
//        savedLocations.removeAll()
//        
//        if let homeLocation = user.homeLocation {
//            geocodeAddressString(address: homeLocation)
//        }
//        
//        if let workLocation = user.workLocation {
//            geocodeAddressString(address: workLocation)
//        }
//    }
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        let resizedImage = renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        return resizedImage
    }
    
    func setupSlidingPanel() {
        slidingPanelView = UIView()
        slidingPanelView.backgroundColor = UIColor(red: 0xb6/255.0, green: 0xce/255.0, blue: 0xe3/255.0, alpha: 1)
        slidingPanelView.layer.cornerRadius = 16
        slidingPanelView.layer.shadowOpacity = 0.3
        slidingPanelView.layer.shadowOffset = CGSize(width: 0, height: -2)
        
        view.addSubview(slidingPanelView)
        
        slidingPanelView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            slidingPanelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            slidingPanelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            slidingPanelView.heightAnchor.constraint(equalToConstant: 600),
            slidingPanelView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 600)
        ])
        
        slidingPanelView.addSubview(cancelButton)
        cancelButton.anchor(top: slidingPanelView.topAnchor,
                            left: slidingPanelView.leftAnchor,
                            paddingTop: 10, paddingLeft: 10)
        
        self.usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        self.usernameLabel.textAlignment = .center
        self.usernameLabel.font = UIFont.boldSystemFont(ofSize: 30)
        self.usernameLabel.textColor = .black
        self.usernameLabel.numberOfLines = 0
        
        slidingPanelView.addSubview(self.usernameLabel)
        self.usernameLabel.anchor(top: slidingPanelView.topAnchor, left: slidingPanelView.leftAnchor, right: slidingPanelView.rightAnchor, paddingTop: 16, paddingLeft: 32, paddingRight: 32)
//        NSLayoutConstraint.activate([
//                usernameLabel.centerXAnchor.constraint(equalTo: slidingPanelView.centerXAnchor),
////                usernameLabel.centerYAnchor.constraint(equalTo: slidingPanelView.centerYAnchor),
//                usernameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: slidingPanelView.leadingAnchor, constant: 50), // Optional: to ensure the label does not hug the edges
//                usernameLabel.trailingAnchor.constraint(lessThanOrEqualTo: slidingPanelView.trailingAnchor, constant: -50) // Optional: to ensure the label does not hug the edges
//            ])
        
        self.addressLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addressLabel.textAlignment = .left
        self.addressLabel.font = UIFont.systemFont(ofSize: 18)
        self.addressLabel.adjustsFontSizeToFitWidth = true
        self.addressLabel.minimumScaleFactor = 0.5
        self.addressLabel.numberOfLines = 0
        self.addressLabel.textColor = .black
//        slidingPanelView.addSubview(self.addressLabel)
        
        let homeIconView = UIImageView()
        homeIconView.translatesAutoresizingMaskIntoConstraints = false
        homeIconView.image = UIImage(named: "home_icon")
        homeIconView.contentMode = .scaleAspectFit
        homeIconView.clipsToBounds = true
        var newSize = CGSize(width: 50, height: 50)
        homeIconView.image = resizeImage(image: homeIconView.image!, targetSize: newSize)
        homeIconView.layer.cornerRadius = 27
        
        let stackView = UIStackView(arrangedSubviews: [homeIconView, self.addressLabel])
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.alignment = .fill
        stackView.spacing = 4

        slidingPanelView.addSubview(stackView)
        
        stackView.anchor(top: usernameLabel.bottomAnchor, left: slidingPanelView.leftAnchor, right: slidingPanelView.rightAnchor, paddingTop: 16, paddingLeft: 10, paddingRight: 10)
        
        let plugIconView = UIImageView()
        plugIconView.translatesAutoresizingMaskIntoConstraints = false
        plugIconView.image = UIImage(named: "charger_plug_icon_white")
        plugIconView.contentMode = .scaleAspectFit
        plugIconView.clipsToBounds = true
        newSize = CGSize(width: 55, height: 55)
        plugIconView.image = resizeImage(image: plugIconView.image!, targetSize: newSize)
        plugIconView.layer.cornerRadius = 18
        
        chargerLabel.translatesAutoresizingMaskIntoConstraints = false
        chargerLabel.textAlignment = .left
        chargerLabel.font = UIFont.systemFont(ofSize: 18)
        chargerLabel.adjustsFontSizeToFitWidth = true
        chargerLabel.minimumScaleFactor = 0.5
        chargerLabel.numberOfLines = 0
        chargerLabel.textColor = .black
        chargerLabel.text = "L2 (Tesla NACS and J1722 Connectors)"
        
        let stackView2 = UIStackView(arrangedSubviews: [plugIconView, chargerLabel])
        stackView2.axis = .horizontal
        stackView2.distribution = .fillProportionally
        stackView2.alignment = .fill
        stackView2.spacing = 4
        
        slidingPanelView.addSubview(stackView2)
        
        stackView2.anchor(top: stackView.bottomAnchor, left: slidingPanelView.leftAnchor, right: slidingPanelView.rightAnchor, paddingTop: 4, paddingLeft: 10, paddingRight: 10)
        
        let clockIconView = UIImageView()
        clockIconView.translatesAutoresizingMaskIntoConstraints = false
        clockIconView.image = UIImage(named: "clock_icon")
        clockIconView.contentMode = .scaleAspectFit
        clockIconView.clipsToBounds = true
        newSize = CGSize(width: 50, height: 50)
        clockIconView.image = resizeImage(image: clockIconView.image!, targetSize: newSize)
        clockIconView.layer.cornerRadius = 32
        
        let clockLabel = UILabel()
        clockLabel.translatesAutoresizingMaskIntoConstraints = false
        clockLabel.textAlignment = .left
        clockLabel.font = UIFont.systemFont(ofSize: 18)
        clockLabel.adjustsFontSizeToFitWidth = true
        clockLabel.minimumScaleFactor = 0.5
        clockLabel.numberOfLines = 0
        clockLabel.textColor = .black
        clockLabel.text = "Available daily from \(availability[0][0]):\(availability[0][1]) \(availability[0][2]) to \(availability[1][0]):\(availability[1][1]) \(availability[1][2])"
        
        let stackView3 = UIStackView(arrangedSubviews: [clockIconView, clockLabel])
        stackView3.axis = .horizontal
        stackView3.distribution = .fillProportionally
        stackView3.alignment = .fill
        stackView3.spacing = 4
        
        slidingPanelView.addSubview(stackView3)
        
        stackView3.anchor(top: stackView2.bottomAnchor, left: slidingPanelView.leftAnchor, right: slidingPanelView.rightAnchor, paddingTop: 4, paddingLeft: 10, paddingRight: 10)
        
        let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.image = UIImage(named: "charger_graphic")
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 15
            imageView.layer.borderWidth = 4
        imageView.layer.borderColor = UIColor(red: 0x2e/255.0, green: 0x47/255.0, blue: 0x5c/255.0, alpha: 1).cgColor
            
        slidingPanelView.addSubview(imageView)
        
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: slidingPanelView.centerXAnchor),
                imageView.topAnchor.constraint(equalTo: stackView3.bottomAnchor, constant: 20), // Adjust this as needed
                imageView.widthAnchor.constraint(equalToConstant: 300), // Specify your desired width
                imageView.heightAnchor.constraint(equalToConstant: 200) // Specify your desired height
            ])
        
        let chargeButton = UIButton()
        chargeButton.translatesAutoresizingMaskIntoConstraints = false
        chargeButton.setTitle("Book Charge Now", for: .normal)
        chargeButton.backgroundColor = UIColor(red: 0x2e/255.0, green: 0x47/255.0, blue: 0x5c/255.0, alpha: 1)
        chargeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        chargeButton.setTitleColor(.orange, for: .normal)
        chargeButton.layer.cornerRadius = 25 // Adjust this value as needed
        chargeButton.clipsToBounds = true
        chargeButton.addTarget(self, action: #selector(chargeButtonPressed), for: .touchUpInside)
            // Add the button to the slidingPanelView
            slidingPanelView.addSubview(chargeButton)

            // Setup constraints for the button
            NSLayoutConstraint.activate([
                chargeButton.leadingAnchor.constraint(equalTo: slidingPanelView.leadingAnchor, constant: 20),
                chargeButton.trailingAnchor.constraint(equalTo: slidingPanelView.trailingAnchor, constant: -20),
                chargeButton.bottomAnchor.constraint(equalTo: slidingPanelView.bottomAnchor, constant: -20),
                chargeButton.heightAnchor.constraint(equalToConstant: 50) // Set the height of the button
            ])
    }
    
    @objc func chargeButtonPressed() {
        guard let uid = currentSelectedAnnotation?.uid else { return }
        guard let pickupCoordinates = locationManager?.location?.coordinate else { return }
//        guard let destinationCoordinates = view.destination?.coordinate else { return }
        
//        shouldPresentLoadingView(true, message: "Finding you a ride")
        observeCurrentTrip(uid)
        PassengerService.shared.uploadTrip(pickupCoordinates, uid) { (err, ref) in
            if let error = err {
                print("DEBUG: Failed to upload trip with error \(error.localizedDescription)")
                return
            }
        }
        handleDismissal()
    }
    
    
    
    func geocodeAddressString(address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { (placemarks, error) in
            guard let clPlacemark = placemarks?.first else { return }
            let placemark = MKPlacemark(placemark: clPlacemark)
            self.savedLocations.append(placemark)
            self.tableView.reloadData()
        }
    }
    
    func configureUI() {
        configureNavigationBar()
        configureMapView()
        configureRideActionView()
        configureBannerView()
        view.addSubview(actionButton)
        actionButton.anchor(top: view.safeAreaLayoutGuide.topAnchor,
                            left: view.leftAnchor,
                            paddingTop: 16,
                            paddingLeft: 20,
                            width: 30,
                            height: 30)
        configureTableView()
        presentRules()
    }
    
    func presentRules() {
        if user?.accountType == .driver {
            
        }
    }
    
    func configureBannerView() {
        bannerView.backgroundColor = UIColor(red: 0x2e/255.0, green: 0x47/255.0, blue: 0x5c/255.0, alpha: 1)
        view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        let logoImageView = UIImageView()
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.image = UIImage(named: "logo")
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.addSubview(logoImageView)
        NSLayoutConstraint.activate([
                bannerView.topAnchor.constraint(equalTo: view.topAnchor),
                bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bannerView.heightAnchor.constraint(equalToConstant: 120) // Adjust the height as needed
            ])
        NSLayoutConstraint.activate([
                logoImageView.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
                logoImageView.centerYAnchor.constraint(equalTo: bannerView.centerYAnchor, constant: 25),
                logoImageView.widthAnchor.constraint(equalTo: bannerView.widthAnchor, multiplier: 0.4), // Width is 1/4 of the banner's width
                logoImageView.heightAnchor.constraint(equalTo: logoImageView.widthAnchor) // Height equals the width to maintain aspect ratio (assumes the logo is square)
            ])
    }

    func configureLocationInputActivationView() {
        view.addSubview(inputActivationView)
        inputActivationView.centerX(inView: view)
        inputActivationView.setDimensions(height: 50, width: view.frame.width - 64)
        inputActivationView.anchor(top: actionButton.bottomAnchor, paddingTop: 32)
        inputActivationView.alpha = 0
        inputActivationView.delegate = self
        
        UIView.animate(withDuration: 2) {
            self.inputActivationView.alpha = 1
        }
    }
    
    func configureNavigationBar() {
        navigationController?.navigationBar.isHidden = true
    }
    
    func configureMapView() {
        view.addSubview(mapView)
        mapView.frame = view.frame
        
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.delegate = self
    }
    
    func configureDriverMapView() {
        let driverAnno = mapView.addAnnotationAndSelect(forCoordinate: (trip?.driverCoordinates)!)
        let placemark = MKPlacemark(coordinate: (trip?.driverCoordinates)!)
        let mapItem = MKMapItem(placemark: placemark)
        generatePolyline(toDestination: mapItem)
        let annotation = MKPointAnnotation()
        annotation.coordinate = (user?.homeLocation)!
        mapView.zoomToFit(annotations: [driverAnno, annotation])
    }
    
    func configureLocationInputView() {
        locationInputView.delegate = self
        view.addSubview(locationInputView)
        locationInputView.anchor(top: view.topAnchor,
                                 left: view.leftAnchor,
                                 right: view.rightAnchor,
                                 height: locationInputViewHeight)
        locationInputView.alpha = 0
        
        UIView.animate(withDuration: 0.5) {
            self.locationInputView.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.tableView.frame.origin.y = self.locationInputViewHeight
            }
        }
    }
    
    func configureRideActionView() {
        view.addSubview(rideActionView)
        rideActionView.delegate = self
        rideActionView.frame = CGRect(x: 0,
                                      y: view.frame.height,
                                      width: view.frame.width,
                                      height: rideActionViewHeight)
    }
    
    func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(LocationCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.rowHeight = 60
        tableView.tableFooterView = UIView()
        
        let height = view.frame.height - locationInputViewHeight
        tableView.frame = CGRect(x: 0, y: view.frame.height, width: view.frame.width, height: height)
        
        view.addSubview(tableView)
    }
    
    func dismissLocationView(completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.locationInputView.alpha = 0
            self.tableView.frame.origin.y = self.view.frame.height
            self.locationInputView.removeFromSuperview()
        }, completion: completion)
    }
    
    func animateRideActionView(shouldShow: Bool, destination: MKPlacemark? = nil, config: RideActionViewConfiguration? = nil, user: User? = nil) {
        let yOrigin = shouldShow ? self.view.frame.height - self.rideActionViewHeight : self.view.frame.height
        
        UIView.animate(withDuration: 0.3) {
            self.rideActionView.frame.origin.y = yOrigin
        }
        
        if shouldShow {
            guard let config = config else { return }
            
            if let destination = destination {
                rideActionView.destination = destination
            }
            if let user = user {
                rideActionView.user = user
            }
            
            rideActionView.config = config
        }
    }
}

// MARK: - MapView Helpers

private extension HomeController {
    func searchBy(naturalLanguageQuery: String, completion: @escaping([MKPlacemark]) -> Void) {
        var results = [MKPlacemark]()
        
        let request = MKLocalSearch.Request()
        request.region = mapView.region
        request.naturalLanguageQuery = naturalLanguageQuery
        
        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            guard let response = response else { return }
            
            response.mapItems.forEach { (item) in
                results.append(item.placemark)
            }
            completion(results)
        }
    }
    
    func generatePolyline(toDestination destination: MKMapItem) {
        let request = MKDirections.Request()
        request.transportType = .automobile
        if user?.accountType == .driver {
//            var annotation: HomeAddressAnnotation
            guard let uid = Auth.auth().currentUser?.uid else { return }
            guard let locations = self.houselocations else { return }
            guard let homelocation = locations[uid] else { return }
            let annotation = self.getAnnotation(uid, homelocation)
            let placemark = MKPlacemark(coordinate: annotation.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            request.source = mapItem
            request.destination = destination
//            let directionRequest = MKDirections(request: request)
        }
        if user?.accountType == .passenger {
            request.source = MKMapItem.forCurrentLocation()
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: currentSelectedAnnotation!.coordinate))
        }
        let directionRequest = MKDirections(request: request)
        directionRequest.calculate { (response, error) in
            if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }
            guard let response = response else { return }
            self.route = response.routes[0]
            guard let polyline = self.route?.polyline else { return }
            print(polyline)
            self.mapView.addOverlay(polyline)
        }
    }
    
    func removeAnnotationAndOverlays() {
        mapView.annotations.forEach { (annotation) in
            if let anno = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(anno)
            }
        }
        
        if mapView.overlays.count > 0 {
            mapView.removeOverlay(mapView.overlays[0])
        }
    }
    
    func centerMapOnUserLocation() {
        guard let coordinate = locationManager?.location?.coordinate else { return }
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
        mapView.setRegion(region, animated: true)
    }
    
    func setCustomRegion(withType type: AnnotationType, coordinates: CLLocationCoordinate2D) {
        let region = CLCircularRegion(center: coordinates, radius: 25, identifier: type.rawValue)
        locationManager?.startMonitoring(for: region)
    }
}

// MARK: - MKMapViewDelegate

extension HomeController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let user = user else { return }
        guard user.accountType == .driver else { return }
        guard let location = userLocation.location else { return }
        DriverService.shared.updateDriverLocation(location: location)
    }
    
//    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
//        if let annotation = annotation as? DriverAnnotation {
//            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
//            view.image = #imageLiteral(resourceName: "chevron-sign-to-right")
//            return view
//        }
//        return nil
//    }
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? HomeAddressAnnotation {
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
//            view.image = #imageLiteral(resourceName: "pin")
            let pinImage = UIImage(named: "pin")
                    let size = CGSize(width: 30, height: 45)
                    UIGraphicsBeginImageContext(size)
                    pinImage?.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()

            view.image = resizedImage
            return view
        }
//        print("Hello there")
        if let annotation = annotation as? MKPointAnnotation {
//            print("yes it is!")
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
            view.canShowCallout = true

            view.image = UIImage(named: "chevron-sign-to-right")
            
            return view
        }

        return nil  // Return nil for default annotations
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let route = self.route {
            let polyline = route.polyline
            let lineRenderer = MKPolylineRenderer(overlay: polyline)
            lineRenderer.strokeColor = .mainBlueTint
            lineRenderer.lineWidth = 4
            return lineRenderer
        }
        return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? HomeAddressAnnotation else {return}
        currentSelectedAnnotation = annotation
        REF_USERS.child(annotation.uid).observeSingleEvent(of: .value, with: { snapshot in
            let value = snapshot.value as? NSDictionary
            let username = value?["fullname"] as? String ?? "meme"
            let user_title = "Charge with " + username
            self.usernameLabel.text = user_title
            let address = value?["homeAddress"] as? String ?? "addy unaivalable"
            self.addressLabel.text = address
            self.chargerLabel.text = value?["charger"] as? String ?? "cargar"
            guard let timings = value?["availability"] as? [[Int]] else {return}
            if (timings[0][0] >= 12) {
                self.availability[0][2] = "P.M."
                if (timings[0][0] > 12) {
                    self.availability[0][0] = "\(timings[0][0] - 12)"
                }
            } else {
                self.availability[0][0] = "\(timings[0][0])"
            }
            if (timings[0][1] == 0) {
                self.availability[0][1] = "00"
            }
            if (timings[1][0] < 12) {
                self.availability[1][2] = "A.M."
                self.availability[1][0] = "\(timings[1][0])"
            } else {
                if (timings[1][0] > 12) {
                    self.availability[1][0] = "\(timings[1][0] - 12)"
                }
            }
            if (timings[1][1] == 0) {
                self.availability[1][1] = "00"
            }
                
        }) { error in
          print(error.localizedDescription)
        }
        UIView.animate(withDuration: 0.3) {
            self.slidingPanelView.transform = CGAffineTransform(translationX: 0, y: -600)
        }
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        guard let annotation = view.annotation else {return}
        UIView.animate(withDuration: 0.3) {
            self.slidingPanelView.transform = .identity
        }
    }
    
    func zoomForActiveTrip(withDriverUid uid: String) {
        var annotations = [MKAnnotation]()
        
        self.mapView.annotations.forEach { (annotation) in
            if let anno = annotation as? DriverAnnotation {
                if anno.uid == uid {
                    annotations.append(anno)
                }
            }
            
            if let userAnno = annotation as? MKUserLocation {
                annotations.append(userAnno)
            }
        }
        
    }
}

// MARK: - CLLocationManagerDelegate

extension HomeController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        if region.identifier == AnnotationType.pickup.rawValue {
            print("DEBUG: Did start monitoring pcik up region \(region)")
        }
        
        if region.identifier == AnnotationType.destination.rawValue {
            print("DEBUG: Did start monitoring destination region \(region)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let trip = self.trip else { return }
        
        if region.identifier == AnnotationType.pickup.rawValue {
            DriverService.shared.updateTripState(trip: trip, state: .driverArrived) { (err, ref) in
                self.rideActionView.config = .pickupPassenger
            }
        }
        
        if region.identifier == AnnotationType.destination.rawValue {
            print("DEBUG: Did start monitoring destination region \(region)")
            
            DriverService.shared.updateTripState(trip: trip, state: .arrivedAtDestination) { (err, ref) in
                self.rideActionView.config = .endTrip
            }
        }
    }
    
    func enableLocationServices() {
        locationManager?.delegate = self
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager?.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        case .authorizedAlways:
            locationManager?.startUpdatingLocation()
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        case .authorizedWhenInUse:
            locationManager?.requestAlwaysAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - LocationInputActivationViewDelegate

extension HomeController: LocationInputActivationViewDelegate {
    func presentLocationInputView() {
        inputActivationView.alpha = 0
        configureLocationInputView()
        
    }
}

//MARK: - LocationInputViewDelegate

extension HomeController: LocationInputViewDelegate {
    func executeSearch(query: String) {
        searchBy(naturalLanguageQuery: query) { (results) in
            self.searchResults = results
            self.tableView.reloadData()
        }
    }
    
    func dismissLocationInputView() {
        dismissLocationView { _ in
            UIView.animate(withDuration: 0.3) {
                self.inputActivationView.alpha = 1
            }
        }
    }
}

// MARK: - UITableViewDelegate/DataSource

extension HomeController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Saved Locations" : "Results"
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? savedLocations.count : searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! LocationCell
        if indexPath.section == 0 {
            cell.placemark = savedLocations[indexPath.row]
        }
        
        if indexPath.section == 1 {
            cell.placemark = searchResults[indexPath.row]
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedPlacemark = indexPath.section == 0 ? savedLocations[indexPath.row] : searchResults[indexPath.row]
        
        configureActionButton(config: .dismissActionView)
        
        let destination = MKMapItem(placemark: selectedPlacemark)
        generatePolyline(toDestination: destination)
        
        dismissLocationView { _ in
            self.mapView.addAnnotationAndSelect(forCoordinate: selectedPlacemark.coordinate)
            
            let annotations = self.mapView.annotations.filter({ !$0.isKind(of: DriverAnnotation.self)})
            self.mapView.zoomToFit(annotations: annotations)
            
            self.animateRideActionView(shouldShow: true, destination: selectedPlacemark, config: .requestRide)
        }
    }
}

// MARK: - RideActionViewDelegate

extension HomeController: RideActionViewDelegate {
    func uploadTrip(_ view: RideActionView) {
//        NO IT IS NOT THIS UID
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let pickupCoordinates = locationManager?.location?.coordinate else { return }
        guard let destinationCoordinates = view.destination?.coordinate else { return }
        
        shouldPresentLoadingView(true, message: "Finding you a ride")
        
        PassengerService.shared.uploadTrip(pickupCoordinates, uid) { (err, ref) in
            if let error = err {
                print("DEBUG: Failed to upload trip with error \(error.localizedDescription)")
                return
            }
            
            UIView.animate(withDuration: 0.3) {
                self.rideActionView.frame.origin.y = self.view.frame.height
            }
        }
    }
    
    func cancelTrip() {
        PassengerService.shared.deleteTrip(self.trip!.homeOwnerUid) { (error, ref) in
            if let error = error {
                print("DEBUG: Error deleting trip..\(error.localizedDescription)")
                return
            }
            
            self.centerMapOnUserLocation()
            self.animateRideActionView(shouldShow: false)
            self.removeAnnotationAndOverlays()
            
            self.actionButton.setImage(#imageLiteral(resourceName: "baseline_menu_black_36dp").withRenderingMode(.alwaysOriginal), for: .normal)
            self.actionButtonConfig = .showMenu
            
            self.inputActivationView.alpha = 1
        }
    }
    
    func pickupPassenger() {
        startTrip()
    }
    
    func dropOffPassenger() {
        guard let trip = self.trip else { return }
        
        DriverService.shared.updateTripState(trip: trip, state: .completed) { (error, ref) in
            self.removeAnnotationAndOverlays()
            self.centerMapOnUserLocation()
            self.animateRideActionView(shouldShow: false)
        }
    }
}

// MARK: - ConfirmationControllerDelegate

extension HomeController: ConfirmationControllerDelegate { 
    func didAcceptTrip(_ trip: Charge) {
        self.trip = trip
        
//        self.mapView.addAnnotationAndSelect(forCoordinate: trip.driverCoordinates)
//        
//        setCustomRegion(withType: .pickup, coordinates: trip.driverCoordinates)
//        
//        let placemark = MKPlacemark(coordinate: trip.driverCoordinates)
//        let mapItem = MKMapItem(placemark: placemark)
//        generatePolyline(toDestination: mapItem)
//        
//        mapView.zoomToFit(annotations: mapView.annotations)
        configureDriverMapView()
        
        observeCancelledTrip(trip: trip)
        
        self.dismiss(animated: true) {
            Service.shared.fetchUserData(uid: trip.driverUid) { (passenger) in
                self.animateRideActionView(shouldShow: true, config: .tripAccepted, user: passenger)
            }
        }
    }
}
