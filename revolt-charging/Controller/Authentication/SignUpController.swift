//
//  SignUpController.swift
//  uber-clone
//
//  Created by Abel John on 18/10/2020.
//

import UIKit
import Firebase
import GeoFire

class SignUpController: UIViewController {
    
    // MARK: - Properties
    
    private var location = LocationHandler.shared.locationManager.location
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "ReVolt Charging"
        label.font = UIFont(name: "Avenir-Light", size: 36)
        label.textColor = UIColor(white: 1, alpha: 0.8)
        return label
    }()
    
    private lazy var emailContainerView: UIView = {
        let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "ic_mail_outline_white_2x"), textField: emailTextField)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    
    private lazy var fullnameContainerView: UIView = {
        let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "ic_person_outline_white_2x"), textField: fullnameTextField)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    
    private lazy var passwordContainerView: UIView = {
        let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "ic_account_box_white_2x"), textField: passwordTextField)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    
    private lazy var accountTypeContainerView: UIView = {
        let view = UIView().inputContainerView(segmentedControl: accountTypeSegmentedControl)
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        return view
    }()
    
    private lazy var carContainerView: UIView = {
        let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "car_icon"), textField: carMakeTextField)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    
    private lazy var addressContainerView: UIView = {
        let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "home_icon"), textField: addressTextField)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    
    private lazy var chargerContainerView: UIView = {
        let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "charger_plug_icon_white"), textField: chargerTextField)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    private lazy var timeContainerView: UIView = {
        firstPickerView.datePickerMode = .time
        firstPickerView.translatesAutoresizingMaskIntoConstraints = false
        lastPickerView.datePickerMode = .time
        lastPickerView.translatesAutoresizingMaskIntoConstraints = false
        let view = UIView().inputContainerView(preTimeField: firstPickerView, postTimeField: lastPickerView)
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }()
    
    private let emailTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Email",
                                       isSecureTextEntry: false)
    }()
    
    private let fullnameTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Full Name",
                                       isSecureTextEntry: false)
    }()
    
    private let passwordTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Password",
                                       isSecureTextEntry: true)
    }()
    
    private let addressTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Home Address",
                                       isSecureTextEntry: false)
    }()
    
    private let carMakeTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Car Make",
                                       isSecureTextEntry: false)
    }()
    private let chargerTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "L2 Charger Owned (ex. Tesla NACS)",
                                       isSecureTextEntry: false)
    }()
    private let accountTypeSegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Driver", "Homeowner"])
        sc.backgroundColor = .backgroundColor
        sc.tintColor = UIColor(white: 1, alpha: 0.87)
        sc.selectedSegmentIndex = 0
        sc.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        return sc
    }()
    
    private let signUpButton: AuthButton = {
        let button = AuthButton(type: .system)
        button.setTitle("Sign Up", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.addTarget(self, action: #selector(handleSignUp), for: .touchUpInside)
        return button
    }()
    
    private var stack = UIStackView()
    
    var firstPickerView = UIDatePicker()
    var lastPickerView = UIDatePicker()
    
    
    let alreadyHaveAccountButton: UIButton = {
        let button = UIButton(type: .system)
        let attributedTitle = NSMutableAttributedString(string: "Already have an Account?  ", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 16),
                        NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        attributedTitle.append(NSAttributedString(string: "Log in", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: UIColor.mainBlueTint]))
        button.addTarget(self, action: #selector(handleShowLogin), for: .touchUpInside)
        button.setAttributedTitle(attributedTitle, for: .normal)
        return button
    }()
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        updateStackView()
        configureUI()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Selectors
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func handleSignUp() {
        guard let email = emailTextField.text else { return }
        guard let password = passwordTextField.text else { return }
        guard let fullname = fullnameTextField.text else { return }
        guard let carMake = carMakeTextField.text else { return }
        let accountTypeIndex = accountTypeSegmentedControl.selectedSegmentIndex

        guard let address = addressTextField.text else { return }
        guard let chargerOwned = chargerTextField.text else { return }
        
        
        Auth.auth().createUser(withEmail: email, password: password) { (result, error) in
            if let error = error {
                print("DEBUG: Failed to register user with error \(error.localizedDescription)")
                return
            }
            
            guard let uid = result?.user.uid else { return }
            
            var values = ["email": email,
                          "fullname": fullname,
                          "accountType": accountTypeIndex,
                          "carMake": carMake] as [String : Any]
            
            if accountTypeIndex == 0 {
                let geoFire = GeoFire(firebaseRef: REF_DRIVER_LOCATION)
                guard let location = self.location else { return }
                
                geoFire.setLocation(location, forKey: uid) { (error) in
                    self.uploadUserDataAndShowHomeController(uid: uid, values: values)
                }
            }
            else {
                guard self.lastPickerView.date > self.firstPickerView.date else {
                    let alert = UIAlertController(title: "Times Misaligned", message: "Please ensure the first time is prior to the second available time.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    return
                }
                let hour1 = Calendar.current.component(.hour, from: self.firstPickerView.date)
                let minute1 = Calendar.current.component(.minute, from: self.firstPickerView.date)
                let hour2 = Calendar.current.component(.hour, from: self.lastPickerView.date)
                let minute2 = Calendar.current.component(.minute, from: self.lastPickerView.date)
                values["homeAddress"] = address
                values["charger"] = chargerOwned
                values["availability"] = [[hour1, minute1], [hour2, minute2]]
                print(values["availability"])
                self.uploadUserDataAndShowHomeController(uid: uid, values: values)
            }
        }
    }
    
    @objc func handleShowLogin() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Helpers
    
    @objc func segmentedControlChanged() {
        updateStackView()
    }
    
    func updateStackView() {
        let currentSubviews = stack.arrangedSubviews
            currentSubviews.forEach { subview in
                stack.removeArrangedSubview(subview)
                subview.removeFromSuperview() // This is necessary to actually remove them from the view hierarchy
            }

            // Configure the new views based on the selected segment index
            let viewsToAdd: [UIView]
            if accountTypeSegmentedControl.selectedSegmentIndex == 1 {
                // Homeowner selected
                
                viewsToAdd = [accountTypeContainerView,
                              emailContainerView,
                              fullnameContainerView,
                              passwordContainerView,
                              carContainerView,
                              addressContainerView,
                              chargerContainerView,
                              timeContainerView,
                              signUpButton]
            } else {
                // Driver selected
                viewsToAdd = [accountTypeContainerView,
                              emailContainerView,
                              fullnameContainerView,
                              passwordContainerView,
                              carContainerView,
                              signUpButton]
            }

            // Add the new views to the stack
            viewsToAdd.forEach { stack.addArrangedSubview($0) }
    }
    
    func uploadUserDataAndShowHomeController(uid: String, values: [String: Any]) {
        var values = values
        if values["accountType"] as? Int == 1 {
            if let address = values["homeAddress"] as? String {
                self.geocodeAddressString(address) { coordinate in
                    guard let coordinate = coordinate else { return }
                    let houseLocationArray = [coordinate.latitude, coordinate.longitude]
                    REF_HOME_ADDRESS.child(uid).setValue(["address": address, "houseCoordinates": houseLocationArray]) {  (error, ref) in
                        if let error = error {
                            print("DEBUG: Failed to add home address with error \(error.localizedDescription)")
                            return
                        }
                        print("DEBUG: Successfully added home address")
                    }
                    values["houseCoordinates"] = houseLocationArray
                    REF_USERS.child(uid).updateChildValues(values, withCompletionBlock: { (error, ref) in
                        let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
                        guard let controller = keyWindow?.rootViewController as? ContainerController else { return }
                        controller.configure(true)
                        self.dismiss(animated: true, completion: nil)
                    })
                }
                print("SignUpController")
                print(values)
            }
        } else {
            REF_USERS.child(uid).updateChildValues(values, withCompletionBlock: { (error, ref) in
                let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
                guard let controller = keyWindow?.rootViewController as? ContainerController else { return }
                controller.configure(true)
                self.dismiss(animated: true, completion: nil)
            })
        }
    }
    func configureUI() {
        view.backgroundColor = .backgroundColor
        
        view.addSubview(titleLabel)
        titleLabel.centerX(inView: view)
        titleLabel.anchor(top: view.safeAreaLayoutGuide.topAnchor)
        
        stack = UIStackView(arrangedSubviews: [accountTypeContainerView,
                                                   emailContainerView,
                                                   fullnameContainerView,
                                                   passwordContainerView,
                                                   carContainerView,
                                                   signUpButton])
        stack.axis = .vertical
        stack.distribution = .fillProportionally
        stack.spacing = 24
        
        view.addSubview(stack)
        stack.anchor(top: titleLabel.bottomAnchor,
                     left: view.leftAnchor,
                     right: view.rightAnchor,
                     paddingTop: 25,
                     paddingLeft: 16,
                     paddingRight: 16)
//        let timeStack = UIStackView(arrangedSubviews: [firstPickerView, lastPickerView])
//        timeStack.axis = .horizontal
//        timeStack.distribution = .fillProportionally
//        view.addSubview(timeStack)
////        firstPickerView
//            timeStack.anchor(top: stack.bottomAnchor,
//                          left: view.leftAnchor,
//                          right: view.rightAnchor,
//                          paddingTop: 4,
//                          paddingLeft: 16,
//                          paddingRight: 16)
        
        view.addSubview(alreadyHaveAccountButton)
        alreadyHaveAccountButton.centerX(inView: view)
        alreadyHaveAccountButton.anchor(bottom: view.safeAreaLayoutGuide.bottomAnchor, height: 32)
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
    
//    func numberOfComponents(in pickerView: UIPickerView) -> Int {
//        return 2
//    }
//
//    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
//        if component == 0 {
//            return 10
//        } else {
//            return 100
//        }
//    }
//
//    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        if component == 0 {
//            return "First \(row)"
//        } else {
//            return "Second \(row)"
//        }
//    }
}
