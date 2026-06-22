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

    private static let glowSubviewTag = 9_133_701
    /// Fixed halo size in points (see layout).
    private static let glowSide: CGFloat = 40
    /// Rounded square at pulse start; animates up to a full circle (`glowSide / 2`).
    private static let glowCornerRadiusStart: CGFloat = 12

    private var lastGlowSignature: String?

    override func prepareForReuse() {
        super.prepareForReuse()
        lastGlowSignature = nil
        viewWithTag(Self.glowSubviewTag)?.removeFromSuperview()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        guard let flutterAnnotation = annotation as? FlutterAnnotation, flutterAnnotation.glow else { return }

        let glow: UIView
        if let existing = viewWithTag(Self.glowSubviewTag) as? UIView {
            glow = existing
        } else {
            glow = UIView()
            glow.tag = Self.glowSubviewTag
            glow.isUserInteractionEnabled = false
            glow.layer.masksToBounds = true
            insertSubview(glow, at: 0)
        }

        let side = Self.glowSide
        glow.layer.masksToBounds = true
        glow.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        glow.center = CGPoint(x: bounds.midX, y: bounds.midY)

        let argb = flutterAnnotation.glowColorArgb
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        let intensity = CGFloat(min(max(flutterAnnotation.glowIntensity, 0), 1))
        let fillAlpha = a * 0.55 * intensity
        glow.backgroundColor = UIColor(red: r, green: g, blue: b, alpha: fillAlpha)

        let sig = "\(flutterAnnotation.glowColorArgb)-\(flutterAnnotation.glowIntensity)"
        if sig != lastGlowSignature {
            lastGlowSignature = sig
            glow.layer.removeAllAnimations()
            let peakOpacity = Float(a * intensity)
            let maxScale = 1.0 + 0.95 * intensity
            let pulseDuration = (1.1 + (1.0 - Double(intensity)) * 0.9) 
            let cornerEnd = side / 2
            Self.addRepeatingGlowPulse(
                to: glow.layer,
                maxScale: maxScale,
                peakOpacity: peakOpacity,
                pulseDuration: pulseDuration,
                cornerRadiusFrom: Self.glowCornerRadiusStart,
                cornerRadiusTo: cornerEnd
            )
        }
    }

    /// One full outward pulse per cycle (ease-out), repeated forever; does not restart on layout unless color/intensity change.
    private static func addRepeatingGlowPulse(
        to layer: CALayer,
        maxScale: CGFloat,
        peakOpacity: Float,
        pulseDuration: CFTimeInterval,
        cornerRadiusFrom: CGFloat,
        cornerRadiusTo: CGFloat
    ) {
        guard peakOpacity > 0 else { return }

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = maxScale
        scale.duration = pulseDuration
        scale.autoreverses = false
        scale.repeatCount = .infinity
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        scale.isRemovedOnCompletion = false

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = peakOpacity
        opacity.toValue = 0
        opacity.duration = pulseDuration
        opacity.autoreverses = false
        opacity.repeatCount = .infinity
        opacity.timingFunction = CAMediaTimingFunction(name: .easeOut)
        opacity.isRemovedOnCompletion = false

        let corner = CABasicAnimation(keyPath: "cornerRadius")
        corner.fromValue = cornerRadiusFrom
        corner.toValue = cornerRadiusTo
        corner.duration = pulseDuration
        corner.autoreverses = false
        corner.repeatCount = .infinity
        corner.timingFunction = CAMediaTimingFunction(name: .easeOut)
        corner.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DIdentity
        layer.opacity = peakOpacity
        layer.cornerRadius = cornerRadiusFrom
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
            let badgeLabel = UILabel(frame: badge.bounds.insetBy(dx: 4, dy: 2))
            badgeLabel.text = labelText
            badgeLabel.font = .systemFont(ofSize: annotation.dopinLabelFontSize, weight: .semibold)
            badgeLabel.textAlignment = .center
            badgeLabel.textColor = annotation.dopinLabelColor
            badge.addSubview(badgeLabel)
            container.addSubview(badge)
        }

        if let count = annotation.dopinMarkerCount, count > 0 {
            addCountBadge(to: container, frameW: frameW, frameH: frameH, count: count)
        }

        container.bounds = CGRect(origin: .zero, size: CGSize(width: totalW, height: totalH))
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

        let pinView = UIImageView(frame: container.bounds)
        pinView.tag = pinTag
        pinView.contentMode = .scaleToFill
        let hasImage = annotation.svgImagePngData != nil
            || !(annotation.svgImageUrl ?? "").isEmpty
        pinView.image = hasImage
            ? SvgMarkerImageLoader.eventMarkerImage(width: width, height: height)
            : SvgMarkerImageLoader.eventFillMarkerImage(width: width, height: height)
        container.addSubview(pinView)

        let avatarFrame = SvgMarkerImageLoader.centerAvatarFrame(width: width, height: height)
        let avatarView = UIImageView(frame: avatarFrame)
        avatarView.tag = avatarTag
        avatarView.contentMode = .scaleAspectFill
        avatarView.backgroundColor = UIColor(white: 0.92, alpha: 1)
        avatarView.layer.cornerRadius = avatarFrame.width / 2
        avatarView.clipsToBounds = true
        avatarView.isHidden = !hasImage
        container.addSubview(avatarView)

        container.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        return container
    }
}
