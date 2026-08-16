// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Native Dopin map marker (iOS). Image + optional border + optional bottom label.
///
/// Image priority: [imagePng] → [imageFromAsset] → [imageUrls].
/// [imageUrls] accepts up to 4 URLs; layout adapts to count (1–4).
/// [width] / [height] define the outer frame: 1 and 3–4 images use the full size;
/// 2 images use full [width] and half [height]. Images shrink inside the fixed frame.
/// Default [borderRadius] is `12`. Pass `null` for a full circle.
/// When [emoji] is set, native draws a centered emoji (image content is skipped).
@immutable
class DopinMarker {
  const DopinMarker({
    this.imageUrls,
    this.imagePng,
    this.imageFromAsset,
    this.emoji,
    this.label,
    this.count,
    this.width = 40,
    this.height = 40,
    this.borderWidth = 2,
    this.borderColor = Colors.white,
    this.borderRadius = 12,
    this.liquidGlassBorder = false,
    this.labelFontSize = 10,
    this.badgeHeight = 18,
    this.labelColor = const Color(0xFF7B2CBF),
    this.labelBackgroundColor = Colors.white,
    this.labelGradientColors,
    this.labelBackgroundGradientColors,
  });

  factory DopinMarker.withPng({
    required Uint8List imagePng,
    String? emoji,
    String? label,
    int? count,
    double width = 40,
    double height = 40,
    double borderWidth = 2,
    Color borderColor = Colors.white,
    double? borderRadius = 12,
    bool liquidGlassBorder = false,
    double labelFontSize = 10,
    double badgeHeight = 18,
    Color labelColor = const Color(0xFF7B2CBF),
    Color labelBackgroundColor = Colors.white,
    List<Color>? labelGradientColors,
    List<Color>? labelBackgroundGradientColors,
  }) {
    return DopinMarker(
      imagePng: imagePng,
      emoji: emoji,
      label: label,
      count: count,
      width: width,
      height: height,
      borderWidth: borderWidth,
      borderColor: borderColor,
      borderRadius: borderRadius,
      liquidGlassBorder: liquidGlassBorder,
      labelFontSize: labelFontSize,
      badgeHeight: badgeHeight,
      labelColor: labelColor,
      labelBackgroundColor: labelBackgroundColor,
      labelGradientColors: labelGradientColors,
      labelBackgroundGradientColors: labelBackgroundGradientColors,
    );
  }

  static Future<DopinMarker> withAssetImage(
    ImageConfiguration configuration,
    String assetName, {
    AssetBundle? bundle,
    String? package,
    bool mipmaps = true,
    String? emoji,
    String? label,
    int? count,
    double width = 40,
    double height = 40,
    double borderWidth = 2,
    Color borderColor = Colors.white,
    double? borderRadius = 12,
    bool liquidGlassBorder = false,
    double labelFontSize = 10,
    double badgeHeight = 18,
    Color labelColor = const Color(0xFF7B2CBF),
    Color labelBackgroundColor = Colors.white,
    List<Color>? labelGradientColors,
    List<Color>? labelBackgroundGradientColors,
  }) async {
    List<dynamic> assetJson;
    if (!mipmaps && configuration.devicePixelRatio != null) {
      assetJson = <dynamic>[
        assetName,
        configuration.devicePixelRatio,
      ];
    } else {
      final AssetImage assetImage =
          AssetImage(assetName, package: package, bundle: bundle);
      final AssetBundleImageKey key = await assetImage.obtainKey(configuration);
      assetJson = <dynamic>[key.name, key.scale];
    }
    return DopinMarker(
      imageFromAsset: assetJson,
      emoji: emoji,
      label: label,
      count: count,
      width: width,
      height: height,
      borderWidth: borderWidth,
      borderColor: borderColor,
      borderRadius: borderRadius,
      liquidGlassBorder: liquidGlassBorder,
      labelFontSize: labelFontSize,
      badgeHeight: badgeHeight,
      labelColor: labelColor,
      labelBackgroundColor: labelBackgroundColor,
      labelGradientColors: labelGradientColors,
      labelBackgroundGradientColors: labelBackgroundGradientColors,
    );
  }

  /// Remote image URLs (max 4). Layout for 2–4+ at one location matches the native
  /// cluster stack (rotated avatars; 4+ shows three previews plus a count label).
  final List<String>? imageUrls;
  final Uint8List? imagePng;
  final List<dynamic>? imageFromAsset;

  /// Center emoji glyph. When non-empty, native skips image content and draws
  /// the emoji (optionally on a Liquid Glass disc when [liquidGlassBorder]).
  final String? emoji;

  /// Bottom badge; `null` or empty = no badge.
  final String? label;

  /// Top-right count badge. `null` or `<= 0` = hidden. Values above 9 show `9+`.
  final int? count;

  final double width;
  final double height;
  final double borderWidth;
  final Color borderColor;

  /// Outer corner radius. Defaults to `12`. `null` → circle (half of min [width], [height]).
  final double? borderRadius;

  /// When true, native iOS draws a Liquid Glass ring for the border (iOS 26+;
  /// frosted blur fallback on earlier versions) instead of a solid fill.
  /// With [emoji], draws a full Liquid Glass disc instead of a ring.
  final bool liquidGlassBorder;

  final double labelFontSize;
  final double badgeHeight;
  final Color labelColor;

  /// Background color of the bottom label badge.
  final Color labelBackgroundColor;

  /// When set (2+ colors), native iOS draws the badge label with a horizontal gradient.
  final List<Color>? labelGradientColors;

  /// When set (2+ colors), native iOS fills the badge background with a diagonal
  /// gradient (top-left → bottom-right; overrides [labelBackgroundColor]).
  final List<Color>? labelBackgroundGradientColors;

  Map<String, dynamic> _toJson() {
    final Map<String, dynamic> json = <String, dynamic>{
      'width': width,
      'height': height,
      'borderWidth': borderWidth,
      'borderColor': borderColor.value,
      'labelFontSize': labelFontSize,
      'badgeHeight': badgeHeight,
      'labelColor': labelColor.value,
      'labelBackgroundColor': labelBackgroundColor.value,
      if (liquidGlassBorder) 'liquidGlassBorder': true,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        'imageUrls': imageUrls!.take(4).toList(),
      if (imagePng != null) 'imagePng': imagePng,
      if (imageFromAsset != null) 'imageFromAsset': imageFromAsset,
      if (borderRadius != null) 'borderRadius': borderRadius,
    };
    final String? trimmedEmoji = emoji;
    // Include even when empty — marks native emoji-center pin (vs avatar).
    if (trimmedEmoji != null) {
      json['emoji'] = trimmedEmoji.trim();
    }
    final String? trimmed = label?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      json['label'] = trimmed;
    }
    if (count != null && count! > 0) {
      json['count'] = count;
    }
    if (labelGradientColors != null && labelGradientColors!.length >= 2) {
      json['labelGradientColors'] =
          labelGradientColors!.map((c) => c.value).toList();
    }
    if (labelBackgroundGradientColors != null &&
        labelBackgroundGradientColors!.length >= 2) {
      json['labelBackgroundGradientColors'] =
          labelBackgroundGradientColors!.map((c) => c.value).toList();
    }
    return json;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DopinMarker) return false;
    final DopinMarker o = other;
    return _listEqual(imageUrls, o.imageUrls) &&
        _bytesEqual(imagePng, o.imagePng) &&
        _listEqual(imageFromAsset, o.imageFromAsset) &&
        emoji == o.emoji &&
        label == o.label &&
        count == o.count &&
        width == o.width &&
        height == o.height &&
        borderWidth == o.borderWidth &&
        borderColor == o.borderColor &&
        borderRadius == o.borderRadius &&
        liquidGlassBorder == o.liquidGlassBorder &&
        labelFontSize == o.labelFontSize &&
        badgeHeight == o.badgeHeight &&
        labelColor == o.labelColor &&
        labelBackgroundColor == o.labelBackgroundColor &&
        _listEqual(labelGradientColors, o.labelGradientColors) &&
        _listEqual(
            labelBackgroundGradientColors, o.labelBackgroundGradientColors);
  }

  @override
  int get hashCode => Object.hash(
        imageUrls == null ? null : Object.hashAll(imageUrls!),
        imagePng?.length,
        imageFromAsset == null ? null : Object.hashAll(imageFromAsset!),
        emoji,
        label,
        count,
        width,
        height,
        borderWidth,
        borderColor,
        borderRadius,
        liquidGlassBorder,
        labelFontSize,
        badgeHeight,
        labelColor,
        labelBackgroundColor,
        labelGradientColors == null
            ? null
            : Object.hashAll(labelGradientColors!),
        labelBackgroundGradientColors == null
            ? null
            : Object.hashAll(labelBackgroundGradientColors!),
      );

  static bool _bytesEqual(Uint8List? a, Uint8List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _listEqual(List<dynamic>? a, List<dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
