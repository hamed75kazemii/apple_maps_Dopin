//
//  FlutterAnnotation.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 07.03.20.
//

import Foundation
import MapKit
import UIKit

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
    /// Normalized origin of glow pulses within marker bounds.
    var glowAnchor: Offset = Offset(x: 0.5, y: 0.5)

    var markerShadowEnabled: Bool = false
    var markerShadowColor: UIColor = UIColor.black.withAlphaComponent(0.3)
    var markerShadowBlurRadius: CGFloat = 18
    var markerShadowOffsetX: CGFloat = 0
    var markerShadowOffsetY: CGFloat = 4

    var usesDopinMarker: Bool = false
    var dopinImageUrls: [String] = []
    var dopinImagePngData: Data?
    var dopinImageAssetName: String?
    var dopinImageAssetScale: CGFloat = 1.0
    var dopinMarkerLabel: String?
    var dopinMarkerCount: Int?
    var dopinFrameWidth: CGFloat = 40
    var dopinFrameHeight: CGFloat = 40
    var dopinBorderWidth: CGFloat = 2
    var dopinBorderColor: UIColor = .white
    /// `nil` = draw as circle on native side.
    var dopinBorderRadius: CGFloat?
    var dopinLabelFontSize: CGFloat = 10
    var dopinBadgeHeight: CGFloat = 18
    var dopinLabelColor: UIColor = UIColor(red: 123/255, green: 44/255, blue: 191/255, alpha: 1)

    var usesSvgMarker: Bool = false
    var svgWidth: CGFloat = 38
    var svgHeight: CGFloat = 50
    var svgImageUrl: String?
    var svgImagePngData: Data?

    var dopinMarkerSignature: String {
        let pngLen = dopinImagePngData?.count ?? 0
        let asset = dopinImageAssetName ?? ""
        let radius = dopinBorderRadius.map { "\($0)" } ?? "circle"
        let urls = dopinImageUrls.joined(separator: ",")
        return "\(urls)|\(pngLen)|\(asset)|\(dopinImageAssetScale)|\(dopinMarkerLabel ?? "")|\(dopinMarkerCount.map { "\($0)" } ?? "")|\(dopinFrameWidth)|\(dopinFrameHeight)|\(dopinBorderWidth)|\(dopinBorderColor)|\(radius)|\(dopinLabelFontSize)|\(dopinBadgeHeight)|\(dopinLabelColor)"
    }

    var svgMarkerSignature: String {
        let pngLen = svgImagePngData?.count ?? 0
        return "\(svgWidth)|\(svgHeight)|\(svgImageUrl ?? "")|\(pngLen)"
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
        if let glowAnchorJSON = annotationData["glowAnchor"] as? Array<Double> {
            self.glowAnchor = Offset(from: glowAnchorJSON)
        }

        if let shadow = annotationData["shadow"] as? Dictionary<String, Any> {
            self.markerShadowEnabled = true
            if let color = shadow["color"] as? NSNumber {
                self.markerShadowColor = Self.uiColorFromArgb(color.uint32Value)
            } else if let color = shadow["color"] as? Int {
                self.markerShadowColor = Self.uiColorFromArgb(UInt32(color))
            }
            if let blur = Self.cg(shadow["blurRadius"]) {
                self.markerShadowBlurRadius = blur
            }
            if let offset = shadow["offset"] as? Array<Double>, offset.count >= 2 {
                self.markerShadowOffsetX = CGFloat(offset[0])
                self.markerShadowOffsetY = CGFloat(offset[1])
            }
        }

        if let dopin = annotationData["dopinMarker"] as? Dictionary<String, Any> {
            self.usesDopinMarker = true
            let layout = dopin["layout"] as? Dictionary<String, Any>
            if let urlList = dopin["imageUrls"] as? [String] {
                self.dopinImageUrls = Array(urlList.prefix(4).filter { !$0.isEmpty })
            } else if let url = dopin["imageUrl"] as? String, !url.isEmpty {
                self.dopinImageUrls = [url]
            }
            if let png = dopin["imagePng"] as? FlutterStandardTypedData {
                self.dopinImagePngData = png.data
            }
            if let assetData = dopin["imageFromAsset"] as? Array<Any> {
                let assetPath = assetData[0] as! String
                self.dopinImageAssetScale = CGFloat(assetData[1] as? Double ?? 1.0)
                self.dopinImageAssetName = registrar.lookupKey(forAsset: assetPath)
            }
            if let label = dopin["label"] as? String {
                let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                self.dopinMarkerLabel = trimmed.isEmpty ? nil : trimmed
            }
            if let count = dopin["count"] as? NSNumber {
                let value = count.intValue
                self.dopinMarkerCount = value > 0 ? value : nil
            } else if let count = dopin["count"] as? Int {
                self.dopinMarkerCount = count > 0 ? count : nil
            }
            if let w = Self.cg(dopin["width"]) ?? Self.cg(layout?["width"]) ?? Self.cg(layout?["innerWidth"]) {
                self.dopinFrameWidth = w
            }
            if let h = Self.cg(dopin["height"]) ?? Self.cg(layout?["height"]) ?? Self.cg(layout?["innerHeight"]) {
                self.dopinFrameHeight = h
            }
            if let bw = Self.cg(dopin["borderWidth"]) ?? Self.cg(layout?["borderWidth"]) {
                self.dopinBorderWidth = bw
            }
            if let br = Self.cg(dopin["borderRadius"]) ?? Self.cg(layout?["borderRadius"]) {
                self.dopinBorderRadius = br
            }
            if let border = dopin["borderColor"] as? NSNumber {
                self.dopinBorderColor = Self.uiColorFromArgb(border.uint32Value)
            } else if let border = dopin["borderColor"] as? Int {
                self.dopinBorderColor = Self.uiColorFromArgb(UInt32(border))
            }
            if let lc = dopin["labelColor"] as? NSNumber {
                self.dopinLabelColor = Self.uiColorFromArgb(lc.uint32Value)
            } else if let lc = dopin["labelColor"] as? Int {
                self.dopinLabelColor = Self.uiColorFromArgb(UInt32(lc))
            }
            if let lfs = Self.cg(dopin["labelFontSize"]) ?? Self.cg(layout?["labelFontSize"]) {
                self.dopinLabelFontSize = lfs
            }
            if let bh = Self.cg(dopin["badgeHeight"]) ?? Self.cg(layout?["badgeHeight"]) {
                self.dopinBadgeHeight = bh
            }
        }

        if let svg = annotationData["svgMarker"] as? Dictionary<String, Any> {
            self.usesSvgMarker = true
            if let w = Self.cg(svg["width"]) {
                self.svgWidth = w
            }
            if let h = Self.cg(svg["height"]) {
                self.svgHeight = h
            }
            if let url = svg["imageUrl"] as? String, !url.isEmpty {
                self.svgImageUrl = url
            }
            if let png = svg["imagePng"] as? FlutterStandardTypedData {
                self.svgImagePngData = png.data
            }
        }
    }

    private static func cg(_ value: Any?) -> CGFloat? {
        if let d = value as? Double { return CGFloat(d) }
        if let n = value as? NSNumber { return CGFloat(n.doubleValue) }
        return nil
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
        return lhs.id == rhs.id && lhs.title == rhs.title && lhs.subtitle == rhs.subtitle && lhs.image == rhs.image && lhs.alpha == rhs.alpha && lhs.isDraggable == rhs.isDraggable && lhs.wasDragged == rhs.wasDragged && lhs.isVisible == rhs.isVisible && lhs.icon == rhs.icon && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude && lhs.infoWindowConsumesTapEvents == rhs.infoWindowConsumesTapEvents && lhs.anchor == rhs.anchor && lhs.calloutOffset == rhs.calloutOffset && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude && lhs.zIndex == rhs.zIndex && lhs.glow == rhs.glow && lhs.glowColorArgb == rhs.glowColorArgb && lhs.glowIntensity == rhs.glowIntensity && lhs.glowAnchor == rhs.glowAnchor && lhs.markerShadowEnabled == rhs.markerShadowEnabled && lhs.markerShadowColor == rhs.markerShadowColor && lhs.markerShadowBlurRadius == rhs.markerShadowBlurRadius && lhs.markerShadowOffsetX == rhs.markerShadowOffsetX && lhs.markerShadowOffsetY == rhs.markerShadowOffsetY && lhs.usesDopinMarker == rhs.usesDopinMarker && lhs.dopinImageUrls == rhs.dopinImageUrls && lhs.dopinImagePngData == rhs.dopinImagePngData && lhs.dopinImageAssetName == rhs.dopinImageAssetName && lhs.dopinImageAssetScale == rhs.dopinImageAssetScale && lhs.dopinMarkerLabel == rhs.dopinMarkerLabel && lhs.dopinMarkerCount == rhs.dopinMarkerCount && lhs.dopinFrameWidth == rhs.dopinFrameWidth && lhs.dopinFrameHeight == rhs.dopinFrameHeight && lhs.dopinBorderWidth == rhs.dopinBorderWidth && lhs.dopinBorderColor == rhs.dopinBorderColor && lhs.dopinBorderRadius == rhs.dopinBorderRadius && lhs.dopinLabelFontSize == rhs.dopinLabelFontSize && lhs.dopinBadgeHeight == rhs.dopinBadgeHeight && lhs.dopinLabelColor == rhs.dopinLabelColor && lhs.usesSvgMarker == rhs.usesSvgMarker && lhs.svgWidth == rhs.svgWidth && lhs.svgHeight == rhs.svgHeight && lhs.svgImageUrl == rhs.svgImageUrl && lhs.svgImagePngData == rhs.svgImagePngData
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

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    static func == (lhs: Offset, rhs: Offset) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
    
    static func != (lhs: Offset, rhs: Offset) -> Bool {
        return !(lhs == rhs)
    }
}
