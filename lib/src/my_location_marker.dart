// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Optional custom style for the user-location indicator (iOS).
///
/// * With a non-empty [imageUrl]: native [DopinMarker] (avatar, glow, label, …).
/// * Without [imageUrl]: Apple Maps default blue-dot indicator.
@immutable
class MyLocationMarker {
  const MyLocationMarker({
    this.imageUrl,
    this.label = 'Me',
    this.glow = true,
    this.shadow = const MarkerShadow(),
  });

  /// Avatar image URL. When `null` or empty, the default map location dot is used.
  final String? imageUrl;

  /// Bottom badge text. Pass `null` or empty to hide the badge.
  final String? label;

  /// Pulsing glow behind the avatar (custom avatar only).
  final bool glow;

  /// Drop shadow under the marker (custom avatar only).
  final MarkerShadow shadow;

  /// Whether a custom Dopin avatar should replace the default blue dot.
  bool get hasCustomAvatar {
    final String? url = imageUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  static const double _width = 46;
  static const double _height = 46;
  static const double _badgeHeight = 18;
  static const double _badgeOverlap = 8;

  /// Geographic anchor at the avatar center (not the bottom label).
  static const Offset _anchor = Offset(0.5, _height / 2 / (_height + _badgeHeight - _badgeOverlap));

  DopinMarker get _dopinMarker => DopinMarker(
        imageUrls: <String>[imageUrl!],
        label: label,
        width: _width,
        height: _height,
        borderWidth: 3,
        borderColor: Colors.white,
        borderRadius: 12,
        labelColor: const Color(0xFF7B2CBF),
        labelGradientColors: const <Color>[
          Color(0xFFEC30E4),
          Color(0xFF581DFF),
        ],
      );

  Map<String, dynamic> _toJson() {
    assert(hasCustomAvatar);
    return <String, dynamic>{
      'dopinMarker': _dopinMarker._toJson(),
      'anchor': <double>[_anchor.dx, _anchor.dy],
      if (glow) ...<String, dynamic>{
        'glow': true,
        'glowAnchor': <double>[_anchor.dx, _anchor.dy],
      },
      'shadow': shadow._toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MyLocationMarker) return false;
    final MyLocationMarker o = other;
    return imageUrl == o.imageUrl &&
        label == o.label &&
        glow == o.glow &&
        shadow == o.shadow;
  }

  @override
  int get hashCode => Object.hash(imageUrl, label, glow, shadow);
}
