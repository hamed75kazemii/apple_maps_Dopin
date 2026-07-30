//
//  FlutterAppleMap.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 09.10.19.
//

import Foundation
import MapKit
import CoreLocation

enum BUTTON_IDS: Int {
    case LOCATION = 100
}


class FlutterMapView: MKMapView, UIGestureRecognizerDelegate {
    weak var mapContainerView: UIView?
    weak var channel: FlutterMethodChannel?
    var oldBounds: CGRect?
    var options: Dictionary<String, Any>?
    var isMyLocationButtonShowing: Bool? = false
    /// Mirrors Flutter `onPOITap != null`; when false, built-in POIs are not selectable.
    var isPOITapEnabled: Bool = false

    /// Raw Flutter [MyLocationMarker] JSON when a custom avatar URL is set.
    var userLocationMarkerData: Dictionary<String, Any>?

    var usesCustomUserLocationMarker: Bool {
        return userLocationMarkerData != nil
    }

    /// Called when Core Location delivers a new fix (custom marker mode).
    var onUserLocationUpdate: ((CLLocationCoordinate2D) -> Void)?

    /// Called when location tracking stops (custom marker mode).
    var onUserLocationClear: (() -> Void)?

    var lastUserCoordinate: CLLocationCoordinate2D?
    
    fileprivate let locationManager: CLLocationManager = CLLocationManager()
    
    let mapTypes: Array<MKMapType> = [
        MKMapType.standard,
        MKMapType.satellite,
        MKMapType.hybrid,
        MKMapType.satelliteFlyover,
        MKMapType.hybridFlyover,
        MKMapType.mutedStandard,
    ]

    /// When true, low zoom levels use a wide region so MapKit renders the 3D globe.
    var prefersGlobeProjection: Bool = false

    /// Flutter [AppleMap.globeAtMinZoom]: auto standard ↔ hybrid flyover by zoom.
    var globeAtMinZoom: Bool = false

    /// Flutter [AppleMap.clusteringEnabled]: native MapKit marker clustering.
    var clusteringEnabled: Bool = true

    /// True while the map region is changing (pan/zoom) — used for cluster fade-in.
    var isMapRegionChanging: Bool = false

    /// Set after the first camera idle so initial markers skip cluster fade.
    var hasCompletedInitialMapLoad: Bool = false

    /// Map type index requested from Flutter ([MapType] enum).
    var userRequestedMapTypeIndex: Int = 0

    /// Flutter [ElevationStyle] index: 0 = flat, 1 = realistic.
    var elevationStyleIndex: Int = 0

    private var isAutoGlobeActive: Bool = false

    private static let globeZoomThreshold: Double = 2.5
    private static let standardZoomThreshold: Double = 3.5
    private static let standardMapTypeIndex: Int = 0
    private static let hybridFlyoverMapTypeIndex: Int = 4
    private static let mutedStandardMapTypeIndex: Int = 5
    
    let userTrackingModes: Array<MKUserTrackingMode> = [
        MKUserTrackingMode.none,
        MKUserTrackingMode.follow,
        MKUserTrackingMode.followWithHeading,
    ]
    
    convenience init(
        channel: FlutterMethodChannel,
        options: Dictionary<String, Any>,
        userLocationMarkerData: Dictionary<String, Any>? = nil
    ) {
        self.init(frame: CGRect.zero)
        self.channel = channel
        self.options = options
        self.userLocationMarkerData = userLocationMarkerData
        self.locationManager.delegate = self
        initialiseTapGestureRecognizers()
        self.applyPOITapInteraction(enabled: Self.poiTapEnabled(from: options))
        self.overrideUserInterfaceStyle = .light
        self.interpretOptions(options: options)
    }

    private static func poiTapEnabled(from options: Dictionary<String, Any>?) -> Bool {
        return options?["poiTapEnabled"] as? Bool ?? false
    }

    /// Enables or disables native selection for Apple Maps built-in POIs on iOS 17+.
    /// On older versions this is silently a no-op.
    func applyPOITapInteraction(enabled: Bool) {
        self.isPOITapEnabled = enabled
        if #available(iOS 17.0, *) {
            self.selectableMapFeatures = enabled ? [.pointsOfInterest] : []
        }
    }

    /// Clears MapKit selection (Flutter markers and native POI feature callouts).
    func clearSelection(animated: Bool = false) {
        for annotation in self.selectedAnnotations {
            self.deselectAnnotation(annotation, animated: animated)
        }
    }
    
    var actualHeading: CLLocationDirection {
        get {
            if mapContainerView != nil {
                var heading: CLLocationDirection = fabs(180 * asin(Double(mapContainerView!.transform.b)) / .pi)
                if mapContainerView!.transform.b <= 0 {
                    if mapContainerView!.transform.a >= 0 {
                        // do nothing
                    } else {
                        heading = 180 - heading
                    }
                } else {
                    if mapContainerView!.transform.a <= 0 {
                        heading = heading + 180
                    } else {
                        heading = 360 - heading
                    }
                }
                return heading
            }
            return CLLocationDirection.zero
        }
    }
    
    // To calculate the displayed region we have to get the layout bounds.
    // Because the self is layed out using an auto layout we have to call
    // setCenterCoordinate after the self was layed out.
    override func layoutSubviews() {
        // Only update the map in layoutSubviews if the bounds changed
        if self.bounds != oldBounds {
            if self.options != nil {
                self.interpretOptions(options: self.options!)
            }
            if #available(iOS 9.0, *) {
                setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: zoomLevel, animated: false)
                mapContainerView = self.findViewOfType("MKScrollContainerView", inView: self)
            } else {
                setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: zoomLevel, animated: false)
            }
        }
        oldBounds = self.bounds
    }
    
    
    override func didMoveToSuperview() {
        if oldBounds != CGRect.zero {
            oldBounds = CGRect.zero
        }
    }
    
    private func findViewOfType(_ viewType: String, inView view: UIView) -> UIView? {
      // function scans subviews recursively and returns
      // reference to the found one of a type
      if view.subviews.count > 0 {
        for v in view.subviews {
          let valueDescription = v.description
          let keywords = viewType
          if valueDescription.range(of: keywords) != nil {
            return v
          }
          if let inSubviews = self.findViewOfType(viewType, inView: v) {
            return inSubviews
          }
        }
        return nil
      } else {
        return nil
      }
    }
    
    func interpretOptions(options: Dictionary<String, Any>) {
        if let isCompassEnabled: Bool = options["compassEnabled"] as? Bool {
            if #available(iOS 9.0, *) {
                self.showsCompass = isCompassEnabled
                self.mapTrackingButton(isVisible: self.isMyLocationButtonShowing ?? false)
            }
        }

        if let padding: Array<Any> = options["padding"] as? Array<Any> {
            var margins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            
            if padding.count >= 1, let top: Double = padding[0] as? Double {
                margins.top = CGFloat(top)
            }
            
            if padding.count >= 2, let left: Double = padding[1] as? Double {
                margins.left = CGFloat(left)
            }
            
            if padding.count >= 3, let bottom: Double = padding[2] as? Double {
                margins.bottom = CGFloat(bottom)
            }
            
            if padding.count >= 4, let right: Double = padding[3] as? Double {
                margins.right = CGFloat(right)
            }
            
            self.layoutMargins = margins
        }
        
        if let globeAtMinZoom: Bool = options["globeAtMinZoom"] as? Bool {
            self.globeAtMinZoom = globeAtMinZoom
            if !globeAtMinZoom {
                isAutoGlobeActive = false
            }
        }

        if let clusteringEnabled: Bool = options["clusteringEnabled"] as? Bool {
            self.clusteringEnabled = clusteringEnabled
        }

        if let elevationStyle: Int = options["elevationStyle"] as? Int {
            elevationStyleIndex = elevationStyle
        }

        if let mapType: Int = options["mapType"] as? Int {
            userRequestedMapTypeIndex = mapType
            if mapType != FlutterMapView.standardMapTypeIndex {
                isAutoGlobeActive = false
                applyMapType(index: mapType)
            } else if !isAutoGlobeActive {
                applyMapType(index: mapType)
            }
        } else if options["elevationStyle"] != nil {
            let index = isAutoGlobeActive
                ? FlutterMapView.hybridFlyoverMapTypeIndex
                : userRequestedMapTypeIndex
            applyMapType(index: index)
        }
        
        if let trafficEnabled: Bool = options["trafficEnabled"] as? Bool {
            if #available(iOS 9.0, *) {
                self.showsTraffic = trafficEnabled
            } else {
                // do nothing
            }
        }
        
        if let rotateGesturesEnabled: Bool = options["rotateGesturesEnabled"] as? Bool {
            self.isRotateEnabled = rotateGesturesEnabled
        }
        
        if let scrollGesturesEnabled: Bool = options["scrollGesturesEnabled"] as? Bool {
            self.isScrollEnabled = scrollGesturesEnabled
        }
        
        if let pitchGesturesEnabled: Bool = options["pitchGesturesEnabled"] as? Bool {
            self.isPitchEnabled = pitchGesturesEnabled
        }
        
        if let zoomGesturesEnabled: Bool = options["zoomGesturesEnabled"] as? Bool{
            self.isZoomEnabled = zoomGesturesEnabled
        }
        
        if let myLocationEnabled: Bool = options["myLocationEnabled"] as? Bool {
            if (myLocationEnabled) {
                self.setUserLocation()
            } else {
                self.removeUserLocation()
            }
            
        }
        
        if let myLocationButtonEnabled: Bool = options["myLocationButtonEnabled"] as? Bool {
            self.mapTrackingButton(isVisible: myLocationButtonEnabled)
        }
        
        if let userTackingMode: Int = options["trackingMode"] as? Int {
            self.setUserTrackingMode(self.userTrackingModes[userTackingMode], animated: false)
        }
        
        if let minMaxZoom: Array<Any> = options["minMaxZoomPreference"] as? Array<Any>{
            if let _minZoom: Double = minMaxZoom[0] as? Double {
                self.minZoomLevel = _minZoom
            }
            if let _maxZoom: Double = minMaxZoom[1] as? Double {
                self.maxZoomLevel = _maxZoom
            }
        }
        
        if let insetsSafeArea: Bool = options["insetsLayoutMarginsFromSafeArea"] as? Bool {
            if #available(iOS 11.0, *) {
                self.insetsLayoutMarginsFromSafeArea = insetsSafeArea
            }
        }

        if let poiTapEnabled: Bool = options["poiTapEnabled"] as? Bool {
            self.applyPOITapInteraction(enabled: poiTapEnabled)
        }

        if let showPOI: Bool = options["showPointsOfInterest"] as? Bool {
            self.showsPointsOfInterest = showPOI
            self.applyPointsOfInterestVisibility()
        }

    }

    func applyPointsOfInterestVisibility() {
        if #available(iOS 16.0, *) {
            let index = isAutoGlobeActive
                ? FlutterMapView.hybridFlyoverMapTypeIndex
                : userRequestedMapTypeIndex
            applyMapType(index: index)
            return
        }
        if #available(iOS 13.0, *) {
            self.pointOfInterestFilter = Self.dopinPointOfInterestFilter(
                showing: showsPointsOfInterest
            )
        }
    }

    /// Dopin-curated POI filter: include allowlisted categories, or hide all.
    @available(iOS 13.0, *)
    private static func dopinPointOfInterestFilter(showing: Bool) -> MKPointOfInterestFilter {
        showing
            ? MKPointOfInterestFilter(including: dopinPointOfInterestCategories())
            : MKPointOfInterestFilter.excludingAll
    }

    /// MapKit categories shown when POIs are enabled (Eat & Drink, Get Active,
    /// Party & Watch, Explore & Talk). Categories introduced in iOS 18 are
    /// appended only when available (sports plus newer landmarks / venues).
    @available(iOS 13.0, *)
    private static func dopinPointOfInterestCategories() -> [MKPointOfInterestCategory] {
        var categories: [MKPointOfInterestCategory] = [
            // Eat & Drink
            .restaurant,
            .cafe,
            .bakery,
            .brewery,
            .winery,
            .foodMarket,
            // Get Active (baseline; sports-specific appended on iOS 18+)
            .park,
            .beach,
            .fitnessCenter,
            // Party & Watch
            .nightlife,
            .movieTheater,
            .theater,
            .stadium,
            .amusementPark,
            // Explore & Talk
            .museum,
            .aquarium,
            .zoo,
            .library,
            .university,
        ]
        if #available(iOS 18.0, *) {
            categories.append(contentsOf: [
                // Eat & Drink / Party & Watch / Explore (iOS 18+)
                .distillery,
                .musicVenue,
                .fairground,
                .landmark,
                .nationalMonument,
                .castle,
                .planetarium,
                .conventionCenter,
                // Get Active — sports-specific
                .hiking,
                .swimming,
                .tennis,
                .basketball,
                .soccer,
                .volleyball,
                .skatePark,
                .skating,
                .rockClimbing,
                .golf,
                .miniGolf,
                .bowling,
                .goKart,
            ])
        }
        return categories
    }

    func setUserLocation() {
        locationManager.delegate = self
        let status = currentAuthorizationStatus()

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            showsUserLocation = true
        case .authorizedAlways, .authorizedWhenInUse:
            showsUserLocation = true
            publishUserLocationFromMapKitIfNeeded()
        default:
            print("Location authorization not granted: \(status.rawValue)")
        }
    }

    /// Reads MapKit's [MKUserLocation] (requires [showsUserLocation]).
    func publishUserLocationFromMapKitIfNeeded() {
        guard usesCustomUserLocationMarker else { return }
        let coordinate = userLocation.coordinate
        guard Self.isValidUserCoordinate(coordinate) else { return }
        lastUserCoordinate = coordinate
        onUserLocationUpdate?(coordinate)
    }

    static func isValidUserCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return false }
        return abs(coordinate.latitude) > 0.0001 || abs(coordinate.longitude) > 0.0001
    }

    private func currentAuthorizationStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return locationManager.authorizationStatus
        }
        return CLLocationManager.authorizationStatus()
    }
    
    func removeUserLocation() {
        self.showsUserLocation = false
        self.onUserLocationClear?()
    }
    
    // Functions used for the mapTrackingButton
    func mapTrackingButton(isVisible visible: Bool) {
        self.isMyLocationButtonShowing = visible
        if let _locationButton = self.viewWithTag(BUTTON_IDS.LOCATION.rawValue) {
           _locationButton.removeFromSuperview()
        }
        if visible {
            let buttonContainer = UIView()
            if #available(iOS 9.0, *) {
                buttonContainer.translatesAutoresizingMaskIntoConstraints = false
                buttonContainer.widthAnchor.constraint(equalToConstant: 35).isActive = true
                buttonContainer.heightAnchor.constraint(equalToConstant: 35).isActive = true
                buttonContainer.layer.cornerRadius = 8
                buttonContainer.tag = BUTTON_IDS.LOCATION.rawValue
                buttonContainer.backgroundColor = .white
                if #available(iOS 11.0, *) {
                    let userTrackingButton = MKUserTrackingButton(mapView: self)
                    userTrackingButton.translatesAutoresizingMaskIntoConstraints = false
                    buttonContainer.addSubview(userTrackingButton)
                    userTrackingButton.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor).isActive = true
                    userTrackingButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor).isActive = true
                } else {
                    let locationButton = UIButton(type: UIButton.ButtonType.custom) as UIButton
                    let image = UIImage(named: "outline_near_me")
                    locationButton.translatesAutoresizingMaskIntoConstraints = false
                    locationButton.setImage(image, for: .normal)
                    locationButton.imageView?.tintColor = .blue
                    locationButton.addTarget(self, action: #selector(centerMapOnUserButtonClicked), for:.touchUpInside)
                    buttonContainer.addSubview(locationButton)
                    locationButton.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor).isActive = true
                    locationButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor).isActive = true
                }
                self.addSubview(buttonContainer)
                buttonContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -5 - self.layoutMargins.right).isActive = true
                buttonContainer.topAnchor.constraint(equalTo: self.topAnchor, constant: self.showsCompass ? 50 : 5 + self.layoutMargins.top).isActive = true
            }
        }
    }
    
    @objc func centerMapOnUserButtonClicked() {
        goToUserLocation()
    }

    func goToUserLocation() {
        let coordinate = resolvedUserCoordinate()
        if let coordinate = coordinate {
            let targetZoom = max(calculatedZoomLevel, 15)
            if #available(iOS 9.0, *) {
                setCenterCoordinateWithAltitude(
                    centerCoordinate: coordinate,
                    zoomLevel: targetZoom,
                    animated: true
                )
            } else {
                setCenterCoordinateRegion(
                    centerCoordinate: coordinate,
                    zoomLevel: targetZoom,
                    animated: true
                )
            }
            return
        }
        setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
    }

    func setTrackingModeIndex(_ index: Int, animated: Bool) {
        guard index >= 0 && index < userTrackingModes.count else { return }
        let mode = userTrackingModes[index]
        if mode != .none {
            setUserLocation()
        }
        setUserTrackingMode(mode, animated: animated)
    }

    private func resolvedUserCoordinate() -> CLLocationCoordinate2D? {
        if let cached = lastUserCoordinate, Self.isValidUserCoordinate(cached) {
            return cached
        }
        let mapKitCoordinate = userLocation.coordinate
        if Self.isValidUserCoordinate(mapKitCoordinate) {
            return mapKitCoordinate
        }
        return nil
    }
    
    func getMapViewAnnotations() -> [FlutterAnnotation?] {
        let flutterAnnotations = self.annotations as? [FlutterAnnotation] ?? []
        let sortedAnnotations = flutterAnnotations.sorted(by: { $0.zIndex  < $1.zIndex })
        return sortedAnnotations
    }
       
    
    // Functions used for GestureRecognition
    private func initialiseTapGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(onMapGesture))
        panGesture.maximumNumberOfTouches = 2
        panGesture.delegate = self
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(onMapGesture))
        pinchGesture.delegate = self
        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(onMapGesture))
        rotateGesture.delegate = self
        let tiltGesture = UISwipeGestureRecognizer(target: self, action: #selector(onMapGesture))
        tiltGesture.numberOfTouchesRequired = 2
        tiltGesture.direction = .up
        tiltGesture.direction = .down
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: nil)
        doubleTapGesture.numberOfTapsRequired = 2
        let longTapGesture = UILongPressGestureRecognizer(target: self, action: #selector(longTap))
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTap))
        tapGesture.require(toFail: doubleTapGesture)    // only recognize taps that are not involved in zooming
        self.addGestureRecognizer(panGesture)
        self.addGestureRecognizer(pinchGesture)
        self.addGestureRecognizer(rotateGesture)
        self.addGestureRecognizer(tiltGesture)
        self.addGestureRecognizer(longTapGesture)
        self.addGestureRecognizer(doubleTapGesture)
        self.addGestureRecognizer(tapGesture)
    }
       
    @objc func onMapGesture(sender: UIGestureRecognizer) {
        let locationOnMap = self.region.center // self.convert(locationInView, toCoordinateFrom: self)
        let zoom = self.calculatedZoomLevel
        let pitch = self.camera.pitch
        let heading = self.actualHeading
        self.updateCameraValues()
        updateGlobeTransitionIfNeeded()
        channel?.invokeMethod("camera#onMove", arguments: ["position": ["heading": heading, "target":  [locationOnMap.latitude, locationOnMap.longitude], "pitch": pitch, "zoom": zoom]])
    }

    @available(iOS 16.0, *)
    private func mapKitElevationStyle() -> MKMapConfiguration.ElevationStyle {
        elevationStyleIndex == 1 ? .realistic : .flat
    }

    /// Applies a [MapType] index to MapKit (configuration API on iOS 16+, legacy mapType below).
    func applyMapType(index: Int) {
        prefersGlobeProjection = index >= 3
        if #available(iOS 16.0, *) {
            let elevation = mapKitElevationStyle()
            let poiFilter: MKPointOfInterestFilter? = {
                if #available(iOS 13.0, *) {
                    return Self.dopinPointOfInterestFilter(showing: showsPointsOfInterest)
                }
                return nil
            }()
            switch index {
            case 0:
                let config = MKStandardMapConfiguration(elevationStyle: elevation)
                if let poiFilter = poiFilter {
                    config.pointOfInterestFilter = poiFilter
                }
                preferredConfiguration = config
            case 1:
                preferredConfiguration = MKImageryMapConfiguration(elevationStyle: elevation)
            case 2:
                let config = MKHybridMapConfiguration(elevationStyle: elevation)
                if let poiFilter = poiFilter {
                    config.pointOfInterestFilter = poiFilter
                }
                preferredConfiguration = config
            case 3:
                preferredConfiguration = MKImageryMapConfiguration(elevationStyle: elevation)
            case 4:
                let config = MKHybridMapConfiguration(elevationStyle: elevation)
                if let poiFilter = poiFilter {
                    config.pointOfInterestFilter = poiFilter
                }
                preferredConfiguration = config
            case FlutterMapView.mutedStandardMapTypeIndex:
                let config = MKStandardMapConfiguration(
                    elevationStyle: elevation,
                    emphasisStyle: .muted
                )
                if let poiFilter = poiFilter {
                    config.pointOfInterestFilter = poiFilter
                }
                preferredConfiguration = config
            default:
                break
            }
        } else if index < mapTypes.count {
            self.mapType = mapTypes[index]
            applyPointsOfInterestVisibility()
        }
    }

    /// When [globeAtMinZoom] is enabled with standard map, switch to hybrid flyover at min zoom.
    func updateGlobeTransitionIfNeeded() {
        guard globeAtMinZoom else { return }
        guard userRequestedMapTypeIndex == FlutterMapView.standardMapTypeIndex else { return }

        let zoom = calculatedZoomLevel

        if zoom <= FlutterMapView.globeZoomThreshold && !isAutoGlobeActive {
            isAutoGlobeActive = true
            applyMapType(index: FlutterMapView.hybridFlyoverMapTypeIndex)
            if zoom <= 2 {
                refreshGlobeProjection()
            }
        } else if zoom >= FlutterMapView.standardZoomThreshold && isAutoGlobeActive {
            isAutoGlobeActive = false
            applyMapType(index: FlutterMapView.standardMapTypeIndex)
        }
    }

    private func refreshGlobeProjection() {
        if #available(iOS 9.0, *) {
            setCenterCoordinateWithAltitude(
                centerCoordinate: centerCoordinate,
                zoomLevel: calculatedZoomLevel,
                animated: false
            )
        }
    }

    @objc func longTap(sender: UIGestureRecognizer){
        if sender.state == .began {
           let locationInView = sender.location(in: self)
           let locationOnMap = self.convert(locationInView, toCoordinateFrom: self)
           
           channel?.invokeMethod("map#onLongPress", arguments: ["position": [locationOnMap.latitude, locationOnMap.longitude]])
        }
    }

    @objc func onTap(tap: UITapGestureRecognizer) {
        if tap.state == .recognized {
            TouchHandler.handleMapTaps(tap: tap, overlays: self.overlays, channel: self.channel, in: self)
        }
    }
    
    func updateCameraValues() {
        if oldBounds != nil && oldBounds != CGRect.zero {
            self.updateStoredCameraValues(newZoomLevel: calculatedZoomLevel, newPitch: camera.pitch, newHeading: actualHeading)
        }
    }
    
    // Always allow multiple gestureRecognizers
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func distanceOfCGPoints(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let xDist = a.x - b.x
        let yDist = a.y - b.y
        return CGFloat(sqrt(xDist * xDist + yDist * yDist))
    }
}

extension FlutterMapView: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            handleAuthorizationChange(manager.authorizationStatus)
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorizationChange(status)
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            showsUserLocation = true
            publishUserLocationFromMapKitIfNeeded()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("User location error: \(error.localizedDescription)")
    }
}
