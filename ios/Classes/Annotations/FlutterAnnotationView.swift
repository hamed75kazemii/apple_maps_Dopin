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
        guard let flutter = annotation as? FlutterAnnotation else { return }
        let target = contentView ?? self
        MarkerShadowStyle.apply(to: target, from: flutter)
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
        guard let flutterAnnotation = annotation as? FlutterAnnotation, flutterAnnotation.glow else { return }

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

final class DopinMarkerAnnotationView: GlowFlutterAnnotationView {

    private static let contentTag = 8_441_001
    private static let imageTagBase = 8_441_002

    private var configuredSignature: String?
    private var imageLoadToken: String?

    override var annotation: MKAnnotation? {
        didSet { applyAnnotationIfNeeded(force: true) }
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
        applyAnnotationIfNeeded(force: true)
    }

    override func applyFlutterMarkerShadow(contentView: UIView? = nil) {
        super.applyFlutterMarkerShadow(contentView: contentView ?? viewWithTag(Self.contentTag))
    }

    private func applyAnnotationIfNeeded(force: Bool) {
        guard let flutter = annotation as? FlutterAnnotation, flutter.usesDopinMarker else { return }

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

        let imageViews = Self.findImageViews(in: content)
        let urlCount = min(annotation.dopinImageUrls.count, 4)

        if urlCount > 1 {
            for index in 0..<urlCount {
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
        iv.clipsToBounds = true
        return iv
    }

    private static func wrapMarkerWithBadge(
        frameView: UIView,
        frameW: CGFloat,
        frameH: CGFloat,
        annotation: FlutterAnnotation
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
            badge.backgroundColor = .white
            badge.layer.cornerRadius = badgeH / 2
            badge.clipsToBounds = true
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

        if let count = annotation.dopinMarkerCount, count > 0 {
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

        if imageCount <= 1 {
            return buildSingleImageMarker(annotation: annotation)
        }
        return buildMultiImageMarker(annotation: annotation, imageCount: imageCount)
    }

    private static func buildSingleImageMarker(annotation: FlutterAnnotation) -> UIView {
        let frameW = annotation.dopinFrameWidth
        let frameH = annotation.dopinFrameHeight
        let border = annotation.dopinBorderWidth
        let outerRadius = annotation.dopinBorderRadius ?? min(frameW, frameH) / 2
        let innerRadius = max(0, outerRadius - border)

        let frameView = UIView(frame: CGRect(x: 0, y: 0, width: frameW, height: frameH))
        frameView.backgroundColor = annotation.dopinBorderColor
        frameView.layer.cornerRadius = outerRadius
        frameView.clipsToBounds = true

        let avatarSide = max(0, min(frameW, frameH) - border * 2)
        let avatarWrap = UIView(frame: CGRect(x: 0, y: 0, width: avatarSide, height: avatarSide))
        avatarWrap.layer.cornerRadius = innerRadius
        avatarWrap.clipsToBounds = true
        avatarWrap.center = CGPoint(x: frameView.bounds.midX, y: frameView.bounds.midY)
        let avatar = imageView(side: avatarSide, cornerRadius: innerRadius, tag: imageTagBase)
        avatarWrap.addSubview(avatar)
        frameView.addSubview(avatarWrap)

        return wrapMarkerWithBadge(frameView: frameView, frameW: frameW, frameH: frameH, annotation: annotation)
    }

    private static func buildMultiImageMarker(annotation: FlutterAnnotation, imageCount: Int) -> UIView {
        let baseW = annotation.dopinFrameWidth
        let baseH = annotation.dopinFrameHeight
        let padding: CGFloat = 4
        let gap: CGFloat = 3

        let frameW = baseW
        let frameH: CGFloat
        let outerRadius: CGFloat

        switch imageCount {
        case 2:
            frameH = baseH / 2
            outerRadius = frameH / 2
        default:
            frameH = baseH
            outerRadius = annotation.dopinBorderRadius ?? min(baseW, baseH) / 2
        }

        let innerW = max(0, frameW - padding * 2)
        let innerH = max(0, frameH - padding * 2)

        let cell: CGFloat
        var placements: [(origin: CGPoint, index: Int)] = []

        switch imageCount {
        case 2:
            let dualPadding: CGFloat = 3
            let dualInnerW = max(0, frameW - dualPadding * 2)
            let dualInnerH = max(0, frameH - dualPadding * 2)
            let maxDualCell = min((dualInnerW - gap) / 2, dualInnerH)
            cell = min(maxDualCell + 2, dualInnerH, (dualInnerW - gap) / 2)
            let rowW = cell * 2 + gap
            let startX = dualPadding + (dualInnerW - rowW) / 2
            let startY = dualPadding + (dualInnerH - cell) / 2
            placements = [
                (CGPoint(x: startX, y: startY), 0),
                (CGPoint(x: startX + cell + gap, y: startY), 1),
            ]
        case 3:
            cell = min((innerW - gap) / 2, (innerH - gap) / 2)
            let gridW = cell * 2 + gap
            let gridH = cell * 2 + gap
            let startX = padding + (innerW - gridW) / 2
            let startY = padding + (innerH - gridH) / 2
            placements = [
                (CGPoint(x: startX, y: startY), 0),
                (CGPoint(x: startX + cell + gap, y: startY), 1),
                (CGPoint(x: startX + (cell + gap) / 2, y: startY + cell + gap), 2),
            ]
        default:
            cell = min((innerW - gap) / 2, (innerH - gap) / 2)
            let gridW = cell * 2 + gap
            let gridH = cell * 2 + gap
            let startX = padding + (innerW - gridW) / 2
            let startY = padding + (innerH - gridH) / 2
            placements = [
                (CGPoint(x: startX, y: startY), 0),
                (CGPoint(x: startX + cell + gap, y: startY), 1),
                (CGPoint(x: startX, y: startY + cell + gap), 2),
                (CGPoint(x: startX + cell + gap, y: startY + cell + gap), 3),
            ]
        }

        let imageCorner = cell * 0.28

        let frameView = UIView(frame: CGRect(x: 0, y: 0, width: frameW, height: frameH))
        frameView.backgroundColor = annotation.dopinBorderColor
        frameView.layer.cornerRadius = outerRadius
        frameView.clipsToBounds = true

        for placement in placements {
            let iv = imageView(side: cell, cornerRadius: imageCorner, tag: imageTagBase + placement.index)
            iv.frame.origin = placement.origin
            frameView.addSubview(iv)
        }

        return wrapMarkerWithBadge(frameView: frameView, frameW: frameW, frameH: frameH, annotation: annotation)
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
        didSet { applyAnnotationIfNeeded(force: true) }
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
        applyAnnotationIfNeeded(force: true)
    }

    override func applyFlutterMarkerShadow(contentView: UIView? = nil) {
        super.applyFlutterMarkerShadow(contentView: contentView ?? viewWithTag(Self.contentTag))
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
        return container
    }
}
