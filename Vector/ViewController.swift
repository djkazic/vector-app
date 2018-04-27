//
//  ViewController.swift
//  Vector
//
//  Created by Kevin Cai on 4/25/18.
//  Copyright © 2018 Kevin Cai. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import GooglePlaces
import SwiftSpinner

class ViewController: UIViewController {
    
    var fieldToPopulate = ""
    var locationManager = CLLocationManager()
    var uberPriceStr: String = "-"
    var uberTimeStr: String = "? mins"
    var lyftPriceStr: String = "-"
    var lyftTimeStr: String = "? mins"
    var mbtaTimeStr: String = "? mins"
    
    @IBOutlet weak var pickupField: UITextField!
    @IBOutlet weak var destField: UITextField!
    @IBOutlet weak var uberPrice: UILabel!
    @IBOutlet weak var uberTime: UILabel!
    @IBOutlet weak var lyftPrice: UILabel!
    @IBOutlet weak var lyftTime: UILabel!
    @IBOutlet weak var mbtaTime: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if CLLocationManager.authorizationStatus() != .authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        }
        if CLLocationManager.locationServicesEnabled() {
            // locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
        uberPrice.text = uberPriceStr
        uberTime.text = uberTimeStr
        lyftPrice.text = lyftPriceStr
        lyftTime.text = lyftTimeStr
        mbtaTime.text = mbtaTimeStr
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            print("User allowed us to access location")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lat = locations.first?.coordinate.latitude {
            if let lon = locations.first?.coordinate.longitude {
                print("Got location update (\(lat), \(lon))!")
                print("Attempting to reverse geocode")
                if let locationRes = locations.first {
                    let geoCoder = CLGeocoder()
                    geoCoder.reverseGeocodeLocation(locationRes, completionHandler: { (placemarks, error) -> Void in
                        var placeMark: CLPlacemark!
                        placeMark = placemarks?[0]
                        if let street = placeMark.thoroughfare {
                            print("Geocode success: \(street)")
                            self.pickupField.text = street
                        }
                    })
                }
            }
        }
    }
    
    @IBAction func pickupPressed(_ sender: UITextField) {
        pickupField.text = ""
        handleGooglePlacesPrompt("pickup")
    }
    
    @IBAction func destPressed(_ sender: UITextField) {
        destField.text = ""
        handleGooglePlacesPrompt("dest")
    }
    
    @IBAction func priceCheckPressed(_ sender: Any) {
        var pickupLat: Double = 0
        var pickupLon: Double = 0
        var destLat: Double = 0
        var destLon: Double = 0
        var geocodePickup = false
        var geocodeDest = false
        SwiftSpinner.show("Aggregating price and time data...")
        if let pickupAddr = self.pickupField.text {
            if let destAddr = self.destField.text {
                print("(debug): Attempting geocode -> lat, lon")
                var geocoder = CLGeocoder()
                geocoder.geocodeAddressString(pickupAddr, completionHandler: {(placemarks: [CLPlacemark]?, error: Error?) -> Void in
                    let placemark = placemarks?.first
                    if let lat = placemark?.location?.coordinate.latitude {
                        if let lon = placemark?.location?.coordinate.longitude {
                            pickupLat = lat
                            pickupLon = lon
                            geocodePickup = true
                            print("(debug): Set pickup geocode")
                        }
                    }
                })
                geocoder = CLGeocoder()
                geocoder.geocodeAddressString(destAddr, completionHandler: {(placemarks: [CLPlacemark]?, error: Error?) -> Void in
                    let placemark = placemarks?.first
                    if let lat = placemark?.location?.coordinate.latitude {
                        if let lon = placemark?.location?.coordinate.longitude {
                            destLat = lat
                            destLon = lon
                            geocodeDest = true
                            print("(debug): Set dest geocode")
                            print("(debug): Checking flags for geocode")
                            if (geocodePickup && geocodeDest) {
                                print("(debug): Price check START")
                                print("(debug): > pickup: (\(pickupLat), \(pickupLon))")
                                print("(debug): > dest: (\(destLat), \(destLon))")
                                //TODO: API call to our server and populating outputs
                                let json: [String: Any] = ["pickupLat": String(pickupLat),
                                                           "pickupLon": String(pickupLon),
                                                           "destLat": String(destLat),
                                                           "destLon": String(destLon)]
                                let jsonData = try? JSONSerialization.data(withJSONObject: json)
                                print("(debug): > jsonData = \(jsonData!)")
                                let apiUrl = "http://127.0.0.1:8888/comp"
                                let url = URL(string: apiUrl)!
                                var request = URLRequest(url: url)
                                request.httpMethod = "POST"
                                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                                request.httpBody = jsonData
                                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                                    guard let data = data, error == nil else {
                                        print(error?.localizedDescription ?? "No data")
                                        return
                                    }
                                    let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
                                    if let responseJSON = responseJSON as? [String: Any] {
                                        print("(debug): Response = \(responseJSON)")
                                        DispatchQueue.main.async {
                                            self.uberPrice.text = (responseJSON["PriceUber"] as? String)?.trimmingCharacters(in: .whitespaces)
                                            self.uberTime.text = (responseJSON["TimeUber"] as? String)?.trimmingCharacters(in: .whitespaces)
                                            self.lyftPrice.text = (responseJSON["PriceLyft"] as? String)?.trimmingCharacters(in: .whitespaces)
                                            self.lyftTime.text = (responseJSON["TimeLyft"] as? String)?.trimmingCharacters(in: .whitespaces)
                                            self.mbtaTime.text = (responseJSON["TimeMBTA"] as? String)?.trimmingCharacters(in: .whitespaces)
                                            SwiftSpinner.hide()
                                        }
                                    }
                                }
                                task.resume()
                            } else {
                                print("(error): could not geocode for addresses")
                            }
                        }
                    }
                })
            }
        }
    }
    
    func handleGooglePlacesPrompt(_ fieldProvided: String) {
        fieldToPopulate = fieldProvided
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self
        let filter = GMSAutocompleteFilter()
        filter.type = .address
        autocompleteController.autocompleteFilter = filter
        
        present(autocompleteController, animated: true, completion: nil)
    }
}

extension ViewController: GMSAutocompleteViewControllerDelegate {
    // Handle the user's selection.
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        // Print place info to the console.
        if let formattedAddr = place.formattedAddress {
            print("Place address: \(formattedAddr)")
            switch(fieldToPopulate) {
            case "pickup":
                pickupField.text = formattedAddr
            case "dest":
                destField.text = formattedAddr
            default:
                print("(debug): \(fieldToPopulate)")
            }
            fieldToPopulate = ""
        }
        
        // Close the autocomplete widget.
        self.dismiss(animated: true, completion: nil)
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        // TODO: handle the error.
        print("Error: ", error.localizedDescription)
    }
    
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    // Show the network activity indicator.
    func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    // Hide the network activity indicator.
    func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}

extension UIViewController {
    class func displaySpinner(onView : UIView) -> UIView {
        let spinnerView = UIView.init(frame: onView.bounds)
        spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        let ai = UIActivityIndicatorView.init(activityIndicatorStyle: .whiteLarge)
        ai.startAnimating()
        ai.center = spinnerView.center
        DispatchQueue.main.async {
            spinnerView.addSubview(ai)
            onView.addSubview(spinnerView)
        }
        return spinnerView
    }
    
    class func removeSpinner(spinner :UIView) {
        DispatchQueue.main.async {
            spinner.removeFromSuperview()
        }
    }
}
