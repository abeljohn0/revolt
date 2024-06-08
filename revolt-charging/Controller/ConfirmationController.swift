//
//  ConfirmationController.swift
//  uber-clone
//
//  Created by Abel John on 22/10/2020.
//

import UIKit
import MapKit

protocol ConfirmationControllerDelegate: class {
    func didAcceptTrip(_ trip: Charge)
}

class ConfirmationController: UIViewController {
    
    // MARK: - Properties
    
    private let mapView = MKMapView()
    let trip: Charge
    var slidingPanelView: UIView!
    var countdownLabel = UILabel(frame: CGRect(x: 20, y: 20, width: 200, height: 50))
    var driver: User? {
        didSet {
            updateRequestLabel()
        }
    }
    var homeowner: User? {
        didSet {
            updateETA()
        }
    }
    weak var delegate: ConfirmationControllerDelegate?
    
    var timer: Timer?
        
    var countdown: Int = 119
    var minutes: Int = 1
    private var route: MKRoute?
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "baseline_clear_white_36pt_2x").withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(handleDismissal), for: .touchUpInside)
        return button
    }()
    
    private var requestLabel: UILabel = {
        let label = UILabel()
        label.text = "Would you like to grant access to your charger?"
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .black
        return label
    }()
    
    private var etaLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.text = ""
        label.textColor = .black
        return label
    }()
    
    private let acceptTripButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(handleAcceptTrip), for: .touchUpInside)
        button.backgroundColor = .white
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        button.setTitleColor(.black, for: .normal)
        button.setTitle("Accept", for: .normal)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 2
//        35f281
        button.layer.borderColor = UIColor(red: 0x2b/255.0, green: 0xb5/255.0, blue: 0x63/255.0, alpha: 1).cgColor
//        49c97c
        button.backgroundColor = UIColor(red: 0x49/255.0, green: 0xc9/255.0, blue: 0x7c/255.0, alpha: 1)
        return button
    }()
    private let declineTripButton: UIButton = {
        let button = UIButton(type: .system)
        button.addTarget(self, action: #selector(handleDismissal), for: .touchUpInside)
        button.backgroundColor = .white
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        button.setTitleColor(.black, for: .normal)
        button.setTitle("Decline", for: .normal)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.systemRed.cgColor
        button.backgroundColor = UIColor(red: 0xf5/255.0, green: 0x62/255.0, blue: 0x8c/255.0, alpha: 1)
        return button
    }()
    
    // MARK: - Lifecycle
    
    init(trip: Charge) {
        self.trip = trip
        super.init(nibName: nil, bundle: nil)
        fetchUserData(trip.driverUid, 0)
        fetchUserData(trip.homeOwnerUid, 1)
//        print(self.user)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
//        configureMapView()
        setupLabel()
        startTimer()
    }
    
    // MARK: - Selectors
    
    @objc func handleAcceptTrip() {
        DriverService.shared.acceptTrip(trip: trip) { (error, ref) in
            self.delegate?.didAcceptTrip(self.trip)
        }
    }
    
    @objc func handleDismissal() {
        DriverService.shared.updateTripState(trip: self.trip, state: .cancelled, completion: {(error, ref) in
            DriverService.shared.deleteTrip(completion: {(error, ref) in})
        })
        print("handle dismissal")
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - API
    
    // MARK: - Helpers
    // TODO: PUT THIS ENTIRE FUNCTION UNDER THE PICKUP DELEGATE!!!
    func configureMapView() {
//        let region = MKCoordinateRegion(center: trip.driverCoordinates, latitudinalMeters: 1000, longitudinalMeters: 1000)
//        mapView.setRegion(region, animated: false)
        
        mapView.addAnnotationAndSelect(forCoordinate: trip.driverCoordinates)
        let placemark = MKPlacemark(coordinate: trip.driverCoordinates)
        let mapItem = MKMapItem(placemark: placemark)
//        generatePolyline(toDestination: mapItem)
        
        mapView.zoomToFit(annotations: mapView.annotations)
    }
    
    func configureUI() {
//        navigationController?.navigationBar.barStyle = .black
//        view.backgroundColor = .backgroundColor
//        
//        view.addSubview(cancelButton)
//        cancelButton.anchor(top: view.safeAreaLayoutGuide.topAnchor,
//                            left: view.leftAnchor,
//                            paddingLeft: 16)
//        
//        view.addSubview(mapView)
//        mapView.setDimensions(height: 270, width: 270)
//        mapView.layer.cornerRadius = 270 / 2
//        mapView.centerX(inView: view)
//        mapView.centerY(inView: view, constant: -200)
//        
//        view.addSubview(requestLabel)
//        requestLabel.centerX(inView: view)
//        requestLabel.anchor(top: mapView.bottomAnchor, paddingTop: 16)
//        requestLabel.contentMode = .scaleAspectFit
//        requestLabel.clipsToBounds = true
        slidingPanelView = UIView()
//        B6CEE3
        slidingPanelView.backgroundColor = UIColor(red: 0xb6/255.0, green: 0xce/255.0, blue: 0xe3/255.0, alpha: 1)
        slidingPanelView.layer.cornerRadius = 16
        slidingPanelView.layer.shadowOpacity = 0.3
        slidingPanelView.layer.shadowOffset = CGSize(width: 0, height: -2)
        
        view.addSubview(slidingPanelView)
        
        slidingPanelView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            slidingPanelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            slidingPanelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            slidingPanelView.heightAnchor.constraint(equalToConstant: 250),
            slidingPanelView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 250)
        ])
//        requestLabel.contentMode = .scaleAspectFit
//        requestLabel.clipsToBounds = true
        requestLabel.textAlignment = .center
        requestLabel.translatesAutoresizingMaskIntoConstraints = false
        requestLabel.adjustsFontSizeToFitWidth = true
        requestLabel.minimumScaleFactor = 0.5
        requestLabel.numberOfLines = 0
        slidingPanelView.addSubview(requestLabel)
//        NSLayoutConstraint.activate([
//            requestLabel.topAnchor.constraint(equalTo: slidingPanelView.topAnchor, constant: 16),  // Add top margin
//            requestLabel.leadingAnchor.constraint(equalTo: slidingPanelView.leadingAnchor, constant: 16),  // Add leading margin
//            requestLabel.trailingAnchor.constraint(equalTo: slidingPanelView.trailingAnchor, constant: -16)  // Add trailing margin
//        ])
        requestLabel.anchor(top: slidingPanelView.topAnchor, left: slidingPanelView.leftAnchor, right: slidingPanelView.rightAnchor, paddingTop: 16, paddingLeft: 10, paddingRight: 10)
        etaLabel.textAlignment = .center
        slidingPanelView.addSubview(etaLabel)
        etaLabel.anchor(top: requestLabel.bottomAnchor,left: slidingPanelView.leftAnchor, right: slidingPanelView.rightAnchor, paddingTop: 10, paddingLeft: 32,
                        paddingRight: 32)
        slidingPanelView.addSubview(countdownLabel)
        countdownLabel.anchor(top: etaLabel.bottomAnchor,
                              left: slidingPanelView.leftAnchor
                              , right: slidingPanelView.rightAnchor,
                              paddingTop: 12,
                              paddingLeft: 32,
                              paddingRight: 32,
                              height: 50)
//        slidingPanelView.addSubview(acceptTripButton)
//        slidingPanelView.addSubview(declineTripButton)
        let stackView = UIStackView(arrangedSubviews: [declineTripButton, acceptTripButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.spacing = 4

        stackView.translatesAutoresizingMaskIntoConstraints = false
        slidingPanelView.addSubview(stackView)
        stackView.anchor(top: countdownLabel.bottomAnchor, left: slidingPanelView.leftAnchor
                         , right: slidingPanelView.rightAnchor,
                         paddingTop: 10,
                         paddingLeft: 16,
                         paddingRight: 16,
                         height: 50)
//        declineTripButton.anchor(top: countdownLabel.bottomAnchor,
//                                left: view.leftAnchor,
//                                 right: acceptTripButton.leftAnchor,
//                                paddingTop: 8,
//                                paddingLeft: 32,
//                                paddingRight: 4,
//                                height: 50)
//        acceptTripButton.anchor(top: countdownLabel.bottomAnchor,
//                                left: declineTripButton.rightAnchor,
//                                right: view.rightAnchor,
//                                paddingTop: 8,
//                                paddingLeft: 4,
//                                paddingRight: 32,
//                                height: 50)
//        NSLayoutConstraint.activate([
//            requestLabel.leadingAnchor.constraint(equalTo: slidingPanelView.leadingAnchor, constant: 20),
//            requestLabel.trailingAnchor.constraint(equalTo: slidingPanelView.trailingAnchor, constant: -20),
//            requestLabel.bottomAnchor.constraint(equalTo: slidingPanelView.bottomAnchor, constant: -20),
//            requestLabel.heightAnchor.constraint(equalToConstant: 50) // Set the height of the button
//        ])
//        print(requestLabel.frame)
//        let chargeButton = UIButton()
//        chargeButton.translatesAutoresizingMaskIntoConstraints = false
//        chargeButton.setTitle("Charge Now", for: .normal)
//        chargeButton.backgroundColor = UIColor(red: 0x2e/255.0, green: 0x47/255.0, blue: 0x5c/255.0, alpha: 1)
//        chargeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
//        chargeButton.setTitleColor(.orange, for: .normal)
//        chargeButton.layer.cornerRadius = 25 // Adjust this value as needed
//        chargeButton.clipsToBounds = true
////        chargeButton.addTarget(self, action: #selector(chargeButtonPressed), for: .touchUpInside)
//            // Add the button to the slidingPanelView
//            slidingPanelView.addSubview(chargeButton)
//
//            // Setup constraints for the button
//            NSLayoutConstraint.activate([
//                chargeButton.leadingAnchor.constraint(equalTo: slidingPanelView.leadingAnchor, constant: 20),
//                chargeButton.trailingAnchor.constraint(equalTo: slidingPanelView.trailingAnchor, constant: -20),
//                chargeButton.bottomAnchor.constraint(equalTo: slidingPanelView.bottomAnchor, constant: -20),
//                chargeButton.heightAnchor.constraint(equalToConstant: 50) // Set the height of the button
//            ])
        UIView.animate(withDuration: 0.3) {
            self.slidingPanelView.transform = CGAffineTransform(translationX: 0, y: -250)
        }
    }
    
    func updateRequestLabel() {
        self.requestLabel.text = "\(self.driver!.fullname) would like to use your charger"
    }
    
    func setupLabel() {
        countdownLabel.text = "1:59"
        countdownLabel.textAlignment = .center
        countdownLabel.textColor = UIColor(red: 0x2e/255.0, green: 0x47/255.0, blue: 0x5c/255.0, alpha: 1)
        countdownLabel.font = UIFont.boldSystemFont(ofSize: 30)
    }
    
    func startTimer() {
        // Invalidate any existing timer
        timer?.invalidate()
        
        // Schedule a new timer
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    
    func updateETA() {
        guard let src = trip.driverCoordinates else { return }
        guard let dest = homeowner?.homeLocation else { return }
        let sourcePlacemark = MKPlacemark(coordinate: src)
        let destinationPlacemark = MKPlacemark(coordinate: dest)

        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        let directionsRequest = MKDirections.Request()
        directionsRequest.source = sourceItem
        directionsRequest.destination = destinationItem
        directionsRequest.transportType = .automobile 
        
        let directions = MKDirections(request: directionsRequest)
        directions.calculate { (response, error) in
            guard let response = response else {
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                }
                return
            }

            if let route = response.routes.first {
                let eta = route.expectedTravelTime
                let distance = route.distance
                let hours = Int(eta / 3600)
                let minutes = Int((eta.truncatingRemainder(dividingBy: 3600)) / 60)
                if hours == 0 {
                    self.etaLabel.text = "They are \(minutes) minutes away"
                } else {
                    self.etaLabel.text = "They are \(hours) hours and \(minutes) minutes away"
                }
                print("ETA: \(eta) seconds")
                print("Distance: \(distance) meters")
            }
        }
    }
    
    @objc func updateTimer() {
        var seconds: Int
        if countdown > 0 {
            countdown -= 1
            seconds = countdown % 60
            if seconds < 10 {
                countdownLabel.text = "\(minutes):0\(seconds)"
                if seconds == 0 && minutes != 0 {
                    minutes -= 1
                }
            } else {
                countdownLabel.text = "\(minutes):\(seconds)"
            }
        } else {
            // Stop the timer
            timer?.invalidate()
            timer = nil
            
            // Perform any action when the countdown finishes
            countdownFinished()
        }
    }

    func countdownFinished() {
        // Alert to indicate time's up
        let alert = UIAlertController(title: "Charge Session Approved", message: "Pull Up", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func fetchUserData(_ uid: String, _ id: Int) {
        if id == 0 {
            Service.shared.fetchUserData(uid: uid, completion: { user in
                self.driver = user
            })
        } else if id == 1 {
            Service.shared.fetchUserData(uid: uid, completion: { user in
                self.homeowner = user
            })
        }
    }
}
