//
//  FlutterAnnotationView.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 30.03.21.
//

import Foundation
import MapKit
import QuartzCore
import UIKit

protocol ZPositionableAnnotation {
    var stickyZPosition: CGFloat {
        get
        set
    }
}

class FlutterAnnotationView: MKAnnotationView {

    /// Override the layer factory for this class to return a custom CALayer class
    override class var layerClass: AnyClass {
        return ZPositionableLayer.self
    }

    /// convenience accessor for setting zPosition
    var stickyZPosition: CGFloat {
        get {
            return (self.layer as! ZPositionableLayer).stickyZPosition
        }
        set {
            (self.layer as! ZPositionableLayer).stickyZPosition = newValue
        }
    }

    func applyFlutterMarkerShadow(contentView: UIView? = nil) {
        guard let flutter = resolvedFlutterAnnotation() else { return }
        let target = contentView ?? self
        MarkerShadowStyle.apply(to: target, from: flutter)
    }

    func resolvedFlutterAnnotation() -> FlutterAnnotation? {
        if let flutter = annotation as? FlutterAnnotation {
            return flutter
        }
        if annotation is MKUserLocation {
            return (self as? DopinMarkerAnnotationView)?.userLocationStyle
        }
        return nil
    }
}

/// Glow pulse behind custom bitmap or [DopinMarkerAnnotationView] markers when [FlutterAnnotation.glow] is true.
class GlowFlutterAnnotationView: FlutterAnnotationView {

    private static let glowPulseTagBase = 9_133_710
    /// Fixed halo size in points (see layout).
    private static let glowSide: CGFloat = 40
    /// Visual (size, borderRadius) keyframes for each pulse; layer cornerRadius is derived from scale.
    private static let glowPulseKeyframes: [(size: CGFloat, borderRadius: CGFloat)] = [
        (40, 12),
        (52, 17),
        (64, 21),
        (81, 30),
    ]
    /// Overlapping pulse rings; stagger keeps several visible at once.
    private static let glowPulseCount = 6
    /// Slow outward expansion per ring.
    private static let glowPulseDuration: CFTimeInterval = 2.8
    /// Short gap between ring starts (high frequency, overlapping slow pulses).
    private static let glowPulseStagger: CFTimeInterval = 0.7

    private var lastGlowSignature: String?

    private static func glowCenter(in bounds: CGRect, anchor: Offset) -> CGPoint {
        CGPoint(
            x: bounds.minX + bounds.width * CGFloat(anchor.x),
            y: bounds.minY + bounds.height * CGFloat(anchor.y)
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        lastGlowSignature = nil
        removeGlowPulseSubviews()
    }

    private func removeGlowPulseSubviews() {
        for index in 0..<Self.glowPulseCount {
            viewWithTag(Self.glowPulseTagBase + index)?.removeFromSuperview()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        guard let flutterAnnotation = resolvedFlutterAnnotation(), flutterAnnotation.glow else { return }

        let side = Self.glowSide
        let center = Self.glowCenter(in: bounds, anchor: flutterAnnotation.glowAnchor)

        let argb = flutterAnnotation.glowColorArgb
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        let intensity = CGFloat(min(max(flutterAnnotation.glowIntensity, 0), 1))
        let fillAlpha = a * 0.55 * intensity

        for index in 0..<Self.glowPulseCount {
            let tag = Self.glowPulseTagBase + index
            let glow: UIView
            if let existing = viewWithTag(tag) as? UIView {
                glow = existing
            } else {
                glow = UIView()
                glow.tag = tag
                glow.isUserInteractionEnabled = false
                glow.layer.masksToBounds = true
                insertSubview(glow, at: 0)
            }

            glow.layer.masksToBounds = true
            glow.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            glow.center = center
            glow.backgroundColor = UIColor(red: r, green: g, blue: b, alpha: fillAlpha)
        }

        let sig = "\(flutterAnnotation.glowColorArgb)-\(flutterAnnotation.glowIntensity)"
        if sig != lastGlowSignature {
            lastGlowSignature = sig
            let peakOpacity = Float(a * intensity)
            let pulseDuration = Self.glowPulseDuration + (1.0 - Double(intensity)) * 0.6
            let baseTime = CACurrentMediaTime()

            for index in 0..<Self.glowPulseCount {
                guard let glow = viewWithTag(Self.glowPulseTagBase + index) else { continue }
                glow.layer.removeAllAnimations()
                Self.addRepeatingGlowPulse(
                    to: glow.layer,
                    peakOpacity: peakOpacity,
                    pulseDuration: pulseDuration,
                    staggerDelay: Double(index) * Self.glowPulseStagger,
                    baseTime: baseTime
                )
            }
        }
    }

    /// Maps visual size / border-radius pairs to layer `scale` and `cornerRadius` keyframes.
    private static func glowPulseKeyframeAnimation(
        keyPath: String,
        values: [CGFloat],
        keyTimes: [NSNumber],
        pulseDuration: CFTimeInterval,
        staggerDelay: CFTimeInterval,
        baseTime: CFTimeInterval
    ) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        animation.keyTimes = keyTimes
        animation.duration = pulseDuration
        animation.autoreverses = false
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.beginTime = baseTime + staggerDelay
        if values.count > 1 {
            animation.timingFunctions = Array(
                repeating: CAMediaTimingFunction(name: .linear),
                count: values.count - 1
            )
        }
        return animation
    }

    private static func glowPulseLayerKeyframes() -> (
        scales: [CGFloat],
        layerCornerRadii: [CGFloat],
        keyTimes: [NSNumber],
        startLayerCornerRadius: CGFloat
    ) {
        let startSize = glowPulseKeyframes.first!.size
        let endSize = glowPulseKeyframes.last!.size
        let sizeRange = endSize - startSize

        var scales: [CGFloat] = []
        var layerCornerRadii: [CGFloat] = []
        var keyTimes: [NSNumber] = []

        for keyframe in glowPulseKeyframes {
            let scale = keyframe.size / glowSide
            let layerCorner = keyframe.borderRadius / scale
            scales.append(scale)
            layerCornerRadii.append(layerCorner)
            let time = sizeRange > 0 ? (keyframe.size - startSize) / sizeRange : 0
            keyTimes.append(NSNumber(value: Double(time)))
        }

        return (scales, layerCornerRadii, keyTimes, layerCornerRadii.first ?? 0)
    }

    /// One full outward pulse per cycle, repeated forever; does not restart on layout unless color/intensity change.
    private static func addRepeatingGlowPulse(
        to layer: CALayer,
        peakOpacity: Float,
        pulseDuration: CFTimeInterval,
        staggerDelay: CFTimeInterval,
        baseTime: CFTimeInterval
    ) {
        guard peakOpacity > 0 else { return }

        let keyframes = glowPulseLayerKeyframes()

        let scale = glowPulseKeyframeAnimation(
            keyPath: "transform.scale",
            values: keyframes.scales,
            keyTimes: keyframes.keyTimes,
            pulseDuration: pulseDuration,
            staggerDelay: staggerDelay,
            baseTime: baseTime
        )

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = peakOpacity
        opacity.toValue = 0
        opacity.duration = pulseDuration
        opacity.autoreverses = false
        opacity.repeatCount = .infinity
        opacity.timingFunction = CAMediaTimingFunction(name: .easeOut)
        opacity.isRemovedOnCompletion = false
        opacity.beginTime = baseTime + staggerDelay

        let corner = glowPulseKeyframeAnimation(
            keyPath: "cornerRadius",
            values: keyframes.layerCornerRadii,
            keyTimes: keyframes.keyTimes,
            pulseDuration: pulseDuration,
            staggerDelay: staggerDelay,
            baseTime: baseTime
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DIdentity
        layer.opacity = 0
        layer.cornerRadius = keyframes.startLayerCornerRadius
        CATransaction.commit()

        layer.add(scale, forKey: "glowScaleLoop")
        layer.add(opacity, forKey: "glowOpacityLoop")
        layer.add(corner, forKey: "glowCornerLoop")
    }
}

@available(iOS 11.0, *)
class FlutterMarkerAnnotationView: MKMarkerAnnotationView {
    /// Override the layer factory for this class to return a custom CALayer class
    override class var layerClass: AnyClass {
        return ZPositionableLayer.self
    }
}

@available(iOS 11.0, *)
extension FlutterMarkerAnnotationView: ZPositionableAnnotation {
    /// convenience accessor for setting zPosition
    var stickyZPosition: CGFloat {
        get {
            return (self.layer as! ZPositionableLayer).stickyZPosition
        }
        set {
            (self.layer as! ZPositionableLayer).stickyZPosition = newValue
        }
    }
}

@available(iOS 11.0, *)
extension MKAnnotationView {
    /// Plays a spring scale-in when [FlutterAnnotation.pendingScaleInAnimation] is set.
    func playScaleInOnAddIfNeeded(for annotation: FlutterAnnotation) {
        guard annotation.pendingScaleInAnimation else { return }
        annotation.pendingScaleInAnimation = false

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.layoutIfNeeded()
            guard self.bounds.width > 0.5, self.bounds.height > 0.5 else { return }

            let targetTransform = self.transform
            let smallScale: CGFloat = 0.01
            let bounceUp = -max(self.bounds.height * 0.14, 8)
            let bounceDown = max(self.bounds.height * 0.09, 5)
            let animationOptions: UIView.AnimationOptions = [
                .allowUserInteraction,
                .beginFromCurrentState,
            ]

            func markerTransform(scale: CGFloat, yOffset: CGFloat) -> CGAffineTransform {
                targetTransform
                    .scaledBy(x: scale, y: scale)
                    .translatedBy(x: 0, y: yOffset / scale)
            }

            self.transform = markerTransform(scale: smallScale, yOffset: 0)
            self.alpha = CGFloat(annotation.alpha ?? 1.0)

            // small → full size while jumping up
            UIView.animate(
                withDuration: 0.14,
                delay: 0,
                options: animationOptions.union(.curveEaseOut),
                animations: {
                    self.transform = markerTransform(scale: 1.0, yOffset: bounceUp)
                },
                completion: { finished in
                    guard finished else { return }
                    // overshoot below the resting position
                    UIView.animate(
                        withDuration: 0.12,
                        delay: 0,
                        options: animationOptions.union(.curveEaseIn),
                        animations: {
                            self.transform = markerTransform(scale: 1.0, yOffset: bounceDown)
                        },
                        completion: { finished in
                            guard finished else { return }
                            // settle back to the original position
                            UIView.animate(
                                withDuration: 0.28,
                                delay: 0,
                                usingSpringWithDamping: 0.62,
                                initialSpringVelocity: 0.6,
                                options: animationOptions,
                                animations: {
                                    self.transform = targetTransform
                                }
                            )
                        }
                    )
                }
            )
        }
    }

    /// Plays a scale-out hide when [FlutterAnnotation.pendingScaleOutAnimation] is set.
    func playScaleOutOnHideIfNeeded(for annotation: FlutterAnnotation) {
        guard annotation.pendingScaleOutAnimation else { return }
        annotation.pendingScaleOutAnimation = false

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.layoutIfNeeded()
            guard self.bounds.width > 0.5, self.bounds.height > 0.5 else {
                self.alpha = 0
                self.canShowCallout = false
                self.isDraggable = false
                return
            }

            let targetTransform = CGAffineTransform.identity
            let restingTransform = self.transform
            let smallScale: CGFloat = 0.01
            let bounceUp = -max(self.bounds.height * 0.14, 8)
            let animationOptions: UIView.AnimationOptions = [
                .allowUserInteraction,
                .beginFromCurrentState,
            ]

            func markerTransform(scale: CGFloat, yOffset: CGFloat) -> CGAffineTransform {
                restingTransform
                    .scaledBy(x: scale, y: scale)
                    .translatedBy(x: 0, y: yOffset / max(scale, 0.001))
            }

            // jump up slightly, then shrink + fade out
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                options: animationOptions.union(.curveEaseOut),
                animations: {
                    self.transform = markerTransform(scale: 1.0, yOffset: bounceUp)
                },
                completion: { finished in
                    guard finished else { return }
                    UIView.animate(
                        withDuration: 0.18,
                        delay: 0,
                        options: animationOptions.union(.curveEaseIn),
                        animations: {
                            self.transform = markerTransform(scale: smallScale, yOffset: 0)
                            self.alpha = 0
                        },
                        completion: { _ in
                            self.transform = targetTransform
                            self.canShowCallout = false
                            self.isDraggable = false
                        }
                    )
                }
            )
        }
    }
}

/// iOS 11 automagically manages the CALayer zPosition, which breaks manual z-ordering.
/// This subclass just throws away any values which the OS sets for zPosition, and provides
/// a specialized accessor for setting the zPosition
private class ZPositionableLayer: CALayer {

    /// no-op accessor for setting the zPosition
    override var zPosition: CGFloat {
        get {
            return super.zPosition
        }
        set {
            // do nothing
        }
    }

    /// specialized accessor for setting the zPosition
    var stickyZPosition: CGFloat {
        get {
            return super.zPosition
        }
        set {
            super.zPosition = newValue
        }
    }
}

// MARK: - Dopin native markers

enum MarkerShadowStyle {
    static func apply(to view: UIView, from annotation: FlutterAnnotation) {
        guard annotation.markerShadowEnabled else {
            view.layer.shadowOpacity = 0
            return
        }

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        annotation.markerShadowColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        view.layer.shadowColor = UIColor(red: r, green: g, blue: b, alpha: 1).cgColor
        view.layer.shadowOpacity = Float(a)
        view.layer.shadowRadius = annotation.markerShadowBlurRadius
        view.layer.shadowOffset = CGSize(
            width: annotation.markerShadowOffsetX,
            height: annotation.markerShadowOffsetY
        )
        view.layer.masksToBounds = false
    }
}

enum DopinMarkerImageLoader {

    private static let cache = NSCache<NSString, UIImage>()
    private static var inFlight = [String: [(UIImage?) -> Void]]()

    private static let resourceBundle: Bundle = {
        let pluginBundle = Bundle(for: DopinMarkerAnnotationView.self)
        if let url = pluginBundle.url(forResource: "apple_maps_flutter", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return pluginBundle
    }()

    /// Shown when a remote [imageUrl] fails to load or is invalid.
    static var blankProfileImage: UIImage? {
        if let image = UIImage(named: "blank_profile", in: resourceBundle, compatibleWith: nil) {
            return image
        }
        return UIImage(named: "dopin_fallback", in: resourceBundle, compatibleWith: nil)
    }

    static func applyProfileImage(_ image: UIImage?, to imageView: UIImageView) {
        if let image = image {
            imageView.image = image
            imageView.backgroundColor = .clear
        } else if let placeholder = blankProfileImage {
            imageView.image = placeholder
            imageView.backgroundColor = .clear
        } else {
            imageView.image = nil
            imageView.backgroundColor = UIColor(white: 0.92, alpha: 1)
        }
    }

    /// Priority: PNG bytes → asset → first URL (legacy single-image callers).
    static func load(for annotation: FlutterAnnotation, completion: @escaping (UIImage?) -> Void) {
        if let data = annotation.dopinImagePngData,
           let image = UIImage(data: data, scale: UIScreen.main.scale) {
            completion(image)
            return
        }
        if let name = annotation.dopinImageAssetName,
           let base = UIImage(named: name) {
            let scale = annotation.dopinImageAssetScale
            if abs(scale - 1.0) < 0.001, let cg = base.cgImage {
                completion(UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: base.imageOrientation))
            } else if let cg = base.cgImage {
                completion(UIImage(cgImage: cg, scale: scale, orientation: base.imageOrientation))
            } else {
                completion(base)
            }
            return
        }
        load(urlString: annotation.dopinImageUrls.first, completion: completion)
    }

    static func load(urlString: String?, useBlankFallback: Bool = true, completion: @escaping (UIImage?) -> Void) {
        guard let urlString = urlString, !urlString.isEmpty, let url = URL(string: urlString) else {
            completion(useBlankFallback ? blankProfileImage : nil)
            return
        }

        let key = urlString as NSString
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        if inFlight[urlString] != nil {
            inFlight[urlString]?.append(completion)
            return
        }
        inFlight[urlString] = [completion]

        URLSession.shared.dataTask(with: url) { data, response, _ in
            let image: UIImage?
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                image = useBlankFallback ? blankProfileImage : nil
            } else if let data = data, let decoded = UIImage(data: data, scale: UIScreen.main.scale) {
                cache.setObject(decoded, forKey: key)
                image = decoded
            } else {
                image = useBlankFallback ? blankProfileImage : nil
            }
            DispatchQueue.main.async {
                let waiters = inFlight.removeValue(forKey: urlString) ?? []
                for waiter in waiters {
                    waiter(image)
                }
            }
        }.resume()
    }
}

// MARK: - Marker dialog bubble (pill + tail + RTL marquee)

/// Pill / cloud dialog above Dopin / SVG markers. Fixed width; pill overflows
/// scroll R→L with a right-edge fade (feed-style marquee). Cloud style uses a
/// frosted-glass thought bubble (Figma cloud dialog).
enum MarkerDialogBubbleBuilder {

    private static let tailWidth: CGFloat = 24
    private static let tailHeight: CGFloat = 10
    private static let fadeFraction: CGFloat = 0.28
    /// Softer left-edge fade than the right (feed-style).
    private static let leftFadeFraction: CGFloat = 0.12
    private static let loopGap: CGFloat = 28
    private static let marqueeKey = "markerDialogMarquee"
    /// Tag on the marker body inside a dialog wrap (shadow must not hit the glass).
    static let markerBodyTag = 8_441_090

    /// Design reference size for the cloud body path (Figma Union 68×49).
    private static let cloudDesignWidth: CGFloat = 68
    private static let cloudDesignHeight: CGFloat = 49
    /// Design body ends at y=43 of 49 — the rest is the bottom lobe.
    private static let cloudBodyDesignHeight: CGFloat = 43
    /// Body width / one-line height, shared with the note composer bubble.
    private static let cloudWidth: CGFloat = 80
    private static let cloudMinHeight: CGFloat = 56
    /// Detached thought-dot diameter and its gap below the body.
    private static let cloudDotSize: CGFloat = 10
    private static let cloudDotGap: CGFloat = 2
    /// Line height multiple used by every cloud bubble.
    private static let cloudLineHeightFactor: CGFloat = 1.2
    /// Glass tint opacity of the cloud body and thought-dot.
    private static let cloudTintAlpha: CGFloat = 0.80
    /// Visible lines before the text area becomes scrollable.
    private static let cloudMaxVisibleLines = 3

    /// Normalize whitespace; wrapping is width-based (64pt), not character-grid.
    private static func clampCloudDialogText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func wrapIfNeeded(markerContent: UIView, annotation: FlutterAnnotation) -> UIView {
        guard annotation.usesMarkerDialog else { return markerContent }

        let bubble = buildBubble(annotation: annotation)
        let gap = annotation.dialogGapAboveMarker
        let markerSize = markerContent.bounds.size
        let bubbleSize = bubble.bounds.size

        let totalWidth = max(bubbleSize.width, markerSize.width)
        // gap may be negative (cloud thought-dot overlaps the marker).
        let rawMarkerY = bubbleSize.height + gap
        let bubbleY: CGFloat = rawMarkerY < 0 ? -rawMarkerY : 0
        let markerY = max(0, rawMarkerY)
        let totalHeight = max(bubbleY + bubbleSize.height, markerY + markerSize.height)

        let container = UIView(frame: CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight))
        container.backgroundColor = .clear
        container.clipsToBounds = false

        // Marker under the bubble so the thought-dot stays visible on top.
        markerContent.tag = markerBodyTag
        markerContent.frame.origin = CGPoint(
            x: (totalWidth - markerSize.width) / 2,
            y: markerY
        )
        container.addSubview(markerContent)

        bubble.frame.origin = CGPoint(
            x: (totalWidth - bubbleSize.width) / 2,
            y: bubbleY
        )
        container.addSubview(bubble)

        container.bounds = CGRect(origin: .zero, size: CGSize(width: totalWidth, height: totalHeight))
        return container
    }

    private static func buildBubble(annotation: FlutterAnnotation) -> UIView {
        if annotation.dialogStyle == "cloud" {
            return buildCloudBubble(annotation: annotation)
        }
        return buildPillBubble(annotation: annotation)
    }

    private static func buildPillBubble(annotation: FlutterAnnotation) -> UIView {
        let width = annotation.dialogWidth
        let height = annotation.dialogHeight
        let totalHeight = height + tailHeight
        let hPad = annotation.dialogHorizontalPadding

        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: totalHeight))
        container.backgroundColor = .clear
        container.clipsToBounds = false
        container.isUserInteractionEnabled = false

        let bgLayer = CAShapeLayer()
        bgLayer.path = bubblePath(width: width, bodyHeight: height).cgPath
        bgLayer.fillColor = annotation.dialogBackgroundColor.cgColor
        container.layer.insertSublayer(bgLayer, at: 0)

        let textWidth = max(0, width - hPad * 2)
        let textContainer = UIView(frame: CGRect(x: hPad, y: 0, width: textWidth, height: height))
        textContainer.clipsToBounds = true
        textContainer.backgroundColor = .clear
        container.addSubview(textContainer)

        let font = roundedFont(size: annotation.dialogFontSize)
        let text = annotation.dialogText
        let measured = (text as NSString).size(withAttributes: [.font: font])
        let labelHeight = ceil(font.lineHeight)
        let labelY = (height - labelHeight) / 2
        let needsMarquee = measured.width > textWidth + 0.5

        if needsMarquee {
            installMarquee(
                in: textContainer,
                text: text,
                font: font,
                textColor: annotation.dialogTextColor,
                labelHeight: labelHeight,
                labelY: labelY,
                textWidth: measured.width,
                speed: annotation.dialogMarqueeSpeed
            )
        } else {
            let label = UILabel(frame: CGRect(x: 0, y: labelY, width: textWidth, height: labelHeight))
            label.text = text
            label.font = font
            label.textColor = annotation.dialogTextColor
            label.textAlignment = .left
            label.lineBreakMode = .byClipping
            textContainer.addSubview(label)
        }

        applyEdgeFadeMask(to: textContainer)
        return container
    }

    /// Frosted-glass cloud thought bubble (Figma Group 809 / Union path).
    /// Same metrics as the note composer bubble: fixed body width, height grown
    /// from the wrapped text, up to 3 lines visible, then vertical scroll.
    private static func buildCloudBubble(annotation: FlutterAnnotation) -> UIView {
        let text = clampCloudDialogText(annotation.dialogText)
        let font = roundedFont(size: annotation.dialogFontSize)
        let hPad = max(0, annotation.dialogHorizontalPadding)
        let vPad = max(0, annotation.dialogVerticalPadding)
        let lineHeight = annotation.dialogFontSize * cloudLineHeightFactor

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: annotation.dialogTextColor,
            .paragraphStyle: paragraph,
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)

        let measured = measureCloudText(
            attributed: attributed,
            font: font,
            lineHeight: lineHeight,
            explicitWidth: annotation.dialogWidth,
            explicitHeight: annotation.dialogHeight,
            hPad: hPad,
            vPad: vPad
        )
        let width = measured.cloudSize.width
        let height = measured.cloudSize.height
        let textWidth = measured.textSize.width
        let visibleTextHeight = measured.visibleTextHeight
        let fullTextHeight = measured.fullTextHeight
        let needsScroll = fullTextHeight > visibleTextHeight + 0.5

        let totalHeight = height + cloudDotGap + cloudDotSize

        let container: UIView
        if needsScroll {
            // Pass-through host: only the scroll view captures touches.
            container = _CloudDialogPassThroughView(
                frame: CGRect(x: 0, y: 0, width: width, height: totalHeight)
            )
            container.isUserInteractionEnabled = true
        } else {
            container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: totalHeight))
            container.isUserInteractionEnabled = false
        }
        container.backgroundColor = .clear
        container.clipsToBounds = false

        let cloudPath = cloudBodyPath(width: width, height: height)
        // Liquid Glass (iOS 26+) / frosted blur fallback; tint forced to ~80%.
        let tint = annotation.dialogBackgroundColor
        let cloudGlass = makeGlassView(
            path: cloudPath,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            tint: tint
        )
        container.addSubview(cloudGlass)

        let lobeReserve = height * (1 - cloudBodyDesignHeight / cloudDesignHeight)
        // Always keep top/bottom inset; center only within the remaining band.
        let textBand = max(visibleTextHeight, height - lobeReserve - vPad * 2)
        let textTop = vPad + max(0, (textBand - visibleTextHeight) / 2)
        // Center the text column so leftover space from min cloud width is even.
        let textFrame = CGRect(
            x: (width - textWidth) / 2,
            y: textTop,
            width: textWidth,
            height: visibleTextHeight
        )

        let scrollView = UIScrollView(frame: textFrame)
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = needsScroll
        scrollView.isScrollEnabled = needsScroll
        scrollView.isUserInteractionEnabled = needsScroll
        scrollView.clipsToBounds = true
        scrollView.contentSize = CGSize(width: textWidth, height: fullTextHeight)
        // Prefer text scroll over map pan when dragging on the bubble.
        scrollView.delaysContentTouches = true
        scrollView.canCancelContentTouches = true
        container.addSubview(scrollView)

        let label = UILabel(frame: CGRect(x: 0, y: 0, width: textWidth, height: fullTextHeight))
        label.attributedText = attributed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontSizeToFitWidth = false
        label.preferredMaxLayoutWidth = textWidth
        scrollView.addSubview(label)

        // Thought-dot: same tint + hairline border as the cloud body.
        let dotRect = CGRect(
            x: (width - cloudDotSize) / 2,
            y: height + cloudDotGap,
            width: cloudDotSize,
            height: cloudDotSize
        )
        let dot = UIView(frame: dotRect)
        dot.backgroundColor = tintWithAlpha(tint, alpha: cloudTintAlpha)
        dot.layer.cornerRadius = cloudDotSize / 2
        dot.layer.borderWidth = 1
        dot.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        dot.isUserInteractionEnabled = false
        dot.layer.shadowColor = UIColor.black.cgColor
        dot.layer.shadowOpacity = 0.15
        dot.layer.shadowOffset = CGSize(width: 0, height: 3)
        dot.layer.shadowRadius = 8
        dot.layer.shadowPath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: dotRect.size)).cgPath
        container.addSubview(dot)
        container.bringSubviewToFront(scrollView)

        return container
    }

    private struct CloudTextLayout {
        let textSize: CGSize
        let visibleTextHeight: CGFloat
        let fullTextHeight: CGFloat
        let cloudSize: CGSize
    }

    /// Sizes the cloud like the note composer bubble: the body width is fixed
    /// and the height grows with the wrapped text.
    private static func measureCloudText(
        attributed: NSAttributedString,
        font: UIFont,
        lineHeight: CGFloat,
        explicitWidth: CGFloat,
        explicitHeight: CGFloat,
        hPad: CGFloat,
        vPad: CGFloat
    ) -> CloudTextLayout {
        let minTextWidth: CGFloat = 24
        let ns = attributed.string as NSString
        let attrs: [NSAttributedString.Key: Any]
        if attributed.length > 0 {
            attrs = attributed.attributes(at: 0, effectiveRange: nil)
        } else {
            attrs = [.font: font]
        }

        let cloudW = explicitWidth > 0 ? explicitWidth : cloudWidth
        let textWidth = max(minTextWidth, cloudW - hPad * 2)

        let full = ns.boundingRect(
            with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        let fullTextHeight = max(lineHeight, ceil(full.height))
        let visibleTextHeight = min(
            fullTextHeight,
            ceil(lineHeight * CGFloat(cloudMaxVisibleLines))
        )

        // Scale the body so the path's 43/49 mid-section covers text + padding.
        let bodyHeight = visibleTextHeight + vPad * 2
        let cloudH = explicitHeight > 0
            ? explicitHeight
            : max(
                cloudMinHeight,
                ceil(bodyHeight * (cloudDesignHeight / cloudBodyDesignHeight))
            )

        let lobeReserve = cloudH * (1 - cloudBodyDesignHeight / cloudDesignHeight)
        let finalVisible = min(
            visibleTextHeight,
            max(lineHeight, cloudH - lobeReserve - vPad * 2)
        )

        return CloudTextLayout(
            textSize: CGSize(width: textWidth, height: finalVisible),
            visibleTextHeight: finalVisible,
            fullTextHeight: fullTextHeight,
            cloudSize: CGSize(width: cloudW, height: cloudH)
        )
    }

    private static func makeGlassView(
        path: UIBezierPath,
        bounds: CGRect,
        tint: UIColor
    ) -> UIView {
        // Host must stay fully opaque and unmasked — any superview mask/alpha
        // on UIVisualEffectView kills live backdrop sampling (Apple docs).
        let host = UIView(frame: bounds)
        host.backgroundColor = .clear
        host.clipsToBounds = false
        host.isUserInteractionEnabled = false

        let shadowLayer = CAShapeLayer()
        shadowLayer.frame = bounds
        shadowLayer.path = path.cgPath
        shadowLayer.fillColor = UIColor.clear.cgColor
        shadowLayer.shadowColor = UIColor.black.cgColor
        shadowLayer.shadowOpacity = 0.18
        shadowLayer.shadowOffset = CGSize(width: 0, height: 4)
        shadowLayer.shadowRadius = 10
        shadowLayer.shadowPath = path.cgPath
        host.layer.addSublayer(shadowLayer)

        // Force ~80% opacity on the caller tint (Liquid Glass / fallback).
        let glassTint = tintWithAlpha(tint, alpha: cloudTintAlpha)

        let effectView: UIVisualEffectView
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = false
            glass.tintColor = glassTint
            effectView = UIVisualEffectView(effect: glass)
        } else {
            // Pre–Liquid Glass: classic frosted blur + tint overlay.
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            let tintView = UIView(frame: bounds)
            tintView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            tintView.backgroundColor = glassTint
            effectView.contentView.addSubview(tintView)

            let sheen = CAGradientLayer()
            sheen.frame = bounds
            sheen.colors = [
                UIColor.white.withAlphaComponent(0.15).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor,
            ]
            sheen.startPoint = CGPoint(x: 0, y: 0)
            sheen.endPoint = CGPoint(x: 1, y: 1)
            effectView.contentView.layer.addSublayer(sheen)
        }

        effectView.frame = bounds
        effectView.isUserInteractionEnabled = false
        effectView.mask = makePathImageMaskView(path: path, bounds: bounds)
        host.addSubview(effectView)

        let border = CAShapeLayer()
        border.frame = bounds
        border.path = path.cgPath
        border.fillColor = UIColor.clear.cgColor
        border.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        border.lineWidth = 1
        host.layer.addSublayer(border)

        return host
    }

    private static func tintWithAlpha(_ color: UIColor, alpha: CGFloat) -> UIColor {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(red: r, green: g, blue: b, alpha: alpha)
        }
        return color.withAlphaComponent(alpha)
    }

    /// Shared by cloud dialog + liquid-glass marker borders.
    static func tintWithAlphaForGlass(_ color: UIColor, alpha: CGFloat) -> UIColor {
        tintWithAlpha(color, alpha: alpha)
    }

    /// Opaque white silhouette used as `UIVisualEffectView.mask` (alpha = visibility).
    private static func makePathImageMaskView(path: UIBezierPath, bounds: CGRect) -> UIView {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: bounds.size))
            UIColor.white.setFill()
            path.fill()
        }
        let imageView = UIImageView(image: image)
        imageView.frame = bounds
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = false
        return imageView
    }

    /// Shared solid path mask (full disc / cloud body).
    static func makePathMaskView(path: UIBezierPath, bounds: CGRect) -> UIView {
        makePathImageMaskView(path: path, bounds: bounds)
    }

    /// Even-odd path mask (e.g. glass ring: outer circle minus inner circle).
    static func makeEvenOddPathMaskView(path: UIBezierPath, bounds: CGRect) -> UIView {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { ctx in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: bounds.size))
            UIColor.white.setFill()
            // `UIBezierPath.fill(with:alpha:)` takes CGBlendMode — use CGContext fill rule.
            ctx.cgContext.addPath(path.cgPath)
            ctx.cgContext.fillPath(using: .evenOdd)
        }
        let imageView = UIImageView(image: image)
        imageView.frame = bounds
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = false
        return imageView
    }

    private static func applyDialogShadow(to view: UIView, path: UIBezierPath) {
        // Kept for pill dialog; cloud glass uses a sibling shadow layer instead
        // so UIVisualEffectView is not forced into an offscreen pass.
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 9
        view.layer.shadowPath = path.cgPath
        view.layer.masksToBounds = false
    }

    /// Cloud body path from Figma Union, scaled into [width]×[height].
    /// Design coords: content box 68×49 (SVG path inset x+4).
    private static func cloudBodyPath(width: CGFloat, height: CGFloat) -> UIBezierPath {
        let sx = width / cloudDesignWidth
        let sy = height / cloudDesignHeight

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        // Path translated from SVG (x − 4): rounded rect + bottom thought lobe.
        let path = UIBezierPath()
        path.move(to: p(52, 0))
        path.addCurve(to: p(68, 16), controlPoint1: p(60.8366, 0), controlPoint2: p(68, 7.16344))
        path.addLine(to: p(68, 27))
        path.addCurve(to: p(52, 43), controlPoint1: p(68, 35.8366), controlPoint2: p(60.8366, 43))
        path.addLine(to: p(45.7402, 43))
        path.addCurve(to: p(33, 49), controlPoint1: p(44.5358, 46.4234), controlPoint2: p(39.2893, 49))
        path.addCurve(to: p(20.2598, 43), controlPoint1: p(26.7107, 49), controlPoint2: p(21.4642, 46.4234))
        path.addLine(to: p(16, 43))
        path.addCurve(to: p(0, 27), controlPoint1: p(7.16344, 43), controlPoint2: p(0, 35.8366))
        path.addLine(to: p(0, 16))
        path.addCurve(to: p(16, 0), controlPoint1: p(0, 7.16344), controlPoint2: p(7.16344, 0))
        path.addLine(to: p(52, 0))
        path.close()
        return path
    }

    private static func installMarquee(
        in container: UIView,
        text: String,
        font: UIFont,
        textColor: UIColor,
        labelHeight: CGFloat,
        labelY: CGFloat,
        textWidth: CGFloat,
        speed: CGFloat
    ) {
        let travel = textWidth + loopGap
        let strip = UIView(frame: CGRect(x: 0, y: 0, width: travel * 2, height: container.bounds.height))
        strip.backgroundColor = .clear

        func makeLabel(x: CGFloat) -> UILabel {
            let label = UILabel(frame: CGRect(x: x, y: labelY, width: ceil(textWidth), height: labelHeight))
            label.text = text
            label.font = font
            label.textColor = textColor
            label.lineBreakMode = .byClipping
            return label
        }

        strip.addSubview(makeLabel(x: 0))
        strip.addSubview(makeLabel(x: travel))
        container.addSubview(strip)

        // Continuous R→L scroll; duplicated label keeps the loop seamless.
        let duration = Double(travel) / Double(max(speed, 1))
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -travel
        animation.duration = max(duration, 0.1)
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        strip.layer.add(animation, forKey: marqueeKey)
    }

    private static func applyEdgeFadeMask(to view: UIView) {
        let mask = CAGradientLayer()
        mask.frame = view.bounds
        mask.startPoint = CGPoint(x: 0, y: 0.5)
        mask.endPoint = CGPoint(x: 1, y: 0.5)
        let opaque = UIColor.black.cgColor
        let clear = UIColor.clear.cgColor
        let leftEnd = min(leftFadeFraction, 0.45)
        let rightStart = max(0, 1 - fadeFraction)
        mask.colors = [clear, opaque, opaque, clear]
        mask.locations = [
            0,
            NSNumber(value: Double(leftEnd)),
            NSNumber(value: Double(rightStart)),
            1,
        ]
        view.layer.mask = mask
    }

    private static func bubblePath(width: CGFloat, bodyHeight: CGFloat) -> UIBezierPath {
        let r = bodyHeight / 2
        let path = UIBezierPath()
        let midX = width / 2
        let halfTail = tailWidth / 2

        path.move(to: CGPoint(x: r, y: 0))
        path.addLine(to: CGPoint(x: width - r, y: 0))
        path.addArc(
            withCenter: CGPoint(x: width - r, y: r),
            radius: r,
            startAngle: -.pi / 2,
            endAngle: .pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: midX + halfTail, y: bodyHeight))
        path.addLine(to: CGPoint(x: midX, y: bodyHeight + tailHeight))
        path.addLine(to: CGPoint(x: midX - halfTail, y: bodyHeight))
        path.addLine(to: CGPoint(x: r, y: bodyHeight))
        path.addArc(
            withCenter: CGPoint(x: r, y: r),
            radius: r,
            startAngle: .pi / 2,
            endAngle: -.pi / 2,
            clockwise: true
        )
        path.close()
        return path
    }

    private static func roundedFont(size: CGFloat) -> UIFont {
        if let descriptor = UIFont.systemFont(ofSize: size, weight: .regular)
            .fontDescriptor
            .withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: .regular)
    }
}

/// Lets empty areas pass touches through so marker `onTap` still fires; only
/// interactive children (the text scroll view) receive gestures.
private final class _CloudDialogPassThroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

final class DopinMarkerAnnotationView: GlowFlutterAnnotationView {

    private static let contentTag = 8_441_001
    private static let imageTagBase = 8_441_002

    /// Style payload when this view renders [MKUserLocation].
    var userLocationStyle: FlutterAnnotation?

    private var configuredSignature: String?
    private var imageLoadToken: String?

    override var annotation: MKAnnotation? {
        // Signature-gated: coordinate-only moves / viewFor re-queries must not
        // tear down and rebuild the avatar chrome (visible flicker while walking).
        didSet { applyAnnotationIfNeeded(force: false) }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        userLocationStyle = nil
        configuredSignature = nil
        imageLoadToken = nil
        viewWithTag(Self.contentTag)?.removeFromSuperview()
        image = nil
        bounds = .zero
        frame = .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyAnnotationIfNeeded(force: false)
        if annotation is MKUserLocation, let style = userLocationStyle {
            let width = frame.size.width
            let height = frame.size.height
            guard width > 0, height > 0 else { return }
            // Prefer live avatar center when a cloud dialog auto-sizes the bubble.
            if style.usesMarkerDialog,
               style.dialogStyle == "cloud",
               let content = viewWithTag(Self.contentTag),
               let markerBody = content.viewWithTag(MarkerDialogBubbleBuilder.markerBodyTag) {
                let avatarCenterY = markerBody.frame.minY + style.dopinFrameHeight / 2
                let avatarCenterX = markerBody.frame.midX
                centerOffset = CGPoint(
                    x: width / 2 - avatarCenterX,
                    y: height / 2 - avatarCenterY
                )
            } else {
                centerOffset = CGPoint(
                    x: (0.5 - style.anchor.x) * width,
                    y: (0.5 - style.anchor.y) * height
                )
            }
        }
    }

    func configureIfNeeded() {
        applyAnnotationIfNeeded(force: false)
    }

    override func applyFlutterMarkerShadow(contentView: UIView? = nil) {
        let content = contentView ?? viewWithTag(Self.contentTag)
        // Shadow on a superview of UIVisualEffectView forces an offscreen pass and
        // kills cloud glass blur — pin shadow to the marker body only.
        if let flutter = resolvedFlutterAnnotation(),
           flutter.usesMarkerDialog,
           flutter.dialogStyle == "cloud",
           let content = content,
           let markerBody = content.viewWithTag(MarkerDialogBubbleBuilder.markerBodyTag) {
            content.layer.shadowOpacity = 0
            MarkerShadowStyle.apply(to: markerBody, from: flutter)
            return
        }
        // Liquid-glass border already draws its own sibling shadow layer; a CALayer
        // shadow on the content host would kill the glass backdrop sample.
        if let flutter = resolvedFlutterAnnotation(),
           flutter.dopinLiquidGlassBorder,
           let content = content {
            content.layer.shadowOpacity = 0
            return
        }
        super.applyFlutterMarkerShadow(contentView: content)
    }

    override func resolvedFlutterAnnotation() -> FlutterAnnotation? {
        if let flutter = annotation as? FlutterAnnotation {
            return flutter
        }
        if annotation is MKUserLocation {
            return userLocationStyle
        }
        return nil
    }

    private func applyAnnotationIfNeeded(force: Bool) {
        guard let flutter = resolvedFlutterAnnotation(), flutter.usesDopinMarker else { return }

        let sig = flutter.dopinMarkerSignature
        if !force, sig == configuredSignature {
            if let content = viewWithTag(Self.contentTag) {
                applyFlutterMarkerShadow(contentView: content)
            }
            return
        }
        configuredSignature = sig

        viewWithTag(Self.contentTag)?.removeFromSuperview()
        image = nil
        backgroundColor = .clear
        clipsToBounds = false

        let content = Self.buildDopinMarker(annotation: flutter)
        content.tag = Self.contentTag
        addSubview(content)

        let size = content.bounds.size
        bounds = CGRect(origin: .zero, size: size)
        frame.size = size
        content.frame = bounds

        loadMarkerImages(into: content, annotation: flutter)
        applyFlutterMarkerShadow(contentView: content)
    }

    private func loadMarkerImages(into content: UIView, annotation: FlutterAnnotation) {
        let token = annotation.dopinMarkerSignature
        imageLoadToken = token

        // Emoji-center markers (category pin) — including empty glyph.
        if annotation.dopinEmoji != nil {
            return
        }

        let imageViews = Self.findImageViews(in: content)
        let urlCount = min(annotation.dopinImageUrls.count, 4)

        if urlCount >= 2 {
            let previewSlots = min(3, urlCount)
            for index in 0..<previewSlots {
                guard index < imageViews.count else { break }
                let url = annotation.dopinImageUrls[index]
                let imageView = imageViews[index]
                DopinMarkerImageLoader.load(urlString: url) { [weak self] image in
                    guard let self = self, self.imageLoadToken == token else { return }
                    DopinMarkerImageLoader.applyProfileImage(image, to: imageView)
                }
            }
            return
        }

        guard let imageView = imageViews.first else { return }
        DopinMarkerImageLoader.load(for: annotation) { [weak self] image in
            guard let self = self, self.imageLoadToken == token else { return }
            DopinMarkerImageLoader.applyProfileImage(image, to: imageView)
        }
    }

    private static func findImageViews(in root: UIView) -> [UIImageView] {
        var views: [UIImageView] = []
        for index in 0..<4 {
            if let iv = root.viewWithTag(imageTagBase + index) as? UIImageView {
                views.append(iv)
            }
        }
        return views.sorted { $0.tag < $1.tag }
    }

    private static func imageView(side: CGFloat, cornerRadius: CGFloat, tag: Int) -> UIImageView {
        let iv = UIImageView(frame: CGRect(x: 0, y: 0, width: side, height: side))
        iv.tag = tag
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = UIColor(white: 0.92, alpha: 1)
        iv.layer.cornerRadius = cornerRadius
        iv.layer.cornerCurve = .continuous
        iv.clipsToBounds = true
        return iv
    }

    private static func wrapMarkerWithBadge(
        frameView: UIView,
        frameW: CGFloat,
        frameH: CGFloat,
        annotation: FlutterAnnotation,
        suppressCountBadge: Bool = false
    ) -> UIView {
        let labelText = annotation.dopinMarkerLabel ?? ""
        let hasLabel = !labelText.isEmpty
        let badgeH = annotation.dopinBadgeHeight
        let badgeOverlap: CGFloat = 8
        let totalW = frameW
        let totalH = hasLabel ? frameH + badgeH - badgeOverlap : frameH

        let container = UIView(frame: CGRect(x: 0, y: 0, width: totalW, height: totalH))
        container.clipsToBounds = false
        container.addSubview(frameView)

        if hasLabel {
            let badge = UIView(frame: CGRect(x: 0, y: totalH - badgeH, width: totalW, height: badgeH))
            badge.layer.cornerRadius = badgeH / 2
            badge.clipsToBounds = true
            if let bgColors = annotation.dopinLabelBackgroundGradientColors, bgColors.count >= 2 {
                badge.backgroundColor = .clear
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = badge.bounds
                gradientLayer.colors = bgColors.map { $0.cgColor }
                gradientLayer.startPoint = CGPoint(x: 0, y: 0)
                gradientLayer.endPoint = CGPoint(x: 1, y: 1)
                badge.layer.insertSublayer(gradientLayer, at: 0)
            } else {
                badge.backgroundColor = annotation.dopinLabelBackgroundColor
            }
            let labelFrame = badge.bounds.insetBy(dx: 4, dy: 2)
            let badgeLabel = makeBadgeLabel(
                text: labelText,
                frame: labelFrame,
                fontSize: annotation.dopinLabelFontSize,
                textColor: annotation.dopinLabelColor,
                gradientColors: annotation.dopinLabelGradientColors
            )
            badge.addSubview(badgeLabel)
            container.addSubview(badge)
        }

        if !suppressCountBadge, let count = annotation.dopinMarkerCount, count > 0 {
            addCountBadge(to: container, frameW: frameW, frameH: frameH, count: count)
        }

        container.bounds = CGRect(origin: .zero, size: CGSize(width: totalW, height: totalH))
        return container
    }

    private static func makeBadgeLabel(
        text: String,
        frame: CGRect,
        fontSize: CGFloat,
        textColor: UIColor,
        gradientColors: [UIColor]?
    ) -> UIView {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        if let colors = gradientColors, colors.count >= 2 {
            return makeGradientTextLabel(text: text, frame: frame, font: font, colors: colors)
        }

        let label = UILabel(frame: frame)
        label.text = text
        label.font = font
        label.textAlignment = .center
        label.textColor = textColor
        return label
    }

    private static func makeGradientTextLabel(
        text: String,
        frame: CGRect,
        font: UIFont,
        colors: [UIColor]
    ) -> UIView {
        let maskLabel = UILabel(frame: frame)
        maskLabel.text = text
        maskLabel.font = font
        maskLabel.textAlignment = .center
        maskLabel.textColor = .black
        maskLabel.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: frame.size)
        let maskImage = renderer.image { context in
            maskLabel.layer.render(in: context.cgContext)
        }

        let container = UIView(frame: frame)
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = container.bounds
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        let maskLayer = CALayer()
        maskLayer.frame = gradientLayer.bounds
        maskLayer.contents = maskImage.cgImage
        gradientLayer.mask = maskLayer

        container.layer.addSublayer(gradientLayer)
        return container
    }

    private static func addCountBadge(
        to container: UIView,
        frameW: CGFloat,
        frameH: CGFloat,
        count: Int
    ) {
        let badgeSize = max(15, min(frameW, frameH) * 0.40)
        let badgeText = count > 9 ? "9+" : "\(count)"
        let x = frameW - badgeSize * 0.80
        let y = -badgeSize * 0.03
        let badge = UIView(frame: CGRect(x: x, y: y, width: badgeSize, height: badgeSize))
        badge.backgroundColor = .white
        badge.layer.cornerRadius = badgeSize / 2
        badge.clipsToBounds = false
        badge.layer.shadowColor = UIColor.black.cgColor
        badge.layer.shadowOpacity = 0.22
        badge.layer.shadowRadius = 2
        badge.layer.shadowOffset = CGSize(width: 0, height: 1)

        let badgeLabel = UILabel(frame: badge.bounds)
        badgeLabel.text = badgeText
        badgeLabel.font = .systemFont(ofSize: badgeSize * 0.52, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.textColor = .black
        badge.addSubview(badgeLabel)
        container.addSubview(badge)
    }

    private static func buildDopinMarker(annotation: FlutterAnnotation) -> UIView {
        let urlCount = min(annotation.dopinImageUrls.count, 4)
        let hasFallbackImage = annotation.dopinImagePngData != nil || annotation.dopinImageAssetName != nil
        let imageCount = urlCount > 0 ? urlCount : (hasFallbackImage ? 1 : 1)

        let marker: UIView
        if imageCount <= 1 {
            marker = buildSingleImageMarker(annotation: annotation)
        } else {
            var memberCount = imageCount
            if let count = annotation.dopinMarkerCount, count > memberCount {
                memberCount = count
            }

            let previewSlots = min(3, imageCount)
            let stackContent = ClusterStackMarkerBuilder.buildContent(
                memberCount: memberCount,
                previewSlots: previewSlots,
                imageTagBase: imageTagBase
            )
            marker = wrapMarkerWithBadge(
                frameView: stackContent,
                frameW: ClusterStackMarkerBuilder.totalWidth,
                frameH: stackContent.bounds.height,
                annotation: annotation,
                suppressCountBadge: memberCount > previewSlots
            )
        }
        return MarkerDialogBubbleBuilder.wrapIfNeeded(markerContent: marker, annotation: annotation)
    }

    private static func buildSingleImageMarker(annotation: FlutterAnnotation) -> UIView {
        // Category pin: `emoji` key present (glyph may be empty).
        if let emoji = annotation.dopinEmoji {
            return buildEmojiGlassMarker(annotation: annotation, emoji: emoji)
        }

        let frameW = annotation.dopinFrameWidth
        let frameH = annotation.dopinFrameHeight
        let border = annotation.dopinBorderWidth
        let outerRadius = annotation.dopinBorderRadius ?? min(frameW, frameH) / 2
        let innerRadius = max(0, outerRadius - border)

        let frameView: UIView
        if annotation.dopinLiquidGlassBorder {
            frameView = buildLiquidGlassBorderFrame(
                frameW: frameW,
                frameH: frameH,
                border: border,
                outerRadius: outerRadius,
                innerRadius: innerRadius,
                tint: annotation.dopinBorderColor,
                shadowEnabled: annotation.markerShadowEnabled,
                shadowColor: annotation.markerShadowColor,
                shadowBlurRadius: annotation.markerShadowBlurRadius,
                shadowOffsetX: annotation.markerShadowOffsetX,
                shadowOffsetY: annotation.markerShadowOffsetY
            )
        } else {
            frameView = UIView(frame: CGRect(x: 0, y: 0, width: frameW, height: frameH))
            frameView.backgroundColor = annotation.dopinBorderColor
            frameView.layer.cornerRadius = outerRadius
            frameView.layer.cornerCurve = .continuous
            frameView.clipsToBounds = true
        }

        let avatarSide = max(0, min(frameW, frameH) - border * 2)
        let avatarWrap = UIView(frame: CGRect(x: 0, y: 0, width: avatarSide, height: avatarSide))
        avatarWrap.layer.cornerRadius = innerRadius
        avatarWrap.layer.cornerCurve = .continuous
        avatarWrap.clipsToBounds = true
        avatarWrap.center = CGPoint(x: frameView.bounds.midX, y: frameView.bounds.midY)
        let avatar = imageView(side: avatarSide, cornerRadius: innerRadius, tag: imageTagBase)
        avatarWrap.addSubview(avatar)
        frameView.addSubview(avatarWrap)

        return wrapMarkerWithBadge(frameView: frameView, frameW: frameW, frameH: frameH, annotation: annotation)
    }

    /// Figma category pin: Liquid Glass ring (`borderWidth`, default 3) + centered emoji.
    private static func buildEmojiGlassMarker(
        annotation: FlutterAnnotation,
        emoji: String
    ) -> UIView {
        let frameW = annotation.dopinFrameWidth
        let frameH = annotation.dopinFrameHeight
        let border = max(annotation.dopinBorderWidth, 0)
        let outerRadius = annotation.dopinBorderRadius ?? min(frameW, frameH) / 2
        let innerRadius = max(0, outerRadius - border)
        let bounds = CGRect(x: 0, y: 0, width: frameW, height: frameH)

        let frameView: UIView
        if annotation.dopinLiquidGlassBorder && border > 0 {
            frameView = buildLiquidGlassBorderFrame(
                frameW: frameW,
                frameH: frameH,
                border: border,
                outerRadius: outerRadius,
                innerRadius: innerRadius,
                tint: annotation.dopinBorderColor,
                shadowEnabled: annotation.markerShadowEnabled,
                shadowColor: annotation.markerShadowColor,
                shadowBlurRadius: annotation.markerShadowBlurRadius,
                shadowOffsetX: annotation.markerShadowOffsetX,
                shadowOffsetY: annotation.markerShadowOffsetY
            )
        } else if annotation.dopinLiquidGlassBorder {
            frameView = buildLiquidGlassFillFrame(
                bounds: bounds,
                outerRadius: outerRadius,
                tint: annotation.dopinBorderColor,
                shadowEnabled: annotation.markerShadowEnabled,
                shadowColor: annotation.markerShadowColor,
                shadowBlurRadius: annotation.markerShadowBlurRadius,
                shadowOffsetX: annotation.markerShadowOffsetX,
                shadowOffsetY: annotation.markerShadowOffsetY
            )
        } else {
            frameView = UIView(frame: bounds)
            frameView.backgroundColor = annotation.dopinBorderColor
            frameView.layer.cornerRadius = outerRadius
            frameView.layer.cornerCurve = .continuous
            frameView.clipsToBounds = true
        }

        let centerSide = max(0, min(frameW, frameH) - border * 2)
        let center = UIView(frame: CGRect(x: 0, y: 0, width: centerSide, height: centerSide))
        center.backgroundColor = .white
        center.layer.cornerRadius = innerRadius
        center.layer.cornerCurve = .continuous
        center.clipsToBounds = true
        center.center = CGPoint(x: bounds.midX, y: bounds.midY)
        center.isUserInteractionEnabled = false

        let emojiLabel = UILabel(frame: center.bounds)
        emojiLabel.text = emoji
        emojiLabel.textAlignment = .center
        emojiLabel.baselineAdjustment = .alignCenters
        // Figma: ~20pt on 40pt disc.
        emojiLabel.font = .systemFont(ofSize: min(frameW, frameH) * 0.5)
        emojiLabel.adjustsFontSizeToFitWidth = true
        emojiLabel.minimumScaleFactor = 0.5
        emojiLabel.isUserInteractionEnabled = false
        emojiLabel.isHidden = emoji.isEmpty
        center.addSubview(emojiLabel)
        frameView.addSubview(center)

        return wrapMarkerWithBadge(
            frameView: frameView,
            frameW: frameW,
            frameH: frameH,
            annotation: annotation
        )
    }

    /// Full-disc Liquid Glass (category emoji pin) — not a hollow ring.
    private static func buildLiquidGlassFillFrame(
        bounds: CGRect,
        outerRadius: CGFloat,
        tint: UIColor,
        shadowEnabled: Bool,
        shadowColor: UIColor,
        shadowBlurRadius: CGFloat,
        shadowOffsetX: CGFloat,
        shadowOffsetY: CGFloat
    ) -> UIView {
        let host = UIView(frame: bounds)
        host.backgroundColor = .clear
        host.clipsToBounds = false
        host.isUserInteractionEnabled = false

        let discPath = UIBezierPath(roundedRect: bounds, cornerRadius: outerRadius)

        if shadowEnabled {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            shadowColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            let shadowLayer = CAShapeLayer()
            shadowLayer.frame = bounds
            shadowLayer.path = discPath.cgPath
            shadowLayer.fillColor = UIColor.clear.cgColor
            shadowLayer.shadowColor = UIColor(red: r, green: g, blue: b, alpha: 1).cgColor
            shadowLayer.shadowOpacity = Float(a)
            shadowLayer.shadowOffset = CGSize(width: shadowOffsetX, height: shadowOffsetY)
            shadowLayer.shadowRadius = shadowBlurRadius
            shadowLayer.shadowPath = discPath.cgPath
            host.layer.addSublayer(shadowLayer)
        }

        let glassTint = MarkerDialogBubbleBuilder.tintWithAlphaForGlass(tint, alpha: 0.90)

        let effectView: UIVisualEffectView
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = false
            glass.tintColor = glassTint
            effectView = UIVisualEffectView(effect: glass)
        } else {
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            let tintView = UIView(frame: bounds)
            tintView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            tintView.backgroundColor = glassTint
            effectView.contentView.addSubview(tintView)

            let sheen = CAGradientLayer()
            sheen.frame = bounds
            sheen.colors = [
                UIColor.white.withAlphaComponent(0.22).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor,
            ]
            sheen.startPoint = CGPoint(x: 0, y: 0)
            sheen.endPoint = CGPoint(x: 1, y: 1)
            effectView.contentView.layer.addSublayer(sheen)
        }

        effectView.frame = bounds
        effectView.isUserInteractionEnabled = false
        effectView.mask = MarkerDialogBubbleBuilder.makePathMaskView(path: discPath, bounds: bounds)
        host.addSubview(effectView)

        let rim = CAShapeLayer()
        rim.frame = bounds
        rim.path = discPath.cgPath
        rim.fillColor = UIColor.clear.cgColor
        rim.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        rim.lineWidth = 1
        host.layer.addSublayer(rim)

        return host
    }

    /// Circular / rounded frame whose ring uses Liquid Glass (iOS 26+) or frosted blur.
    ///
    /// Host stays unmasked so `UIVisualEffectView` can sample the map; the ring is
    /// applied via an even-odd path mask. Drop shadow is a sibling shape layer so it
    /// does not force an offscreen pass on the glass effect.
    private static func buildLiquidGlassBorderFrame(
        frameW: CGFloat,
        frameH: CGFloat,
        border: CGFloat,
        outerRadius: CGFloat,
        innerRadius: CGFloat,
        tint: UIColor,
        shadowEnabled: Bool,
        shadowColor: UIColor,
        shadowBlurRadius: CGFloat,
        shadowOffsetX: CGFloat,
        shadowOffsetY: CGFloat
    ) -> UIView {
        let bounds = CGRect(x: 0, y: 0, width: frameW, height: frameH)
        let host = UIView(frame: bounds)
        host.backgroundColor = .clear
        host.clipsToBounds = false
        host.isUserInteractionEnabled = false

        let outerPath = UIBezierPath(roundedRect: bounds, cornerRadius: outerRadius)
        outerPath.usesEvenOddFillRule = true
        let inset = border
        let innerBounds = bounds.insetBy(dx: inset, dy: inset)
        let innerPath = UIBezierPath(roundedRect: innerBounds, cornerRadius: innerRadius)
        outerPath.append(innerPath)

        if shadowEnabled {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            shadowColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            let shadowLayer = CAShapeLayer()
            shadowLayer.frame = bounds
            shadowLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: outerRadius).cgPath
            shadowLayer.fillColor = UIColor.clear.cgColor
            shadowLayer.shadowColor = UIColor(red: r, green: g, blue: b, alpha: 1).cgColor
            shadowLayer.shadowOpacity = Float(a)
            shadowLayer.shadowOffset = CGSize(width: shadowOffsetX, height: shadowOffsetY)
            shadowLayer.shadowRadius = shadowBlurRadius
            shadowLayer.shadowPath = shadowLayer.path
            host.layer.addSublayer(shadowLayer)
        }

        let glassTint = MarkerDialogBubbleBuilder.tintWithAlphaForGlass(tint, alpha: 0.90)

        let effectView: UIVisualEffectView
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = false
            glass.tintColor = glassTint
            effectView = UIVisualEffectView(effect: glass)
        } else {
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            let tintView = UIView(frame: bounds)
            tintView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            tintView.backgroundColor = glassTint
            effectView.contentView.addSubview(tintView)

            let sheen = CAGradientLayer()
            sheen.frame = bounds
            sheen.colors = [
                UIColor.white.withAlphaComponent(0.22).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor,
            ]
            sheen.startPoint = CGPoint(x: 0, y: 0)
            sheen.endPoint = CGPoint(x: 1, y: 1)
            effectView.contentView.layer.addSublayer(sheen)
        }

        effectView.frame = bounds
        effectView.isUserInteractionEnabled = false
        effectView.mask = MarkerDialogBubbleBuilder.makeEvenOddPathMaskView(path: outerPath, bounds: bounds)
        host.addSubview(effectView)

        // Subtle rim highlight so the ring reads against busy map tiles.
        let rim = CAShapeLayer()
        rim.frame = bounds
        rim.path = UIBezierPath(roundedRect: bounds, cornerRadius: outerRadius).cgPath
        rim.fillColor = UIColor.clear.cgColor
        rim.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        rim.lineWidth = 1
        host.layer.addSublayer(rim)

        return host
    }
}

// MARK: - SVG markers

enum SvgMarkerImageLoader {

    private static let cache = NSCache<NSString, UIImage>()

    private static let resourceBundle: Bundle = {
        let pluginBundle = Bundle(for: SvgMarkerAnnotationView.self)
        if let url = pluginBundle.url(forResource: "apple_maps_flutter", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return pluginBundle
    }()

    /// Circle center in the bundled SVG viewBox (0 0 38 50).
    private static let circleCenterXRatio: CGFloat = 19.0 / 38.0
    private static let circleCenterYRatio: CGFloat = 19.0 / 50.0
    private static let avatarWidthRatio: CGFloat = 0.8

    /// Renders the bundled vector SVG at [width]×[height] points (device scale).
    static func eventMarkerImage(width: CGFloat, height: CGFloat) -> UIImage? {
        renderedVectorImage(named: "event_marker", width: width, height: height)
    }

    /// Filled pin shown when [SvgMarker] center image fails to load.
    static func eventFillMarkerImage(width: CGFloat, height: CGFloat) -> UIImage? {
        renderedVectorImage(named: "event_fill_marker", width: width, height: height)
    }

    private static func renderedVectorImage(named name: String, width: CGFloat, height: CGFloat) -> UIImage? {
        let scale = UIScreen.main.scale
        let key = "\(name)|\(width)|\(height)|\(scale)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let vector = UIImage(named: name, in: resourceBundle, compatibleWith: nil) else {
            return nil
        }

        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            vector.draw(in: CGRect(origin: .zero, size: size))
        }
        cache.setObject(rendered, forKey: key)
        return rendered
    }

    static func centerAvatarFrame(width: CGFloat, height: CGFloat) -> CGRect {
        let side = width * avatarWidthRatio
        let centerX = width * circleCenterXRatio
        let centerY = height * circleCenterYRatio
        return CGRect(x: centerX - side / 2, y: centerY - side / 2, width: side, height: side)
    }

    /// Renders an emoji string centered on a transparent square of `side` points.
    static func emojiImage(_ emoji: String, side: CGFloat) -> UIImage {
        let fontSize = side * 0.62
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize)
        ]
        let text = emoji as NSString
        let textSize = text.size(withAttributes: attrs)

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let origin = CGPoint(
                x: (side - textSize.width) / 2,
                y: (side - textSize.height) / 2
            )
            text.draw(at: origin, withAttributes: attrs)
        }
    }

    /// Dominant vivid color of `image`, rendered with boosted brightness.
    ///
    /// Groups pixels by hue (ignoring transparent, near-gray, very dark and very
    /// bright pixels), picks the most frequent hue bucket, then returns it with a
    /// high brightness / saturation so the placeholder circle reads as a light,
    /// colorful chip rather than a muddy average.
    static func dominantColor(of image: UIImage) -> UIColor {
        let fallback = UIColor(white: 0.92, alpha: 1)
        guard let cg = image.cgImage else { return fallback }

        let side = 32
        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        let count = side * side * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        let bucketCount = 18
        var data = [UInt8](repeating: 0, count: count)

        return data.withUnsafeMutableBytes { raw -> UIColor in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: side,
                    height: side,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else { return fallback }

            context.clear(CGRect(x: 0, y: 0, width: side, height: side))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

            let buffer = base.assumingMemoryBound(to: UInt8.self)
            var counts = [Int](repeating: 0, count: bucketCount)
            var hueSum = [CGFloat](repeating: 0, count: bucketCount)
            var satSum = [CGFloat](repeating: 0, count: bucketCount)

            for index in stride(from: 0, to: count, by: bytesPerPixel) {
                let alpha = CGFloat(buffer[index + 3]) / 255.0
                guard alpha > 0.4 else { continue }

                // premultipliedLast → recover the true (unpremultiplied) color.
                let r = min(CGFloat(buffer[index]) / 255.0 / alpha, 1)
                let g = min(CGFloat(buffer[index + 1]) / 255.0 / alpha, 1)
                let b = min(CGFloat(buffer[index + 2]) / 255.0 / alpha, 1)

                var h: CGFloat = 0
                var s: CGFloat = 0
                var v: CGFloat = 0
                UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: nil)

                // Ignore near-gray / near-black / near-white pixels.
                guard s > 0.25, v > 0.2, v < 0.98 else { continue }

                let bucket = min(Int(h * CGFloat(bucketCount)), bucketCount - 1)
                counts[bucket] += 1
                hueSum[bucket] += h
                satSum[bucket] += s
            }

            var bestBucket = -1
            var bestCount = 0
            for bucket in 0..<bucketCount where counts[bucket] > bestCount {
                bestCount = counts[bucket]
                bestBucket = bucket
            }

            guard bestBucket >= 0, bestCount > 0 else { return fallback }

            let hue = hueSum[bestBucket] / CGFloat(bestCount)
            let saturation = satSum[bestBucket] / CGFloat(bestCount)

            // Dominant hue shown as a light, pastel chip (low saturation, full brightness).
            return UIColor(
                hue: hue,
                saturation: min(max(saturation, 0.22), 0.4),
                brightness: 1.0,
                alpha: 1
            )
        }
    }

    static func loadCenterImage(for annotation: FlutterAnnotation, completion: @escaping (UIImage?) -> Void) {
        if let data = annotation.svgImagePngData,
           let image = UIImage(data: data, scale: UIScreen.main.scale) {
            completion(image)
            return
        }
        DopinMarkerImageLoader.load(
            urlString: annotation.svgImageUrl,
            useBlankFallback: false,
            completion: completion
        )
    }
}

final class SvgMarkerAnnotationView: GlowFlutterAnnotationView {

    private static let contentTag = 8_442_001
    private static let pinTag = 8_442_002
    private static let avatarTag = 8_442_003

    private var configuredSignature: String?
    private var imageLoadToken: String?

    override var annotation: MKAnnotation? {
        didSet { applyAnnotationIfNeeded(force: false) }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        configuredSignature = nil
        imageLoadToken = nil
        viewWithTag(Self.contentTag)?.removeFromSuperview()
        image = nil
        bounds = .zero
        frame = .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyAnnotationIfNeeded(force: false)
    }

    func configureIfNeeded() {
        applyAnnotationIfNeeded(force: false)
    }

    override func applyFlutterMarkerShadow(contentView: UIView? = nil) {
        let content = contentView ?? viewWithTag(Self.contentTag)
        if let flutter = annotation as? FlutterAnnotation,
           flutter.usesMarkerDialog,
           flutter.dialogStyle == "cloud",
           let content = content,
           let markerBody = content.viewWithTag(MarkerDialogBubbleBuilder.markerBodyTag) {
            content.layer.shadowOpacity = 0
            MarkerShadowStyle.apply(to: markerBody, from: flutter)
            return
        }
        super.applyFlutterMarkerShadow(contentView: content)
    }

    private func applyAnnotationIfNeeded(force: Bool) {
        guard let flutter = annotation as? FlutterAnnotation, flutter.usesSvgMarker else { return }

        let sig = flutter.svgMarkerSignature
        if !force, sig == configuredSignature {
            applyFlutterMarkerShadow()
            return
        }
        configuredSignature = sig
        imageLoadToken = sig

        viewWithTag(Self.contentTag)?.removeFromSuperview()
        image = nil
        backgroundColor = .clear
        clipsToBounds = false

        let content = Self.buildSvgMarker(annotation: flutter)
        content.tag = Self.contentTag
        addSubview(content)

        let size = content.bounds.size
        bounds = CGRect(origin: .zero, size: size)
        frame.size = size
        content.frame = bounds

        loadCenterImage(into: content, annotation: flutter)
        applyFlutterMarkerShadow(contentView: content)
    }

    private func loadCenterImage(into content: UIView, annotation: FlutterAnnotation) {
        guard let pinView = content.viewWithTag(Self.pinTag) as? UIImageView,
              let avatarView = content.viewWithTag(Self.avatarTag) as? UIImageView else { return }

        let width = annotation.svgWidth
        let height = annotation.svgHeight

        // Emoji takes precedence and is drawn synchronously in buildSvgMarker.
        if let emoji = annotation.svgEmoji, !emoji.isEmpty {
            avatarView.isHidden = false
            pinView.image = SvgMarkerImageLoader.eventMarkerImage(width: width, height: height)
            return
        }

        let hasImage = annotation.svgImagePngData != nil
            || (annotation.svgImageUrl?.isEmpty == false)

        guard hasImage else {
            avatarView.isHidden = true
            pinView.image = SvgMarkerImageLoader.eventFillMarkerImage(width: width, height: height)
            return
        }

        avatarView.isHidden = false
        pinView.image = SvgMarkerImageLoader.eventMarkerImage(width: width, height: height)

        let token = annotation.svgMarkerSignature
        imageLoadToken = token
        SvgMarkerImageLoader.loadCenterImage(for: annotation) { [weak self, weak pinView, weak avatarView] image in
            guard let self = self,
                  let pinView = pinView,
                  let avatarView = avatarView,
                  self.imageLoadToken == token else { return }

            if let image = image {
                avatarView.isHidden = false
                avatarView.image = image
                avatarView.backgroundColor = .clear
                pinView.image = SvgMarkerImageLoader.eventMarkerImage(width: width, height: height)
            } else {
                avatarView.isHidden = true
                pinView.image = SvgMarkerImageLoader.eventFillMarkerImage(width: width, height: height)
            }
        }
    }

    private static func buildSvgMarker(annotation: FlutterAnnotation) -> UIView {
        let width = annotation.svgWidth
        let height = annotation.svgHeight
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        container.clipsToBounds = false

        let emoji = annotation.svgEmoji ?? ""
        let hasEmoji = !emoji.isEmpty

        let pinView = UIImageView(frame: container.bounds)
        pinView.tag = pinTag
        pinView.contentMode = .scaleToFill
        let hasImage = annotation.svgImagePngData != nil
            || !(annotation.svgImageUrl ?? "").isEmpty
        let hasCenterContent = hasEmoji || hasImage
        pinView.image = hasCenterContent
            ? SvgMarkerImageLoader.eventMarkerImage(width: width, height: height)
            : SvgMarkerImageLoader.eventFillMarkerImage(width: width, height: height)
        container.addSubview(pinView)

        let avatarFrame = SvgMarkerImageLoader.centerAvatarFrame(width: width, height: height)
        let avatarView = UIImageView(frame: avatarFrame)
        avatarView.tag = avatarTag
        avatarView.layer.cornerRadius = avatarFrame.width / 2
        avatarView.clipsToBounds = true

        if hasEmoji {
            let emojiImage = SvgMarkerImageLoader.emojiImage(emoji, side: avatarFrame.width)
            avatarView.image = nil
            avatarView.backgroundColor = SvgMarkerImageLoader.dominantColor(of: emojiImage)
            avatarView.isHidden = false

            let emojiLabel = UILabel(frame: avatarView.bounds)
            emojiLabel.text = emoji
            emojiLabel.textAlignment = .center
            emojiLabel.baselineAdjustment = .alignCenters
            emojiLabel.font = .systemFont(ofSize: avatarFrame.width * 0.46)
            emojiLabel.adjustsFontSizeToFitWidth = true
            emojiLabel.minimumScaleFactor = 0.3
            emojiLabel.isUserInteractionEnabled = false
            avatarView.addSubview(emojiLabel)
        } else {
            avatarView.contentMode = .scaleAspectFill
            avatarView.backgroundColor = UIColor(white: 0.92, alpha: 1)
            avatarView.isHidden = !hasImage
        }
        container.addSubview(avatarView)

        container.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        return MarkerDialogBubbleBuilder.wrapIfNeeded(markerContent: container, annotation: annotation)
    }
}

// MARK: - Card markers

final class CardMarkerAnnotationView: GlowFlutterAnnotationView {

    private static let contentTag = 8_443_001
    private static let imageTag = 8_443_002
    private static let subtitleIconTag = 8_443_003
    private static let distanceIconTag = 8_443_004
    private static let bgLayerName = "cardMarkerBackground"

    // Layout constants (points).
    private static let hPad: CGFloat = 14
    private static let vPad: CGFloat = 11
    private static let imageTextGap: CGFloat = 12
    private static let textDistanceGap: CGFloat = 16
    private static let subtitleGap: CGFloat = 3
    private static let subtitleIconGap: CGFloat = 5
    private static let distanceIconGap: CGFloat = 4
    private static let tailWidth: CGFloat = 24
    private static let tailHeight: CGFloat = 10
    private static let minTextColumnWidth: CGFloat = 40

    private var configuredSignature: String?
    private var imageLoadToken: String?

    override var annotation: MKAnnotation? {
        didSet { applyAnnotationIfNeeded(force: false) }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        configuredSignature = nil
        imageLoadToken = nil
        viewWithTag(Self.contentTag)?.removeFromSuperview()
        image = nil
        bounds = .zero
        frame = .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyAnnotationIfNeeded(force: false)
    }

    func configureIfNeeded() {
        applyAnnotationIfNeeded(force: false)
    }

    override func applyFlutterMarkerShadow(contentView: UIView? = nil) {
        let content = contentView ?? viewWithTag(Self.contentTag)
        super.applyFlutterMarkerShadow(contentView: content)
        // Ensure the drop shadow follows the card + tail silhouette rather than
        // the (transparent) container bounds.
        if let content = content,
           let bgLayer = content.layer.sublayers?.first(where: { $0.name == Self.bgLayerName }) as? CAShapeLayer {
            content.layer.shadowPath = bgLayer.path
        }
    }

    private func applyAnnotationIfNeeded(force: Bool) {
        guard let flutter = annotation as? FlutterAnnotation, flutter.usesCardMarker else { return }

        let sig = flutter.cardMarkerSignature
        if !force, sig == configuredSignature {
            applyFlutterMarkerShadow()
            return
        }
        configuredSignature = sig

        viewWithTag(Self.contentTag)?.removeFromSuperview()
        image = nil
        backgroundColor = .clear
        clipsToBounds = false

        let content = Self.buildCardMarker(annotation: flutter)
        content.tag = Self.contentTag
        addSubview(content)

        let size = content.bounds.size
        bounds = CGRect(origin: .zero, size: size)
        frame.size = size
        content.frame = bounds

        loadImages(into: content, annotation: flutter)
        applyFlutterMarkerShadow(contentView: content)
    }

    private func loadImages(into content: UIView, annotation: FlutterAnnotation) {
        let token = annotation.cardMarkerSignature
        imageLoadToken = token

        if let imageView = content.viewWithTag(Self.imageTag) as? UIImageView {
            Self.loadImage(
                pngData: annotation.cardImagePngData,
                assetName: annotation.cardImageAssetName,
                assetScale: annotation.cardImageAssetScale,
                urlString: annotation.cardImageUrl,
                useBlankFallback: true
            ) { [weak self, weak imageView] image in
                guard let self = self, let imageView = imageView, self.imageLoadToken == token else { return }
                DopinMarkerImageLoader.applyProfileImage(image, to: imageView)
            }
        }

        if let subtitleIcon = content.viewWithTag(Self.subtitleIconTag) as? UIImageView {
            Self.loadImage(
                pngData: annotation.cardSubtitleIconPngData,
                assetName: nil,
                assetScale: 1.0,
                urlString: annotation.cardSubtitleIconUrl,
                useBlankFallback: false
            ) { [weak self, weak subtitleIcon] image in
                guard let self = self, let subtitleIcon = subtitleIcon, self.imageLoadToken == token else { return }
                subtitleIcon.image = image?.withRenderingMode(.alwaysTemplate)
            }
        }
    }

    private static func loadImage(
        pngData: Data?,
        assetName: String?,
        assetScale: CGFloat,
        urlString: String?,
        useBlankFallback: Bool,
        completion: @escaping (UIImage?) -> Void
    ) {
        if let data = pngData, let image = UIImage(data: data, scale: UIScreen.main.scale) {
            completion(image)
            return
        }
        if let name = assetName, let base = UIImage(named: name) {
            if abs(assetScale - 1.0) < 0.001, let cg = base.cgImage {
                completion(UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: base.imageOrientation))
            } else if let cg = base.cgImage {
                completion(UIImage(cgImage: cg, scale: assetScale, orientation: base.imageOrientation))
            } else {
                completion(base)
            }
            return
        }
        DopinMarkerImageLoader.load(urlString: urlString, useBlankFallback: useBlankFallback, completion: completion)
    }

    private static func textSize(_ text: String, font: UIFont) -> CGSize {
        return (text as NSString).size(withAttributes: [.font: font])
    }

    private static func buildCardMarker(annotation: FlutterAnnotation) -> UIView {
        let titleFont = UIFont.systemFont(ofSize: annotation.cardTitleFontSize, weight: .semibold)
        let subtitleFont = UIFont.systemFont(ofSize: annotation.cardSubtitleFontSize, weight: .regular)
        let distanceFont = UIFont.systemFont(ofSize: annotation.cardDistanceFontSize, weight: .regular)

        let title = annotation.cardTitle ?? ""
        let subtitle = annotation.cardSubtitle ?? ""
        let distance = annotation.cardDistance ?? ""

        let hasSubtitle = !subtitle.isEmpty
        let hasDistance = !distance.isEmpty
        let hasSubtitleIcon = annotation.cardSubtitleIconPngData != nil
            || (annotation.cardSubtitleIconUrl?.isEmpty == false)
        let showDistanceIcon = hasDistance && annotation.cardShowDistanceIcon

        let imageSize = annotation.cardImageSize
        let subtitleIconSide = annotation.cardSubtitleFontSize + 1
        let distanceIconSide = annotation.cardDistanceFontSize + 1

        // Measure text.
        let titleWidth = ceil(textSize(title, font: titleFont).width)
        let subtitleTextWidth = hasSubtitle ? ceil(textSize(subtitle, font: subtitleFont).width) : 0
        let subtitleRowWidth = subtitleTextWidth
            + (hasSubtitleIcon ? subtitleIconSide + subtitleIconGap : 0)
        let distanceTextWidth = hasDistance ? ceil(textSize(distance, font: distanceFont).width) : 0
        let distanceBlockWidth = hasDistance
            ? distanceTextWidth + (showDistanceIcon ? distanceIconSide + distanceIconGap : 0)
            : 0

        let titleHeight = ceil(titleFont.lineHeight)
        let subtitleRowHeight = hasSubtitle
            ? max(ceil(subtitleFont.lineHeight), hasSubtitleIcon ? subtitleIconSide : 0)
            : 0
        let textColumnHeight = titleHeight + (hasSubtitle ? subtitleGap + subtitleRowHeight : 0)

        let cardHeight = max(imageSize, textColumnHeight) + vPad * 2

        // Fixed (non-text) horizontal space.
        let fixedWidth = hPad + imageSize + imageTextGap
            + (distanceBlockWidth > 0 ? textDistanceGap + distanceBlockWidth : 0)
            + hPad
        let naturalTextColumn = max(titleWidth, subtitleRowWidth)
        let availableTextColumn = max(minTextColumnWidth, annotation.cardMaxWidth - fixedWidth)
        let textColumnWidth = max(minTextColumnWidth, min(naturalTextColumn, availableTextColumn))

        let totalWidth = fixedWidth + textColumnWidth
        let totalHeight = cardHeight + tailHeight

        let container = UIView(frame: CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight))
        container.backgroundColor = .clear
        container.clipsToBounds = false

        // Background shape: rounded card body + downward tail.
        let bgLayer = CAShapeLayer()
        bgLayer.name = bgLayerName
        bgLayer.path = cardPath(
            width: totalWidth,
            cardHeight: cardHeight,
            cornerRadius: min(annotation.cardCornerRadius, cardHeight / 2)
        ).cgPath
        bgLayer.fillColor = annotation.cardBackgroundColor.cgColor
        container.layer.insertSublayer(bgLayer, at: 0)

        // Leading image.
        let imageY = (cardHeight - imageSize) / 2
        let imageView = UIImageView(frame: CGRect(x: hPad, y: imageY, width: imageSize, height: imageSize))
        imageView.tag = imageTag
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = UIColor(white: 0.92, alpha: 1)
        imageView.layer.cornerRadius = imageSize / 2
        imageView.clipsToBounds = true
        container.addSubview(imageView)

        // Text column.
        let textX = hPad + imageSize + imageTextGap
        let textTop = (cardHeight - textColumnHeight) / 2

        let titleLabel = UILabel(frame: CGRect(x: textX, y: textTop, width: textColumnWidth, height: titleHeight))
        titleLabel.text = title
        titleLabel.font = titleFont
        titleLabel.textColor = annotation.cardTitleColor
        titleLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(titleLabel)

        if hasSubtitle {
            let subtitleY = textTop + titleHeight + subtitleGap
            var subtitleTextX = textX
            if hasSubtitleIcon {
                let iconY = subtitleY + (subtitleRowHeight - subtitleIconSide) / 2
                let subtitleIcon = UIImageView(frame: CGRect(x: textX, y: iconY, width: subtitleIconSide, height: subtitleIconSide))
                subtitleIcon.tag = subtitleIconTag
                subtitleIcon.contentMode = .scaleAspectFit
                subtitleIcon.tintColor = annotation.cardSubtitleColor
                container.addSubview(subtitleIcon)
                subtitleTextX += subtitleIconSide + subtitleIconGap
            }
            let subtitleLabel = UILabel(frame: CGRect(
                x: subtitleTextX,
                y: subtitleY,
                width: max(0, textX + textColumnWidth - subtitleTextX),
                height: subtitleRowHeight
            ))
            subtitleLabel.text = subtitle
            subtitleLabel.font = subtitleFont
            subtitleLabel.textColor = annotation.cardSubtitleColor
            subtitleLabel.lineBreakMode = .byTruncatingTail
            container.addSubview(subtitleLabel)
        }

        // Trailing distance block.
        if hasDistance {
            let distanceRight = totalWidth - hPad
            let distanceBlockX = distanceRight - distanceBlockWidth
            let distanceCenterY = cardHeight / 2
            var distanceTextX = distanceBlockX
            if showDistanceIcon {
                let iconY = distanceCenterY - distanceIconSide / 2
                let distanceIcon = UIImageView(frame: CGRect(x: distanceBlockX, y: iconY, width: distanceIconSide, height: distanceIconSide))
                distanceIcon.tag = distanceIconTag
                distanceIcon.contentMode = .scaleAspectFit
                distanceIcon.tintColor = annotation.cardDistanceColor
                distanceIcon.image = defaultDistanceIcon(annotation: annotation)
                container.addSubview(distanceIcon)
                distanceTextX += distanceIconSide + distanceIconGap
            }
            let distanceHeight = ceil(distanceFont.lineHeight)
            let distanceLabel = UILabel(frame: CGRect(
                x: distanceTextX,
                y: distanceCenterY - distanceHeight / 2,
                width: distanceTextWidth,
                height: distanceHeight
            ))
            distanceLabel.text = distance
            distanceLabel.font = distanceFont
            distanceLabel.textColor = annotation.cardDistanceColor
            distanceLabel.textAlignment = .right
            container.addSubview(distanceLabel)
        }

        container.bounds = CGRect(origin: .zero, size: CGSize(width: totalWidth, height: totalHeight))
        return container
    }

    private static func defaultDistanceIcon(annotation: FlutterAnnotation) -> UIImage? {
        if let data = annotation.cardDistanceIconPngData,
           let image = UIImage(data: data, scale: UIScreen.main.scale) {
            return image.withRenderingMode(.alwaysTemplate)
        }
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: annotation.cardDistanceFontSize, weight: .regular)
            return UIImage(systemName: "mappin.and.ellipse", withConfiguration: config)?
                .withRenderingMode(.alwaysTemplate)
        }
        return nil
    }

    /// Rounded-rectangle card body with a centered downward-pointing tail.
    private static func cardPath(width: CGFloat, cardHeight: CGFloat, cornerRadius: CGFloat) -> UIBezierPath {
        let r = min(cornerRadius, min(width, cardHeight) / 2)
        let path = UIBezierPath()
        let tailHalf = tailWidth / 2
        let midX = width / 2

        // Top-left corner start.
        path.move(to: CGPoint(x: r, y: 0))
        path.addLine(to: CGPoint(x: width - r, y: 0))
        path.addArc(withCenter: CGPoint(x: width - r, y: r), radius: r,
                    startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: width, y: cardHeight - r))
        path.addArc(withCenter: CGPoint(x: width - r, y: cardHeight - r), radius: r,
                    startAngle: 0, endAngle: .pi / 2, clockwise: true)
        // Bottom edge → tail → bottom edge.
        path.addLine(to: CGPoint(x: midX + tailHalf, y: cardHeight))
        path.addLine(to: CGPoint(x: midX, y: cardHeight + tailHeight))
        path.addLine(to: CGPoint(x: midX - tailHalf, y: cardHeight))
        path.addLine(to: CGPoint(x: r, y: cardHeight))
        path.addArc(withCenter: CGPoint(x: r, y: cardHeight - r), radius: r,
                    startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addArc(withCenter: CGPoint(x: r, y: r), radius: r,
                    startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        path.close()
        return path
    }
}

// MARK: - Cluster stack layout (shared by map clusters and multi-dopin markers)

/// Draws label text with a white outline and solid dark fill on top.
private final class ClusterOutlinedLabel: UILabel {

    var outlineColor: UIColor = .white
    var outlineWidth: CGFloat = 3
    var fillColor: UIColor = UIColor(red: 19 / 255, green: 19 / 255, blue: 19 / 255, alpha: 1)

    override func drawText(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let text = text, let font = font else {
            super.drawText(in: rect)
            return
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
        ]

        context.setLineJoin(.round)
        context.setLineWidth(outlineWidth)

        context.setTextDrawingMode(.stroke)
        (text as NSString).draw(in: rect, withAttributes: attributes.merging([
            .foregroundColor: outlineColor,
        ]) { _, new in new })

        context.setTextDrawingMode(.fill)
        (text as NSString).draw(in: rect, withAttributes: attributes.merging([
            .foregroundColor: fillColor,
        ]) { _, new in new })
    }
}

enum ClusterStackMarkerBuilder {

    struct AvatarPlacement {
        let side: CGFloat
        let cornerRadius: CGFloat
        let rotationDegrees: CGFloat
        let center: CGPoint
    }

    static let stackHeight: CGFloat = 52
    static let totalWidth: CGFloat = 76

    private static let avatarPlacements: [AvatarPlacement] = [
        AvatarPlacement(side: 40, cornerRadius: 12, rotationDegrees: -8.1, center: CGPoint(x: 22, y: 34)),
        AvatarPlacement(side: 40, cornerRadius: 12, rotationDegrees: 10.88, center: CGPoint(x: 48, y: 34)),
        AvatarPlacement(side: 28.053, cornerRadius: 8, rotationDegrees: 2.75, center: CGPoint(x: 32, y: 16)),
    ]

    static func moreLabelText(memberCount: Int, previewCount: Int) -> String? {
        let remaining = max(0, memberCount - previewCount)
        guard remaining > 0 else { return nil }
        if remaining > 9 {
            return "9+ more"
        }
        return "\(remaining) more"
    }

    static func buildContent(memberCount: Int, previewSlots: Int, imageTagBase: Int) -> UIView {
        let labelFontSize: CGFloat = 12
        let labelSpacing: CGFloat = 6
        let labelText = moreLabelText(memberCount: memberCount, previewCount: previewSlots)
        let hasLabel = labelText != nil

        let labelHeight: CGFloat = hasLabel ? ceil(labelFontSize * 1.7) : 0
        let totalHeight = stackHeight + (hasLabel ? labelSpacing + labelHeight : 0)

        let container = UIView(frame: CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight))
        container.clipsToBounds = false
        container.backgroundColor = .clear

        let stackView = UIView(frame: CGRect(x: 0, y: 0, width: totalWidth, height: stackHeight))
        stackView.clipsToBounds = false
        container.addSubview(stackView)

        let placements = avatarPlacements(for: previewSlots)
        for (index, placement) in placements.enumerated() {
            let avatar = makeRotatedAvatar(placement: placement, imageTag: imageTagBase + index)
            stackView.addSubview(avatar)
        }

        if let labelText = labelText {
            let labelY = stackHeight + labelSpacing
            let label = makeOutlinedLabel(
                text: labelText,
                fontSize: labelFontSize,
                frame: CGRect(x: 0, y: labelY, width: totalWidth, height: labelHeight)
            )
            container.addSubview(label)
        }

        container.bounds = CGRect(origin: .zero, size: CGSize(width: totalWidth, height: totalHeight))
        return container
    }

    private static func avatarPlacements(for count: Int) -> [AvatarPlacement] {
        switch count {
        case 2:
            return Array(avatarPlacements.prefix(2))
        default:
            return Array(avatarPlacements.prefix(min(3, count)))
        }
    }

    private static func makeOutlinedLabel(text: String, fontSize: CGFloat, frame: CGRect) -> UILabel {
        let font: UIFont
        if let rounded = UIFont(name: "SFProRounded-Semibold", size: fontSize) {
            font = rounded
        } else {
            font = .systemFont(ofSize: fontSize, weight: .semibold)
        }

        let label = ClusterOutlinedLabel(frame: frame)
        label.textAlignment = .center
        label.backgroundColor = .clear
        label.numberOfLines = 1
        label.font = font
        label.text = text
        label.fillColor = UIColor(red: 19 / 255, green: 19 / 255, blue: 19 / 255, alpha: 1)
        label.outlineColor = .white
        label.outlineWidth = 3
        return label
    }

    private static func makeRotatedAvatar(placement: AvatarPlacement, imageTag: Int) -> UIView {
        let borderWidth: CGFloat = 3
        let side = placement.side
        let outer = UIView(frame: CGRect(x: 0, y: 0, width: side, height: side))
        outer.backgroundColor = .white
        outer.layer.cornerRadius = placement.cornerRadius
        outer.layer.cornerCurve = .continuous
        outer.clipsToBounds = false
        outer.layer.shadowColor = UIColor.black.cgColor
        outer.layer.shadowOpacity = 0.14
        outer.layer.shadowRadius = 8.95
        outer.layer.shadowOffset = CGSize(width: 0, height: 4)
        outer.layer.masksToBounds = false

        let innerSide = max(0, side - borderWidth * 2)
        let innerRadius = max(0, placement.cornerRadius - borderWidth)
        let imageView = UIImageView(frame: CGRect(x: borderWidth, y: borderWidth, width: innerSide, height: innerSide))
        imageView.tag = imageTag
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = UIColor(white: 0.92, alpha: 1)
        imageView.layer.cornerRadius = innerRadius
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true
        outer.addSubview(imageView)

        let wrapper = UIView(frame: CGRect(x: 0, y: 0, width: side, height: side))
        wrapper.backgroundColor = .clear
        wrapper.clipsToBounds = false
        wrapper.addSubview(outer)
        outer.center = CGPoint(x: side / 2, y: side / 2)
        wrapper.center = placement.center
        wrapper.transform = CGAffineTransform(rotationAngle: placement.rotationDegrees * .pi / 180)
        return wrapper
    }
}

// MARK: - Cluster markers

enum ClusterMemberPreviewResolver {

    struct PreviewImageRef {
        let member: FlutterAnnotation
        let urlIndex: Int
    }

    /// Logical image count for labels (matches multi-dopin marker semantics).
    static func imageCount(for annotation: FlutterAnnotation) -> Int {
        if annotation.usesDopinMarker {
            let urlCount = min(annotation.dopinImageUrls.count, 4)
            let hasFallbackImage = annotation.dopinImagePngData != nil
                || annotation.dopinImageAssetName != nil
            var count = urlCount > 0 ? urlCount : (hasFallbackImage ? 1 : 1)
            if let markerCount = annotation.dopinMarkerCount, markerCount > count {
                count = markerCount
            }
            return count
        }
        return 1
    }

    static func totalImageCount(for members: [FlutterAnnotation]) -> Int {
        members.reduce(0) { $0 + imageCount(for: $1) }
    }

    /// First [limit] images across cluster members, in member order.
    static func flattenedPreviewRefs(
        for members: [FlutterAnnotation],
        limit: Int = 3
    ) -> [PreviewImageRef] {
        var refs: [PreviewImageRef] = []
        for member in members {
            let logicalCount = imageCount(for: member)
            for index in 0..<logicalCount {
                if refs.count >= limit { return refs }
                refs.append(PreviewImageRef(member: member, urlIndex: index))
            }
        }
        return refs
    }

    static func signature(for members: [FlutterAnnotation]) -> String {
        let totalImages = totalImageCount(for: members)
        let previewSig = flattenedPreviewRefs(for: members, limit: 3)
            .map { "\($0.member.id ?? ""):\($0.urlIndex)" }
            .joined(separator: ",")
        return "\(totalImages)|\(previewSig)"
    }

    static func memberSignature(_ annotation: FlutterAnnotation) -> String {
        if annotation.usesDopinMarker { return annotation.dopinMarkerSignature }
        if annotation.usesSvgMarker { return annotation.svgMarkerSignature }
        if annotation.usesCardMarker { return annotation.cardMarkerSignature }
        return annotation.id
    }

    static func loadPreview(for annotation: FlutterAnnotation, completion: @escaping (UIImage?) -> Void) {
        if annotation.usesDopinMarker {
            DopinMarkerImageLoader.load(for: annotation, completion: completion)
            return
        }
        if annotation.usesSvgMarker {
            if let emoji = annotation.svgEmoji, !emoji.isEmpty {
                completion(SvgMarkerImageLoader.emojiImage(emoji, side: 32))
                return
            }
            SvgMarkerImageLoader.loadCenterImage(for: annotation) { image in
                if let image = image {
                    completion(image)
                } else {
                    completion(SvgMarkerImageLoader.eventFillMarkerImage(width: 24, height: 32))
                }
            }
            return
        }
        if annotation.usesCardMarker {
            loadCardPreview(annotation, completion: completion)
            return
        }
        if let image = annotation.icon.image {
            completion(image)
            return
        }
        completion(DopinMarkerImageLoader.blankProfileImage)
    }

    static func loadClusterPreview(
        _ ref: PreviewImageRef,
        completion: @escaping (UIImage?) -> Void
    ) {
        let member = ref.member
        if member.usesDopinMarker {
            if !member.dopinImageUrls.isEmpty {
                let index = min(ref.urlIndex, member.dopinImageUrls.count - 1)
                DopinMarkerImageLoader.load(
                    urlString: member.dopinImageUrls[index],
                    completion: completion
                )
                return
            }
            DopinMarkerImageLoader.load(for: member, completion: completion)
            return
        }
        loadPreview(for: member, completion: completion)
    }

    private static func loadCardPreview(
        _ annotation: FlutterAnnotation,
        completion: @escaping (UIImage?) -> Void
    ) {
        if let data = annotation.cardImagePngData,
           let image = UIImage(data: data, scale: UIScreen.main.scale) {
            completion(image)
            return
        }
        if let name = annotation.cardImageAssetName, let base = UIImage(named: name) {
            let scale = annotation.cardImageAssetScale
            if abs(scale - 1.0) < 0.001, let cg = base.cgImage {
                completion(UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: base.imageOrientation))
            } else if let cg = base.cgImage {
                completion(UIImage(cgImage: cg, scale: scale, orientation: base.imageOrientation))
            } else {
                completion(base)
            }
            return
        }
        DopinMarkerImageLoader.load(urlString: annotation.cardImageUrl, completion: completion)
    }
}

@available(iOS 11.0, *)
final class ClusterMarkerAnnotationView: MKAnnotationView {

    static let reuseId = "cluster_marker"

    private static let contentTag = 8_445_001
    private static let imageTagBase = 8_445_010

    private var configuredSignature: String?
    private var imageLoadToken: String?

    override var annotation: MKAnnotation? {
        didSet { applyClusterIfNeeded(force: false) }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        canShowCallout = false
        clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        configuredSignature = nil
        imageLoadToken = nil
        viewWithTag(Self.contentTag)?.removeFromSuperview()
        bounds = .zero
        frame = .zero
    }

    func configureIfNeeded() {
        applyClusterIfNeeded(force: false)
    }

    private func applyClusterIfNeeded(force: Bool) {
        guard let cluster = annotation as? MKClusterAnnotation else { return }

        let members = cluster.memberAnnotations.compactMap { $0 as? FlutterAnnotation }
        let sig = ClusterMemberPreviewResolver.signature(for: members)
        if !force, sig == configuredSignature { return }
        configuredSignature = sig

        viewWithTag(Self.contentTag)?.removeFromSuperview()
        image = nil

        let totalImageCount = ClusterMemberPreviewResolver.totalImageCount(for: members)
        let previewSlots = min(3, totalImageCount)
        let previewRefs = ClusterMemberPreviewResolver.flattenedPreviewRefs(
            for: members,
            limit: previewSlots
        )
        let content = ClusterStackMarkerBuilder.buildContent(
            memberCount: totalImageCount,
            previewSlots: previewSlots,
            imageTagBase: Self.imageTagBase
        )
        content.tag = Self.contentTag
        addSubview(content)

        let size = content.bounds.size
        bounds = CGRect(origin: .zero, size: size)
        frame.size = size
        content.frame = bounds
        centerOffset = CGPoint(x: 0, y: -size.height / 2)

        loadPreviewImages(into: content, refs: previewRefs)
    }

    private func loadPreviewImages(into content: UIView, refs: [ClusterMemberPreviewResolver.PreviewImageRef]) {
        let token = configuredSignature ?? UUID().uuidString
        imageLoadToken = token

        for (index, ref) in refs.enumerated() {
            guard let imageView = content.viewWithTag(Self.imageTagBase + index) as? UIImageView else {
                continue
            }
            ClusterMemberPreviewResolver.loadClusterPreview(ref) { [weak self] image in
                guard let self = self, self.imageLoadToken == token else { return }
                DopinMarkerImageLoader.applyProfileImage(image, to: imageView)
            }
        }
    }
}
