// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Drop shadow for map markers (iOS).
@immutable
class MarkerShadow {
  const MarkerShadow({
    this.color = const Color(0x40000000),
    this.blurRadius = 4,
    this.offset = const Offset(0, 2),
  }) : assert(blurRadius >= 0);

  /// Shadow color; alpha controls opacity.
  final Color color;

  /// Blur radius in logical pixels.
  final double blurRadius;

  /// Shadow offset from the marker.
  final Offset offset;

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'color': color.value,
      'blurRadius': blurRadius,
      'offset': <double>[offset.dx, offset.dy],
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MarkerShadow) return false;
    final MarkerShadow o = other;
    return color == o.color &&
        blurRadius == o.blurRadius &&
        offset == o.offset;
  }

  @override
  int get hashCode => Object.hash(color, blurRadius, offset);
}
