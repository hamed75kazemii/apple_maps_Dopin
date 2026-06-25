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
/// If [borderRadius] is omitted, the marker is drawn as a circle.
@immutable
class DopinMarker {
  const DopinMarker({
    this.imageUrls,
    this.imagePng,
    this.imageFromAsset,
    this.label,
    this.count,
    this.width = 40,
    this.height = 40,
    this.borderWidth = 2,
    this.borderColor = Colors.white,
    this.borderRadius,
    this.labelFontSize = 10,
    this.badgeHeight = 18,
    this.labelColor = const Color(0xFF7B2CBF),
    this.labelGradientColors,
  });

  factory DopinMarker.withPng({
    required Uint8List imagePng,
    String? label,
    int? count,
    double width = 40,
    double height = 40,
    double borderWidth = 2,
    Color borderColor = Colors.white,
    double? borderRadius,
    double labelFontSize = 10,
    double badgeHeight = 18,
    Color labelColor = const Color(0xFF7B2CBF),
    List<Color>? labelGradientColors,
  }) {
    return DopinMarker(
      imagePng: imagePng,
      label: label,
      count: count,
      width: width,
      height: height,
      borderWidth: borderWidth,
      borderColor: borderColor,
      borderRadius: borderRadius,
      labelFontSize: labelFontSize,
      badgeHeight: badgeHeight,
      labelColor: labelColor,
      labelGradientColors: labelGradientColors,
    );
  }

  static Future<DopinMarker> withAssetImage(
    ImageConfiguration configuration,
    String assetName, {
    AssetBundle? bundle,
    String? package,
    bool mipmaps = true,
    String? label,
    int? count,
    double width = 40,
    double height = 40,
    double borderWidth = 2,
    Color borderColor = Colors.white,
    double? borderRadius,
    double labelFontSize = 10,
    double badgeHeight = 18,
    Color labelColor = const Color(0xFF7B2CBF),
    List<Color>? labelGradientColors,
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
      label: label,
      count: count,
      width: width,
      height: height,
      borderWidth: borderWidth,
      borderColor: borderColor,
      borderRadius: borderRadius,
      labelFontSize: labelFontSize,
      badgeHeight: badgeHeight,
      labelColor: labelColor,
      labelGradientColors: labelGradientColors,
    );
  }

  /// Remote image URLs (max 4). Layout: 1 = single, 2 = pill row,
  /// 3 = triangle, 4 = 2×2 grid.
  final List<String>? imageUrls;
  final Uint8List? imagePng;
  final List<dynamic>? imageFromAsset;

  /// Bottom badge; `null` or empty = no badge.
  final String? label;

  /// Top-right count badge. `null` or `<= 0` = hidden. Values above 9 show `9+`.
  final int? count;

  final double width;
  final double height;
  final double borderWidth;
  final Color borderColor;

  /// Outer corner radius. `null` → circle (half of min [width], [height]).
  final double? borderRadius;

  final double labelFontSize;
  final double badgeHeight;
  final Color labelColor;

  /// When set (2+ colors), native iOS draws the badge label with a horizontal gradient.
  final List<Color>? labelGradientColors;

  Map<String, dynamic> _toJson() {
    final Map<String, dynamic> json = <String, dynamic>{
      'width': width,
      'height': height,
      'borderWidth': borderWidth,
      'borderColor': borderColor.value,
      'labelFontSize': labelFontSize,
      'badgeHeight': badgeHeight,
      'labelColor': labelColor.value,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        'imageUrls': imageUrls!.take(4).toList(),
      if (imagePng != null) 'imagePng': imagePng,
      if (imageFromAsset != null) 'imageFromAsset': imageFromAsset,
      if (borderRadius != null) 'borderRadius': borderRadius,
    };
    final String? trimmed = label?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      json['label'] = trimmed;
    }
    if (count != null && count! > 0) {
      json['count'] = count;
    }
    if (labelGradientColors != null && labelGradientColors!.length >= 2) {
      json['labelGradientColors'] =
          labelGradientColors!.map((Color c) => c.value).toList();
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
        label == o.label &&
        count == o.count &&
        width == o.width &&
        height == o.height &&
        borderWidth == o.borderWidth &&
        borderColor == o.borderColor &&
        borderRadius == o.borderRadius &&
        labelFontSize == o.labelFontSize &&
        badgeHeight == o.badgeHeight &&
        labelColor == o.labelColor &&
        _listEqual(labelGradientColors, o.labelGradientColors);
  }

  @override
  int get hashCode => Object.hash(
        imageUrls == null ? null : Object.hashAll(imageUrls!),
        imagePng?.length,
        imageFromAsset == null ? null : Object.hashAll(imageFromAsset!),
        label,
        count,
        width,
        height,
        borderWidth,
        borderColor,
        borderRadius,
        labelFontSize,
        badgeHeight,
        labelColor,
        labelGradientColors == null
            ? null
            : Object.hashAll(labelGradientColors!),
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
