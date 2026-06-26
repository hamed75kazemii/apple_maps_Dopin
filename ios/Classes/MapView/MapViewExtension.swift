//
//  MapViewExtension.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 22.09.19.
//

import Foundation
import UIKit
import MapKit

public extension MKMapView {
    // keeps track of the Map values
    private struct Holder {
        static var _zoomLevel: Double = Double(0)
        static var _pitch: CGFloat = CGFloat(0)
        static var _heading: CLLocationDirection = CLLocationDirection(0)
        static var _maxZoomLevel: Double = Double(21)
        static var _minZoomLevel: Double = Double(2)
    }

    /// Runs a MapKit animation, optionally overriding the system duration.
    func runMapAnimation(animated: Bool, duration: TimeInterval? = nil, _ animations: () -> Void) {
        guard animated else {
            animations()
            return
        }
        if let duration = duration, duration > 0 {
            CATransaction.begin()
            CATransaction.setAnimationDuration(duration)
            animations()
            CATransaction.commit()
        } else {
            animations()
        }
    }
    
    var maxZoomLevel: Double {
        set(_maxZoomLevel) {
            Holder._maxZoomLevel = _maxZoomLevel
            if Holder._zoomLevel > _maxZoomLevel {
                if #available(iOS 9.0, *) {
                    self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: _maxZoomLevel, animated: false)
                } else {
                    self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: _maxZoomLevel, animated: false)
                }
            }
        }
        get {
            return Holder._maxZoomLevel
        }
    }
    
    var minZoomLevel: Double {
        set(_minZoomLevel) {
            Holder._minZoomLevel = _minZoomLevel
            if Holder._zoomLevel < _minZoomLevel {
                if #available(iOS 9.0, *) {
                   self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: _minZoomLevel, animated: false)
                } else {
                   self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: _minZoomLevel, animated: false)
                }
            }
        }
        get {
           return Holder._minZoomLevel
        }
    }
    
    var zoomLevel: Double {
        get {
            return Holder._zoomLevel
        }
    }
    
    var calculatedZoomLevel: Double {
        get {
            let centerPixelSpaceX = Utils.longitudeToPixelSpaceX(longitude: self.centerCoordinate.longitude)

            let lonLeft = self.centerCoordinate.longitude - (self.region.span.longitudeDelta / 2)

            let leftPixelSpaceX = Utils.longitudeToPixelSpaceX(longitude: lonLeft)
            let pixelSpaceWidth = abs(centerPixelSpaceX - leftPixelSpaceX) * 2

            let zoomScale = pixelSpaceWidth / Double(self.bounds.size.width)

            let zoomExponent = Utils.logC(val: zoomScale, forBase: 2)

            var zoomLevel = 21 - zoomExponent
            
            zoomLevel = Utils.roundToTwoDecimalPlaces(number: zoomLevel)
            
            Holder._zoomLevel = zoomLevel
            
            return zoomLevel
            
        }
        set (newZoomLevel) {
            Holder._zoomLevel = newZoomLevel
        }
    }
    
    func setCenterCoordinate(_ positionData: Dictionary<String, Any>, animated: Bool, duration: TimeInterval? = nil) {
        let targetList :Array<CLLocationDegrees> = positionData["target"] as? Array<CLLocationDegrees> ?? [self.camera.centerCoordinate.latitude, self.camera.centerCoordinate.longitude]
        let zoom :Double = positionData["zoom"] as? Double ?? Holder._zoomLevel
        Holder._zoomLevel = zoom
        if let pitch :CGFloat = positionData["pitch"] as? CGFloat {
            Holder._pitch = pitch
        }
        if let heading :CLLocationDirection = positionData["heading"] as? CLLocationDirection {
            Holder._heading = heading
        }
        let centerCoordinate :CLLocationCoordinate2D = CLLocationCoordinate2D(latitude:  targetList[0], longitude: targetList[1])
        if #available(iOS 9.0, *) {
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: zoom, animated: animated, duration: duration)
        } else {
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: zoom, animated: animated, duration: duration)
        }
    }
    
    func setBounds(_ positionData: Dictionary<String, Any>, animated: Bool, duration: TimeInterval? = nil) {
        guard let targetList :Array<Array<CLLocationDegrees>> = positionData["target"] as? Array<Array<CLLocationDegrees>> else { return }
        let padding :Double = positionData["padding"] as? Double ?? 0
        let coodinates: Array<CLLocationCoordinate2D> = targetList.map { (coordinate : Array<CLLocationDegrees>) in
            return CLLocationCoordinate2D(latitude:  coordinate[0], longitude: coordinate[1])
        }
        guard let mapRect = coodinates.mapRect() else { return }
        let edgePadding = UIEdgeInsets(top: CGFloat(padding), left: CGFloat(padding), bottom: CGFloat(padding), right: CGFloat(padding))
        runMapAnimation(animated: animated, duration: duration) {
            self.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: animated)
        }
    }
    
    func setCenterCoordinateRegion(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double, animated: Bool, duration: TimeInterval? = nil) {
        // clamp large numbers to 28
        let zoomL = min(zoomLevel, 28);
    
        // use the zoom level to compute the region
        let span = self.coordinateSpanWithMapView(centerCoordinate: centerCoordinate, zoomLevel: Int(zoomL))
        let region = MKCoordinateRegion.init(center: centerCoordinate, span: span)
        
        // set the region like normal
        runMapAnimation(animated: animated, duration: duration) {
            self.setRegion(region, animated: animated)
        }
        
        // Setting the pitch/heading doesn't work while animating yet.
        // The animation will stop if the you change camera properties while it's running.
        if (!animated) {
            self.camera.pitch = Holder._pitch
            self.camera.heading = Holder._heading
        }
    }
    
    func coordinateSpanWithMapView(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Int) -> MKCoordinateSpan  {
        // convert center coordiate to pixel space
        let centerPixelX = Utils.longitudeToPixelSpaceX(longitude: centerCoordinate.longitude)
        let centerPixelY = Utils.latitudeToPixelSpaceY(latitude: centerCoordinate.latitude)
    
        // determine the scale value from the zoom level
        let zoomExponent = Double(21 - zoomLevel)
        let zoomScale = pow(2.0, zoomExponent)

        // scale the map’s size in pixel space
        let mapSizeInPixels = self.bounds.size
        let scaledMapWidth = Double(mapSizeInPixels.width) * zoomScale
        let scaledMapHeight = Double(mapSizeInPixels.height) * zoomScale;
    
        // figure out the position of the top-left pixel
        let topLeftPixelX = centerPixelX - (scaledMapWidth / 2);
        let topLeftPixelY = centerPixelY - (scaledMapHeight / 2);
    
        // find delta between left and right longitudes
        let minLng = Utils.pixelSpaceXToLongitude(pixelX: topLeftPixelX)
        let maxLng = Utils.pixelSpaceXToLongitude(pixelX: topLeftPixelX + scaledMapWidth)
        let longitudeDelta = maxLng - minLng;
    
        // find delta between top and bottom latitudes
        let minLat = Utils.pixelSpaceYToLatitude(pixelY: topLeftPixelY)
        let maxLat = Utils.pixelSpaceYToLatitude(pixelY: topLeftPixelY + scaledMapHeight)
        let latitudeDelta = -1 * (maxLat - minLat)
    
        // create and return the lat/lng span
        return MKCoordinateSpan.init(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    }
    
    @available(iOS 9.0, *)
    func setCenterCoordinateWithAltitude(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double, animated: Bool, duration: TimeInterval? = nil) {
        // clamp large numbers to 28
        let zoomL = min(zoomLevel, 28);

        // Flyover / realistic imagery: use a wide region so the map shows a 3D globe.
        let useGlobeRegion = (self as? FlutterMapView)?.prefersGlobeProjection == true && zoomL <= 2
        if useGlobeRegion {
            let span = MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            let region = MKCoordinateRegion(center: centerCoordinate, span: span)
            runMapAnimation(animated: animated, duration: duration) {
                self.setRegion(region, animated: animated)
            }
            if !animated {
                self.camera.pitch = Holder._pitch
                self.camera.heading = Holder._heading
            }
            return
        }

        let altitude = getCameraAltitude(centerCoordinate: centerCoordinate, zoomLevel: zoomL)
        let camera = MKMapCamera(lookingAtCenter: centerCoordinate, fromDistance: CLLocationDistance(altitude), pitch: Holder._pitch, heading: Holder._heading)
        runMapAnimation(animated: animated, duration: duration) {
            self.setCamera(camera, animated: animated)
        }
    }
    
    private func getCameraAltitude(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double) -> Double {
        // convert center coordiate to pixel space
        let centerPixelY = Utils.latitudeToPixelSpaceY(latitude: centerCoordinate.latitude)
        // determine the scale value from the zoom level
        let zoomExponent:Double = 21.0 - zoomLevel
        let zoomScale:Double = pow(2.0, zoomExponent)
        // scale the map’s size in pixel space
        let mapSizeInPixels = self.bounds.size
        let scaledMapHeight = Double(mapSizeInPixels.height) * zoomScale
        // figure out the position of the top-left pixel
        let topLeftPixelY = centerPixelY - (scaledMapHeight / 2.0)
        // find delta between left and right longitudes
        let maxLat = Utils.pixelSpaceYToLatitude(pixelY: topLeftPixelY + scaledMapHeight)
        let topBottom = CLLocationCoordinate2D.init(latitude: maxLat, longitude: centerCoordinate.longitude)
        
        let distance = MKMapPoint.init(centerCoordinate).distance(to: MKMapPoint.init(topBottom))
        let altitude = distance / tan(.pi*(15/180.0))
        
        return altitude
    }
    
    func getVisibleRegion() -> Dictionary<String, Array<Double>> {
        if self.bounds.size != CGSize.zero {
            // convert center coordiate to pixel space
            let centerPixelX = Utils.longitudeToPixelSpaceX(longitude: self.centerCoordinate.longitude)
            let centerPixelY = Utils.latitudeToPixelSpaceY(latitude: self.centerCoordinate.latitude)

            // determine the scale value from the zoom level
            let zoomExponent = Double(21 - Holder._zoomLevel)
            let zoomScale = pow(2.0, zoomExponent)

            // scale the map’s size in pixel space
            let mapSizeInPixels = self.bounds.size
            let scaledMapWidth = Double(mapSizeInPixels.width) * zoomScale
            let scaledMapHeight = Double(mapSizeInPixels.height) * zoomScale;

            // figure out the position of the top-left pixel
            let topLeftPixelX = centerPixelX - (scaledMapWidth / 2);
            let topLeftPixelY = centerPixelY - (scaledMapHeight / 2);

            // find the southwest coordinate
            let minLng = Utils.pixelSpaceXToLongitude(pixelX: topLeftPixelX)
            let minLat = Utils.pixelSpaceYToLatitude(pixelY: topLeftPixelY)

            // find the northeast coordinate
            let maxLng = Utils.pixelSpaceXToLongitude(pixelX: topLeftPixelX + scaledMapWidth)
            let maxLat = Utils.pixelSpaceYToLatitude(pixelY: topLeftPixelY + scaledMapHeight)

            return ["northeast": [minLat, maxLng], "southwest": [maxLat, minLng]]
        }
        return ["northeast": [0.0, 0.0], "southwest": [0.0, 0.0]]
    }
    
    func zoomIn(animated: Bool, duration: TimeInterval? = nil) {
        if Holder._zoomLevel - 1 <= Holder._maxZoomLevel {
            if Holder._zoomLevel < 2 {
                Holder._zoomLevel = 2
            }
            Holder._zoomLevel += 1
            if #available(iOS 9.0, *) {
                self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated, duration: duration)
            } else {
                self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated, duration: duration)
            }
        }
    }
    
    func zoomOut(animated: Bool, duration: TimeInterval? = nil) {
        if Holder._zoomLevel - 1 >= Holder._minZoomLevel {
            Holder._zoomLevel -= 1
            if round(Holder._zoomLevel) <= 2 {
               Holder._zoomLevel = 0
            }

            if #available(iOS 9.0, *) {
               self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated, duration: duration)
            } else {
               self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated, duration: duration)
            }
        }
    }
    
    func zoomTo(newZoomLevel: Double, animated: Bool, duration: TimeInterval? = nil) {
        if newZoomLevel < Holder._minZoomLevel {
            Holder._zoomLevel = Holder._minZoomLevel
        } else if newZoomLevel > Holder._maxZoomLevel {
            Holder._zoomLevel = Holder._maxZoomLevel
        } else {
            Holder._zoomLevel = newZoomLevel
        }

        if #available(iOS 9.0, *) {
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated, duration: duration)
        } else {
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated, duration: duration)
        }
    }
    
    func zoomBy(zoomBy: Double, animated: Bool, duration: TimeInterval? = nil) {
        if Holder._zoomLevel + zoomBy < Holder._minZoomLevel {
            Holder._zoomLevel = Holder._minZoomLevel
        } else if Holder._zoomLevel + zoomBy > Holder._maxZoomLevel {
            Holder._zoomLevel = Holder._maxZoomLevel
        } else {
            Holder._zoomLevel = Holder._zoomLevel + zoomBy
        }
        
        if #available(iOS 9.0, *) {
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated, duration: duration)
        } else {
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated, duration: duration)
        }
    }
    
    func updateStoredCameraValues(newZoomLevel: Double, newPitch: CGFloat, newHeading: CLLocationDirection) {
        Holder._zoomLevel = newZoomLevel
        Holder._pitch = newPitch
        Holder._heading = newHeading
    }

    /// Positions the camera for a single orbit frame: looks at `center` (optionally
    /// offset so the focused point stays off-screen-center) with the given
    /// `heading`/`pitch`/`zoomLevel`, without animation. Designed to be called
    /// every frame from a `CADisplayLink` so the heading sweep is driven natively
    /// instead of round-tripping through the Flutter method channel.
    ///
    /// `verticalScreenOffset` is expressed in screen points: a positive value
    /// shifts the camera target opposite the heading so the orbit center appears
    /// that many points above the screen center (mirrors the focus-padding
    /// emulation previously done in Dart).
    func setOrbitCamera(center: CLLocationCoordinate2D, zoomLevel: Double, pitch: CGFloat, heading: CLLocationDirection, verticalScreenOffset: Double) {
        Holder._zoomLevel = zoomLevel
        Holder._pitch = pitch
        Holder._heading = heading

        var targetCenter = center
        if abs(verticalScreenOffset) > 0.5 {
            let metersPerPixel = 156543.03392 * cos(center.latitude * .pi / 180.0) / pow(2.0, zoomLevel)
            let offsetMeters = verticalScreenOffset * metersPerPixel
            let offsetBearing = (heading + 180.0).truncatingRemainder(dividingBy: 360.0)
            targetCenter = MKMapView.offsetCoordinate(center, distanceMeters: offsetMeters, bearingDegrees: offsetBearing)
        }

        if #available(iOS 9.0, *) {
            let zoomL = min(zoomLevel, 28)
            let altitude = getCameraAltitude(centerCoordinate: targetCenter, zoomLevel: zoomL)
            let camera = MKMapCamera(lookingAtCenter: targetCenter, fromDistance: CLLocationDistance(altitude), pitch: pitch, heading: heading)
            self.setCamera(camera, animated: false)
        } else {
            setCenterCoordinateRegion(centerCoordinate: targetCenter, zoomLevel: zoomLevel, animated: false)
        }
    }

    /// Returns the coordinate reached by travelling `distanceMeters` along the
    /// great-circle `bearingDegrees` (clockwise from north) from `coord`.
    static func offsetCoordinate(_ coord: CLLocationCoordinate2D, distanceMeters: Double, bearingDegrees: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6378137.0
        let bearing = bearingDegrees * .pi / 180.0
        let angularDistance = distanceMeters / earthRadius
        let lat1 = coord.latitude * .pi / 180.0
        let lon1 = coord.longitude * .pi / 180.0
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1),
                                cos(angularDistance) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180.0 / .pi, longitude: lon2 * 180.0 / .pi)
    }
}

extension Array where Element == CLLocationCoordinate2D {
    func mapRect() -> MKMapRect? {
        return map(MKMapPoint.init).mapRect()
    }
}

extension Array where Element == CLLocation {
    func mapRect() -> MKMapRect? {
        return map { MKMapPoint($0.coordinate) }.mapRect()
    }
}

extension Array where Element == MKMapPoint {
    func mapRect() -> MKMapRect? {
        guard count > 0 else { return nil }

        let xs = map { $0.x }
        let ys = map { $0.y }

        let west = xs.min()!
        let east = xs.max()!
        let width = east - west

        let south = ys.min()!
        let north = ys.max()!
        let height = north - south

        return MKMapRect(x: west, y: south, width: width, height: height)
    }
}
