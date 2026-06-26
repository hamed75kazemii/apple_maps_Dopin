//
//  AppleMapController.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 03.09.19.
//

import Foundation
import MapKit
import UIKit

public class AppleMapController: NSObject, FlutterPlatformView {
    var contentView: UIView
    var mapView: FlutterMapView
    var registrar: FlutterPluginRegistrar
    var channel: FlutterMethodChannel
    var initialCameraPosition: [String: Any]
    var options: [String: Any]
    var currentlySelectedAnnotation: String?
    var snapShotOptions: MKMapSnapshotter.Options = MKMapSnapshotter.Options()
    var snapShot: MKMapSnapshotter?

    // Native camera orbit driven by a CADisplayLink so the heading sweep runs at
    // the display's frame rate without crossing the Flutter method channel.
    private var orbitDisplayLink: CADisplayLink?
    private var orbitCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    private var orbitHeading: Double = 0
    private var orbitZoom: Double = 0
    private var orbitPitch: CGFloat = 0
    private var orbitDegreesPerSecond: Double = 0
    private var orbitVerticalScreenOffset: Double = 0
    private var orbitLastTimestamp: CFTimeInterval = 0
    // Sinusoidal pitch oscillation: when orbitPitchMax > orbitPitchMin the pitch
    // sweeps between the two over orbitPitchPeriod seconds while the orbit runs.
    private var orbitPitchMin: Double = 0
    private var orbitPitchMax: Double = 0
    private var orbitPitchPeriod: Double = 0
    private var orbitElapsed: CFTimeInterval = 0

    var isOrbiting: Bool {
        return orbitDisplayLink != nil
    }

    deinit {
        orbitDisplayLink?.invalidate()
        orbitDisplayLink = nil
    }
    
    public init(withFrame frame: CGRect, withRegistrar registrar: FlutterPluginRegistrar, withargs args: Dictionary<String, Any> ,withId id: Int64) {
        self.options = args["options"] as! [String: Any]
        self.channel = FlutterMethodChannel(name: "apple_maps_plugin.luisthein.de/apple_maps_\(id)", binaryMessenger: registrar.messenger())
        
        self.mapView = FlutterMapView(channel: channel, options: options)
        self.registrar = registrar
        
        // To stop the odd movement of the Apple logo.
        self.contentView = UIScrollView()
        self.contentView.addSubview(mapView)
        mapView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        self.initialCameraPosition = args["initialCameraPosition"]! as! Dictionary<String, Any>
        
        super.init()
        
        self.mapView.delegate = self
        
        self.mapView.setCenterCoordinate(initialCameraPosition, animated: false)
        self.setMethodCallHandlers()
        
        if let annotationsToAdd: NSArray = args["annotationsToAdd"] as? NSArray {
            self.annotationsToAdd(annotations: annotationsToAdd)
        }
        if let polylinesToAdd: NSArray = args["polylinesToAdd"] as? NSArray {
            self.addPolylines(polylineData: polylinesToAdd)
        }
        if let polygonsToAdd: NSArray = args["polygonsToAdd"] as? NSArray {
            self.addPolygons(polygonData: polygonsToAdd)
        }
        if let circlesToAdd: NSArray = args["circlesToAdd"] as? NSArray {
            self.addCircles(circleData: circlesToAdd)
        }
    }
    
    public func view() -> UIView {
        return contentView
    }
    
    private func setMethodCallHandlers() {
        channel.setMethodCallHandler({ [unowned self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if let args: Dictionary<String, Any> = call.arguments as? Dictionary<String,Any> {
                switch(call.method) {
                case "annotations#update":
                    self.annotationUpdate(args: args)
                    result(nil)
                    break
                case "annotations#showInfoWindow":
                    self.selectAnnotation(with: args["annotationId"] as! String)
                    break
                case "annotations#hideInfoWindow":
                    self.hideAnnotation(with: args["annotationId"] as! String)
                    break
                case "annotations#isInfoWindowShown":
                    result(self.isAnnotationSelected(with: args["annotationId"] as! String))
                    break
                case "polylines#update":
                    self.polylineUpdate(args: args)
                    result(nil)
                    break
                case "polygons#update":
                    self.polygonUpdate(args: args)
                    result(nil)
                    break
                case "circles#update":
                    self.circleUpdate(args: args)
                    result(nil)
                    break
                case "map#update":
                    self.mapView.interpretOptions(options: args["options"] as! Dictionary<String, Any>)
                    break
                case "camera#animate":
                    self.animateCamera(args: args)
                    result(nil)
                    break
                case "camera#move":
                    self.moveCamera(args: args)
                    result(nil)
                    break
                case "camera#startOrbit":
                    self.startOrbit(args: args)
                    result(nil)
                    break
                case "camera#setOrbitFrame":
                    self.setOrbitFrame(args: args)
                    result(nil)
                    break
                case "camera#convert":
                    self.cameraConvert(args: args, result: result)
                    break
                case "map#takeSnapshot":
                    self.takeSnapshot(options: SnapshotOptions.init(options: args), onCompletion: { (snapshot: FlutterStandardTypedData?, error: Error?) -> Void in
                        result(snapshot ?? error)
                    })
                default:
                    result(FlutterMethodNotImplemented)
                    break
                }
            } else {
                switch call.method {
                case "map#getVisibleRegion":
                    result(self.mapView.getVisibleRegion())
                    break
                case "map#isCompassEnabled":
                    if #available(iOS 9.0, *) {
                        result(self.mapView.showsCompass)
                    } else {
                        result(false)
                    }
                    break
                case "map#isPitchGesturesEnabled":
                    result(self.mapView.isPitchEnabled)
                    break
                case "map#isScrollGesturesEnabled":
                    result(self.mapView.isScrollEnabled)
                    break
                case "map#isZoomGesturesEnabled":
                    result(self.mapView.isZoomEnabled)
                    break
                case "map#isRotateGesturesEnabled":
                    result(self.mapView.isRotateEnabled)
                    break
                case "map#isMyLocationButtonEnabled":
                    result(self.mapView.isMyLocationButtonShowing ?? false)
                    break
                case "map#getMinMaxZoomLevels":
                    result([self.mapView.minZoomLevel, self.mapView.maxZoomLevel])
                    break
                case "camera#getZoomLevel":
                    result(self.mapView.calculatedZoomLevel)
                    break
                case "camera#stopOrbit":
                    self.stopOrbit()
                    result(nil)
                    break
                default:
                    result(FlutterMethodNotImplemented)
                    break
                }
            }
        })
    }
    
    private func annotationUpdate(args: Dictionary<String, Any>) -> Void {
        if let annotationsToAdd = args["annotationsToAdd"] as? NSArray {
            if annotationsToAdd.count > 0 {
                self.annotationsToAdd(annotations: annotationsToAdd)
            }
        }
        if let annotationsToChange = args["annotationsToChange"] as? NSArray {
            if annotationsToChange.count > 0 {
                self.annotationsToChange(annotations: annotationsToChange)
            }
        }
        if let annotationsToDelete = args["annotationIdsToRemove"] as? NSArray {
            if annotationsToDelete.count > 0 {
                self.annotationsIdsToRemove(annotationIds: annotationsToDelete)
            }
        }
    }
    
    private func polygonUpdate(args: Dictionary<String, Any>) -> Void {
        if let polyligonsToAdd: NSArray = args["polygonsToAdd"] as? NSArray {
            self.addPolygons(polygonData: polyligonsToAdd)
        }
        if let polygonsToChange: NSArray = args["polygonsToChange"] as? NSArray {
            self.changePolygons(polygonData: polygonsToChange)
        }
        if let polygonsToRemove: NSArray = args["polygonIdsToRemove"] as? NSArray {
            self.removePolygons(polygonIds: polygonsToRemove)
        }
    }
    
    private func polylineUpdate(args: Dictionary<String, Any>) -> Void {
        if let polylinesToAdd: NSArray = args["polylinesToAdd"] as? NSArray {
            self.addPolylines(polylineData: polylinesToAdd)
        }
        if let polylinesToChange: NSArray = args["polylinesToChange"] as? NSArray {
            self.changePolylines(polylineData: polylinesToChange)
        }
        if let polylinesToRemove: NSArray = args["polylineIdsToRemove"] as? NSArray {
            self.removePolylines(polylineIds: polylinesToRemove)
        }
    }
    
    private func circleUpdate(args: Dictionary<String, Any>) -> Void {
        if let circlesToAdd: NSArray = args["circlesToAdd"] as? NSArray {
            self.addCircles(circleData: circlesToAdd)
        }
        if let circlesToChange: NSArray = args["circlesToChange"] as? NSArray {
            self.changeCircles(circleData: circlesToChange)
        }
        if let circlesToRemove: NSArray = args["circleIdsToRemove"] as? NSArray {
            self.removeCircles(circleIds: circlesToRemove)
        }
    }
    
    private func moveCamera(args: Dictionary<String, Any>) -> Void {
        let positionData: Dictionary<String, Any> = self.toPositionData(data: args["cameraUpdate"] as! Array<Any>, animated: true)
        if !positionData.isEmpty {
            guard let _ = positionData["moveToBounds"] else {
                self.mapView.setCenterCoordinate(positionData, animated: false)
                return
            }
            self.mapView.setBounds(positionData, animated: false)
        }
    }
    
    private func animateCamera(args: Dictionary<String, Any>) -> Void {
        let duration = Self.animationDuration(from: args["duration"])
        let positionData: Dictionary<String, Any> = self.toPositionData(data: args["cameraUpdate"] as! Array<Any>, animated: true, duration: duration)
        if !positionData.isEmpty {
            guard let _ = positionData["moveToBounds"] else {
                self.mapView.setCenterCoordinate(positionData, animated: true, duration: duration)
                return
            }
            self.mapView.setBounds(positionData, animated: true, duration: duration)
        }
    }

    private static func animationDuration(from value: Any?) -> TimeInterval? {
        let milliseconds: Double?
        if let ms = value as? Double {
            milliseconds = ms
        } else if let ms = value as? Int {
            milliseconds = Double(ms)
        } else {
            milliseconds = nil
        }
        guard let ms = milliseconds, ms > 0 else { return nil }
        return TimeInterval(ms / 1000.0)
    }
    
    // MARK: - Native camera orbit

    private func startOrbit(args: Dictionary<String, Any>) -> Void {
        guard let centerList = args["center"] as? Array<Double>, centerList.count == 2 else { return }
        self.invalidateOrbitDisplayLink()

        self.orbitCenter = CLLocationCoordinate2D(latitude: centerList[0], longitude: centerList[1])
        self.orbitZoom = args["zoom"] as? Double ?? self.mapView.zoomLevel
        self.orbitPitch = CGFloat(args["pitch"] as? Double ?? Double(self.mapView.camera.pitch))
        self.orbitDegreesPerSecond = args["degreesPerSecond"] as? Double ?? 12.0
        self.orbitVerticalScreenOffset = args["verticalScreenOffset"] as? Double ?? 0.0
        self.orbitHeading = args["startBearing"] as? Double ?? Double(self.mapView.actualHeading)
        self.orbitPitchMin = args["pitchMin"] as? Double ?? 0.0
        self.orbitPitchMax = args["pitchMax"] as? Double ?? 0.0
        self.orbitPitchPeriod = args["pitchPeriodSeconds"] as? Double ?? 0.0
        self.orbitElapsed = 0

        // Position the first frame immediately so there is no visible jump before
        // the display link fires.
        self.mapView.setOrbitCamera(
            center: self.orbitCenter,
            zoomLevel: self.orbitZoom,
            pitch: self.currentOrbitPitch(),
            heading: self.orbitHeading,
            verticalScreenOffset: self.orbitVerticalScreenOffset
        )

        self.orbitLastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(self.onOrbitTick(_:)))
        link.add(to: .main, forMode: .common)
        self.orbitDisplayLink = link
    }

    /// Positions the camera using the same native math as the first orbit frame,
    /// without starting the display-link sweep.
    private func setOrbitFrame(args: Dictionary<String, Any>) -> Void {
        guard let centerList = args["center"] as? Array<Double>, centerList.count == 2 else { return }
        let center = CLLocationCoordinate2D(latitude: centerList[0], longitude: centerList[1])
        let zoom = args["zoom"] as? Double ?? self.mapView.zoomLevel
        let pitch = CGFloat(args["pitch"] as? Double ?? Double(self.mapView.camera.pitch))
        let heading = args["bearing"] as? Double ?? Double(self.mapView.actualHeading)
        let verticalScreenOffset = args["verticalScreenOffset"] as? Double ?? 0.0
        self.mapView.setOrbitCamera(
            center: center,
            zoomLevel: zoom,
            pitch: pitch,
            heading: heading,
            verticalScreenOffset: verticalScreenOffset
        )
    }

    /// Returns the pitch for the current orbit frame. When a valid oscillation
    /// range is configured the pitch follows a sine wave between `orbitPitchMin`
    /// and `orbitPitchMax`, starting at the minimum; otherwise the fixed
    /// `orbitPitch` is used.
    private func currentOrbitPitch() -> CGFloat {
        guard orbitPitchPeriod > 0, orbitPitchMax > orbitPitchMin else {
            return orbitPitch
        }
        let mid = (orbitPitchMin + orbitPitchMax) / 2.0
        let amplitude = (orbitPitchMax - orbitPitchMin) / 2.0
        // -cos starts the cycle at the minimum and rises smoothly to the maximum.
        let phase = 2.0 * Double.pi * (orbitElapsed / orbitPitchPeriod)
        let value = mid - amplitude * cos(phase)
        return CGFloat(value)
    }

    @objc private func onOrbitTick(_ link: CADisplayLink) -> Void {
        // Seed the timestamp on the first tick so the very first delta is ~0.
        if self.orbitLastTimestamp == 0 {
            self.orbitLastTimestamp = link.timestamp
            return
        }
        let dt = link.timestamp - self.orbitLastTimestamp
        self.orbitLastTimestamp = link.timestamp
        self.orbitElapsed += dt

        var heading = (self.orbitHeading + self.orbitDegreesPerSecond * dt).truncatingRemainder(dividingBy: 360.0)
        if heading < 0 { heading += 360.0 }
        self.orbitHeading = heading

        self.mapView.setOrbitCamera(
            center: self.orbitCenter,
            zoomLevel: self.orbitZoom,
            pitch: self.currentOrbitPitch(),
            heading: self.orbitHeading,
            verticalScreenOffset: self.orbitVerticalScreenOffset
        )
    }

    private func invalidateOrbitDisplayLink() -> Void {
        self.orbitDisplayLink?.invalidate()
        self.orbitDisplayLink = nil
        self.orbitLastTimestamp = 0
        self.orbitElapsed = 0
    }

    private func stopOrbit() -> Void {
        let wasOrbiting = self.isOrbiting
        self.invalidateOrbitDisplayLink()
        guard wasOrbiting else { return }

        // Push the final camera state back to Flutter so the Dart side's cached
        // camera position stays in sync after the native sweep ends.
        let center = self.mapView.region.center
        self.channel.invokeMethod("camera#onMove", arguments: ["position": [
            "heading": self.mapView.actualHeading,
            "target": [center.latitude, center.longitude],
            "pitch": self.mapView.camera.pitch,
            "zoom": self.mapView.calculatedZoomLevel
        ]])
        self.channel.invokeMethod("camera#onIdle", arguments: "")
    }

    private func cameraConvert(args: Dictionary<String, Any>, result: FlutterResult) -> Void {
        guard let annotation = args["annotation"] as? Array<Double> else {
            result(nil)
            return
        }
        let point = self.mapView.convert(CLLocationCoordinate2D(latitude: annotation[0] , longitude: annotation[1]), toPointTo: self.view())
        result(["point": [point.x, point.y]])
    }
    
    private func toPositionData(data: Array<Any>, animated: Bool, duration: TimeInterval? = nil) -> Dictionary<String, Any> {
        var positionData: Dictionary<String, Any> = [:]
        if let update: String = data[0] as? String {
            switch(update) {
            case "newCameraPosition":
                if let _positionData : Dictionary<String, Any> = data[1] as? Dictionary<String, Any> {
                    positionData = _positionData
                }
            case "newLatLng":
                if let _positionData : Array<Any> = data[1] as? Array<Any> {
                    positionData = ["target": _positionData]
                }
            case "newLatLngZoom":
                if let _positionData: Array<Any> = data[1] as? Array<Any> {
                    let zoom: Double = data[2] as? Double ?? 0
                    positionData = ["target": _positionData, "zoom": zoom]
                }
            case "newLatLngBounds":
                if let _positionData: Array<Any> = data[1] as? Array<Any> {
                    let padding: Double = data[2] as? Double ?? 0
                    positionData = ["target": _positionData, "padding": padding, "moveToBounds": true]
                }
            case "zoomBy":
                if let zoomBy: Double = data[1] as? Double {
                    mapView.zoomBy(zoomBy: zoomBy, animated: animated, duration: duration)
                }
            case "zoomTo":
                if let zoomTo: Double = data[1] as? Double {
                    mapView.zoomTo(newZoomLevel: zoomTo, animated: animated, duration: duration)
                }
            case "zoomIn":
                mapView.zoomIn(animated: animated, duration: duration)
            case "zoomOut":
                mapView.zoomOut(animated: animated, duration: duration)
            default:
                positionData = [:]
            }
            return positionData
        }
        return [:]
    }
}


extension AppleMapController: MKMapViewDelegate {
    // onIdle
    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // While the native orbit is running we drive the camera every frame; emitting
        // camera#onMove/onIdle here would flood the Flutter channel and defeat the
        // whole point of moving the orbit off the Dart timer. stopOrbit() sends a
        // single final position instead.
        if self.isOrbiting {
            self.mapView.updateGlobeTransitionIfNeeded()
            return
        }
        if ((self.mapView.mapContainerView) != nil) {
            self.mapView.updateGlobeTransitionIfNeeded()
            let locationOnMap = self.mapView.region.center
            self.channel.invokeMethod("camera#onMove", arguments: ["position": ["heading": self.mapView.actualHeading, "target":  [locationOnMap.latitude, locationOnMap.longitude], "pitch": self.mapView.camera.pitch, "zoom": self.mapView.calculatedZoomLevel]])
        }
        self.channel.invokeMethod("camera#onIdle", arguments: "")
    }
    
    // onMoveStarted
    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        if self.isOrbiting { return }
        self.channel.invokeMethod("camera#onMoveStarted", arguments: "")
    }
    
    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is FlutterPolyline {
            return self.polylineRenderer(overlay: overlay)
        } else if overlay is FlutterPolygon {
            return self.polygonRenderer(overlay: overlay)
        } else if overlay is FlutterCircle {
            return self.circleRenderer(overlay: overlay)
        }
        return MKOverlayRenderer()
    }
}

extension AppleMapController {
    private func takeSnapshot(options: SnapshotOptions, onCompletion: @escaping (FlutterStandardTypedData?, Error?) -> Void) {
        // MKMapSnapShotOptions setting.
        snapShotOptions.region = self.mapView.region
        snapShotOptions.size = self.mapView.frame.size
        snapShotOptions.scale = UIScreen.main.scale
        snapShotOptions.showsBuildings = options.showBuildings
        snapShotOptions.showsPointsOfInterest = options.showPointsOfInterest
        
        // Set MKMapSnapShotOptions to MKMapSnapShotter.
        snapShot = MKMapSnapshotter(options: snapShotOptions)
        
        snapShot?.cancel()
        
        if #available(iOS 10.0, *) {
            snapShot?.start { [weak self] snapshot, error in
                guard let self = self else {
                    return
                }
                
                guard let snapshot = snapshot, error == nil else {
                    onCompletion(nil, error)
                    return
                }
                
                let image = UIGraphicsImageRenderer(size: self.snapShotOptions.size).image { [weak self] context in
                    guard let self = self else {
                        return
                    }
                    snapshot.image.draw(at: .zero)
                    let rect = self.snapShotOptions.mapRect
                    if options.showAnnotations {
                        for annotation in self.mapView.getMapViewAnnotations() {
                            self.drawAnnotations(annotation: annotation, point: snapshot.point(for: annotation!.coordinate))
                        }
                    }
                    if options.showOverlays {
                        for overlay in self.mapView.overlays {
                            if ((overlay.intersects?(rect)) != nil) {
                                self.drawOverlays(overlay: overlay, snapshot: snapshot, context: context)
                            }
                        }
                    }
                }

                if let imageData = image.pngData() {
                    onCompletion(FlutterStandardTypedData.init(bytes: imageData), nil)
                }
            }
        }
    }
    
    private func drawAnnotations(annotation: FlutterAnnotation?, point: CGPoint) {
        guard annotation != nil else {
            return
        }
        let annotationView = self.getAnnotationView(annotation: annotation!)
        
        var offsetPoint = point
        
        offsetPoint.x -= annotationView.bounds.width / 2
        offsetPoint.y -= annotationView.bounds.height / 2
        
        
        if #available(iOS 11.0, *), annotationView is MKMarkerAnnotationView {
            annotationView.drawHierarchy(in: CGRect(x: offsetPoint.x, y: offsetPoint.y, width: annotationView.bounds.width, height: annotationView.bounds.height), afterScreenUpdates: true)
        } else {
            offsetPoint.x += annotationView.centerOffset.x
            offsetPoint.y += annotationView.centerOffset.y
            let annotationImage = annotationView.image
            annotationImage?.draw(at: offsetPoint)
        }
    }
    
    @available(iOS 10.0, *)
    private func drawOverlays(overlay: MKOverlay?, snapshot: MKMapSnapshotter.Snapshot, context: UIGraphicsRendererContext) {
        guard overlay != nil else {
            return
        }
        
        if let flutterOverlay: FlutterOverlay = overlay as? FlutterOverlay {
            flutterOverlay.getCAShapeLayer(snapshot: snapshot).render(in: context.cgContext)
        }
        
    }
}
