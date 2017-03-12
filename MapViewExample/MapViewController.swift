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
    fileprivate var toLocation: CLLocation?

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

            getLocationAndShowRoute(address: "東京都渋谷区道玄坂2-2−1")
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
            let showRoute = #selector(showRoute(transportType:))
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: showRoute, object: nil)
            self.perform(showRoute, with: MKDirectionsTransportType.any, afterDelay: 0.5)
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

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            // Just in case
            let renderer = MKOverlayRenderer(overlay: overlay)
            return renderer
        }
        // We added polylines so we expect to use MKPolylineRenderer
        let lineRenderer = MKPolylineRenderer(polyline: polyline)
        lineRenderer.strokeColor = .orange
        lineRenderer.lineWidth = 3
        return lineRenderer
    }

    // MARK: - Helpers

    func image(text: String?) -> UIImage {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 45, height: 45))
        label.text = text
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = .purple
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

    func getLocationAndShowRoute(address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { (placemarks, error) in
            if let error = error {
                self.showOneWayAlert(title: "Geocoder error", message: error.localizedDescription)
                return
            }
            guard let placemark = placemarks?.last else {
                self.showOneWayAlert(title: "Geocoder error", message: "No placemarks found")
                return
            }
            guard let location = placemark.location else {
                self.showOneWayAlert(title: "Geocoder error", message: "No location in placemark")
                return
            }
            // Add location
            let annotation = MKPointAnnotation()
            annotation.coordinate = location.coordinate
            annotation.title = address
            self.mapView.addAnnotation(annotation)
            self.toLocation = location
            self.showRoute(transportType: .any)
        }
    }

    func showRoute(transportType: MKDirectionsTransportType) {
        guard let from = fromLocation else {
            print("showRoute: no fromLocation")
            return
        }
        guard let to = toLocation else {
            print("showRoute: no toLocation")
            return
        }

        // Search routes in MapKit
        // http://qiita.com/oggata/items/18ce281d5818269c7281
        let fromPlacemark = MKPlacemark(coordinate: from.coordinate, addressDictionary: nil)
        let toPlacemark = MKPlacemark(coordinate: to.coordinate, addressDictionary: nil)

        let fromItem = MKMapItem(placemark:fromPlacemark)
        let toItem = MKMapItem(placemark:toPlacemark)

        let request = MKDirectionsRequest()
        request.source = fromItem
        request.destination = toItem
        request.requestsAlternateRoutes = false // only one route
        request.transportType = transportType

        let directions = MKDirections(request:request)
        directions.calculate { response, error in
            if let error = error {
                self.showOneWayAlert(title: "Route search error", message: error.localizedDescription)
                return
            }
            guard let route = response?.routes.last else {
                self.showOneWayAlert(title: "Route search error", message: "No routes found")
                return
            }
            self.mapView.removeOverlays(self.mapView.overlays)
            self.mapView.add(route.polyline)
        }
    }

    func showOneWayAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Accept", style: .default, handler: { (_) in
            alert.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }
}
