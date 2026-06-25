//
//  AnnotationController.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 09.09.19.
//

import Foundation
import MapKit

extension AppleMapController: AnnotationDelegate {

    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView)  {
        if let annotation: FlutterAnnotation = view.annotation as? FlutterAnnotation  {
            self.currentlySelectedAnnotation = annotation.id
            if !annotation.selectedProgrammatically {
                if !self.isAnnotationInFront(zIndex: annotation.zIndex) {
                    self.moveToFront(annotation: annotation)
                }
                self.onAnnotationClick(annotation: annotation)
                // Deselect so the same marker can be tapped again (MapKit only fires didSelect once while selected).
                let annotationToDeselect = annotation
                DispatchQueue.main.async { [weak self] in
                    self?.mapView.deselectAnnotation(annotationToDeselect, animated: false)
                }
                if self.currentlySelectedAnnotation == annotation.id {
                    self.currentlySelectedAnnotation = nil
                }
            } else {
                annotation.selectedProgrammatically = false
            }

            if annotation.infoWindowConsumesTapEvents {
                let tapGestureRecognizer = InfoWindowTapGestureRecognizer(target: self, action: #selector(onCalloutTapped))
                tapGestureRecognizer.annotationId = annotation.id
                tapGestureRecognizer.annotationView = view
                view.addGestureRecognizer(tapGestureRecognizer)
            }
            return
        }
    }

    /// Built-in map features (`MKMapFeatureAnnotation`) are delivered through this
    /// delegate method (iOS 16+), not `mapView(_:didSelect view:)`. POI forwarding
    /// to Flutter is gated to iOS 17+ where `selectableMapFeatures` is supported.
    @available(iOS 16.0, *)
    public func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        if annotation is MKUserLocation || annotation is FlutterAnnotation {
            return
        }
        if #available(iOS 17.0, *) {
            self.handlePOISelectionIfNeeded(annotation)
        }
    }

    @available(iOS 17.0, *)
    private func handlePOISelectionIfNeeded(_ annotation: MKAnnotation?) {
        guard self.mapView.isPOITapEnabled else {
            return
        }
        guard let feature = annotation as? MKMapFeatureAnnotation else {
            return
        }

        let coordinate = feature.coordinate
        let name = feature.title
        let category = self.categoryString(for: feature.pointOfInterestCategory)

        var payload: [String: Any] = [
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
        ]
        if let name = name {
            payload["name"] = name
        }
        if let category = category {
            payload["category"] = category
        }
        self.appendIconFields(to: &payload, feature: feature, category: category)

        // Send immediately with the synchronously available data so Flutter
        // can react without waiting on the network. If MKMapItemRequest is
        // available we additionally resolve the richer MKMapItem and emit a
        // second `map#onPOITap` with the placemark coordinate / category.
        self.channel.invokeMethod("map#onPOITap", arguments: payload)

        let request = MKMapItemRequest(mapFeatureAnnotation: feature)
        request.getMapItem { [weak self] item, error in
            guard let self = self, error == nil, let item = item else {
                return
            }
            let placemarkCoordinate = item.placemark.coordinate
            var resolved: [String: Any] = [
                "latitude": placemarkCoordinate.latitude,
                "longitude": placemarkCoordinate.longitude,
            ]
            if let resolvedName = item.name ?? name {
                resolved["name"] = resolvedName
            }
            let resolvedCategory = self.categoryString(for: item.pointOfInterestCategory) ?? category
            if let resolvedCategory = resolvedCategory {
                resolved["category"] = resolvedCategory
            }
            self.appendIconFields(to: &resolved, feature: feature, category: resolvedCategory ?? category)
            self.channel.invokeMethod("map#onPOITap", arguments: resolved)
        }
    }

    @available(iOS 17.0, *)
    private func appendIconFields(
        to payload: inout [String: Any],
        feature: MKMapFeatureAnnotation,
        category: String?
    ) {
        if let category = category {
            // Maki-style slug (e.g. "Cafe" -> "cafe") for client icon lookup.
            payload["icon"] = category.prefix(1).lowercased() + category.dropFirst()
        }
        guard let iconStyle = feature.iconStyle else {
            return
        }
        if let pngData = iconStyle.image.pngData() {
            payload["iconPng"] = FlutterStandardTypedData(bytes: pngData)
        }
        payload["iconColor"] = self.colorToArgb(iconStyle.backgroundColor)
    }

    private func colorToArgb(_ color: UIColor) -> Int {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Int(alpha * 255.0) << 24)
            | (Int(red * 255.0) << 16)
            | (Int(green * 255.0) << 8)
            | Int(blue * 255.0)
    }

    private func categoryString(for category: MKPointOfInterestCategory?) -> String? {
        guard let category = category else { return nil }
        // MKPointOfInterestCategory rawValue is a stable string identifier such
        // as "MKPOICategoryCafe" - we strip the prefix so Flutter consumers
        // receive a clean, lowercase-ish identifier (e.g. "Cafe").
        let raw = category.rawValue
        let prefix = "MKPOICategory"
        if raw.hasPrefix(prefix) {
            return String(raw.dropFirst(prefix.count))
        }
        return raw
    }

    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        // Let MapKit provide its default rendering for selectable POI features
        // (`MKMapFeatureAnnotation`, iOS 17+) - we only customise FlutterAnnotation views.
        if #available(iOS 17.0, *), annotation is MKMapFeatureAnnotation {
            return nil
        }
        if let flutterAnnotation = annotation as? FlutterAnnotation {
            return self.getAnnotationView(annotation: flutterAnnotation)
        }
        return nil
    }

    func getAnnotationView(annotation: FlutterAnnotation) -> MKAnnotationView {
        let identifier: String = annotation.id
        var annotationView = self.mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        let oldflutterAnnoation = annotationView?.annotation as? FlutterAnnotation
        let oldDopinSig = oldflutterAnnoation?.dopinMarkerSignature
        let newDopinSig = annotation.dopinMarkerSignature
        let dopinUsageChanged = oldflutterAnnoation?.usesDopinMarker != annotation.usesDopinMarker
        let oldSvgSig = oldflutterAnnoation?.svgMarkerSignature
        let newSvgSig = annotation.svgMarkerSignature
        let svgUsageChanged = oldflutterAnnoation?.usesSvgMarker != annotation.usesSvgMarker
        if annotationView == nil
            || oldflutterAnnoation?.icon.iconType != annotation.icon.iconType
            || oldflutterAnnoation?.glow != annotation.glow
            || dopinUsageChanged
            || svgUsageChanged
            || (annotation.usesDopinMarker && oldDopinSig != newDopinSig)
            || (annotation.usesSvgMarker && oldSvgSig != newSvgSig) {
            if annotation.usesSvgMarker {
                annotationView = getSvgMarkerAnnotationView(annotation: annotation, id: identifier)
            } else if annotation.usesDopinMarker {
                annotationView = getDopinMarkerAnnotationView(annotation: annotation, id: identifier)
            } else if #available(iOS 11.0, *), annotation.icon.iconType == IconType.MARKER {
                annotationView = getMarkerAnnotationView(annotation: annotation, id: identifier)
            } else if annotation.icon.iconType == .CUSTOM_FROM_ASSET || annotation.icon.iconType == .CUSTOM_FROM_BYTES {
                annotationView = getCustomAnnotationView(annotation: annotation, id: identifier)
            } else {
                annotationView = getPinAnnotationView(annotation: annotation, id: identifier)
            }
        }
        guard annotationView != nil else {
            return FlutterAnnotationView()
        }
        annotationView!.annotation = annotation
        if let dopinView = annotationView as? DopinMarkerAnnotationView {
            dopinView.configureIfNeeded()
        }
        if let svgView = annotationView as? SvgMarkerAnnotationView {
            svgView.configureIfNeeded()
        }
        if let flutterView = annotationView as? FlutterAnnotationView {
            flutterView.applyFlutterMarkerShadow()
        }
        // If annotation is not visible set alpha to 0 and don't let the user interact with it
        if !annotation.isVisible! {
            annotationView!.canShowCallout = false
            annotationView!.alpha = CGFloat(0.0)
            annotationView!.isDraggable = false
            return annotationView! as! FlutterAnnotationView
        }
        if annotation.icon.iconType != .MARKER {
            self.initInfoWindow(annotation: annotation, annotationView: annotationView!)
            if annotation.icon.iconType != .PIN || annotation.usesDopinMarker || annotation.usesSvgMarker {
                let x = (0.5 - annotation.anchor.x) * Double(annotationView!.frame.size.width)
                let y = (0.5 - annotation.anchor.y) * Double(annotationView!.frame.size.height)
                annotationView!.centerOffset = CGPoint(x: x, y: y)
            }
        }
        annotationView!.canShowCallout = true
        annotationView!.alpha = CGFloat(annotation.alpha ?? 1.00)
        annotationView!.isDraggable = annotation.isDraggable ?? false

        return annotationView!
    }

    func annotationsToAdd(annotations: NSArray) {
        for annotation in annotations {
            let annotationData: Dictionary<String, Any> = annotation as! Dictionary<String, Any>
            addAnnotation(annotationData: annotationData)
        }
    }

    func annotationsToChange(annotations: NSArray) {
        let oldAnnotations: [MKAnnotation] = self.mapView.annotations
        for annotation in annotations {
            let annotationData: Dictionary<String, Any> = annotation as! Dictionary<String, Any>
            if let annotationToChange = oldAnnotations.filter({($0 as? FlutterAnnotation)?.id == annotationData["annotationId"] as? String})[0] as? FlutterAnnotation {
                let newAnnotation = FlutterAnnotation.init(fromDictionary: annotationData, registrar: registrar)
                if annotationToChange != newAnnotation {
                    if !annotationToChange.wasDragged {
                        updateAnnotation(annotation: newAnnotation)
                    } else {
                        annotationToChange.wasDragged = false
                    }
                }
            }
        }
    }

    func annotationsIdsToRemove(annotationIds: NSArray) {
        for annotationId in annotationIds {
            if let _annotationId: String = annotationId as? String {
                removeAnnotation(id: _annotationId)
            }
        }
    }

    func removeAllAnnotations() {
        self.mapView.removeAnnotations(self.mapView.annotations)
    }

    func onAnnotationClick(annotation: MKAnnotation) {
        if let flutterAnnotation: FlutterAnnotation = annotation as? FlutterAnnotation {
            channel.invokeMethod("annotation#onTap", arguments: ["annotationId" : flutterAnnotation.id])
        }
    }

    func selectAnnotation(with id: String) {
        if let annotation: FlutterAnnotation = self.getAnnotation(with: id) {
            annotation.selectedProgrammatically = true
            self.mapView.selectAnnotation(annotation, animated: true)
        }
    }

    func hideAnnotation(with id: String) {
        if let annotation: FlutterAnnotation = self.getAnnotation(with: id) {
            self.mapView.deselectAnnotation(annotation, animated: true)
        }
    }

    func isAnnotationSelected(with id: String) -> Bool {
        return self.mapView.selectedAnnotations.contains(where: { annotation in return self.getAnnotation(with: id) == (annotation as? FlutterAnnotation)})
    }


    private func removeAnnotation(id: String) {
        if let flutterAnnotation: FlutterAnnotation = self.getAnnotation(with: id) {
            self.mapView.removeAnnotation(flutterAnnotation)
        }
    }

    private func initInfoWindow(annotation: FlutterAnnotation, annotationView: MKAnnotationView) {
        let x = self.getInfoWindowXOffset(annotationView: annotationView, annotation: annotation)
        let y = self.getInfoWindowYOffset(annotationView: annotationView, annotation: annotation)
        annotationView.calloutOffset = CGPoint(x: x, y: y)
        if #available(iOS 9.0, *) {
            let lines = annotation.subtitle?.split(whereSeparator: { $0.isNewline })
            if lines != nil {
                let customCallout = UIStackView()
                customCallout.axis = .vertical
                customCallout.alignment = .fill
                customCallout.distribution = .fill
                for line in lines! {
                    let subtitle = UILabel()
                    subtitle.text = String(line)
                    customCallout.addArrangedSubview(subtitle)
                }
                annotationView.detailCalloutAccessoryView = customCallout
            }
        }
    }

    @objc func onCalloutTapped(infoWindowTap: InfoWindowTapGestureRecognizer) {
        if infoWindowTap.annotationId != nil && self.currentlySelectedAnnotation == infoWindowTap.annotationId! {
            self.channel.invokeMethod("infoWindow#onTap", arguments: ["annotationId": infoWindowTap.annotationId])
        }
        if infoWindowTap.annotationView != nil && self.currentlySelectedAnnotation != infoWindowTap.annotationId! {
            infoWindowTap.annotationView?.removeGestureRecognizer(infoWindowTap)
        }
    }

    private func getAnnotation(with id: String) -> FlutterAnnotation? {
        return self.mapView.annotations.filter { annotation in return (annotation as? FlutterAnnotation)?.id == id }.first as? FlutterAnnotation
    }

    private func annotationExists(with id: String) -> Bool {
        return self.getAnnotation(with: id) != nil
    }

    private func addAnnotation(annotationData: Dictionary<String, Any>) {
        let annotation: FlutterAnnotation = FlutterAnnotation(fromDictionary: annotationData, registrar: registrar)
        self.addAnnotation(annotation: annotation)
    }

    /**
     Checks if an Annotation with the same id exists and removes it before adding if necessary
     - Parameter annotation: the FlutterAnnotation that should be added
     */
    private func addAnnotation(annotation: FlutterAnnotation) {
        if self.annotationExists(with: annotation.id) {
            self.removeAnnotation(id: annotation.id)
        }
        if annotation.zIndex == -1 {
            annotation.zIndex = self.getNextAnnotationZIndex()
            channel.invokeMethod("annotation#onZIndexChanged", arguments: ["annotationId": annotation.id!, "zIndex": annotation.zIndex])
        }
        self.mapView.addAnnotation(annotation)
    }

    private func updateAnnotation(annotation: FlutterAnnotation) {
        if let oldAnnotation = self.getAnnotation(with: annotation.id) {
            UIView.animate(withDuration: 0.32, animations: {
                oldAnnotation.coordinate = annotation.coordinate
                oldAnnotation.zIndex = annotation.zIndex
                oldAnnotation.anchor = annotation.anchor
                oldAnnotation.alpha = annotation.alpha
                oldAnnotation.isVisible = annotation.isVisible
                oldAnnotation.title = annotation.title
                oldAnnotation.subtitle = annotation.subtitle
                oldAnnotation.markerShadowEnabled = annotation.markerShadowEnabled
                oldAnnotation.markerShadowColor = annotation.markerShadowColor
                oldAnnotation.markerShadowBlurRadius = annotation.markerShadowBlurRadius
                oldAnnotation.markerShadowOffsetX = annotation.markerShadowOffsetX
                oldAnnotation.markerShadowOffsetY = annotation.markerShadowOffsetY
                oldAnnotation.usesDopinMarker = annotation.usesDopinMarker
                oldAnnotation.dopinImageUrls = annotation.dopinImageUrls
                oldAnnotation.dopinImagePngData = annotation.dopinImagePngData
                oldAnnotation.dopinImageAssetName = annotation.dopinImageAssetName
                oldAnnotation.dopinImageAssetScale = annotation.dopinImageAssetScale
                oldAnnotation.dopinMarkerLabel = annotation.dopinMarkerLabel
                oldAnnotation.dopinMarkerCount = annotation.dopinMarkerCount
                oldAnnotation.dopinFrameWidth = annotation.dopinFrameWidth
                oldAnnotation.dopinFrameHeight = annotation.dopinFrameHeight
                oldAnnotation.dopinBorderWidth = annotation.dopinBorderWidth
                oldAnnotation.dopinBorderColor = annotation.dopinBorderColor
                oldAnnotation.dopinBorderRadius = annotation.dopinBorderRadius
                oldAnnotation.dopinLabelFontSize = annotation.dopinLabelFontSize
                oldAnnotation.dopinBadgeHeight = annotation.dopinBadgeHeight
                oldAnnotation.dopinLabelColor = annotation.dopinLabelColor
                oldAnnotation.usesSvgMarker = annotation.usesSvgMarker
                oldAnnotation.svgWidth = annotation.svgWidth
                oldAnnotation.svgHeight = annotation.svgHeight
                oldAnnotation.svgImageUrl = annotation.svgImageUrl
                oldAnnotation.svgImagePngData = annotation.svgImagePngData
                oldAnnotation.glow = annotation.glow
                oldAnnotation.glowColorArgb = annotation.glowColorArgb
                oldAnnotation.glowIntensity = annotation.glowIntensity
                oldAnnotation.glowAnchor = annotation.glowAnchor
            })
            
            if let view = self.mapView.view(for: oldAnnotation) {
                if annotation.usesDopinMarker || annotation.usesSvgMarker {
                    let newView = getAnnotationView(annotation: annotation)
                    view.frame.size = newView.frame.size
                    view.bounds = newView.bounds
                    view.setNeedsLayout()
                } else {
                    let newAnnotationView = getAnnotationView(annotation: annotation)
                    view.image = newAnnotationView.image
                }
            }
        }
    }

    private func getNextAnnotationZIndex() -> Double {
        let mapViewAnnotations = self.mapView.getMapViewAnnotations()
        if mapViewAnnotations.isEmpty {
            return 0;
        }
        return (mapViewAnnotations.last??.zIndex ?? 0) + 1
    }

    private func isAnnotationInFront(zIndex: Double) -> Bool {
        return (self.mapView.getMapViewAnnotations().last??.zIndex ?? 0) == zIndex
    }

    private func getPinAnnotationView(annotation: FlutterAnnotation, id: String) -> MKPinAnnotationView {
        var pinAnnotationView: MKPinAnnotationView
        if #available(iOS 11.0, *) {
            self.mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: id)
            pinAnnotationView = self.mapView.dequeueReusableAnnotationView(withIdentifier: id, for: annotation) as! MKPinAnnotationView
        } else {
            pinAnnotationView = MKPinAnnotationView.init(annotation: annotation, reuseIdentifier: id)
        }
        pinAnnotationView.layer.zPosition = annotation.zIndex

        if let hueColor: Double = annotation.icon.hueColor {
            pinAnnotationView.pinTintColor = UIColor.init(hue: hueColor, saturation: 1, brightness: 1, alpha: 1)
        }

        return pinAnnotationView
    }

    @available(iOS 11.0, *)
    private func getMarkerAnnotationView(annotation: FlutterAnnotation, id: String) -> FlutterMarkerAnnotationView {
        self.mapView.register(FlutterMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: id)
        let markerAnnotationView: FlutterMarkerAnnotationView = self.mapView.dequeueReusableAnnotationView(withIdentifier: id, for: annotation) as! FlutterMarkerAnnotationView
        markerAnnotationView.stickyZPosition = annotation.zIndex

        if let hueColor: Double = annotation.icon.hueColor {
            markerAnnotationView.markerTintColor = UIColor.init(hue: hueColor, saturation: 1, brightness: 1, alpha: 1)
        }

        return markerAnnotationView
    }

    private func getSvgMarkerAnnotationView(annotation: FlutterAnnotation, id: String) -> SvgMarkerAnnotationView {
        let reuseId = "svg_\(id)"
        let annotationView: SvgMarkerAnnotationView
        if #available(iOS 11.0, *) {
            self.mapView.register(SvgMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: reuseId)
            annotationView = self.mapView.dequeueReusableAnnotationView(withIdentifier: reuseId, for: annotation) as! SvgMarkerAnnotationView
        } else {
            annotationView = SvgMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
        }
        annotationView.stickyZPosition = annotation.zIndex
        annotationView.canShowCallout = annotation.title != nil || annotation.subtitle != nil
        return annotationView
    }

    private func getDopinMarkerAnnotationView(annotation: FlutterAnnotation, id: String) -> DopinMarkerAnnotationView {
        let reuseId = "dopin_\(id)"
        let annotationView: DopinMarkerAnnotationView
        if #available(iOS 11.0, *) {
            self.mapView.register(DopinMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: reuseId)
            annotationView = self.mapView.dequeueReusableAnnotationView(withIdentifier: reuseId, for: annotation) as! DopinMarkerAnnotationView
        } else {
            annotationView = DopinMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
        }
        annotationView.stickyZPosition = annotation.zIndex
        annotationView.canShowCallout = annotation.title != nil || annotation.subtitle != nil
        return annotationView
    }

    private func getCustomAnnotationView(annotation: FlutterAnnotation, id: String) -> FlutterAnnotationView {
        let annotationView: FlutterAnnotationView
        let useGlow = annotation.glow
        if #available(iOS 11.0, *) {
            if useGlow {
                self.mapView.register(GlowFlutterAnnotationView.self, forAnnotationViewWithReuseIdentifier: id)
            } else {
                self.mapView.register(FlutterAnnotationView.self, forAnnotationViewWithReuseIdentifier: id)
            }
            annotationView = self.mapView.dequeueReusableAnnotationView(withIdentifier: id, for: annotation) as! FlutterAnnotationView
        } else {
            annotationView = useGlow
                ? GlowFlutterAnnotationView(annotation: annotation, reuseIdentifier: id)
                : FlutterAnnotationView(annotation: annotation, reuseIdentifier: id)
        }
        annotationView.image = annotation.icon.image
        annotationView.stickyZPosition = annotation.zIndex
        return annotationView
    }

    private func getInfoWindowXOffset(annotationView: MKAnnotationView, annotation: FlutterAnnotation) -> CGFloat {
        if annotation.icon.iconType == .PIN {
            return annotationView.frame.origin.x - (annotationView.frame.origin.x * CGFloat(annotation.calloutOffset.x))
        }
        return annotationView.frame.origin.x + (annotationView.frame.width * CGFloat(annotation.calloutOffset.x))
    }

    private func getInfoWindowYOffset(annotationView: MKAnnotationView, annotation: FlutterAnnotation) -> CGFloat {
        return annotationView.frame.height * CGFloat(annotation.calloutOffset.y)
    }

    private func moveToFront(annotation: FlutterAnnotation) {
        let id: String = annotation.id
        annotation.zIndex = self.getNextAnnotationZIndex()
        channel.invokeMethod("annotation#onZIndexChanged", arguments: ["annotationId": id, "zIndex": annotation.zIndex])
        self.addAnnotation(annotation: annotation)
        self.selectAnnotation(with: id)
    }
}

class InfoWindowTapGestureRecognizer: UITapGestureRecognizer {
    var annotationView: UIView?
    var annotationId: String?
}
