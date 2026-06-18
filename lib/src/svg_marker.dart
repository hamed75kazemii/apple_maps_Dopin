// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Native event pin marker (iOS).
///
/// The icon is a vector SVG bundled in the plugin's iOS asset catalog and
/// rendered natively at [width] × [height] points. For pin-shaped icons, use
/// `anchor: Offset(0.5, 1.0)` on the parent [Annotation].
@immutable
class SvgMarker {
  const SvgMarker({
    this.width = 38,
    this.height = 50,
  });

  /// Logical width in points.
  final double width;

  /// Logical height in points.
  final double height;

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'width': width,
      'height': height,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SvgMarker) return false;
    final SvgMarker o = other;
    return width == o.width && height == o.height;
  }

  @override
  int get hashCode => Object.hash(width, height);
}
