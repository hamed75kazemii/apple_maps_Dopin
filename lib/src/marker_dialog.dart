// Copyright 2024 Apple Maps Flutter contributors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Pill-shaped dialog bubble shown above a map marker (iOS).
///
/// When set on [Annotation.dialog], a fixed-width dark bubble with a downward
/// tail appears above the marker (Dopin / SVG). Long [text] scrolls
/// right-to-left with a right-edge fade, matching the Dopin feed marquee.
@immutable
class MarkerDialog {
  const MarkerDialog({
    required this.text,
    this.width = 163,
    this.height = 32,
    this.backgroundColor = const Color(0xFF131313),
    this.textColor = Colors.white,
    this.fontSize = 14,
    this.horizontalPadding = 10,
    this.gapAboveMarker = 4,
    this.marqueeSpeed = 16,
  }) : assert(width > 0),
       assert(height > 0),
       assert(fontSize > 0),
       assert(horizontalPadding >= 0),
       assert(gapAboveMarker >= 0),
       assert(marqueeSpeed > 0);

  /// Text shown inside the bubble. Empty / whitespace-only → dialog is hidden.
  final String text;

  /// Fixed bubble body width in points (not including the tail).
  final double width;

  /// Fixed bubble body height in points (not including the tail).
  final double height;

  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  /// Horizontal inset for the scrolling text inside the pill.
  final double horizontalPadding;

  /// Vertical space between the dialog tail tip and the marker top.
  final double gapAboveMarker;

  /// Marquee speed in points per second when [text] overflows [width].
  final double marqueeSpeed;

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'text': text,
      'width': width,
      'height': height,
      'backgroundColor': backgroundColor.value,
      'textColor': textColor.value,
      'fontSize': fontSize,
      'horizontalPadding': horizontalPadding,
      'gapAboveMarker': gapAboveMarker,
      'marqueeSpeed': marqueeSpeed,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MarkerDialog) return false;
    return text == other.text &&
        width == other.width &&
        height == other.height &&
        backgroundColor == other.backgroundColor &&
        textColor == other.textColor &&
        fontSize == other.fontSize &&
        horizontalPadding == other.horizontalPadding &&
        gapAboveMarker == other.gapAboveMarker &&
        marqueeSpeed == other.marqueeSpeed;
  }

  @override
  int get hashCode => Object.hash(
        text,
        width,
        height,
        backgroundColor,
        textColor,
        fontSize,
        horizontalPadding,
        gapAboveMarker,
        marqueeSpeed,
      );
}
