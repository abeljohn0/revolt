//
//  NormsController.swift
//  uber-clone
//
//  Created by Abel John on 6/5/24.
//

import UIKit

class NormsController: UIViewController {
    private let user: User
    var ruleText: String = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    init(_ user: User) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "baseline_clear_white_36pt_2x").withRenderingMode(.alwaysOriginal), for: .normal)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.backgroundColor =  UIColor(red: 0x2e/255.0, green: 0x47/255.0, blue: 0x5c/255.0, alpha: 1)
        button.addTarget(self, action: #selector(handleDismissal), for: .touchUpInside)
        return button
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .black
        button.setTitle("I confirm I will abide by these rules", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.layer.cornerRadius = 6
        button.layer.borderWidth = 1
        button.backgroundColor =  UIColor(red: 0x2e/255.0, green: 0x47/255.0, blue: 0x5c/255.0, alpha: 1)
        button.addTarget(self, action: #selector(handleDismissal), for: .touchUpInside)
        return button
    }()
    
    @objc func handleDismissal() {
        dismiss(animated: true, completion: nil)
    }
    
    private func setupView() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)  // Semi-transparent background

        let contentView = UIView()
        contentView.backgroundColor = UIColor(red: 0xb6/255.0, green: 0xce/255.0, blue: 0xe3/255.0, alpha: 1)
        contentView.layer.cornerRadius = 12
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)

        // Constraints for the contentView
        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentView.widthAnchor.constraint(equalToConstant: 350),
            contentView.heightAnchor.constraint(equalToConstant: 500)
        ])
        
        if user.accountType == .passenger {
            ruleText =
            """
            Dear \(user.fullname):
            
            Welcome to ReVolt Charging! We are excited to have you onboard our service. Please note the following three rules as you start using our service.
            
            1. Treat the charging location and homeowner's property with respect; do not cause damage and while on homeowner property stay in the driveway only.
            2. Arrive and depart within the booked time slots to avoid inconveniencing the homeowner and other drivers.
            3. Non-Discrimination: Interact without discrimination, respecting all users regardless of race, nationality, religion, gender, or other characteristics.
            
            Thanks, and have fun charging up!
            """
        } else if user.accountType == .driver {
            ruleText = """
            Dear \(user.fullname):
            
            Welcome to ReVolt Charging! We are excited to have you onboard our service. Please note the following rules for homeowner's on our service.
            
            1. Ensure that listed availability times are accurate and that the charger is accessible during those times.
            2. Maintain your charging equipment to meet industry standards and regulations. If broken, please take down charger listing from ReVolt.
            3. Non-Discrimination: You must agree to provide services without discrimination based on race, nationality, religion, gender, or other protected characteristics.
            
            Thanks, and have fun charging up!
            """
        }

        let label = UILabel()
        label.text = ruleText
        
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        // Constraints for the label
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
//        contentView.addSubview(cancelButton)
//                cancelButton.anchor(top: contentView.safeAreaLayoutGuide.topAnchor,
//                                    right: contentView.rightAnchor,
//                                    paddingTop: 16, paddingRight: 16)
        
        contentView.addSubview(actionButton)
        actionButton.anchor(top: label.bottomAnchor, left: contentView.leftAnchor, right: contentView.rightAnchor, paddingTop: 5, paddingLeft: 6, paddingRight: 6)
        
    }
}

