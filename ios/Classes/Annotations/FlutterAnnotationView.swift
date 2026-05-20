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
        guard let flutter = annotation as? FlutterAnnotation,
              let style = flutter.dopinMarkerStyle else { return }

        let sig = flutter.dopinMarkerSignature
        if !force, sig == configuredSignature { return }
        configuredSignature = sig

        viewWithTag(Self.contentTag)?.removeFromSuperview()
        image = nil
        backgroundColor = .clear
        clipsToBounds = false

        let content: UIView
        switch style {
        case .me:
            content = Self.buildMeMarker(
                label: flutter.dopinMarkerLabel ?? "Me",
                primary: flutter.dopinPrimaryColor,
                second: flutter.dopinSecondPrimaryColor
            )
        case .event:
            content = Self.buildEventMarker(borderColor: flutter.dopinBorderColor)
        case .dopin:
            content = Self.buildDopinMarker(borderColor: flutter.dopinBorderColor)
        case .cluster:
            content = Self.buildClusterMarker(
                count: flutter.dopinClusterCount,
                primary: flutter.dopinBorderColor,
                second: flutter.dopinSecondPrimaryColor
            )
        }
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

    private static func buildMeMarker(label: String, primary: UIColor, second: UIColor) -> UIView {
        let w: CGFloat = 46
        let h: CGFloat = 54
        let container = UIView(frame: CGRect(x: 0, y: 0, width: w, height: h))

        let outer = UIView(frame: CGRect(x: 3, y: 0, width: 40, height: 46))
        outer.backgroundColor = .white
        outer.layer.cornerRadius = 15
        outer.clipsToBounds = true

        let pad: CGFloat = 3
        let avatarFrame = CGRect(x: pad, y: pad, width: 40 - pad * 2, height: 40 - pad * 2)
        let avatarWrap = UIView(frame: avatarFrame)
        avatarWrap.layer.cornerRadius = 12
        avatarWrap.clipsToBounds = true
        avatarWrap.center = CGPoint(x: outer.bounds.midX, y: outer.bounds.midY - 2)
        let avatar = UIImageView(frame: avatarWrap.bounds)
        avatar.tag = imageTag
        avatar.contentMode = .scaleAspectFill
        avatar.backgroundColor = UIColor(white: 0.92, alpha: 1)
        avatarWrap.addSubview(avatar)
        outer.addSubview(avatarWrap)
        container.addSubview(outer)

        let badge = UIView(frame: CGRect(x: 0, y: h - 20, width: w, height: 20))
        badge.backgroundColor = .white
        badge.layer.cornerRadius = 10
        badge.clipsToBounds = true
        let badgeLabel = UILabel(frame: badge.bounds.insetBy(dx: 4, dy: 2))
        badgeLabel.text = label
        badgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        badgeLabel.textAlignment = .center
        badgeLabel.textColor = primary
        badge.addSubview(badgeLabel)
        Self.applyGradientText(to: badgeLabel, colors: [primary, second])
        container.addSubview(badge)

        container.bounds = CGRect(origin: .zero, size: CGSize(width: w, height: h))
        return container
    }

    private static func applyGradientText(to label: UILabel, colors: [UIColor]) {
        label.layoutIfNeeded()
        let gradient = CAGradientLayer()
        gradient.colors = colors.map { $0.cgColor }
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = label.bounds
        let text = CATextLayer()
        text.string = label.text
        text.font = label.font
        text.fontSize = label.font.pointSize
        text.alignmentMode = .center
        text.frame = label.bounds
        text.contentsScale = UIScreen.main.scale
        gradient.mask = text
        label.layer.addSublayer(gradient)
        label.textColor = .clear
    }

    private static func buildEventMarker(borderColor: UIColor) -> UIView {
        let side: CGFloat = 40
        let shadowPad: CGFloat = 12
        let total = side + shadowPad * 2
        let container = UIView(frame: CGRect(x: 0, y: 0, width: total, height: total))
        container.backgroundColor = .clear

        let shadowHost = UIView(frame: CGRect(x: shadowPad, y: shadowPad, width: side, height: side))
        shadowHost.layer.shadowColor = UIColor.black.cgColor
        shadowHost.layer.shadowOpacity = 0.25
        shadowHost.layer.shadowRadius = 13
        shadowHost.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadowHost.backgroundColor = .clear

        let ring = UIView(frame: shadowHost.bounds)
        ring.backgroundColor = borderColor
        ring.layer.cornerRadius = side / 2
        ring.clipsToBounds = true

        let image = UIImageView(frame: ring.bounds.insetBy(dx: 2, dy: 2))
        image.tag = imageTag
        image.layer.cornerRadius = (side - 4) / 2
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.backgroundColor = UIColor(white: 0.9, alpha: 1)
        ring.addSubview(image)
        shadowHost.addSubview(ring)
        container.addSubview(shadowHost)

        container.bounds = CGRect(origin: .zero, size: CGSize(width: total, height: total))
        return container
    }

    private static func buildDopinMarker(borderColor: UIColor) -> UIView {
        let side: CGFloat = 43
        let pad: CGFloat = 10
        let total = side + pad * 2
        let container = UIView(frame: CGRect(x: 0, y: 0, width: total, height: total))

        let shadowHost = UIView(frame: CGRect(x: pad, y: pad, width: side, height: side))
        shadowHost.layer.shadowColor = UIColor.black.cgColor
        shadowHost.layer.shadowOpacity = 0.15
        shadowHost.layer.shadowRadius = 9
        shadowHost.layer.shadowOffset = .zero

        let border = UIView(frame: shadowHost.bounds)
        border.backgroundColor = borderColor
        border.layer.cornerRadius = 12
        border.clipsToBounds = true

        let image = UIImageView(frame: border.bounds.insetBy(dx: 3, dy: 3))
        image.tag = imageTag
        image.layer.cornerRadius = 9
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.backgroundColor = UIColor(white: 0.9, alpha: 1)
        border.addSubview(image)
        shadowHost.addSubview(border)
        container.addSubview(shadowHost)

        container.bounds = CGRect(origin: .zero, size: CGSize(width: total, height: total))
        return container
    }

    private static func buildClusterMarker(count: Int, primary: UIColor, second: UIColor) -> UIView {
        let outer: CGFloat = 72
        let container = UIView(frame: CGRect(x: 0, y: 0, width: outer, height: outer))

        let shell = UIView(frame: container.bounds)
        shell.backgroundColor = .white
        shell.layer.cornerRadius = outer / 2

        let ring = UIView(frame: shell.bounds.insetBy(dx: 6, dy: 6))
        ring.layer.cornerRadius = ring.bounds.width / 2
        ring.clipsToBounds = true
        let gradient = CAGradientLayer()
        gradient.colors = [primary.cgColor, second.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = ring.bounds
        ring.layer.insertSublayer(gradient, at: 0)

        let inner = UIView(frame: ring.bounds.insetBy(dx: 4, dy: 4))
        inner.backgroundColor = .white
        inner.layer.cornerRadius = inner.bounds.width / 2

        let label = UILabel(frame: inner.bounds)
        label.text = count > 9 ? "9+" : "\(count)"
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .black
        inner.addSubview(label)

        ring.addSubview(inner)
        shell.addSubview(ring)
        container.addSubview(shell)

        container.bounds = CGRect(origin: .zero, size: CGSize(width: outer, height: outer))
        return container
    }
}
