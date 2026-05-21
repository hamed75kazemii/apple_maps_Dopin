// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Native Dopin map marker (iOS). Image + optional border + optional bottom label.
///
/// Image priority: [imagePng] → [imageFromAsset] → [imageUrl].
/// If [borderRadius] is omitted, the marker is drawn as a circle.
@immutable
class DopinMarker {
  const DopinMarker({
    this.imageUrl,
    this.imagePng,
    this.imageFromAsset,
    this.label,
    this.width = 40,
    this.height = 40,
    this.borderWidth = 2,
    this.borderColor = Colors.white,
    this.borderRadius,
    this.labelFontSize = 10,
    this.badgeHeight = 18,
    this.labelColor = const Color(0xFF7B2CBF),
  });

  factory DopinMarker.withPng({
    required Uint8List imagePng,
    String? label,
    double width = 40,
    double height = 40,
    double borderWidth = 2,
    Color borderColor = Colors.white,
    double? borderRadius,
    double labelFontSize = 10,
    double badgeHeight = 18,
    Color labelColor = const Color(0xFF7B2CBF),
  }) {
    return DopinMarker(
      imagePng: imagePng,
      label: label,
      width: width,
      height: height,
      borderWidth: borderWidth,
      borderColor: borderColor,
      borderRadius: borderRadius,
      labelFontSize: labelFontSize,
      badgeHeight: badgeHeight,
      labelColor: labelColor,
    );
  }

  static Future<DopinMarker> withAssetImage(
    ImageConfiguration configuration,
    String assetName, {
    AssetBundle? bundle,
    String? package,
    bool mipmaps = true,
    String? label,
    double width = 40,
    double height = 40,
    double borderWidth = 2,
    Color borderColor = Colors.white,
    double? borderRadius,
    double labelFontSize = 10,
    double badgeHeight = 18,
    Color labelColor = const Color(0xFF7B2CBF),
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
      width: width,
      height: height,
      borderWidth: borderWidth,
      borderColor: borderColor,
      borderRadius: borderRadius,
      labelFontSize: labelFontSize,
      badgeHeight: badgeHeight,
      labelColor: labelColor,
    );
  }

  final String? imageUrl;
  final Uint8List? imagePng;
  final List<dynamic>? imageFromAsset;

  /// Bottom badge; `null` or empty = no badge.
  final String? label;

  final double width;
  final double height;
  final double borderWidth;
  final Color borderColor;

  /// Outer corner radius. `null` → circle (half of min [width], [height]).
  final double? borderRadius;

  final double labelFontSize;
  final double badgeHeight;
  final Color labelColor;

  Map<String, dynamic> _toJson() {
    final Map<String, dynamic> json = <String, dynamic>{
      'width': width,
      'height': height,
      'borderWidth': borderWidth,
      'borderColor': borderColor.value,
      'labelFontSize': labelFontSize,
      'badgeHeight': badgeHeight,
      'labelColor': labelColor.value,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imagePng != null) 'imagePng': imagePng,
      if (imageFromAsset != null) 'imageFromAsset': imageFromAsset,
      if (borderRadius != null) 'borderRadius': borderRadius,
    };
    final String? trimmed = label?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      json['label'] = trimmed;
    }
    return json;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DopinMarker) return false;
    final DopinMarker o = other;
    return imageUrl == o.imageUrl &&
        _bytesEqual(imagePng, o.imagePng) &&
        _listEqual(imageFromAsset, o.imageFromAsset) &&
        label == o.label &&
        width == o.width &&
        height == o.height &&
        borderWidth == o.borderWidth &&
        borderColor == o.borderColor &&
        borderRadius == o.borderRadius &&
        labelFontSize == o.labelFontSize &&
        badgeHeight == o.badgeHeight &&
        labelColor == o.labelColor;
  }

  @override
  int get hashCode => Object.hash(
        imageUrl,
        imagePng?.length,
        imageFromAsset == null ? null : Object.hashAll(imageFromAsset!),
        label,
        width,
        height,
        borderWidth,
        borderColor,
        borderRadius,
        labelFontSize,
        badgeHeight,
        labelColor,
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
