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
    this.gapAboveMarker = 4,
    this.marqueeSpeed = 16,
    this.style = MarkerDialogStyle.pill,
  }) : assert(width > 0 || style == MarkerDialogStyle.cloud),
       assert(height > 0 || style == MarkerDialogStyle.cloud),
       assert(width >= 0),
       assert(height >= 0),
       assert(fontSize > 0),
       assert(horizontalPadding >= 0),
       assert(marqueeSpeed > 0);

  /// Text shown inside the bubble. Empty / whitespace-only → dialog is hidden.
  final String text;

  /// Bubble body width in points (not including the tail).
  ///
  /// For [MarkerDialogStyle.cloud], `0` means auto-size to [text].
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

  /// Vertical space between the dialog tail tip and the marker top.
  ///
  /// Negative values overlap the tail onto the marker (used by [CloudDialogBox]
  /// so the thought-dot sits on the avatar).
  final double gapAboveMarker;

  /// Marquee speed in points per second when [text] overflows [width].
  ///
  /// Ignored for [MarkerDialogStyle.cloud] (text wraps instead).
  final double marqueeSpeed;

  /// Bubble appearance. Defaults to the classic dark pill.
  final MarkerDialogStyle style;

  /// Max graphemes shown inside a [CloudDialogBox] (pill is unlimited / marquee).
  static const int cloudMaxCharacters = 40;

  /// Max graphemes per line inside a [CloudDialogBox] (hard-wrapped).
  static const int cloudMaxCharactersPerLine = 20;

  String get _resolvedText {
    if (style != MarkerDialogStyle.cloud) return text;
    return _formatCloudText(text);
  }

  /// Clamp to [cloudMaxCharacters] and hard-wrap every [cloudMaxCharactersPerLine].
  static String _formatCloudText(String value) {
    final String cleaned = value
        .replaceAll('\n', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return cleaned;

    final List<int> chars = <int>[];
    for (final int rune in cleaned.runes) {
      if (chars.length >= cloudMaxCharacters) break;
      chars.add(rune);
    }
    if (chars.isEmpty) return '';

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % cloudMaxCharactersPerLine == 0) {
        buffer.write('\n');
      }
      buffer.writeCharCode(chars[i]);
    }
    return buffer.toString();
  }

  /// Estimated cloud body size for layout/anchor when [width]/[height] are auto (`0`).
  static Size estimateCloudBodySize({
    required String text,
    double fontSize = 12,
    double horizontalPadding = 4,
  }) {
    final String formatted = _formatCloudText(text);
    if (formatted.isEmpty) {
      return const Size(52, 36);
    }
    const double minTextWidth = 36;
    const double vPad = 5;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: formatted,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.15,
          fontFamily: '.SF Pro Rounded',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    );
    painter.layout();
    final double textW = painter.width.clamp(minTextWidth, 200.0);
    final double textH = painter.height;
    final double cloudW = (textW + horizontalPadding * 2).clamp(52.0, 200.0);
    final double lobeExtra = textH * 0.18 > 6 ? textH * 0.18 : 6;
    final double cloudH = (textH + vPad * 2 + lobeExtra).clamp(36.0, 140.0);
    return Size(cloudW, cloudH);
  }

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'text': _resolvedText,
      'width': width,
      'height': height,
      'backgroundColor': backgroundColor.value,
      'textColor': textColor.value,
      'fontSize': fontSize,
      'horizontalPadding': horizontalPadding,
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
        gapAboveMarker,
        marqueeSpeed,
        style,
      );
}

/// Cloud thought-bubble dialog with frosted-glass fill (iOS).
///
/// Pass to [Annotation.dialog] like [MarkerDialog]. Matches the Dopin Figma
/// cloud dialog: scalloped cloud body, dotted tail overlapping the marker, and
/// live map blur behind.
///
/// [text] is clamped to [MarkerDialog.cloudMaxCharacters] (40) and hard-wrapped
/// every [MarkerDialog.cloudMaxCharactersPerLine] (20). With default
/// [width]/[height] of `0`, the native bubble sizes itself to the text.
@immutable
class CloudDialogBox extends MarkerDialog {
  const CloudDialogBox({
    required String text,
    /// `0` = auto-size to [text]. Set an explicit value to pin that axis.
    double width = 0,
    /// `0` = auto-size to [text]. Set an explicit value to pin that axis.
    double height = 0,
    /// Frosted tint over the live blur (more transparent = stronger glass).
    Color backgroundColor = const Color(0x28FFFFFF),
    /// Text / font color inside the cloud. Defaults to black.
    Color textColor = Colors.black,
    double fontSize = 12,
    double horizontalPadding = 4,
    /// Slight overlap so the thought-dot still kisses the marker.
    double gapAboveMarker = -5,
    double marqueeSpeed = 16,
  }) : super(
          text: text,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
          textColor: textColor,
          fontSize: fontSize,
          horizontalPadding: horizontalPadding,
          gapAboveMarker: gapAboveMarker,
          marqueeSpeed: marqueeSpeed,
          style: MarkerDialogStyle.cloud,
        );
}
