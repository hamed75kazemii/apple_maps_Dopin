// Copyright 2024 Apple Maps Flutter contributors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Native Dopin "card" map marker (iOS).
///
/// Renders a horizontal callout-style card with a downward tail that points at
/// the annotation [Annotation.position] (use `anchor: Offset(0.5, 1.0)`). The
/// card shows, from left to right:
///
/// * a circular leading [image] ([imagePng] → [imageFromAsset] → [imageUrl]),
/// * a bold [title] with an optional [subtitle] row (optional leading
///   [subtitleIconPng] / [subtitleIconUrl]),
/// * a trailing [distance] string next to a location-pin icon.
///
/// The [distance] is passed through verbatim, so the unit (meters, miles, …) is
/// decided entirely on the Flutter side, e.g. `'2.1 m'` or `'1.3 mi'`.
@immutable
class CardMarker {
  const CardMarker({
    required this.title,
    this.subtitle,
    this.distance,
    this.imageUrl,
    this.imagePng,
    this.imageFromAsset,
    this.subtitleIconUrl,
    this.subtitleIconPng,
    this.distanceIconPng,
    this.showDistanceIcon = true,
    this.backgroundColor = const Color(0xFF1C1C1E),
    this.titleColor = Colors.white,
    this.subtitleColor = const Color(0xFF9E9E9E),
    this.distanceColor = const Color(0xFF9E9E9E),
    this.imageSize = 44,
    this.cornerRadius = 22,
    this.titleFontSize = 17,
    this.subtitleFontSize = 14,
    this.distanceFontSize = 15,
    this.maxWidth = 320,
  });

  /// Convenience factory that draws the leading [image] from a bundled asset.
  static Future<CardMarker> withAssetImage(
    ImageConfiguration configuration,
    String assetName, {
    required String title,
    AssetBundle? bundle,
    String? package,
    bool mipmaps = true,
    String? subtitle,
    String? distance,
    String? subtitleIconUrl,
    Uint8List? subtitleIconPng,
    Uint8List? distanceIconPng,
    bool showDistanceIcon = true,
    Color backgroundColor = const Color(0xFF1C1C1E),
    Color titleColor = Colors.white,
    Color subtitleColor = const Color(0xFF9E9E9E),
    Color distanceColor = const Color(0xFF9E9E9E),
    double imageSize = 44,
    double cornerRadius = 22,
    double titleFontSize = 17,
    double subtitleFontSize = 14,
    double distanceFontSize = 15,
    double maxWidth = 320,
  }) async {
    List<dynamic> assetJson;
    if (!mipmaps && configuration.devicePixelRatio != null) {
      assetJson = <dynamic>[assetName, configuration.devicePixelRatio];
    } else {
      final AssetImage assetImage =
          AssetImage(assetName, package: package, bundle: bundle);
      final AssetBundleImageKey key = await assetImage.obtainKey(configuration);
      assetJson = <dynamic>[key.name, key.scale];
    }
    return CardMarker(
      title: title,
      subtitle: subtitle,
      distance: distance,
      imageFromAsset: assetJson,
      subtitleIconUrl: subtitleIconUrl,
      subtitleIconPng: subtitleIconPng,
      distanceIconPng: distanceIconPng,
      showDistanceIcon: showDistanceIcon,
      backgroundColor: backgroundColor,
      titleColor: titleColor,
      subtitleColor: subtitleColor,
      distanceColor: distanceColor,
      imageSize: imageSize,
      cornerRadius: cornerRadius,
      titleFontSize: titleFontSize,
      subtitleFontSize: subtitleFontSize,
      distanceFontSize: distanceFontSize,
      maxWidth: maxWidth,
    );
  }

  /// Main title, shown bold on the first line.
  final String title;

  /// Optional category / secondary line shown below the [title].
  final String? subtitle;

  /// Trailing distance text. Passed verbatim to the native side, so the unit
  /// (e.g. `'2.1 m'`, `'1.3 mi'`) is entirely up to the Flutter caller.
  final String? distance;

  /// Leading image sources. Priority: [imagePng] → [imageFromAsset] → [imageUrl].
  final String? imageUrl;
  final Uint8List? imagePng;
  final List<dynamic>? imageFromAsset;

  /// Optional small icon drawn before the [subtitle] text.
  final String? subtitleIconUrl;
  final Uint8List? subtitleIconPng;

  /// Optional override for the location-pin icon drawn before [distance].
  /// When `null`, a system pin glyph tinted with [distanceColor] is used.
  final Uint8List? distanceIconPng;

  /// When `false`, no leading icon is drawn before [distance].
  final bool showDistanceIcon;

  final Color backgroundColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color distanceColor;

  /// Diameter of the circular leading image, in points.
  final double imageSize;

  /// Corner radius of the card body, in points.
  final double cornerRadius;

  final double titleFontSize;
  final double subtitleFontSize;
  final double distanceFontSize;

  /// Maximum card width in points. The title/subtitle truncate to fit.
  final double maxWidth;

  Map<String, dynamic> _toJson() {
    final Map<String, dynamic> json = <String, dynamic>{
      'title': title,
      'showDistanceIcon': showDistanceIcon,
      'backgroundColor': backgroundColor.value,
      'titleColor': titleColor.value,
      'subtitleColor': subtitleColor.value,
      'distanceColor': distanceColor.value,
      'imageSize': imageSize,
      'cornerRadius': cornerRadius,
      'titleFontSize': titleFontSize,
      'subtitleFontSize': subtitleFontSize,
      'distanceFontSize': distanceFontSize,
      'maxWidth': maxWidth,
    };

    void addTrimmed(String key, String? value) {
      final String? trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        json[key] = trimmed;
      }
    }

    addTrimmed('subtitle', subtitle);
    addTrimmed('distance', distance);
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      json['imageUrl'] = imageUrl;
    }
    if (imagePng != null) {
      json['imagePng'] = imagePng;
    }
    if (imageFromAsset != null) {
      json['imageFromAsset'] = imageFromAsset;
    }
    if (subtitleIconUrl != null && subtitleIconUrl!.isNotEmpty) {
      json['subtitleIconUrl'] = subtitleIconUrl;
    }
    if (subtitleIconPng != null) {
      json['subtitleIconPng'] = subtitleIconPng;
    }
    if (distanceIconPng != null) {
      json['distanceIconPng'] = distanceIconPng;
    }
    return json;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CardMarker) return false;
    final CardMarker o = other;
    return title == o.title &&
        subtitle == o.subtitle &&
        distance == o.distance &&
        imageUrl == o.imageUrl &&
        _bytesEqual(imagePng, o.imagePng) &&
        _listEqual(imageFromAsset, o.imageFromAsset) &&
        subtitleIconUrl == o.subtitleIconUrl &&
        _bytesEqual(subtitleIconPng, o.subtitleIconPng) &&
        _bytesEqual(distanceIconPng, o.distanceIconPng) &&
        showDistanceIcon == o.showDistanceIcon &&
        backgroundColor == o.backgroundColor &&
        titleColor == o.titleColor &&
        subtitleColor == o.subtitleColor &&
        distanceColor == o.distanceColor &&
        imageSize == o.imageSize &&
        cornerRadius == o.cornerRadius &&
        titleFontSize == o.titleFontSize &&
        subtitleFontSize == o.subtitleFontSize &&
        distanceFontSize == o.distanceFontSize &&
        maxWidth == o.maxWidth;
  }

  @override
  int get hashCode => Object.hash(
        title,
        subtitle,
        distance,
        imageUrl,
        imagePng?.length,
        imageFromAsset == null ? null : Object.hashAll(imageFromAsset!),
        subtitleIconUrl,
        subtitleIconPng?.length,
        distanceIconPng?.length,
        showDistanceIcon,
        backgroundColor,
        titleColor,
        subtitleColor,
        distanceColor,
        imageSize,
        cornerRadius,
        Object.hash(titleFontSize, subtitleFontSize, distanceFontSize, maxWidth),
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
