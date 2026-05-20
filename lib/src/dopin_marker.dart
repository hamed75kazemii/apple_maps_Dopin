// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Native-rendered marker styles (iOS). Matches Dopin app map markers.
enum DopinMarkerStyle {
  /// Avatar with gradient frame and bottom label (default "Me").
  me,

  /// Circular event pin with shadow and white ring.
  event,

  /// Rounded avatar pin with white border and soft shadow.
  dopin,

  /// Cluster bubble with gradient ring and count (`9+` when count > 9).
  cluster,
}

/// Configuration for a native Dopin marker on Apple Maps (iOS only).
///
/// Image source priority on iOS: [imagePng] → [imageFromAsset] → [imageUrl].
@immutable
class DopinMarker {
  const DopinMarker({
    required this.style,
    this.imageUrl,
    this.imagePng,
    this.imageFromAsset,
    this.label = 'Me',
    this.clusterCount = 1,
    this.primaryColor = const Color(0xFF7B2CBF),
    this.secondPrimaryColor = const Color(0xFFEC30E4),
    this.borderColor = Colors.white,
  });

  /// PNG bytes (e.g. from file, network, or [rootBundle.load]).
  factory DopinMarker.withPng({
    required DopinMarkerStyle style,
    required Uint8List imagePng,
    String? label,
    int clusterCount = 1,
    Color primaryColor = const Color(0xFF7B2CBF),
    Color secondPrimaryColor = const Color(0xFFEC30E4),
    Color borderColor = Colors.white,
  }) {
    return DopinMarker(
      style: style,
      imagePng: imagePng,
      label: label,
      clusterCount: clusterCount,
      primaryColor: primaryColor,
      secondPrimaryColor: secondPrimaryColor,
      borderColor: borderColor,
    );
  }

  /// PNG from a Flutter asset (resolution-aware, same as [BitmapDescriptor.fromAssetImage]).
  static Future<DopinMarker> withAssetImage(
    ImageConfiguration configuration,
    String assetName, {
    required DopinMarkerStyle style,
    AssetBundle? bundle,
    String? package,
    bool mipmaps = true,
    String? label,
    int clusterCount = 1,
    Color primaryColor = const Color(0xFF7B2CBF),
    Color secondPrimaryColor = const Color(0xFFEC30E4),
    Color borderColor = Colors.white,
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
      style: style,
      imageFromAsset: assetJson,
      label: label,
      clusterCount: clusterCount,
      primaryColor: primaryColor,
      secondPrimaryColor: secondPrimaryColor,
      borderColor: borderColor,
    );
  }

  final DopinMarkerStyle style;

  /// Remote image URL.
  final String? imageUrl;

  /// PNG-encoded image bytes.
  final Uint8List? imagePng;

  /// Resolved asset descriptor `[lookupKey, scale]` for the iOS bundle.
  final List<dynamic>? imageFromAsset;

  /// Bottom badge text for [DopinMarkerStyle.me] (e.g. "Me").
  final String? label;

  /// Item count for [DopinMarkerStyle.cluster].
  final int clusterCount;

  final Color primaryColor;
  final Color secondPrimaryColor;

  /// Border / ring color (event & dopin). Cluster ring gradient starts here.
  /// [DopinMarkerStyle.me] frame is always white; label uses [primaryColor]→[secondPrimaryColor].
  final Color borderColor;

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'style': style.name,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imagePng != null) 'imagePng': imagePng,
      if (imageFromAsset != null) 'imageFromAsset': imageFromAsset,
      if (label != null) 'label': label,
      'clusterCount': clusterCount,
      'primaryColor': primaryColor.value,
      'secondPrimaryColor': secondPrimaryColor.value,
      'borderColor': borderColor.value,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DopinMarker) return false;
    final DopinMarker o = other;
    return style == o.style &&
        imageUrl == o.imageUrl &&
        _bytesEqual(imagePng, o.imagePng) &&
        _listEqual(imageFromAsset, o.imageFromAsset) &&
        label == o.label &&
        clusterCount == o.clusterCount &&
        primaryColor == o.primaryColor &&
        secondPrimaryColor == o.secondPrimaryColor &&
        borderColor == o.borderColor;
  }

  @override
  int get hashCode => Object.hash(
        style,
        imageUrl,
        imagePng?.length,
        imageFromAsset == null ? null : Object.hashAll(imageFromAsset!),
        label,
        clusterCount,
        primaryColor,
        secondPrimaryColor,
        borderColor,
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
