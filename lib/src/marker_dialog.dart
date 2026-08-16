// Copyright 2024 Apple Maps Flutter contributors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Visual style for a marker dialog bubble (iOS).
enum MarkerDialogStyle {
  /// Dark pill with a triangular downward tail (default).
  pill,

  /// Cloud thought-bubble with frosted-glass fill and a dotted tail.
  cloud,
}

/// Pill-shaped dialog bubble shown above a map marker (iOS).
///
/// When set on [Annotation.dialog], a fixed-width dark bubble with a downward
/// tail appears above the marker (Dopin / SVG). Long [text] scrolls
/// right-to-left with a right-edge fade, matching the Dopin feed marquee.
///
/// For the frosted cloud style, use [CloudDialogBox] (or
/// `style: MarkerDialogStyle.cloud`).
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
    this.verticalPadding = 0,
    this.gapAboveMarker = 4,
    this.marqueeSpeed = 16,
    this.style = MarkerDialogStyle.pill,
  })  : assert(width > 0 || style == MarkerDialogStyle.cloud),
        assert(height > 0 || style == MarkerDialogStyle.cloud),
        assert(width >= 0),
        assert(height >= 0),
        assert(fontSize > 0),
        assert(horizontalPadding >= 0),
        assert(verticalPadding >= 0),
        assert(marqueeSpeed > 0);

  /// Text shown inside the bubble. Empty / whitespace-only → dialog is hidden.
  final String text;

  /// Bubble body width in points (not including the tail).
  ///
  /// For [MarkerDialogStyle.cloud], `0` means [cloudWidth].
  final double width;

  /// Bubble body height in points (not including the tail).
  ///
  /// For [MarkerDialogStyle.cloud], `0` means auto-size to [text].
  final double height;

  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  /// Horizontal inset for text inside the bubble.
  final double horizontalPadding;

  /// Vertical inset for text inside the bubble (cloud style). Ignored for pill.
  final double verticalPadding;

  /// Vertical space between the dialog tail tip and the marker top.
  ///
  /// Negative values overlap the tail onto the marker.
  final double gapAboveMarker;

  /// Marquee speed in points per second when [text] overflows [width].
  ///
  /// Ignored for [MarkerDialogStyle.cloud] (text wraps / scrolls instead).
  final double marqueeSpeed;

  /// Bubble appearance. Defaults to the classic dark pill.
  final MarkerDialogStyle style;

  /// Cloud body width. Fixed so the map bubble and the note composer bubble
  /// are the same shape.
  static const double cloudWidth = 80;

  /// One-line cloud body height; grows when the text wraps further.
  static const double cloudMinHeight = 56;

  /// Detached thought-dot diameter and its gap below the cloud body.
  static const double cloudDotSize = 10;
  static const double cloudDotGap = 2;

  /// Line height multiple used by every cloud bubble.
  static const double cloudLineHeightFactor = 1.2;

  /// Visible lines in [CloudDialogBox] before the text area scrolls.
  static const int cloudMaxVisibleLines = 3;

  /// Figma cloud is 49pt tall and its body ends at y=43 — the rest is the lobe.
  static const double _cloudDesignHeight = 49;
  static const double _cloudBodyDesignHeight = 43;

  String get _resolvedText {
    if (style != MarkerDialogStyle.cloud) return text;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Estimated cloud body size for layout/anchor when [width]/[height] are auto (`0`).
  ///
  /// Mirrors the native bubble: fixed [cloudWidth], height grown from the
  /// wrapped text (up to [cloudMaxVisibleLines], after which the text scrolls).
  static Size estimateCloudBodySize({
    required String text,
    double fontSize = 12,
    double horizontalPadding = 4,
    double verticalPadding = 10,
  }) {
    final String cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final double textWidth =
        (cloudWidth - horizontalPadding * 2).clamp(24.0, cloudWidth);
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: cleaned.isEmpty ? ' ' : cleaned,
        style: TextStyle(
          fontSize: fontSize,
          height: cloudLineHeightFactor,
          fontFamily: '.SF Pro Rounded',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth);

    final double maxVisibleH =
        fontSize * cloudLineHeightFactor * cloudMaxVisibleLines;
    final double visibleH =
        painter.height < maxVisibleH ? painter.height : maxVisibleH;
    final double bodyH = visibleH + verticalPadding * 2;
    final double cloudH =
        bodyH * (_cloudDesignHeight / _cloudBodyDesignHeight);
    return Size(cloudWidth, cloudH < cloudMinHeight ? cloudMinHeight : cloudH);
  }

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'text': _resolvedText,
      'width': width,
      'height': height,
      'backgroundColor': backgroundColor.toARGB32(),
      'textColor': textColor.toARGB32(),
      'fontSize': fontSize,
      'horizontalPadding': horizontalPadding,
      'verticalPadding': verticalPadding,
      'gapAboveMarker': gapAboveMarker,
      'marqueeSpeed': marqueeSpeed,
      'style': style.name,
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
        verticalPadding == other.verticalPadding &&
        gapAboveMarker == other.gapAboveMarker &&
        marqueeSpeed == other.marqueeSpeed &&
        style == other.style;
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
        verticalPadding,
        gapAboveMarker,
        marqueeSpeed,
        style,
      );
}

/// Cloud thought-bubble dialog with frosted-glass fill (iOS).
///
/// Pass to [Annotation.dialog] like [MarkerDialog]. Text wraps inside
/// [MarkerDialog.cloudWidth] minus [horizontalPadding]. Up to
/// [MarkerDialog.cloudMaxVisibleLines] (3) lines are shown; longer text scrolls.
///
/// With default [width]/[height] of `0`, the native bubble uses the shared note
/// bubble metrics: fixed [MarkerDialog.cloudWidth], height grown from the text.
@immutable
class CloudDialogBox extends MarkerDialog {
  const CloudDialogBox({
    required String text,

    /// `0` = [MarkerDialog.cloudWidth]. Set an explicit value to pin that axis.
    double width = 0,

    /// `0` = auto-size to [text]. Set an explicit value to pin that axis.
    double height = 0,

    /// Liquid Glass tint (~80% opacity white). Native forces alpha to 0.80.
    Color backgroundColor = const Color(0xCCFFFFFF),

    /// Text / font color inside the cloud. Defaults to black.
    Color textColor = Colors.black,
    double fontSize = 12,
    double horizontalPadding = 4,
    double verticalPadding = 10,

    /// Space between the thought-dot and the marker top.
    double gapAboveMarker = 8,
    double marqueeSpeed = 16,
  }) : super(
          text: text,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
          textColor: textColor,
          fontSize: fontSize,
          horizontalPadding: horizontalPadding,
          verticalPadding: verticalPadding,
          gapAboveMarker: gapAboveMarker,
          marqueeSpeed: marqueeSpeed,
          style: MarkerDialogStyle.cloud,
        );
}
