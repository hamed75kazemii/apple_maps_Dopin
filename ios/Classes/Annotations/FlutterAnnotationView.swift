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

enum DopinMarkerImageLoader {

    private static let cache = NSCache<NSString, UIImage>()
    private static var inFlight = [String: [(UIImage?) -> Void]]()

    /// Priority: PNG bytes → asset → URL.
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
        load(urlString: annotation.dopinImageUrl, completion: completion)
    }

    static func load(urlString: String?, completion: @escaping (UIImage?) -> Void) {
        guard let urlString = urlString, !urlString.isEmpty, let url = URL(string: urlString) else {
            completion(nil)
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

        URLSession.shared.dataTask(with: url) { data, _, _ in
            var image: UIImage?
            if let data = data {
                image = UIImage(data: data, scale: UIScreen.main.scale)
                if let image = image {
                    cache.setObject(image, forKey: key)
                }
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
    private static let imageTag = 8_441_002

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

    private func applyAnnotationIfNeeded(force: Bool) {
        guard let flutter = annotation as? FlutterAnnotation, flutter.usesDopinMarker else { return }

        let sig = flutter.dopinMarkerSignature
        if !force, sig == configuredSignature { return }
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

        loadMarkerImage(into: content, annotation: flutter)
    }

    private func loadMarkerImage(into content: UIView, annotation: FlutterAnnotation) {
        let token = annotation.dopinMarkerSignature
        imageLoadToken = token
        DopinMarkerImageLoader.load(for: annotation) { [weak self, weak content] image in
            guard let self = self, let content = content, self.imageLoadToken == token else { return }
            guard let imageView = Self.findImageView(in: content) else { return }
            if let image = image {
                imageView.image = image
                imageView.backgroundColor = .clear
            }
        }
    }

    private static func findImageView(in root: UIView) -> UIImageView? {
        if let iv = root.viewWithTag(imageTag) as? UIImageView { return iv }
        for child in root.subviews {
            if let found = findImageView(in: child) { return found }
        }
        return nil
    }

    private static func buildDopinMarker(annotation: FlutterAnnotation) -> UIView {
        let frameW = annotation.dopinFrameWidth
        let frameH = annotation.dopinFrameHeight
        let border = annotation.dopinBorderWidth
        let outerRadius = annotation.dopinBorderRadius ?? min(frameW, frameH) / 2
        let innerRadius = max(0, outerRadius - border)

        let labelText = annotation.dopinMarkerLabel ?? ""
        let hasLabel = !labelText.isEmpty
        let badgeH = annotation.dopinBadgeHeight
        let badgeOverlap: CGFloat = 8
        let totalW = frameW
        let totalH = hasLabel ? frameH + badgeH - badgeOverlap : frameH

        let container = UIView(frame: CGRect(x: 0, y: 0, width: totalW, height: totalH))

        let frameView = UIView(frame: CGRect(x: 0, y: 0, width: frameW, height: frameH))
        frameView.backgroundColor = annotation.dopinBorderColor
        frameView.layer.cornerRadius = outerRadius
        frameView.clipsToBounds = true

        let avatarSide = max(0, min(frameW, frameH) - border * 2)
        let avatarWrap = UIView(frame: CGRect(x: 0, y: 0, width: avatarSide, height: avatarSide))
        avatarWrap.layer.cornerRadius = innerRadius
        avatarWrap.clipsToBounds = true
        avatarWrap.center = CGPoint(x: frameView.bounds.midX, y: frameView.bounds.midY)
        let avatar = UIImageView(frame: avatarWrap.bounds)
        avatar.tag = imageTag
        avatar.contentMode = .scaleAspectFill
        avatar.backgroundColor = UIColor(white: 0.92, alpha: 1)
        avatarWrap.addSubview(avatar)
        frameView.addSubview(avatarWrap)
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

        container.bounds = CGRect(origin: .zero, size: CGSize(width: totalW, height: totalH))
        return container
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

    /// Renders the bundled vector SVG at [width]×[height] points (device scale).
    static func eventMarkerImage(width: CGFloat, height: CGFloat) -> UIImage? {
        let scale = UIScreen.main.scale
        let key = "event_marker|\(width)|\(height)|\(scale)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let vector = UIImage(named: "event_marker", in: resourceBundle, compatibleWith: nil) else {
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
}

final class SvgMarkerAnnotationView: GlowFlutterAnnotationView {

    private var configuredSignature: String?

    override var annotation: MKAnnotation? {
        didSet { applyAnnotationIfNeeded(force: true) }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        configuredSignature = nil
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

    private func applyAnnotationIfNeeded(force: Bool) {
        guard let flutter = annotation as? FlutterAnnotation, flutter.usesSvgMarker else { return }

        let sig = flutter.svgMarkerSignature
        if !force, sig == configuredSignature { return }
        configuredSignature = sig

        backgroundColor = .clear
        clipsToBounds = false

        let size = CGSize(width: flutter.svgWidth, height: flutter.svgHeight)
        bounds = CGRect(origin: .zero, size: size)
        frame.size = size
        image = SvgMarkerImageLoader.eventMarkerImage(
            width: flutter.svgWidth,
            height: flutter.svgHeight
        )
    }
}
