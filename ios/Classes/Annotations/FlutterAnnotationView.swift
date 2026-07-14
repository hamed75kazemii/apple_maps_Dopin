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
            let halfScale: CGFloat = 0.8
            let overshootScale: CGFloat = 1.25
            let animationOptions: UIView.AnimationOptions = [
                .allowUserInteraction,
                .beginFromCurrentState,
            ]

            func scaledTransform(_ factor: CGFloat) -> CGAffineTransform {
                targetTransform.scaledBy(x: factor, y: factor)
            }

            func animateScale(
                to factor: CGFloat,
                duration: TimeInterval,
                curve: UIView.AnimationOptions = [.curveEaseInOut],
                damping: CGFloat? = nil,
                velocity: CGFloat = 0,
                completion: ((Bool) -> Void)? = nil
            ) {
                if let damping = damping {
                    UIView.animate(
                        withDuration: duration,
                        delay: 0,
                        usingSpringWithDamping: damping,
                        initialSpringVelocity: velocity,
                        options: animationOptions,
                        animations: {
                            self.transform = scaledTransform(factor)
                        },
                        completion: completion
                    )
                } else {
                    UIView.animate(
                        withDuration: duration,
                        delay: 0,
                        options: animationOptions.union(curve),
                        animations: {
                            self.transform = scaledTransform(factor)
                        },
                        completion: completion
                    )
                }
            }

            self.transform = scaledTransform(smallScale)

            // Pulse 1: small → big → half scale
            animateScale(to: overshootScale, duration: 0.12, curve: .curveEaseOut) { finished in
                guard finished else { return }
                animateScale(to: halfScale, duration: 0.1, curve: .curveEaseIn) { finished in
                    guard finished else { return }
                    // Pulse 2: half → big → final size
                    animateScale(to: overshootScale, duration: 0.12, curve: .curveEaseOut) { finished in
                        guard finished else { return }
                        animateScale(
                            to: 1.0,
                            duration: 0.30,
                            damping: 0.58,
                            velocity: 0.45
                        )
                    }
                }
            }
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

    /// Style payload when this view renders [MKUserLocation].
    var userLocationStyle: FlutterAnnotation?

    private var configuredSignature: String?
    private var imageLoadToken: String?

    override var annotation: MKAnnotation? {
        didSet { applyAnnotationIfNeeded(force: true) }
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
            let width = Double(frame.size.width)
            let height = Double(frame.size.height)
            if width > 0, height > 0 {
                centerOffset = CGPoint(
                    x: (0.5 - style.anchor.x) * width,
                    y: (0.5 - style.anchor.y) * height
                )
            }
        }
    }

    func configureIfNeeded() {
        applyAnnotationIfNeeded(force: true)
    }

    override func applyFlutterMarkerShadow(contentView: UIView? = nil) {
        super.applyFlutterMarkerShadow(contentView: contentView ?? viewWithTag(Self.contentTag))
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

        if imageCount <= 1 {
            return buildSingleImageMarker(annotation: annotation)
        }

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
        return wrapMarkerWithBadge(
            frameView: stackContent,
            frameW: ClusterStackMarkerBuilder.totalWidth,
            frameH: stackContent.bounds.height,
            annotation: annotation,
            suppressCountBadge: memberCount > previewSlots
        )
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
        AvatarPlacement(side: 33.187, cornerRadius: 10, rotationDegrees: -8.1, center: CGPoint(x: 30, y: 30)),
        AvatarPlacement(side: 40, cornerRadius: 12, rotationDegrees: 10.88, center: CGPoint(x: 48, y: 34)),
        AvatarPlacement(side: 28.053, cornerRadius: 8, rotationDegrees: 2.75, center: CGPoint(x: 38, y: 16)),
    ]

    static func moreLabelText(memberCount: Int, previewCount: Int) -> String? {
        let remaining = max(0, memberCount - previewCount)
        guard remaining > 0 else { return nil }
        if remaining >= 5 {
            return "\(remaining)+ more"
        }
        return remaining == 1 ? "1 more" : "\(remaining) more"
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

    static func signature(for members: [FlutterAnnotation], totalCount: Int) -> String {
        let previews = members.prefix(3).map { memberSignature($0) }.joined(separator: "|")
        return "\(totalCount)|\(previews)"
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
        didSet { applyClusterIfNeeded(force: true) }
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
        applyClusterIfNeeded(force: true)
    }

    private func applyClusterIfNeeded(force: Bool) {
        guard let cluster = annotation as? MKClusterAnnotation else { return }

        let members = cluster.memberAnnotations.compactMap { $0 as? FlutterAnnotation }
        let sig = ClusterMemberPreviewResolver.signature(
            for: members,
            totalCount: cluster.memberAnnotations.count
        )
        if !force, sig == configuredSignature { return }
        configuredSignature = sig

        viewWithTag(Self.contentTag)?.removeFromSuperview()
        image = nil

        let memberCount = cluster.memberAnnotations.count
        let previewSlots = min(3, memberCount)
        let content = ClusterStackMarkerBuilder.buildContent(
            memberCount: memberCount,
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

        loadPreviewImages(into: content, members: Array(members.prefix(previewSlots)))
    }

    private func loadPreviewImages(into content: UIView, members: [FlutterAnnotation]) {
        let token = configuredSignature ?? UUID().uuidString
        imageLoadToken = token

        for (index, member) in members.enumerated() {
            guard let imageView = content.viewWithTag(Self.imageTagBase + index) as? UIImageView else {
                continue
            }
            ClusterMemberPreviewResolver.loadPreview(for: member) { [weak self] image in
                guard let self = self, self.imageLoadToken == token else { return }
                DopinMarkerImageLoader.applyProfileImage(image, to: imageView)
            }
        }
    }
}
