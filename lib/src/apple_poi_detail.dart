// Copyright 2024 Apple Maps Flutter contributors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Details of a built-in Apple Maps Point Of Interest (POI) that was tapped
/// by the user.
///
/// POI tap detection requires iOS 17+ at runtime and a non-null
/// [AppleMap.onPOITap] handler; on older iOS versions the plugin silently does
/// nothing, and without a handler built-in POI labels are not selectable.
///
/// This mirrors `TapInteraction(StandardPOIs())` from Mapbox: it surfaces the
/// taps the user makes on Apple Maps' own labelled points of interest (cafes,
/// shops, landmarks, etc.) - it does **not** report taps on Flutter-managed
/// [Annotation]s, which continue to use [Annotation.onTap].
@immutable
class ApplePOIDetail {
  const ApplePOIDetail({
    required this.latitude,
    required this.longitude,
    this.name,
    this.category,
    this.icon,
    this.iconPng,
    this.iconColor,
  });

  /// Human-readable POI name as shown on the map (e.g. "Blue Bottle Coffee").
  ///
  /// May be `null` when MapKit didn't supply a title for the selected feature.
  final String? name;

  /// Latitude of the POI in degrees.
  final double latitude;

  /// Longitude of the POI in degrees.
  final double longitude;

  /// Optional POI category identifier derived from `MKPointOfInterestCategory`
  /// (e.g. `"Cafe"`, `"Restaurant"`, `"Museum"`). The `MKPOICategory` prefix is
  /// stripped on the native side before being sent over the channel.
  final String? category;

  /// Icon identifier for client-side icon packs (e.g. Maki), derived from the
  /// POI category in lowercase (e.g. `"cafe"`, `"restaurant"`).
  final String? icon;

  /// Rasterized POI icon from MapKit (`MKIconStyle.image`) as PNG bytes, when
  /// available. Use with [Image.memory] or [BitmapDescriptor.fromBytes].
  final Uint8List? iconPng;

  /// Background tint of the MapKit POI icon as `0xAARRGGBB`, when available.
  final int? iconColor;

  /// Convenience accessor returning [latitude] / [longitude] as a [LatLng].
  LatLng get position => LatLng(latitude, longitude);

  /// Parses an [ApplePOIDetail] from the platform channel payload.
  ///
  /// Returns `null` when the payload is missing required coordinates.
  static ApplePOIDetail? _fromMap(dynamic raw) {
    if (raw == null) return null;
    final Map<dynamic, dynamic> map = raw as Map<dynamic, dynamic>;
    final dynamic lat = map['latitude'];
    final dynamic lng = map['longitude'];
    if (lat is! num || lng is! num) {
      return null;
    }
    return ApplePOIDetail(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      name: map['name'] as String?,
      category: map['category'] as String?,
      icon: map['icon'] as String?,
      iconPng: _iconPngFromMap(map['iconPng']),
      iconColor: _iconColorFromMap(map['iconColor']),
    );
  }

  static Uint8List? _iconPngFromMap(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Uint8List) {
      return raw;
    }
    if (raw is TypedData) {
      return Uint8List.view(raw.buffer, raw.offsetInBytes, raw.lengthInBytes);
    }
    return null;
  }

  static int? _iconColorFromMap(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return null;
  }

  @override
  String toString() =>
      'ApplePOIDetail(name: $name, latitude: $latitude, longitude: $longitude, '
      'category: $category, icon: $icon)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApplePOIDetail &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.category == category &&
        other.icon == icon &&
        _bytesEqual(other.iconPng, iconPng) &&
        other.iconColor == iconColor;
  }

  static bool _bytesEqual(Uint8List? a, Uint8List? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(name, latitude, longitude, category, icon, iconColor);
}
