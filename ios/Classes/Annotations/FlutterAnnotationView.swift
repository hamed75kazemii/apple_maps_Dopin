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

/// Custom bitmap marker when [FlutterAnnotation.glow] is true: each pulse expands and fades out completely, then repeats forever until [glow] is false.
final class GlowFlutterAnnotationView: FlutterAnnotationView {

    private static let glowSubviewTag = 9_133_701

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
            insertSubview(glow, at: 0)
        }

        let side = min(bounds.width, bounds.height) * (80.0 / 86.0)
        glow.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        glow.center = CGPoint(x: bounds.midX, y: bounds.midY)
        glow.layer.cornerRadius = side / 2

        let argb = flutterAnnotation.glowColorArgb
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        let intensity = CGFloat(min(max(flutterAnnotation.glowIntensity, 0), 1))
        let fillAlpha = a * 0.35 * intensity
        glow.backgroundColor = UIColor(red: r, green: g, blue: b, alpha: fillAlpha)

        let sig = "\(flutterAnnotation.glowColorArgb)-\(flutterAnnotation.glowIntensity)"
        if sig != lastGlowSignature {
            lastGlowSignature = sig
            glow.layer.removeAllAnimations()
            let peakOpacity = Float(a * intensity)
            let maxScale = 1.0 + 0.6 * intensity
            let pulseDuration = 0.45 + (1.0 - Double(intensity)) * 0.35
            Self.addRepeatingGlowPulse(to: glow.layer, maxScale: maxScale, peakOpacity: peakOpacity, pulseDuration: pulseDuration)
        }
    }

    /// One full outward pulse per cycle (ease-out), repeated forever; does not restart on layout unless color/intensity change.
    private static func addRepeatingGlowPulse(to layer: CALayer, maxScale: CGFloat, peakOpacity: Float, pulseDuration: CFTimeInterval) {
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

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DIdentity
        layer.opacity = peakOpacity
        CATransaction.commit()

        layer.add(scale, forKey: "glowScaleLoop")
        layer.add(opacity, forKey: "glowOpacityLoop")
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
