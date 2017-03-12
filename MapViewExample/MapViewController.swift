//
//  MapViewController.swift
//  MapViewExample
//
//  Created by Ignacio on 2017/03/12.
//  Copyright © 2017 IBM. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet fileprivate weak var mapView: MKMapView!
    
    fileprivate var locationManager: CLLocationManager?
    fileprivate var fromLocation: CLLocation?
    fileprivate var fromLocationAnnotation: MKPointAnnotation?
    
    // MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start location manager
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            locationManager?.requestAlwaysAuthorization()
            locationManager?.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        fromLocation = location
        
        if fromLocationAnnotation == nil {
            // First time: Create and add annotation
            //fromLocationAnnotation = MKPointAnnotation()
            let annotation = PlaceAnnotation()
            annotation.label = "出発"
            fromLocationAnnotation = annotation
            fromLocationAnnotation!.coordinate = fromLocation!.coordinate
            fromLocationAnnotation!.title = "Current Location"
            mapView.addAnnotation(fromLocationAnnotation!)
        } else {
            // Not first time: Update annotation
            mapView.removeAnnotation(fromLocationAnnotation!)
            fromLocationAnnotation!.coordinate = fromLocation!.coordinate
            mapView.addAnnotation(fromLocationAnnotation!)
        }
        mapView.showAnnotations(mapView.annotations, animated: true)
        
        if location.horizontalAccuracy < 80 {
            // IMO 80m is accurate enough to search for routes
//            let changeTransportType = #selector(changeTransportTypeToAutomobile)
//            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: changeTransportType, object: nil)
//            self.perform(changeTransportType, with: nil, afterDelay: 0.5)
        }
        if location.horizontalAccuracy < 30 {
            // IMO 30m is accurate enough to turn off location services to save battery :)
            locationManager?.stopUpdatingLocation()
        }
    }
    
    // MARK: - MKMapViewDelegate

    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? PlaceAnnotation else {
            // Other annotations will show the default pin
            return nil
        }
        // Place annotation
        var annotationView: MKAnnotationView?
        let reuseId = String(describing: PlaceAnnotation.self)
        annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
        if annotationView == nil {
            // Create annotation view
            annotationView = MKAnnotationView(
                annotation: annotation,
                reuseIdentifier: reuseId)
            annotationView?.canShowCallout = true
            annotationView?.image = image(text: annotation.label)
        } else {
            // Update annotation view (update the least possible)
            annotationView?.annotation = annotation
            annotationView?.image = image(text: annotation.label)
        }
        return annotationView
    }
    
    // MARK: - Helpers
    
    func image(text: String?) -> UIImage {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 45, height: 45))
        label.text = text
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.backgroundColor = UIColor.purple
        label.clipsToBounds = true
        label.layer.cornerRadius = label.frame.size.width * 0.5
        label.layer.borderWidth = 3
        label.layer.borderColor = label.textColor.cgColor
        
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 0.0)
        label.layer.render(in: UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!
    }

}

