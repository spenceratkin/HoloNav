//
//  ViewController.swift
//  HoloMap
//
//  Created by Spencer Atkin on 3/10/18.
//  Copyright © 2018 Atkin Labs. All rights reserved.
//

import UIKit
import CoreLocation
import GooglePlaces
import MapKit

class ViewController: UIViewController, CLLocationManagerDelegate, UISearchDisplayDelegate {
    
    var startPlace: GMSPlace?
    var endPlace: GMSPlace?
    var startPin = MKPointAnnotation()
    var endPin = MKPointAnnotation()
    
    let manager = CLLocationManager()
    var resultsViewController: GMSAutocompleteResultsViewController?
    var searchController: UISearchController?
    var resultView: UITextView?
    var editingType = EditingType.none

    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager.delegate = self
        mapView.showsUserLocation = true
        checkAlwaysAuthorization()
        manager.startUpdatingLocation()
        
        resultsViewController = GMSAutocompleteResultsViewController()
        resultsViewController?.delegate = self
        
        searchController = UISearchController(searchResultsController: resultsViewController)
        searchController?.searchResultsUpdater = resultsViewController
        
        // Put the search bar in the navigation bar.
        searchController?.searchBar.sizeToFit()
        navigationItem.titleView = searchController?.searchBar
        
        // When UISearchController presents the results view, present it in
        // this view controller, not one further up the chain.
        definesPresentationContext = true
        
        // Prevent the navigation bar from being hidden when searching.
        searchController?.hidesNavigationBarDuringPresentation = false
        
        startPin.title = "Start"
        endPin.title = "End"
        
        searchController?.searchBar.tintColor = UIColor.white
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func changeStart(_ sender: Any) {
        editingType = EditingType.start
        searchController?.isActive = true
        //searchController?.searchBar.becomeFirstResponder()
    }
    
    @IBAction func changeEnd(_ sender: Any) {
        editingType = EditingType.end
        searchController?.isActive = true
        //searchController?.searchBar.becomeFirstResponder()
    }
    
    @IBAction func didTapNavigate(_ sender: Any) {
        guard let start = startPlace, let end = endPlace else {
            return
        }
        postDict(dict: ["start": ["lat": NSNumber(floatLiteral: start.coordinate.latitude), "long": NSNumber(floatLiteral: start.coordinate.longitude)], "end": ["lat": NSNumber(floatLiteral: end.coordinate.latitude), "long": NSNumber(floatLiteral: end.coordinate.longitude)]], endpoint: "1/route")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        sendLocation(location: location)
    }
    
    func checkAlwaysAuthorization() {
        let status = CLLocationManager.authorizationStatus()
        
        if status == .authorizedWhenInUse || status == .denied {
            print("denied")
            let title = status == .denied ? "Location services are off" : "Background location is not enabled"
            let message = "To use background location you must turn on 'Always' in the Location Services Settings"
        
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
                UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
            }
            alertController.addAction(cancelAction)
            alertController.addAction(settingsAction)
            present(alertController, animated: true, completion: nil)
        } else if status == .notDetermined {
            print("not determined")
            
            manager.requestAlwaysAuthorization()
        }
    }
    
    func sendLocation(location: CLLocation) {
        postDict(dict: ["lat": NSNumber(floatLiteral: location.coordinate.latitude), "long": NSNumber(floatLiteral: location.coordinate.longitude)], endpoint: "1/location")
    }
    
    func postDict(dict: NSDictionary, endpoint: String) {
        guard let url = URL(string: "http://ec2-35-167-101-67.us-west-2.compute.amazonaws.com:3000/api/\(endpoint)/") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        request.addValue("application/json", forHTTPHeaderField:"Content-Type")
        request.addValue("application/json", forHTTPHeaderField:"Accept")
        
        do {
            let postData = try JSONSerialization.data(withJSONObject: dict, options: [])
            print(String(data: try JSONSerialization.data(withJSONObject: dict, options: []), encoding: .utf8) ?? "")
            
            request.httpBody = postData
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard data != nil, response != nil, error == nil else {
                    print("error")
                    return
                }
                
                if let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) {
                    print("recieved: \(dataString)")
                } else {
                    print("no data")
                }
            }
            task.resume()
        } catch _ {
            print("fuck you")
        }
    }
}

enum EditingType {
    case none
    case start
    case end
}

// Handle the user's selection.
extension ViewController: GMSAutocompleteResultsViewControllerDelegate {
    func resultsController(_ resultsController: GMSAutocompleteResultsViewController,
                           didAutocompleteWith place: GMSPlace) {
        searchController?.isActive = false
        // Do something with the selected place.
        guard let address = place.formattedAddress else {
            return
        }
        if editingType == EditingType.start {
            startPlace = place
            startPin.coordinate = startPlace!.coordinate
            startPin.subtitle = address
            mapView.addAnnotation(startPin)
        } else if editingType == EditingType.end {
            endPlace = place
            endPin.coordinate = endPlace!.coordinate
            endPin.subtitle = address
            mapView.addAnnotation(endPin)
        }
    }
    
    func resultsController(_ resultsController: GMSAutocompleteResultsViewController,
                           didFailAutocompleteWithError error: Error){
        // TODO: handle the error.
        print("Error: ", error.localizedDescription)
    }
    
    // Turn the network activity indicator on and off again.
    func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}
