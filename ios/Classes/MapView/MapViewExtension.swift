//
//  MapViewExtension.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 22.09.19.
//

import Foundation
import UIKit
import MapKit
import ObjectiveC

private var ampZoomLevelKey: UInt8 = 0
private var ampPitchKey: UInt8 = 0
private var ampHeadingKey: UInt8 = 0
private var ampMaxZoomLevelKey: UInt8 = 0
private var ampMinZoomLevelKey: UInt8 = 0

public extension MKMapView {
    private var storedZoomLevel: Double {
        get { (objc_getAssociatedObject(self, &ampZoomLevelKey) as? NSNumber)?.doubleValue ?? 0 }
        set { objc_setAssociatedObject(self, &ampZoomLevelKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var storedPitch: CGFloat {
        get {
            if let number = objc_getAssociatedObject(self, &ampPitchKey) as? NSNumber {
                return CGFloat(number.doubleValue)
            }
            return 0
        }
        set { objc_setAssociatedObject(self, &ampPitchKey, NSNumber(value: Double(newValue)), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var storedHeading: CLLocationDirection {
        get { (objc_getAssociatedObject(self, &ampHeadingKey) as? NSNumber)?.doubleValue ?? 0 }
        set { objc_setAssociatedObject(self, &ampHeadingKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var storedMaxZoomLevel: Double {
        get { (objc_getAssociatedObject(self, &ampMaxZoomLevelKey) as? NSNumber)?.doubleValue ?? 21 }
        set { objc_setAssociatedObject(self, &ampMaxZoomLevelKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var storedMinZoomLevel: Double {
        get { (objc_getAssociatedObject(self, &ampMinZoomLevelKey) as? NSNumber)?.doubleValue ?? 2 }
        set { objc_setAssociatedObject(self, &ampMinZoomLevelKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var maxZoomLevel: Double {
        set(_maxZoomLevel) {
            storedMaxZoomLevel = _maxZoomLevel
            if storedZoomLevel > _maxZoomLevel {
                if #available(iOS 9.0, *) {
                    self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: _maxZoomLevel, animated: false)
                } else {
                    self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: _maxZoomLevel, animated: false)
                }
            }
        }
        get {
            return storedMaxZoomLevel
        }
    }
    
    var minZoomLevel: Double {
        set(_minZoomLevel) {
            storedMinZoomLevel = _minZoomLevel
            if storedZoomLevel < _minZoomLevel {
                if #available(iOS 9.0, *) {
                   self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: _minZoomLevel, animated: false)
                } else {
                   self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: _minZoomLevel, animated: false)
                }
            }
        }
        get {
           return storedMinZoomLevel
        }
    }
    
    var zoomLevel: Double {
        get {
            return storedZoomLevel
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
            
            storedZoomLevel = zoomLevel
            
            return zoomLevel
            
        }
        set (newZoomLevel) {
            storedZoomLevel = newZoomLevel
        }
    }
    
    func setCenterCoordinate(_ positionData: Dictionary<String, Any>, animated: Bool) {
        let targetList :Array<CLLocationDegrees> = positionData["target"] as? Array<CLLocationDegrees> ?? [self.camera.centerCoordinate.latitude, self.camera.centerCoordinate.longitude]
        let zoom :Double = positionData["zoom"] as? Double ?? storedZoomLevel
        storedZoomLevel = zoom
        if let pitch :CGFloat = positionData["pitch"] as? CGFloat {
            storedPitch = pitch
        }
        if let heading :CLLocationDirection = positionData["heading"] as? CLLocationDirection {
            storedHeading = heading
        }
        let centerCoordinate :CLLocationCoordinate2D = CLLocationCoordinate2D(latitude:  targetList[0], longitude: targetList[1])
        if #available(iOS 9.0, *) {
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: zoom, animated: animated)
        } else {
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: zoom, animated: animated)
        }
    }
    
    func setBounds(_ positionData: Dictionary<String, Any>, animated: Bool) {
        guard let targetList :Array<Array<CLLocationDegrees>> = positionData["target"] as? Array<Array<CLLocationDegrees>> else { return }
        let padding :Double = positionData["padding"] as? Double ?? 0
        let coodinates: Array<CLLocationCoordinate2D> = targetList.map { (coordinate : Array<CLLocationDegrees>) in
            return CLLocationCoordinate2D(latitude:  coordinate[0], longitude: coordinate[1])
        }
        guard let mapRect = coodinates.mapRect() else { return }
        self.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: CGFloat(padding), left: CGFloat(padding), bottom: CGFloat(padding), right: CGFloat(padding)), animated: animated)
    }
    
    func setCenterCoordinateRegion(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double, animated: Bool) {
        // clamp large numbers to 28
        let zoomL = min(zoomLevel, 28);
    
        // use the zoom level to compute the region
        let span = self.coordinateSpanWithMapView(centerCoordinate: centerCoordinate, zoomLevel: Int(zoomL))
        let region = MKCoordinateRegion.init(center: centerCoordinate, span: span)
        
        // set the region like normal
        self.setRegion(region, animated: animated)
        
        // Setting the pitch/heading doesn't work while animating yet.
        // The animation will stop if the you change camera properties while it's running.
        if (!animated) {
            self.camera.pitch = storedPitch
            self.camera.heading = storedHeading
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
    func setCenterCoordinateWithAltitude(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double, animated: Bool) {
        // clamp large numbers to 28
        let zoomL = min(zoomLevel, 28);

        // Flyover / realistic imagery: use a wide region so the map shows a 3D globe.
        let useGlobeRegion = (self as? FlutterMapView)?.prefersGlobeProjection == true && zoomL <= 2
        if useGlobeRegion {
            let span = MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            let region = MKCoordinateRegion(center: centerCoordinate, span: span)
            self.setRegion(region, animated: animated)
            if !animated {
                self.camera.pitch = storedPitch
                self.camera.heading = storedHeading
            }
            return
        }

        let altitude = getCameraAltitude(centerCoordinate: centerCoordinate, zoomLevel: zoomL)
        self.setCamera(MKMapCamera(lookingAtCenter: centerCoordinate, fromDistance: CLLocationDistance(altitude), pitch: storedPitch, heading: storedHeading), animated: animated)
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
            let zoomExponent = Double(21 - storedZoomLevel)
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
    
    func zoomIn(animated: Bool) {
        if storedZoomLevel - 1 <= storedMaxZoomLevel {
            if storedZoomLevel < 2 {
                storedZoomLevel = 2
            }
            storedZoomLevel += 1
            if #available(iOS 9.0, *) {
                self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: storedZoomLevel, animated: animated)
            } else {
                self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: storedZoomLevel, animated: animated)
            }
        }
    }
    
    func zoomOut(animated: Bool) {
        if storedZoomLevel - 1 >= storedMinZoomLevel {
            storedZoomLevel -= 1
            if round(storedZoomLevel) <= 2 {
               storedZoomLevel = 0
            }

            if #available(iOS 9.0, *) {
               self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: storedZoomLevel, animated: animated)
            } else {
               self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: storedZoomLevel, animated: animated)
            }
        }
    }
    
    func zoomTo(newZoomLevel: Double, animated: Bool) {
        if newZoomLevel < storedMinZoomLevel {
            storedZoomLevel = storedMinZoomLevel
        } else if newZoomLevel > storedMaxZoomLevel {
            storedZoomLevel = storedMaxZoomLevel
        } else {
            storedZoomLevel = newZoomLevel
        }

        if #available(iOS 9.0, *) {
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: storedZoomLevel, animated: animated)
        } else {
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: storedZoomLevel, animated: animated)
        }
    }
    
    func zoomBy(zoomBy: Double, animated: Bool) {
        if storedZoomLevel + zoomBy < storedMinZoomLevel {
            storedZoomLevel = storedMinZoomLevel
        } else if storedZoomLevel + zoomBy > storedMaxZoomLevel {
            storedZoomLevel = storedMaxZoomLevel
        } else {
            storedZoomLevel = storedZoomLevel + zoomBy
        }
        
        if #available(iOS 9.0, *) {
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: storedZoomLevel, animated: animated)
        } else {
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: storedZoomLevel, animated: animated)
        }
    }
    
    func updateStoredCameraValues(newZoomLevel: Double, newPitch: CGFloat, newHeading: CLLocationDirection) {
        storedZoomLevel = newZoomLevel
        storedPitch = newPitch
        storedHeading = newHeading
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
    ///
    /// `horizontalScreenOffset` is expressed in screen points: a positive value
    /// shifts the camera target toward screen-right so the focus appears that
    /// many points left of the screen center.
    func setOrbitCamera(center: CLLocationCoordinate2D, zoomLevel: Double, pitch: CGFloat, heading: CLLocationDirection, verticalScreenOffset: Double, horizontalScreenOffset: Double = 0) {
        storedZoomLevel = zoomLevel
        storedPitch = pitch
        storedHeading = heading

        let targetCenter = MKMapView.focusLookingAtCenter(
            center: center,
            zoomLevel: zoomLevel,
            heading: heading,
            verticalScreenOffset: verticalScreenOffset,
            horizontalScreenOffset: horizontalScreenOffset
        )

        if #available(iOS 9.0, *) {
            let zoomL = min(zoomLevel, 28)
            let altitude = getCameraAltitude(centerCoordinate: targetCenter, zoomLevel: zoomL)
            let camera = MKMapCamera(lookingAtCenter: targetCenter, fromDistance: CLLocationDistance(altitude), pitch: pitch, heading: heading)
            self.setCamera(camera, animated: false)
        } else {
            setCenterCoordinateRegion(centerCoordinate: targetCenter, zoomLevel: zoomLevel, animated: false)
        }
    }

    /// Geographic looking-at center that places `center` at the given screen
    /// offsets from the visual midpoint.
    static func focusLookingAtCenter(
        center: CLLocationCoordinate2D,
        zoomLevel: Double,
        heading: CLLocationDirection,
        verticalScreenOffset: Double,
        horizontalScreenOffset: Double = 0
    ) -> CLLocationCoordinate2D {
        var targetCenter = center
        let hasVertical = abs(verticalScreenOffset) > 0.5
        let hasHorizontal = abs(horizontalScreenOffset) > 0.5
        guard hasVertical || hasHorizontal else { return targetCenter }

        let metersPerPixel = 156543.03392 * cos(center.latitude * .pi / 180.0) / pow(2.0, zoomLevel)

        if hasVertical {
            let offsetMeters = verticalScreenOffset * metersPerPixel
            let offsetBearing = (heading + 180.0).truncatingRemainder(dividingBy: 360.0)
            targetCenter = MKMapView.offsetCoordinate(targetCenter, distanceMeters: offsetMeters, bearingDegrees: offsetBearing)
        }
        if hasHorizontal {
            let offsetMeters = horizontalScreenOffset * metersPerPixel
            let offsetBearing = (heading + 90.0).truncatingRemainder(dividingBy: 360.0)
            targetCenter = MKMapView.offsetCoordinate(targetCenter, distanceMeters: offsetMeters, bearingDegrees: offsetBearing)
        }
        return targetCenter
    }

    /// Inverse of [focusLookingAtCenter]: recovers the logical focus point from
    /// the camera's looking-at center when focus offsets are active.
    static func logicalFocusCenter(
        lookingAt: CLLocationCoordinate2D,
        zoomLevel: Double,
        heading: CLLocationDirection,
        verticalScreenOffset: Double,
        horizontalScreenOffset: Double = 0
    ) -> CLLocationCoordinate2D {
        var center = lookingAt
        let hasVertical = abs(verticalScreenOffset) > 0.5
        let hasHorizontal = abs(horizontalScreenOffset) > 0.5
        guard hasVertical || hasHorizontal else { return center }

        let metersPerPixel = 156543.03392 * cos(lookingAt.latitude * .pi / 180.0) / pow(2.0, zoomLevel)

        // Reverse horizontal first (opposite order of the forward transform).
        if hasHorizontal {
            let offsetMeters = horizontalScreenOffset * metersPerPixel
            let offsetBearing = (heading - 90.0 + 360.0).truncatingRemainder(dividingBy: 360.0)
            center = MKMapView.offsetCoordinate(center, distanceMeters: offsetMeters, bearingDegrees: offsetBearing)
        }
        if hasVertical {
            let offsetMeters = verticalScreenOffset * metersPerPixel
            let offsetBearing = heading.truncatingRemainder(dividingBy: 360.0)
            center = MKMapView.offsetCoordinate(center, distanceMeters: offsetMeters, bearingDegrees: offsetBearing)
        }
        return center
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
