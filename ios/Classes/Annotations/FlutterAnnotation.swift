//
//  FlutterAnnotation.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 07.03.20.
//

import Foundation
import MapKit
import UIKit

enum DopinMarkerStyle: String {
    case me, event, dopin, cluster
}

class FlutterAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var id: String!
    var title: String?
    var subtitle: String?
    var infoWindowConsumesTapEvents: Bool = false
    var image: UIImage?
    var alpha: Double?
    var anchor: Offset = Offset()
    var isDraggable: Bool?
    var wasDragged: Bool = false
    var isVisible: Bool? = true
    var zIndex: Double = -1
    var calloutOffset: Offset = Offset()
    var icon: AnnotationIcon = AnnotationIcon.init()
    var selectedProgrammatically: Bool = false
    var glow: Bool = false
    /// Flutter `Color` value (0xAARRGGBB).
    var glowColorArgb: UInt32 = 0xFF_EC30E4
    var glowIntensity: Double = 1.0

    var dopinMarkerStyle: DopinMarkerStyle?
    var dopinImageUrl: String?
    var dopinImagePngData: Data?
    var dopinImageAssetName: String?
    var dopinImageAssetScale: CGFloat = 1.0
    var dopinMarkerLabel: String?
    var dopinClusterCount: Int = 1
    var dopinPrimaryColor: UIColor = UIColor(red: 123/255, green: 44/255, blue: 191/255, alpha: 1)
    var dopinSecondPrimaryColor: UIColor = UIColor(red: 236/255, green: 48/255, blue: 228/255, alpha: 1)
    var dopinBorderColor: UIColor = .white

    var dopinMarkerSignature: String {
        let style = dopinMarkerStyle?.rawValue ?? ""
        let pngLen = dopinImagePngData?.count ?? 0
        let asset = dopinImageAssetName ?? ""
        return "\(style)|\(dopinImageUrl ?? "")|\(pngLen)|\(asset)|\(dopinImageAssetScale)|\(dopinMarkerLabel ?? "")|\(dopinClusterCount)|\(dopinPrimaryColor)|\(dopinSecondPrimaryColor)|\(dopinBorderColor)"
    }

    public init(fromDictionary annotationData: Dictionary<String, Any>, registrar: FlutterPluginRegistrar) {
        let position: Array<Double> = annotationData["position"] as! Array<Double>
        let infoWindow: Dictionary<String, Any> = annotationData["infoWindow"] as! Dictionary<String, Any>
        let lat: Double = position[0]
        let long: Double = position[1]
        self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        self.title = infoWindow["title"] as? String
        self.subtitle = infoWindow["snippet"] as? String
        self.infoWindowConsumesTapEvents = infoWindow["consumesTapEvents"] as? Bool ?? false
        self.id = annotationData["annotationId"] as? String
        self.isVisible = annotationData["visible"] as? Bool
        self.isDraggable = annotationData["draggable"] as? Bool
        if let zIndex = annotationData["zIndex"] as? Double {
            self.zIndex = zIndex
        }
        
        if let alpha: Double = annotationData["alpha"] as? Double {
            self.alpha = alpha
        }
        
        if let anchorJSON: Array<Double> = annotationData["anchor"] as? Array<Double> {
            self.anchor = Offset(from: anchorJSON)
        }
        
        if let iconData: Array<Any> = annotationData["icon"] as? Array<Any> {
            self.icon = FlutterAnnotation.getAnnotationIcon(iconData: iconData, registrar: registrar, annotationId: id)
        }
        
        if let calloutOffsetJSON = infoWindow["anchor"] as? Array<Double> {
            self.calloutOffset = Offset(from: calloutOffsetJSON)
        }

        self.glow = annotationData["glow"] as? Bool ?? false
        if let n = annotationData["glowColor"] as? NSNumber {
            self.glowColorArgb = n.uint32Value
        } else if let i = annotationData["glowColor"] as? Int64 {
            self.glowColorArgb = UInt32(truncatingIfNeeded: UInt64(i))
        } else if let i = annotationData["glowColor"] as? Int {
            self.glowColorArgb = UInt32(truncatingIfNeeded: UInt64(i))
        }
        if let gi = annotationData["glowIntensity"] as? Double {
            self.glowIntensity = min(max(gi, 0), 1)
        } else         if let gi = annotationData["glowIntensity"] as? NSNumber {
            self.glowIntensity = min(max(gi.doubleValue, 0), 1)
        }

        if let dopin = annotationData["dopinMarker"] as? Dictionary<String, Any> {
            if let styleName = dopin["style"] as? String {
                self.dopinMarkerStyle = DopinMarkerStyle(rawValue: styleName)
            }
            self.dopinImageUrl = dopin["imageUrl"] as? String
            if let png = dopin["imagePng"] as? FlutterStandardTypedData {
                self.dopinImagePngData = png.data
            }
            if let assetData = dopin["imageFromAsset"] as? Array<Any> {
                let assetPath = assetData[0] as! String
                self.dopinImageAssetScale = CGFloat(assetData[1] as? Double ?? 1.0)
                self.dopinImageAssetName = registrar.lookupKey(forAsset: assetPath)
            }
            self.dopinMarkerLabel = dopin["label"] as? String
            if let count = dopin["clusterCount"] as? Int {
                self.dopinClusterCount = count
            } else if let count = dopin["clusterCount"] as? NSNumber {
                self.dopinClusterCount = count.intValue
            }
            if let primary = dopin["primaryColor"] as? NSNumber {
                self.dopinPrimaryColor = Self.uiColorFromArgb(primary.uint32Value)
            } else if let primary = dopin["primaryColor"] as? Int {
                self.dopinPrimaryColor = Self.uiColorFromArgb(UInt32(primary))
            }
            if let second = dopin["secondPrimaryColor"] as? NSNumber {
                self.dopinSecondPrimaryColor = Self.uiColorFromArgb(second.uint32Value)
            } else if let second = dopin["secondPrimaryColor"] as? Int {
                self.dopinSecondPrimaryColor = Self.uiColorFromArgb(UInt32(second))
            }
            if let border = dopin["borderColor"] as? NSNumber {
                self.dopinBorderColor = Self.uiColorFromArgb(border.uint32Value)
            } else if let border = dopin["borderColor"] as? Int {
                self.dopinBorderColor = Self.uiColorFromArgb(UInt32(border))
            }
        }
    }

    private static func uiColorFromArgb(_ value: UInt32) -> UIColor {
        let a = CGFloat((value >> 24) & 0xFF) / 255.0
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a > 0 ? a : 1)
    }
    
    
    static private func getAnnotationIcon(iconData: Array<Any>, registrar: FlutterPluginRegistrar, annotationId: String) -> AnnotationIcon {
        let iconTypeMap: Dictionary<String, IconType> = ["fromAssetImage": .CUSTOM_FROM_ASSET, "fromBytes": .CUSTOM_FROM_BYTES, "defaultAnnotation": .PIN, "markerAnnotation": .MARKER]
        let iconType: IconType = iconTypeMap[iconData[0] as! String] ?? .PIN
        var icon: AnnotationIcon =  AnnotationIcon(id: annotationId, iconType: iconType)
        var scaleParam: CGFloat?
        
        if iconType == .CUSTOM_FROM_ASSET {
            let assetPath: String = iconData[1] as! String
            scaleParam = CGFloat(iconData[2] as? Double ?? 1.0)
            icon = AnnotationIcon(withAsset: registrar.lookupKey(forAsset: assetPath), id: annotationId, iconScale: scaleParam)
        } else if iconType == .CUSTOM_FROM_BYTES {
            icon = AnnotationIcon(fromBytes: iconData[1] as! FlutterStandardTypedData, id: annotationId)
        } else if iconData.count > 1 {
            icon = AnnotationIcon(id: annotationId, iconType: iconType, hueColor: iconData[1] as! Double)
            
        }
        return icon
    }
    
    static func == (lhs: FlutterAnnotation, rhs: FlutterAnnotation) -> Bool {
        return lhs.id == rhs.id && lhs.title == rhs.title && lhs.subtitle == rhs.subtitle && lhs.image == rhs.image && lhs.alpha == rhs.alpha && lhs.isDraggable == rhs.isDraggable && lhs.wasDragged == rhs.wasDragged && lhs.isVisible == rhs.isVisible && lhs.icon == rhs.icon && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude && lhs.infoWindowConsumesTapEvents == rhs.infoWindowConsumesTapEvents && lhs.anchor == rhs.anchor && lhs.calloutOffset == rhs.calloutOffset && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude && lhs.zIndex == rhs.zIndex && lhs.glow == rhs.glow && lhs.glowColorArgb == rhs.glowColorArgb && lhs.glowIntensity == rhs.glowIntensity && lhs.dopinMarkerStyle == rhs.dopinMarkerStyle && lhs.dopinImageUrl == rhs.dopinImageUrl && lhs.dopinImagePngData == rhs.dopinImagePngData && lhs.dopinImageAssetName == rhs.dopinImageAssetName && lhs.dopinImageAssetScale == rhs.dopinImageAssetScale && lhs.dopinMarkerLabel == rhs.dopinMarkerLabel && lhs.dopinClusterCount == rhs.dopinClusterCount && lhs.dopinPrimaryColor == rhs.dopinPrimaryColor && lhs.dopinSecondPrimaryColor == rhs.dopinSecondPrimaryColor && lhs.dopinBorderColor == rhs.dopinBorderColor
    }
    
    static func != (lhs: FlutterAnnotation, rhs: FlutterAnnotation) -> Bool {
        return !(lhs == rhs)
    }
}

struct Offset {
    let x: Double
    let y: Double
    
    public init(from json: Array<Double>) {
        self.x = json[0]
        self.y = json[1]
    }
    
    public init() {
        self.x = 0
        self.y = 0
    }
    
    static func == (lhs: Offset, rhs: Offset) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
    
    static func != (lhs: Offset, rhs: Offset) -> Bool {
        return !(lhs == rhs)
    }
}
