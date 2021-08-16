//
//  MapViewController.swift
//  MapRunner
//
//  Created by Shane Bersiek on 8/15/21.
//

import UIKit
import CoreLocation
import MapKit

class MapViewController: UIViewController {
    
    //MARK: Variables
    let regionInMeters: Double = 1000
    private var run: Run?
    private let locationManager = LocationManager.shared
    private var seconds = 0
    private var timer: Timer?
    private var distance = Measurement(value: 0, unit: UnitLength.meters)
    private var locationList: [CLLocation] = []
    //MARK: IBOutless
    @IBOutlet weak var dataStackView: UIStackView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var paceLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var placeHolder: UIView!
    
    
    //MARK: Life cycles
    override func viewDidLoad() {
        super.viewDidLoad()
        customizeButtons()
        mapView.delegate = self
        checkLocationServices()
    }
    
    //MARK: Functions
    func centerViewOnUserLocation() {
        if let location = locationManager.location?.coordinate {
            let region = MKCoordinateRegion.init(center: location, latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
    }
    
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorization()
        } else {
            // Show alert letting the user know they have to turn this on.
        }
    }
    
    func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
                case .notDetermined, .restricted, .denied:
                    locationManager.requestWhenInUseAuthorization()
                    print("No access")
        case .authorizedAlways, .authorizedWhenInUse:
                    mapView.showsUserLocation = true
                    centerViewOnUserLocation()
                    print("Access")
                @unknown default:
                break
            }
        }
    
    private func updateDisplay() {
      let formattedDistance = FormatDisplay.distance(distance)
      let formattedTime = FormatDisplay.time(seconds)
      let formattedPace = FormatDisplay.pace(distance: distance,
                                             seconds: seconds,
                                             outputUnit: UnitSpeed.minutesPerMile)
      
      distanceLabel.text = "Distance:  \(formattedDistance)"
      timeLabel.text = "Time:  \(formattedTime)"
      paceLabel.text = "Pace:  \(formattedPace)"
    }
    
    func eachSecond() {
      seconds += 1
      updateDisplay()
    }
    
    func customizeButtons(){
        startButton.roundedButton()
        stopButton.roundedButton()
    }
    
    private func stopRun() {
      dataStackView.isHidden = true
      startButton.isHidden = true
      stopButton.isHidden = true
      mapView.isHidden = true
      
      locationManager.stopUpdatingLocation()
    }
    private func startRun() {
      placeHolder.isHidden = true
      dataStackView.isHidden = false
      startButton.isHidden = true
      stopButton.isHidden = false
        mapView.isHidden = false
      
      mapView.removeOverlays(mapView.overlays)
      
      seconds = 0
      distance = Measurement(value: 0, unit: UnitLength.meters)
      locationList.removeAll()
      updateDisplay()
      timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        self.eachSecond()
      }
        locationManager.startUpdatingLocation()
    }
    //MARK: Actions
    @IBAction func startbuttonTapped(_ sender: Any) {
       startRun()
    }
    
    @IBAction func stopButtonTapped(_ sender: Any) {
        let alertController = UIAlertController(title: "End run?",
                                                message: "Do you wish to end your run?",
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
          self.stopRun()
          _ = self.navigationController?.popToRootViewController(animated: true)
        })
        
        present(alertController, animated: true)
    }
    
}



extension MapViewController: CLLocationManagerDelegate{
   
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for newLocation in locations {
          let howRecent = newLocation.timestamp.timeIntervalSinceNow
          guard newLocation.horizontalAccuracy < 20 && abs(howRecent) < 10 else { continue }
          
          if let lastLocation = locationList.last {
            let delta = newLocation.distance(from: lastLocation)
            distance = distance + Measurement(value: delta, unit: UnitLength.meters)
            let coordinates = [lastLocation.coordinate, newLocation.coordinate]
            mapView.addOverlay(MKPolyline(coordinates: coordinates, count: 2))
            let region = MKCoordinateRegion(center: newLocation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)
          }
          
          locationList.append(newLocation)
        }
    }
    
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        ///without this the (first time) you ask for a location it will not update
        checkLocationAuthorization()
    }
    
}


extension MapViewController: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let polyline = overlay as? MKPolyline else {
      return MKOverlayRenderer(overlay: overlay)
    }
    let renderer = MKPolylineRenderer(polyline: polyline)
    renderer.strokeColor = .blue
    renderer.lineWidth = 3
    return renderer
  }
}
